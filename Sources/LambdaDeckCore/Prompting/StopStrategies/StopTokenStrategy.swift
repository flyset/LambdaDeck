import Foundation

struct StopTokenStrategy: StopStrategy {
    let tokens: [SpecialToken]
    let strings: [String]

    init(tokens: [SpecialToken], strings: [String] = []) {
        self.tokens = tokens
        self.strings = strings
    }

    func stopTokenIDs(tokenizer: Tokenizer) -> Set<Int> {
        let ids = tokens.compactMap { tokenizer.specialTokenIDs[$0] }
        return Set(ids)
    }

    func stopStrings() -> [String] {
        strings
    }
}
