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

public enum LambdaDeckModelAdapterResolver {
    public static func resolve(modelPath: String, fallbackModelID: String? = nil) throws -> any LambdaDeckModelAdapter {
        let normalizedModelPath = URL(fileURLWithPath: modelPath).standardizedFileURL.path
        var isDirectory = ObjCBool(false)
        let exists = FileManager.default.fileExists(atPath: normalizedModelPath, isDirectory: &isDirectory)
        guard exists else {
            throw LambdaDeckRuntimeError.unsupportedModelPath("Model path does not exist: \(normalizedModelPath)")
        }

        if isDirectory.boolValue {
            let metadataPath = URL(fileURLWithPath: normalizedModelPath)
                .appendingPathComponent(LambdaDeckBundleMetadataLoader.fileName)
            if FileManager.default.fileExists(atPath: metadataPath.path) {
                return try LambdaDeckMetadataModelAdapter(bundlePath: normalizedModelPath)
            }
        }

        return try ANEMLLModelAdapter(
            modelPath: normalizedModelPath,
            fallbackModelID: fallbackModelID ?? deriveModelID(fromPath: normalizedModelPath)
        )
    }

    private static func deriveModelID(fromPath path: String) -> String {
        let url = URL(fileURLWithPath: path)
        if url.pathExtension == "mlmodelc" {
            return url.deletingPathExtension().lastPathComponent
        }
        return url.lastPathComponent
    }
}

private struct ANEMLLModelAdapter: LambdaDeckModelAdapter {
    let descriptor: LambdaDeckModelAdapterDescriptor
    private let inventory: LambdaDeckRuntimeInventory

    init(modelPath: String, fallbackModelID: String) throws {
        let inventory = try LambdaDeckRuntimeInspector.inspect(modelPath: modelPath)
        self.inventory = inventory

        let promptFormat: LambdaDeckPromptFormat = inventory.adapterKind == .gemma3Chunked ? .gemma3Turns : .auto
        self.descriptor = LambdaDeckModelAdapterDescriptor(
            kind: .anemll,
            adapterID: "anemll.runtime_inspector",
            modelID: fallbackModelID,
            tokenizerDirectory: inventory.tokenizerDirectory.path,
            promptFormat: promptFormat,
            executionPlan: LambdaDeckAdapterExecutionPlan(
                prefillMode: inventory.adapterKind == .gemma3Chunked ? "chunked_prefill" : "single_step_prefill",
                decodeMode: "token_by_token",
                outputMode: "logits_to_argmax"
            )
        )
    }

    func makeRuntime() throws -> any LambdaDeckInferenceRuntime {
        try makeRuntimeFromInventory(self.inventory)
    }
}

private struct LambdaDeckMetadataModelAdapter: LambdaDeckModelAdapter {
    let descriptor: LambdaDeckModelAdapterDescriptor
    private let inventory: LambdaDeckRuntimeInventory

    init(bundlePath: String) throws {
        let metadata = try LambdaDeckBundleMetadataLoader.loadResolved(fromBundlePath: bundlePath)
        guard metadata.adapterKind == .coreMLMonolithic else {
            throw LambdaDeckBundleMetadataError.unsupportedAdapterKind(metadata.adapterKind.rawValue)
        }

        let bundleURL = URL(fileURLWithPath: bundlePath)
        self.inventory = LambdaDeckRuntimeInventory(
            adapterKind: .monolithicCompiled,
            modelRoot: bundleURL,
            tokenizerDirectory: metadata.tokenizerDirectory,
            architecture: metadata.architecture,
            contextLength: metadata.contextLength,
            slidingWindow: metadata.slidingWindow,
            batchSize: metadata.batchSize,
            embeddingsPath: nil,
            lmHeadPath: nil,
            ffnChunkPaths: [],
            monolithicModelPath: metadata.monolithicModelPath
        )

        let promptFormat: LambdaDeckPromptFormat = switch metadata.promptFormat {
        case .chatTranscript:
            .chatTranscript
        case .gemma3Turns:
            .gemma3Turns
        }

        self.descriptor = LambdaDeckModelAdapterDescriptor(
            kind: .lambdaDeckMetadata,
            adapterID: "lambdadeck.bundle.v1",
            modelID: metadata.modelID,
            tokenizerDirectory: metadata.tokenizerDirectory.path,
            promptFormat: promptFormat,
            executionPlan: LambdaDeckAdapterExecutionPlan(
                prefillMode: "single_step_prefill",
                decodeMode: "token_by_token",
                outputMode: "logits_to_argmax"
            )
        )
    }

    func makeRuntime() throws -> any LambdaDeckInferenceRuntime {
        try makeRuntimeFromInventory(self.inventory)
    }
}

private func makeRuntimeFromInventory(_ inventory: LambdaDeckRuntimeInventory) throws -> any LambdaDeckInferenceRuntime {
    guard #available(macOS 15.0, *) else {
        throw LambdaDeckRuntimeError.runtimeFailure(
            "Core ML inference runtime requires macOS 15 or newer."
        )
    }

    switch inventory.adapterKind {
    case .gemma3Chunked:
        return try Gemma3CoreMLRuntime(inventory: inventory)
    case .monolithicCompiled:
        return try MonolithicCoreMLRuntime(inventory: inventory)
    }
}
