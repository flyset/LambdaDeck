func makeRuntimeFromInventory(
    _ inventory: LambdaDeckRuntimeInventory,
    descriptor: LambdaDeckModelAdapterDescriptor
) throws -> any LambdaDeckInferenceRuntime {
    guard #available(macOS 15.0, *) else {
        throw LambdaDeckRuntimeError.runtimeFailure(
            "Core ML inference runtime requires macOS 15 or newer."
        )
    }

    let selection = LambdaDeckStrategySelector.resolve(from: descriptor)
    let promptStrategy = PromptStrategyFactory.make(
        format: selection.promptFormat,
        systemPolicy: selection.promptSystemPolicy
    )
    let stopStrategy = StopStrategyFactory.make(format: selection.promptFormat)
    let tokenizer = try TokenizerFactory.make(
        family: selection.tokenizerFamily,
        directory: inventory.tokenizerDirectory
    )

    switch inventory.adapterKind {
    case .gemma3Chunked:
        return try Gemma3CoreMLRuntime(
            inventory: inventory,
            tokenizer: tokenizer,
            promptStrategy: promptStrategy,
            stopStrategy: stopStrategy
        )
    case .monolithicCompiled:
        return try MonolithicCoreMLRuntime(
            inventory: inventory,
            tokenizer: tokenizer,
            promptStrategy: promptStrategy,
            stopStrategy: stopStrategy
        )
    }
}
