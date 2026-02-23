import Foundation

public enum LambdaDeckTokenizerFamily: String, Codable, Equatable, Sendable {
    case gemmaBPE = "gemma_bpe"
    case bytelevelBPE = "bytelevel_bpe"
    case unknown
}

public protocol Tokenizer: Sendable {
    var vocabularySize: Int { get }
    var specialTokenIDs: [SpecialToken: Int] { get }

    func encode(text: String) -> [Int]
    func encode(segments: [PromptSegment]) throws -> [Int]
    func decode(tokenIDs: [Int], skipSpecialTokens: Bool) -> String
    func isSpecial(tokenID: Int) -> Bool
}
