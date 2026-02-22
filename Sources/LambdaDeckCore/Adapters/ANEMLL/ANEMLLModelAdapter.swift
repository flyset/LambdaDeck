import Foundation

struct ANEMLLModelAdapter: LambdaDeckModelAdapter {
    let descriptor: LambdaDeckModelAdapterDescriptor
    private let inventory: LambdaDeckRuntimeInventory

    init(modelPath: String, fallbackModelID: String) throws {
        let inventory = try LambdaDeckRuntimeInspector.inspect(modelPath: modelPath)
        self.inventory = inventory

        let promptFormat: LambdaDeckPromptFormat = inventory.architecture == "gemma3" ? .gemma3Turns : .auto
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
