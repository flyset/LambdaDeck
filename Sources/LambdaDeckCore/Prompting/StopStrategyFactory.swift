import Foundation

enum StopStrategyFactory {
    static func make(format: LambdaDeckPromptFormat) -> StopStrategy {
        switch format {
        case .gemma3Turns:
            return StopTokenStrategy(tokens: [.eos, .endOfTurn, .eotID, .endOfText])
        case .chatML:
            return StopTokenStrategy(tokens: [.endOfTurn, .eotID, .endOfText, .eos])
        case .chatTranscript, .auto:
            return StopTokenStrategy(
                tokens: [.eos, .endOfText, .eotID],
                strings: ["\nuser:", "\nassistant:", "\nsystem:"]
            )
        }
    }
}
