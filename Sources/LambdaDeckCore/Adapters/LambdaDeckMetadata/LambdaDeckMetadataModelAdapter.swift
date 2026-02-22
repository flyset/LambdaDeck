import Foundation

struct LambdaDeckMetadataModelAdapter: LambdaDeckModelAdapter {
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
