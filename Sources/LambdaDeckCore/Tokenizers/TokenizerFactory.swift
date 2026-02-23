import Foundation

enum TokenizerFactory {
    static func make(
        family: LambdaDeckTokenizerFamily,
        directory: URL
    ) throws -> any Tokenizer {
        switch family {
        case .gemmaBPE:
            return try GemmaBPETokenizer(directory: directory)
        case .bytelevelBPE:
            return try ByteLevelBPETokenizer(directory: directory)
        case .unknown:
            throw LambdaDeckRuntimeError.invalidModelBundle(
                "Unsupported tokenizer family '\(family.rawValue)'."
            )
        }
    }
}
