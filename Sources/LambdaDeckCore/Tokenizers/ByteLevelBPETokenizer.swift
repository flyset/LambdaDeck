import Foundation

private struct ByteLevelTokenizerConfig: Decodable {
    let bosToken: String?
    let eosToken: String?
    let unkToken: String?

    enum CodingKeys: String, CodingKey {
        case bosToken = "bos_token"
        case eosToken = "eos_token"
        case unkToken = "unk_token"
    }
}

private struct ByteLevelTokenizerJSON: Decodable {
    struct MergePair: Decodable {
        let first: String
        let second: String

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let pair = try? container.decode([String].self), pair.count == 2 {
                self.first = pair[0]
                self.second = pair[1]
                return
            }
            if let pair = try? container.decode(String.self) {
                let parts = pair.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
                if parts.count == 2 {
                    self.first = String(parts[0])
                    self.second = String(parts[1])
                    return
                }
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected merge pair as [String, String] or space-separated string"
            )
        }

        var key: String {
            "\(self.first) \(self.second)"
        }
    }

    struct Model: Decodable {
        let vocab: [String: Int]
        let merges: [MergePair]
    }

    let model: Model
}

final class ByteLevelBPETokenizer: @unchecked Sendable {
    private let vocab: [String: Int]
    private let tokenByID: [Int: String]
    private let mergeRanks: [String: Int]
    private let unknownTokenID: Int
    private let explicitSpecialTokenIDs: Set<Int>
    private let orderedSpecialTokens: [String]
    private var bpeCache: [String: [String]]

    let bosTokenID: Int?
    let eosTokenID: Int?
    let vocabularySize: Int

    private static let byteMaps: (encoder: [UInt8: UnicodeScalar], decoder: [UnicodeScalar: UInt8]) = {
        let ranges: [ClosedRange<UInt8>] = [33...126, 161...172, 174...255]
        var bytes: [UInt8] = []
        bytes.reserveCapacity(188)
        for range in ranges {
            bytes.append(contentsOf: range)
        }
        var used = Set(bytes)
        var encoder: [UInt8: UnicodeScalar] = [:]
        var decoder: [UnicodeScalar: UInt8] = [:]
        for byte in bytes {
            let scalar = UnicodeScalar(Int(byte))!
            encoder[byte] = scalar
            decoder[scalar] = byte
        }
        var nextScalar = 256
        for byte in UInt8.min...UInt8.max where !used.contains(byte) {
            let scalar = UnicodeScalar(nextScalar)!
            encoder[byte] = scalar
            decoder[scalar] = byte
            nextScalar += 1
        }
        return (encoder, decoder)
    }()

    static func byteEncodedScalar(for byte: UInt8) -> UnicodeScalar {
        Self.byteMaps.encoder[byte] ?? UnicodeScalar(Int(byte))!
    }

    init(directory: URL) throws {
        let tokenizerURL = directory.appendingPathComponent("tokenizer.json")
        let configURL = directory.appendingPathComponent("tokenizer_config.json")

        let tokenizerData = try Data(contentsOf: tokenizerURL)
        let rawTokenizer = try JSONDecoder().decode(ByteLevelTokenizerJSON.self, from: tokenizerData)
        let configData = try Data(contentsOf: configURL)
        let config = try JSONDecoder().decode(ByteLevelTokenizerConfig.self, from: configData)

        self.vocab = rawTokenizer.model.vocab
        self.tokenByID = Dictionary(uniqueKeysWithValues: rawTokenizer.model.vocab.map { ($1, $0) })
        self.unknownTokenID = rawTokenizer.model.vocab[config.unkToken ?? "<unk>"] ?? 0
        self.bosTokenID = config.bosToken.flatMap { rawTokenizer.model.vocab[$0] }
        self.eosTokenID = config.eosToken.flatMap { rawTokenizer.model.vocab[$0] }
        self.vocabularySize = (rawTokenizer.model.vocab.values.max() ?? -1) + 1

        var mergeRanks: [String: Int] = [:]
        mergeRanks.reserveCapacity(rawTokenizer.model.merges.count)
        for (index, merge) in rawTokenizer.model.merges.enumerated() {
            mergeRanks[merge.key] = index
        }
        self.mergeRanks = mergeRanks

        let explicitSpecialTokens = [
            "<pad>",
            "<eos>",
            "<bos>",
            "<unk>",
            "<|im_start|>",
            "<|im_end|>",
            "<|endoftext|>",
            "<|eot_id|>",
            "<start_of_image>",
            "<image_soft_token>"
        ]
        self.explicitSpecialTokenIDs = Set(explicitSpecialTokens.compactMap { rawTokenizer.model.vocab[$0] })
        self.orderedSpecialTokens = explicitSpecialTokens
            .filter { rawTokenizer.model.vocab[$0] != nil }
            .sorted { $0.count > $1.count }
        self.bpeCache = [:]
    }

    func tokenID(for token: String) -> Int? {
        self.vocab[token]
    }

    func isSpecial(tokenID: Int) -> Bool {
        self.explicitSpecialTokenIDs.contains(tokenID)
    }

    func encode(_ text: String) -> [Int] {
        if text.isEmpty {
            return []
        }

        var result: [Int] = []
        var plainBuffer = ""
        var index = text.startIndex

        while index < text.endIndex {
            if let matched = matchSpecialToken(in: text, at: index) {
                if !plainBuffer.isEmpty {
                    result.append(contentsOf: encodePlainText(plainBuffer))
                    plainBuffer.removeAll(keepingCapacity: true)
                }
                result.append(matched.id)
                index = matched.endIndex
                continue
            }

            plainBuffer.append(text[index])
            index = text.index(after: index)
        }

        if !plainBuffer.isEmpty {
            result.append(contentsOf: encodePlainText(plainBuffer))
        }

        return result
    }

    func decode(tokenIDs: [Int], skipSpecialTokens: Bool) -> String {
        var text = ""
        var byteBuffer: [UInt8] = []

        func flushBytes() {
            guard !byteBuffer.isEmpty else {
                return
            }
            text.append(String(decoding: byteBuffer, as: UTF8.self))
            byteBuffer.removeAll(keepingCapacity: true)
        }

        for tokenID in tokenIDs {
            guard let token = self.tokenByID[tokenID] else {
                continue
            }
            let isSpecial = self.explicitSpecialTokenIDs.contains(tokenID)
            if isSpecial {
                if skipSpecialTokens {
                    flushBytes()
                    continue
                }
                flushBytes()
                text.append(token)
                continue
            }
            if let byte = Self.parseByteToken(token) {
                byteBuffer.append(byte)
                continue
            }

            var appendedAny = false
            for scalar in token.unicodeScalars {
                if let byte = Self.byteMaps.decoder[scalar] {
                    byteBuffer.append(byte)
                    appendedAny = true
                } else {
                    flushBytes()
                    text.append(String(scalar))
                }
            }

            if !appendedAny {
                flushBytes()
                text.append(token)
            }
        }

        flushBytes()
        return text
    }

    private func matchSpecialToken(in text: String, at index: String.Index) -> (id: Int, endIndex: String.Index)? {
        for token in self.orderedSpecialTokens {
            if text[index...].hasPrefix(token), let tokenID = self.vocab[token] {
                return (id: tokenID, endIndex: text.index(index, offsetBy: token.count))
            }
        }
        return nil
    }

    private func encodePlainText(_ text: String) -> [Int] {
        if text.isEmpty {
            return []
        }

        let tokens = byteTokens(from: text)
        let merged = bpe(tokens)
        return merged.map { self.vocab[$0] ?? self.unknownTokenID }
    }

    private func byteTokens(from text: String) -> [String] {
        var tokens: [String] = []
        tokens.reserveCapacity(text.utf8.count)
        for byte in text.utf8 {
            let scalar = Self.byteMaps.encoder[byte] ?? UnicodeScalar(Int(byte))!
            tokens.append(String(scalar))
        }
        return tokens
    }

    private func bpe(_ tokens: [String]) -> [String] {
        guard tokens.count > 1 else {
            return tokens
        }

        let cacheKey = tokens.joined(separator: " ")
        if let cached = self.bpeCache[cacheKey] {
            return cached
        }

        var word = tokens
        while word.count >= 2 {
            var bestRank = Int.max
            var bestIndex: Int? = nil
            for index in 0..<(word.count - 1) {
                let pair = "\(word[index]) \(word[index + 1])"
                if let rank = self.mergeRanks[pair], rank < bestRank {
                    bestRank = rank
                    bestIndex = index
                }
            }

            guard let index = bestIndex else {
                break
            }
            word[index] = word[index] + word[index + 1]
            word.remove(at: index + 1)
        }

        self.bpeCache[cacheKey] = word
        return word
    }

    private static func parseByteToken(_ token: String) -> UInt8? {
        guard token.hasPrefix("<0x"), token.hasSuffix(">"), token.count == 6 else {
            return nil
        }
        let hex = token.dropFirst(3).dropLast(1)
        return UInt8(hex, radix: 16)
    }
}
