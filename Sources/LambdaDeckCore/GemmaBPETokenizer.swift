import Foundation

struct GemmaTokenizerConfig: Decodable {
    let bosToken: String?
    let eosToken: String?

    enum CodingKeys: String, CodingKey {
        case bosToken = "bos_token"
        case eosToken = "eos_token"
    }
}

private struct GemmaTokenizerJSON: Decodable {
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

final class GemmaBPETokenizer {
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
        let rawTokenizer = try JSONDecoder().decode(GemmaTokenizerJSON.self, from: tokenizerData)
        let configData = try Data(contentsOf: configURL)
        let config = try JSONDecoder().decode(GemmaTokenizerConfig.self, from: configData)

        self.vocab = rawTokenizer.model.vocab
        self.tokenByID = Dictionary(uniqueKeysWithValues: rawTokenizer.model.vocab.map { ($1, $0) })
        self.unknownTokenID = rawTokenizer.model.vocab["<unk>"] ?? 0
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
            "<start_of_turn>",
            "<end_of_turn>",
            "<start_of_image>",
            "<image_soft_token>",
            "<|endoftext|>",
            "<|eot_id|>"
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
            if let byte = Self.parseByteFallbackToken(token) {
                byteBuffer.append(byte)
                continue
            }
            flushBytes()
            text.append(token)
        }

        flushBytes()
        return text.replacingOccurrences(of: "▁", with: " ")
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

        let normalized = text.replacingOccurrences(of: " ", with: "▁")
        if normalized.isEmpty {
            return []
        }

        var tokenIDs: [Int] = []
        for piece in bpe(normalized) {
            if let tokenID = self.vocab[piece] {
                tokenIDs.append(tokenID)
                continue
            }

            for byte in piece.utf8 {
                let byteToken = String(format: "<0x%02X>", byte)
                tokenIDs.append(self.vocab[byteToken] ?? self.unknownTokenID)
            }
        }
        return tokenIDs
    }

    private func bpe(_ token: String) -> [String] {
        if let cached = self.bpeCache[token] {
            return cached
        }

        var word = token.map { String($0) }
        if word.count <= 1 {
            self.bpeCache[token] = word
            return word
        }

        while true {
            var bestRank: Int?
            var bestFirst = ""
            var bestSecond = ""

            if word.count < 2 {
                break
            }

            for index in 0..<(word.count - 1) {
                let first = word[index]
                let second = word[index + 1]
                let pair = "\(first) \(second)"
                guard let rank = self.mergeRanks[pair] else {
                    continue
                }
                if bestRank == nil || rank < bestRank! {
                    bestRank = rank
                    bestFirst = first
                    bestSecond = second
                }
            }

            guard bestRank != nil else {
                break
            }

            var merged: [String] = []
            merged.reserveCapacity(word.count)
            var cursor = 0
            while cursor < word.count {
                if cursor < word.count - 1,
                   word[cursor] == bestFirst,
                   word[cursor + 1] == bestSecond
                {
                    merged.append(bestFirst + bestSecond)
                    cursor += 2
                } else {
                    merged.append(word[cursor])
                    cursor += 1
                }
            }

            word = merged
            if word.count == 1 {
                break
            }
        }

        self.bpeCache[token] = word
        return word
    }

    private static func parseByteFallbackToken(_ token: String) -> UInt8? {
        guard token.count == 6,
              token.hasPrefix("<0x"),
              token.hasSuffix(">")
        else {
            return nil
        }

        let start = token.index(token.startIndex, offsetBy: 3)
        let end = token.index(token.endIndex, offsetBy: -1)
        let hex = String(token[start..<end])
        return UInt8(hex, radix: 16)
    }
}
