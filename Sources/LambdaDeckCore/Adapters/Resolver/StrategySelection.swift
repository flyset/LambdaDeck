import Foundation

public struct LambdaDeckStrategySelection: Equatable, Sendable {
    public let tokenizerFamily: LambdaDeckTokenizerFamily
    public let promptFormat: LambdaDeckPromptFormat
    public let promptSystemPolicy: LambdaDeckPromptSystemPolicy
    public let usedFallback: Bool

    public init(
        tokenizerFamily: LambdaDeckTokenizerFamily,
        promptFormat: LambdaDeckPromptFormat,
        promptSystemPolicy: LambdaDeckPromptSystemPolicy,
        usedFallback: Bool
    ) {
        self.tokenizerFamily = tokenizerFamily
        self.promptFormat = promptFormat
        self.promptSystemPolicy = promptSystemPolicy
        self.usedFallback = usedFallback
    }
}

public enum LambdaDeckStrategySelector {
    public static func resolve(from descriptor: LambdaDeckModelAdapterDescriptor) -> LambdaDeckStrategySelection {
        let resolvedPromptFormat: LambdaDeckPromptFormat
        let usedPromptFallback: Bool

        if descriptor.promptFormat == .auto {
            resolvedPromptFormat = .chatTranscript
            usedPromptFallback = true
        } else {
            resolvedPromptFormat = descriptor.promptFormat
            usedPromptFallback = false
        }

        let resolvedTokenizerFamily: LambdaDeckTokenizerFamily
        let usedTokenizerFallback: Bool
        if descriptor.tokenizerFamily != .unknown {
            resolvedTokenizerFamily = descriptor.tokenizerFamily
            usedTokenizerFallback = false
        } else if resolvedPromptFormat == .gemma3Turns {
            resolvedTokenizerFamily = .gemmaBPE
            usedTokenizerFallback = true
        } else {
            resolvedTokenizerFamily = .bytelevelBPE
            usedTokenizerFallback = true
        }

        let defaultPolicy = resolvedPromptFormat.defaultSystemPolicy ?? .ownTurn
        let resolvedPolicy = descriptor.promptSystemPolicy ?? defaultPolicy

        return LambdaDeckStrategySelection(
            tokenizerFamily: resolvedTokenizerFamily,
            promptFormat: resolvedPromptFormat,
            promptSystemPolicy: resolvedPolicy,
            usedFallback: usedPromptFallback || usedTokenizerFallback
        )
    }
}
