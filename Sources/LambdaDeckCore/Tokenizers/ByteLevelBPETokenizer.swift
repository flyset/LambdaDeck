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
            if skipSpecialTokens && self.explicitSpecialTokenIDs.contains(tokenID) {
                flushBytes()
                continue
            }
            if let byte = Self.parseByteToken(token) {
                byteBuffer.append(byte)
                continue
            }
            if token.count == 1, let scalar = token.unicodeScalars.first, scalar.value <= 0xFF {
                byteBuffer.append(UInt8(scalar.value))
                continue
            }
            flushBytes()
            text.append(token)
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
            if let scalar = UnicodeScalar(Int(byte)) {
                let char = String(scalar)
                if self.vocab[char] != nil {
                    tokens.append(char)
                    continue
                }
            }
            tokens.append(Self.byteFallbackToken(byte))
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

    private static func byteFallbackToken(_ byte: UInt8) -> String {
        String(format: "<0x%02X>", byte)
    }

    private static func parseByteToken(_ token: String) -> UInt8? {
        guard token.hasPrefix("<0x"), token.hasSuffix(">"), token.count == 6 else {
            return nil
        }
        let hex = token.dropFirst(3).dropLast(1)
        return UInt8(hex, radix: 16)
    }
}
