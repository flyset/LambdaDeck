import Foundation

public enum LambdaDeckModelAdapterKind: String, Equatable, Sendable {
    case anemll
    case lambdaDeckMetadata
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
    public let tokenizerFamily: LambdaDeckTokenizerFamily
    public let promptFormat: LambdaDeckPromptFormat
    public let promptSystemPolicy: LambdaDeckPromptSystemPolicy?
    public let warnings: [String]
    public let executionPlan: LambdaDeckAdapterExecutionPlan

    public init(
        kind: LambdaDeckModelAdapterKind,
        adapterID: String,
        modelID: String,
        tokenizerDirectory: String,
        tokenizerFamily: LambdaDeckTokenizerFamily,
        promptFormat: LambdaDeckPromptFormat,
        promptSystemPolicy: LambdaDeckPromptSystemPolicy?,
        warnings: [String] = [],
        executionPlan: LambdaDeckAdapterExecutionPlan
    ) {
        self.kind = kind
        self.adapterID = adapterID
        self.modelID = modelID
        self.tokenizerDirectory = tokenizerDirectory
        self.tokenizerFamily = tokenizerFamily
        self.promptFormat = promptFormat
        self.promptSystemPolicy = promptSystemPolicy
        self.warnings = warnings
        self.executionPlan = executionPlan
    }
}

public protocol LambdaDeckModelAdapter: Sendable {
    var descriptor: LambdaDeckModelAdapterDescriptor { get }
    func makeRuntime() throws -> any LambdaDeckInferenceRuntime
}
