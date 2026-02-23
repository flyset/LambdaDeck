import Foundation

public enum LambdaDeckMetadataAdapterKind: String, Codable, Equatable, Sendable {
    case coreMLMonolithic = "coreml.monolithic"
}

public enum LambdaDeckMetadataPromptFormat: String, Codable, Equatable, Sendable {
    case chatTranscript = "chat_transcript"
    case gemma3Turns = "gemma3_turns"
    case chatML = "chatml"
}

public struct LambdaDeckResolvedBundleMetadata: Equatable, Sendable {
    public let modelID: String
    public let adapterKind: LambdaDeckMetadataAdapterKind
    public let tokenizerDirectory: URL
    public let tokenizerFamily: LambdaDeckTokenizerFamily?
    public let monolithicModelPath: URL
    public let contextLength: Int
    public let slidingWindow: Int?
    public let batchSize: Int?
    public let architecture: String?
    public let promptFormat: LambdaDeckMetadataPromptFormat?
    public let promptSystemPolicy: LambdaDeckPromptSystemPolicy?
    public let warnings: [String]

    public init(
        modelID: String,
        adapterKind: LambdaDeckMetadataAdapterKind,
        tokenizerDirectory: URL,
        tokenizerFamily: LambdaDeckTokenizerFamily?,
        monolithicModelPath: URL,
        contextLength: Int,
        slidingWindow: Int?,
        batchSize: Int?,
        architecture: String?,
        promptFormat: LambdaDeckMetadataPromptFormat?,
        promptSystemPolicy: LambdaDeckPromptSystemPolicy?,
        warnings: [String]
    ) {
        self.modelID = modelID
        self.adapterKind = adapterKind
        self.tokenizerDirectory = tokenizerDirectory
        self.tokenizerFamily = tokenizerFamily
        self.monolithicModelPath = monolithicModelPath
        self.contextLength = contextLength
        self.slidingWindow = slidingWindow
        self.batchSize = batchSize
        self.architecture = architecture
        self.promptFormat = promptFormat
        self.promptSystemPolicy = promptSystemPolicy
        self.warnings = warnings
    }
}
