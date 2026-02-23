import Foundation

struct ANEMLLModelAdapter: LambdaDeckModelAdapter {
    let descriptor: LambdaDeckModelAdapterDescriptor
    private let inventory: LambdaDeckRuntimeInventory

    init(modelPath: String, fallbackModelID: String) throws {
        let inventory = try LambdaDeckRuntimeInspector.inspect(modelPath: modelPath)
        self.inventory = inventory

        let architecture = inventory.architecture?.lowercased() ?? ""
        let isGemma3 = architecture == "gemma3"
        let isQwen = architecture.hasPrefix("qwen")

        let promptFormat: LambdaDeckPromptFormat
        let tokenizerFamily: LambdaDeckTokenizerFamily
        let promptSystemPolicy: LambdaDeckPromptSystemPolicy?

        if isGemma3 {
            promptFormat = .gemma3Turns
            tokenizerFamily = .gemmaBPE
            promptSystemPolicy = .prefixFirstUser
        } else if isQwen {
            promptFormat = .chatML
            tokenizerFamily = .bytelevelBPE
            promptSystemPolicy = .ownTurn
        } else {
            promptFormat = .auto
            tokenizerFamily = .unknown
            promptSystemPolicy = nil
        }
        self.descriptor = LambdaDeckModelAdapterDescriptor(
            kind: .anemll,
            adapterID: "anemll.runtime_inspector",
            modelID: fallbackModelID,
            tokenizerDirectory: inventory.tokenizerDirectory.path,
            tokenizerFamily: tokenizerFamily,
            promptFormat: promptFormat,
            promptSystemPolicy: promptSystemPolicy,
            warnings: [],
            executionPlan: LambdaDeckAdapterExecutionPlan(
                prefillMode: inventory.adapterKind == .gemma3Chunked ? "chunked_prefill" : "single_step_prefill",
                decodeMode: "token_by_token",
                outputMode: "logits_to_argmax"
            )
        )
    }

    func makeRuntime() throws -> any LambdaDeckInferenceRuntime {
        try makeRuntimeFromInventory(
            self.inventory,
            descriptor: self.descriptor
        )
    }
}
