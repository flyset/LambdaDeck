func makeRuntimeFromInventory(_ inventory: LambdaDeckRuntimeInventory) throws -> any LambdaDeckInferenceRuntime {
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
