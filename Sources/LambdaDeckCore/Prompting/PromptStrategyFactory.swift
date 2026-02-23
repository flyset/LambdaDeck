import Foundation

enum PromptStrategyFactory {
    static func make(
        format: LambdaDeckPromptFormat,
        systemPolicy: LambdaDeckPromptSystemPolicy
    ) -> PromptStrategy {
        switch format {
        case .auto, .chatTranscript:
            return ChatTranscriptPromptStrategy()
        case .gemma3Turns:
            return Gemma3PromptStrategy(systemPolicy: systemPolicy)
        case .chatML:
            return ChatMLPromptStrategy(systemPolicy: systemPolicy)
        }
    }
}
