import Foundation

public enum PromptSegment: Equatable, Sendable {
    case text(String)
    case special(SpecialToken)
}

public enum SpecialToken: Equatable, Hashable, Sendable {
    case bos
    case eos
    case startOfTurn(Role)
    case endOfTurn
    case endOfText
    case eotID
    case pad
    case unk
    case startOfImage
    case imageSoftToken
}

public enum Role: String, Equatable, Hashable, Sendable {
    case system
    case user
    case assistant
}

public enum LambdaDeckPromptFormat: String, Equatable, Sendable {
    case auto
    case chatTranscript = "chat_transcript"
    case gemma3Turns = "gemma3_turns"
    case chatML = "chatml"
}

public enum LambdaDeckPromptSystemPolicy: String, Codable, Equatable, Sendable {
    case prefixFirstUser = "prefix_first_user"
    case ownTurn = "own_turn"
}

public protocol PromptStrategy: Sendable {
    func render(messages: [OpenAIChatMessage]) throws -> [PromptSegment]
}

public protocol StopStrategy: Sendable {
    func stopTokenIDs(tokenizer: Tokenizer) -> Set<Int>
    func stopStrings() -> [String]
}

public extension StopStrategy {
    func stopStrings() -> [String] {
        []
    }
}

public extension LambdaDeckPromptFormat {
    var defaultSystemPolicy: LambdaDeckPromptSystemPolicy? {
        switch self {
        case .auto:
            return nil
        case .chatTranscript, .chatML:
            return .ownTurn
        case .gemma3Turns:
            return .prefixFirstUser
        }
    }
}
