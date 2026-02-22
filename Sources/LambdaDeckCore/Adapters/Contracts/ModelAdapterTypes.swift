import Foundation

public enum LambdaDeckModelAdapterKind: String, Equatable, Sendable {
    case anemll
    case lambdaDeckMetadata
}

public enum LambdaDeckPromptFormat: String, Equatable, Sendable {
    case auto
    case chatTranscript = "chat_transcript"
    case gemma3Turns = "gemma3_turns"
}

public struct LambdaDeckAdapterExecutionPlan: Equatable, Sendable {
    public let prefillMode: String
    public let decodeMode: String
    public let outputMode: String

    public init(prefillMode: String, decodeMode: String, outputMode: String) {
        self.prefillMode = prefillMode
        self.decodeMode = decodeMode
        self.outputMode = outputMode
    }
}

public struct LambdaDeckModelAdapterDescriptor: Equatable, Sendable {
    public let kind: LambdaDeckModelAdapterKind
    public let adapterID: String
    public let modelID: String
    public let tokenizerDirectory: String
    public let promptFormat: LambdaDeckPromptFormat
    public let executionPlan: LambdaDeckAdapterExecutionPlan

    public init(
        kind: LambdaDeckModelAdapterKind,
        adapterID: String,
        modelID: String,
        tokenizerDirectory: String,
        promptFormat: LambdaDeckPromptFormat,
        executionPlan: LambdaDeckAdapterExecutionPlan
    ) {
        self.kind = kind
        self.adapterID = adapterID
        self.modelID = modelID
        self.tokenizerDirectory = tokenizerDirectory
        self.promptFormat = promptFormat
        self.executionPlan = executionPlan
    }
}

public protocol LambdaDeckModelAdapter: Sendable {
    var descriptor: LambdaDeckModelAdapterDescriptor { get }
    func makeRuntime() throws -> any LambdaDeckInferenceRuntime
}
