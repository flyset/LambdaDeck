import CoreML
import Foundation

@available(macOS 15.0, *)
private struct ChunkInferModels {
    let infer: MLModel
    let inferRotate: MLModel?
}

@available(macOS 15.0, *)
private enum RuntimePromptRenderer {
    static func render(messages: [OpenAIChatMessage], tokenizer: GemmaBPETokenizer) throws -> String {
        if tokenizer.tokenID(for: "<start_of_turn>") != nil, tokenizer.tokenID(for: "<end_of_turn>") != nil {
            return try Gemma3PromptRenderer.render(messages: messages)
        }

        let transcript = messages
            .map { "\($0.role): \($0.content)" }
            .joined(separator: "\n")
        return transcript + "\nassistant:"
    }
}

@available(macOS 15.0, *)
private enum Gemma3PromptRenderer {
    static func render(messages: [OpenAIChatMessage]) throws -> String {
        guard !messages.isEmpty else {
            throw LambdaDeckRuntimeError.invalidRequest("messages must contain at least one message")
        }

        var prompt = "<bos>"
        var loopMessages = messages
        var firstUserPrefix = ""

        if messages[0].role == "system" {
            firstUserPrefix = messages[0].content.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n"
            loopMessages = Array(messages.dropFirst())
        }

        guard !loopMessages.isEmpty else {
            throw LambdaDeckRuntimeError.invalidRequest("at least one user message is required")
        }

        for (index, message) in loopMessages.enumerated() {
            let expectedRole = index % 2 == 0 ? "user" : "assistant"
            guard message.role == expectedRole else {
                throw LambdaDeckRuntimeError.invalidRequest(
                    "Conversation roles must alternate user/assistant/user/assistant... for Gemma models"
                )
            }

            let role = message.role == "assistant" ? "model" : "user"
            prompt += "<start_of_turn>\(role)\n"
            if index == 0, !firstUserPrefix.isEmpty {
                prompt += firstUserPrefix
            }
            prompt += message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            prompt += "<end_of_turn>\n"
        }

        prompt += "<start_of_turn>model\n"
        return prompt
    }
}

@available(macOS 15.0, *)
private enum RuntimeGenerationHelpers {
    static func validateRequest(_ request: OpenAIChatCompletionsRequest) throws {
        if let n = request.n, n != 1 {
            throw LambdaDeckRuntimeError.invalidRequest("Only n=1 is currently supported")
        }
        if let maxTokens = request.maxTokens, maxTokens <= 0 {
            throw LambdaDeckRuntimeError.invalidRequest("max_tokens must be greater than zero")
        }
    }

    static func stopTokenIDs(tokenizer: GemmaBPETokenizer) -> Set<Int> {
        let candidates = [
            tokenizer.eosTokenID,
            tokenizer.tokenID(for: "<end_of_turn>"),
            tokenizer.tokenID(for: "<|eot_id|>"),
            tokenizer.tokenID(for: "<|endoftext|>")
        ]
        return Set(candidates.compactMap { $0 })
    }

    static func stopStrings(from stop: OpenAIStop?) -> [String] {
        switch stop {
        case .none:
            return []
        case .single(let value):
            return value.isEmpty ? [] : [value]
        case .multiple(let values):
            return values.filter { !$0.isEmpty }
        }
    }

    static func maxNewTokens(
        request: OpenAIChatCompletionsRequest,
        promptTokenCount: Int,
        contextLength: Int
    ) throws -> Int {
        let remaining = contextLength - promptTokenCount - 1
        guard remaining > 0 else {
            throw LambdaDeckRuntimeError.invalidRequest(
                "Prompt consumes the model context window (\(contextLength) tokens)."
            )
        }
        let requested = request.maxTokens ?? 256
        return max(1, min(requested, remaining))
    }

    static func findStopStringBoundary(in text: String, stopStrings: [String]) -> String.Index? {
        var earliest: String.Index?
        for stop in stopStrings {
            guard !stop.isEmpty, let range = text.range(of: stop) else {
                continue
            }
            if earliest == nil || range.lowerBound < earliest! {
                earliest = range.lowerBound
            }
        }
        return earliest
    }

    static func delta(newText: String, previousText: String) -> String {
        guard newText.hasPrefix(previousText) else {
            return newText
        }
        return String(newText.dropFirst(previousText.count))
    }

    static func selectNextToken(from provider: any MLFeatureProvider, vocabularySize: Int) throws -> Int {
        if let argmaxIdx = provider.featureValue(for: "argmax_idx")?.multiArrayValue,
           let argmaxVal = provider.featureValue(for: "argmax_val")?.multiArrayValue
        {
            return try selectTokenFromArgmaxOutputs(
                argmaxIndices: argmaxIdx,
                argmaxValues: argmaxVal,
                vocabularySize: vocabularySize
            )
        }

        if let logits = provider.featureValue(for: "output_logits")?.multiArrayValue {
            return try argmaxToken(from: logits, offset: 0, vocabularySize: vocabularySize)
        }

        let splitKeys = provider.featureNames
            .filter { $0.hasPrefix("logits") }
            .sorted { lhs, rhs in
                trailingLogitsIndex(lhs) < trailingLogitsIndex(rhs)
            }

        guard !splitKeys.isEmpty else {
            throw LambdaDeckRuntimeError.runtimeFailure("LM head returned no logits tensors")
        }

        var bestTokenID = 0
        var bestValue = -Float.infinity
        var globalOffset = 0

        for key in splitKeys {
            guard let logits = provider.featureValue(for: key)?.multiArrayValue else {
                continue
            }
            let (localToken, localValue) = try argmaxPair(from: logits, vocabularySize: vocabularySize - globalOffset)
            if localValue > bestValue {
                bestValue = localValue
                bestTokenID = globalOffset + localToken
            }
            globalOffset += logits.count
            if globalOffset >= vocabularySize {
                break
            }
        }

        return max(0, min(bestTokenID, vocabularySize - 1))
    }

    private static func trailingLogitsIndex(_ key: String) -> Int {
        let suffix = key.drop { !$0.isNumber }
        return Int(suffix) ?? 0
    }

    private static func selectTokenFromArgmaxOutputs(
        argmaxIndices: MLMultiArray,
        argmaxValues: MLMultiArray,
        vocabularySize: Int
    ) throws -> Int {
        let count = min(argmaxIndices.count, argmaxValues.count)
        guard count > 0 else {
            throw LambdaDeckRuntimeError.runtimeFailure("argmax output tensors are empty")
        }

        var bestChunk = 0
        var bestChunkValue = -Float.infinity
        for index in 0..<count {
            let value = try readFloat(from: argmaxValues, index: index)
            if value > bestChunkValue {
                bestChunkValue = value
                bestChunk = index
            }
        }

        let localIndex = try readInt(from: argmaxIndices, index: bestChunk)
        let chunkSize = max(1, Int(ceil(Double(vocabularySize) / Double(count))))
        let tokenID = localIndex + bestChunk * chunkSize
        return max(0, min(tokenID, vocabularySize - 1))
    }

    private static func argmaxToken(from logits: MLMultiArray, offset: Int, vocabularySize: Int) throws -> Int {
        let (localToken, _) = try argmaxPair(from: logits, vocabularySize: vocabularySize - offset)
        return offset + localToken
    }

    private static func argmaxPair(from logits: MLMultiArray, vocabularySize: Int) throws -> (Int, Float) {
        let limit = max(0, min(vocabularySize, logits.count))
        guard limit > 0 else {
            throw LambdaDeckRuntimeError.runtimeFailure("No logits available for vocabulary selection")
        }

        var bestToken = 0
        var bestValue = -Float.infinity

        for index in 0..<limit {
            let value = try readFloat(from: logits, index: index)
            if value > bestValue {
                bestValue = value
                bestToken = index
            }
        }
        return (bestToken, bestValue)
    }

    private static func readFloat(from array: MLMultiArray, index: Int) throws -> Float {
        switch array.dataType {
        case .float16:
            let pointer = UnsafeMutablePointer<UInt16>(OpaquePointer(array.dataPointer))
            return Float(Float16(bitPattern: pointer[index]))
        case .float32:
            let pointer = UnsafeMutablePointer<Float>(OpaquePointer(array.dataPointer))
            return pointer[index]
        case .double:
            let pointer = UnsafeMutablePointer<Double>(OpaquePointer(array.dataPointer))
            return Float(pointer[index])
        default:
            throw LambdaDeckRuntimeError.runtimeFailure("Unsupported logits data type: \(array.dataType)")
        }
    }

    private static func readInt(from array: MLMultiArray, index: Int) throws -> Int {
        switch array.dataType {
        case .int32:
            let pointer = UnsafeMutablePointer<Int32>(OpaquePointer(array.dataPointer))
            return Int(pointer[index])
        case .float16:
            let pointer = UnsafeMutablePointer<UInt16>(OpaquePointer(array.dataPointer))
            return Int(Float16(bitPattern: pointer[index]))
        case .float32:
            let pointer = UnsafeMutablePointer<Float>(OpaquePointer(array.dataPointer))
            return Int(pointer[index])
        case .double:
            let pointer = UnsafeMutablePointer<Double>(OpaquePointer(array.dataPointer))
            return Int(pointer[index])
        default:
            throw LambdaDeckRuntimeError.runtimeFailure("Unsupported argmax index data type: \(array.dataType)")
        }
    }
}

@available(macOS 15.0, *)
private enum RuntimeInputBuilders {
    static func makeInt32Array(shape: [Int], values: [Int32]) throws -> MLMultiArray {
        let nsShape = shape.map { NSNumber(value: $0) }
        let array = try MLMultiArray(shape: nsShape, dataType: .int32)
        let pointer = UnsafeMutablePointer<Int32>(OpaquePointer(array.dataPointer))
        for index in 0..<values.count {
            pointer[index] = values[index]
        }
        return array
    }

    static func makeCausalMask(position: Int, contextLength: Int) throws -> MLMultiArray {
        let mask = try MLMultiArray(shape: [1, 1, 1, NSNumber(value: contextLength)], dataType: .float16)
        let pointer = UnsafeMutablePointer<UInt16>(OpaquePointer(mask.dataPointer))
        let zero = Float16(0).bitPattern
        let negativeInfinity = Float16(-Float.greatestFiniteMagnitude).bitPattern
        for column in 0..<contextLength {
            pointer[column] = column <= position ? zero : negativeInfinity
        }
        return mask
    }

    static func makeTokenStepInputs(tokenID: Int, position: Int, contextLength: Int) throws -> (
        inputIDs: MLMultiArray,
        positionIDs: MLMultiArray,
        currentPos: MLMultiArray,
        causalMask: MLMultiArray
    ) {
        let inputIDs = try makeInt32Array(shape: [1, 1], values: [Int32(tokenID)])
        let positionIDs = try makeInt32Array(shape: [1], values: [Int32(position)])
        let currentPos = try makeInt32Array(shape: [1], values: [Int32(position)])
        let causalMask = try makeCausalMask(position: position, contextLength: contextLength)
        return (inputIDs, positionIDs, currentPos, causalMask)
    }
}

@available(macOS 15.0, *)
actor Gemma3CoreMLRuntime: LambdaDeckInferenceRuntime {
    private let tokenizer: GemmaBPETokenizer
    private let embeddingsModel: MLModel
    private let lmHeadModel: MLModel
    private let chunkModels: [ChunkInferModels]
    private let contextLength: Int
    private let slidingWindow: Int?

    init(inventory: LambdaDeckRuntimeInventory) throws {
        guard inventory.adapterKind == .gemma3Chunked,
              let embeddingsPath = inventory.embeddingsPath,
              let lmHeadPath = inventory.lmHeadPath,
              !inventory.ffnChunkPaths.isEmpty
        else {
            throw LambdaDeckRuntimeError.invalidModelBundle("Invalid Gemma3 runtime inventory")
        }

        self.contextLength = inventory.contextLength
        self.slidingWindow = inventory.slidingWindow
        self.tokenizer = try GemmaBPETokenizer(directory: inventory.tokenizerDirectory)

        self.embeddingsModel = try Self.loadModel(url: embeddingsPath, functionName: nil)
        self.lmHeadModel = try Self.loadModel(url: lmHeadPath, functionName: nil)

        var chunks: [ChunkInferModels] = []
        chunks.reserveCapacity(inventory.ffnChunkPaths.count)
        for chunkPath in inventory.ffnChunkPaths {
            let infer = try Self.loadModel(url: chunkPath, functionName: "infer")
            let inferRotate = try? Self.loadModel(url: chunkPath, functionName: "infer_rotate")
            chunks.append(ChunkInferModels(infer: infer, inferRotate: inferRotate))
        }
        self.chunkModels = chunks
    }

    func complete(request: OpenAIChatCompletionsRequest) async throws -> LambdaDeckRuntimeCompletion {
        try await self.generate(request: request, onToken: nil)
    }

    nonisolated func stream(request: OpenAIChatCompletionsRequest) -> AsyncThrowingStream<LambdaDeckRuntimeStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let completion = try await self.generate(request: request) { token in
                        continuation.yield(.token(token))
                    }
                    continuation.yield(.finished(finishReason: completion.finishReason, usage: completion.usage))
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    private func generate(
        request: OpenAIChatCompletionsRequest,
        onToken: (@Sendable (String) -> Void)?
    ) async throws -> LambdaDeckRuntimeCompletion {
        try RuntimeGenerationHelpers.validateRequest(request)

        let prompt = try RuntimePromptRenderer.render(messages: request.messages, tokenizer: self.tokenizer)
        var tokenIDs = self.tokenizer.encode(prompt)
        guard !tokenIDs.isEmpty else {
            throw LambdaDeckRuntimeError.invalidRequest("Prompt tokenization produced an empty token sequence")
        }
        let promptTokenCount = tokenIDs.count

        let maxNewTokens = try RuntimeGenerationHelpers.maxNewTokens(
            request: request,
            promptTokenCount: tokenIDs.count,
            contextLength: self.contextLength
        )
        let stopTokenIDs = RuntimeGenerationHelpers.stopTokenIDs(tokenizer: self.tokenizer)
        let stopStrings = RuntimeGenerationHelpers.stopStrings(from: request.stop)

        let state = self.chunkModels[0].infer.makeState()

        var lastLogits: (any MLFeatureProvider)?
        for (position, tokenID) in tokenIDs.enumerated() {
            try Task.checkCancellation()
            lastLogits = try self.chunkedStep(
                tokenID: tokenID,
                position: position,
                state: state
            )
        }

        guard let initialLogits = lastLogits else {
            throw LambdaDeckRuntimeError.runtimeFailure("Failed to compute initial logits after prefill")
        }

        var logitsProvider = initialLogits
        var completionTokenIDs: [Int] = []
        var completionText = ""
        var finishReason = "stop"

        for _ in 0..<maxNewTokens {
            try Task.checkCancellation()

            let nextToken = try RuntimeGenerationHelpers.selectNextToken(
                from: logitsProvider,
                vocabularySize: self.tokenizer.vocabularySize
            )
            completionTokenIDs.append(nextToken)
            let nextTokenPosition = tokenIDs.count
            tokenIDs.append(nextToken)

            let decoded = self.tokenizer.decode(tokenIDs: completionTokenIDs, skipSpecialTokens: true)
            if let boundary = RuntimeGenerationHelpers.findStopStringBoundary(in: decoded, stopStrings: stopStrings) {
                let truncated = String(decoded[..<boundary])
                let delta = RuntimeGenerationHelpers.delta(newText: truncated, previousText: completionText)
                if !delta.isEmpty {
                    onToken?(delta)
                }
                completionText = truncated
                finishReason = "stop"
                break
            }

            let delta = RuntimeGenerationHelpers.delta(newText: decoded, previousText: completionText)
            if !delta.isEmpty {
                onToken?(delta)
            }
            completionText = decoded

            if stopTokenIDs.contains(nextToken) {
                finishReason = "stop"
                break
            }

            if tokenIDs.count >= self.contextLength {
                finishReason = "length"
                break
            }

            logitsProvider = try self.chunkedStep(
                tokenID: nextToken,
                position: nextTokenPosition,
                state: state
            )

            if completionTokenIDs.count >= maxNewTokens {
                finishReason = "length"
                break
            }
        }

        let usage = OpenAIUsage(
            promptTokens: promptTokenCount,
            completionTokens: completionTokenIDs.count,
            totalTokens: promptTokenCount + completionTokenIDs.count
        )
        return LambdaDeckRuntimeCompletion(content: completionText, finishReason: finishReason, usage: usage)
    }

    private func chunkedStep(tokenID: Int, position: Int, state: MLState) throws -> any MLFeatureProvider {
        let inputs = try RuntimeInputBuilders.makeTokenStepInputs(
            tokenID: tokenID,
            position: position,
            contextLength: self.contextLength
        )

        let embeddingInput = try MLDictionaryFeatureProvider(dictionary: [
            "input_ids": MLFeatureValue(multiArray: inputs.inputIDs)
        ])
        let embeddingOutput = try self.embeddingsModel.prediction(from: embeddingInput)
        guard var hiddenStates = embeddingOutput.featureValue(for: "hidden_states")?.multiArrayValue else {
            throw LambdaDeckRuntimeError.runtimeFailure("Embeddings model did not return hidden_states")
        }

        for chunk in self.chunkModels {
            let useRotate = self.slidingWindow != nil
                && position >= self.slidingWindow!
                && chunk.inferRotate != nil
            let activeModel = useRotate ? chunk.inferRotate! : chunk.infer

            let chunkInput = try MLDictionaryFeatureProvider(dictionary: [
                "hidden_states": MLFeatureValue(multiArray: hiddenStates),
                "position_ids": MLFeatureValue(multiArray: inputs.positionIDs),
                "causal_mask": MLFeatureValue(multiArray: inputs.causalMask),
                "current_pos": MLFeatureValue(multiArray: inputs.currentPos)
            ])
            let chunkOutput = try activeModel.prediction(
                from: chunkInput,
                using: state,
                options: MLPredictionOptions()
            )
            guard let nextHidden = chunkOutput.featureValue(for: "output_hidden_states")?.multiArrayValue else {
                throw LambdaDeckRuntimeError.runtimeFailure("FFN chunk model did not return output_hidden_states")
            }
            hiddenStates = nextHidden
        }

        let lmHeadInput = try MLDictionaryFeatureProvider(dictionary: [
            "hidden_states": MLFeatureValue(multiArray: hiddenStates)
        ])
        return try self.lmHeadModel.prediction(from: lmHeadInput)
    }

    private static func loadModel(url: URL, functionName: String?) throws -> MLModel {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine
        if let functionName {
            config.functionName = functionName
        }
        return try MLModel(contentsOf: url, configuration: config)
    }
}

@available(macOS 15.0, *)
actor MonolithicCoreMLRuntime: LambdaDeckInferenceRuntime {
    private let tokenizer: GemmaBPETokenizer
    private let inferModel: MLModel
    private let inferRotateModel: MLModel?
    private let contextLength: Int
    private let slidingWindow: Int?

    init(inventory: LambdaDeckRuntimeInventory) throws {
        guard inventory.adapterKind == .monolithicCompiled,
              let modelPath = inventory.monolithicModelPath
        else {
            throw LambdaDeckRuntimeError.invalidModelBundle("Invalid monolithic runtime inventory")
        }

        self.tokenizer = try GemmaBPETokenizer(directory: inventory.tokenizerDirectory)
        self.contextLength = inventory.contextLength
        self.slidingWindow = inventory.slidingWindow

        self.inferModel = try Self.loadModel(url: modelPath, functionName: "infer", allowFallbackDefault: true)
        self.inferRotateModel = try? Self.loadModel(url: modelPath, functionName: "infer_rotate", allowFallbackDefault: false)
    }

    func complete(request: OpenAIChatCompletionsRequest) async throws -> LambdaDeckRuntimeCompletion {
        try await self.generate(request: request, onToken: nil)
    }

    nonisolated func stream(request: OpenAIChatCompletionsRequest) -> AsyncThrowingStream<LambdaDeckRuntimeStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let completion = try await self.generate(request: request) { token in
                        continuation.yield(.token(token))
                    }
                    continuation.yield(.finished(finishReason: completion.finishReason, usage: completion.usage))
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    private func generate(
        request: OpenAIChatCompletionsRequest,
        onToken: (@Sendable (String) -> Void)?
    ) async throws -> LambdaDeckRuntimeCompletion {
        try RuntimeGenerationHelpers.validateRequest(request)

        let prompt = try RuntimePromptRenderer.render(messages: request.messages, tokenizer: self.tokenizer)
        var tokenIDs = self.tokenizer.encode(prompt)
        guard !tokenIDs.isEmpty else {
            throw LambdaDeckRuntimeError.invalidRequest("Prompt tokenization produced an empty token sequence")
        }
        let promptTokenCount = tokenIDs.count

        let maxNewTokens = try RuntimeGenerationHelpers.maxNewTokens(
            request: request,
            promptTokenCount: tokenIDs.count,
            contextLength: self.contextLength
        )
        let stopTokenIDs = RuntimeGenerationHelpers.stopTokenIDs(tokenizer: self.tokenizer)
        let stopStrings = RuntimeGenerationHelpers.stopStrings(from: request.stop)

        let state = self.inferModel.makeState()

        var lastLogits: (any MLFeatureProvider)?
        for (position, tokenID) in tokenIDs.enumerated() {
            try Task.checkCancellation()
            lastLogits = try self.monolithicStep(
                tokenID: tokenID,
                position: position,
                state: state
            )
        }

        guard let initialLogits = lastLogits else {
            throw LambdaDeckRuntimeError.runtimeFailure("Failed to compute initial logits after prefill")
        }

        var logitsProvider = initialLogits
        var completionTokenIDs: [Int] = []
        var completionText = ""
        var finishReason = "stop"

        for _ in 0..<maxNewTokens {
            try Task.checkCancellation()

            let nextToken = try RuntimeGenerationHelpers.selectNextToken(
                from: logitsProvider,
                vocabularySize: self.tokenizer.vocabularySize
            )
            completionTokenIDs.append(nextToken)
            let nextTokenPosition = tokenIDs.count
            tokenIDs.append(nextToken)

            let decoded = self.tokenizer.decode(tokenIDs: completionTokenIDs, skipSpecialTokens: true)
            if let boundary = RuntimeGenerationHelpers.findStopStringBoundary(in: decoded, stopStrings: stopStrings) {
                let truncated = String(decoded[..<boundary])
                let delta = RuntimeGenerationHelpers.delta(newText: truncated, previousText: completionText)
                if !delta.isEmpty {
                    onToken?(delta)
                }
                completionText = truncated
                finishReason = "stop"
                break
            }

            let delta = RuntimeGenerationHelpers.delta(newText: decoded, previousText: completionText)
            if !delta.isEmpty {
                onToken?(delta)
            }
            completionText = decoded

            if stopTokenIDs.contains(nextToken) {
                finishReason = "stop"
                break
            }

            if tokenIDs.count >= self.contextLength {
                finishReason = "length"
                break
            }

            logitsProvider = try self.monolithicStep(
                tokenID: nextToken,
                position: nextTokenPosition,
                state: state
            )

            if completionTokenIDs.count >= maxNewTokens {
                finishReason = "length"
                break
            }
        }

        let usage = OpenAIUsage(
            promptTokens: promptTokenCount,
            completionTokens: completionTokenIDs.count,
            totalTokens: promptTokenCount + completionTokenIDs.count
        )
        return LambdaDeckRuntimeCompletion(content: completionText, finishReason: finishReason, usage: usage)
    }

    private func monolithicStep(tokenID: Int, position: Int, state: MLState) throws -> any MLFeatureProvider {
        let inputs = try RuntimeInputBuilders.makeTokenStepInputs(
            tokenID: tokenID,
            position: position,
            contextLength: self.contextLength
        )

        let useRotate = self.slidingWindow != nil
            && position >= self.slidingWindow!
            && self.inferRotateModel != nil
        let activeModel = useRotate ? self.inferRotateModel! : self.inferModel

        let modelInput = try MLDictionaryFeatureProvider(dictionary: [
            "input_ids": MLFeatureValue(multiArray: inputs.inputIDs),
            "position_ids": MLFeatureValue(multiArray: inputs.positionIDs),
            "causal_mask": MLFeatureValue(multiArray: inputs.causalMask),
            "current_pos": MLFeatureValue(multiArray: inputs.currentPos)
        ])
        return try activeModel.prediction(from: modelInput, using: state, options: MLPredictionOptions())
    }

    private static func loadModel(url: URL, functionName: String, allowFallbackDefault: Bool) throws -> MLModel {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine
        config.functionName = functionName

        do {
            return try MLModel(contentsOf: url, configuration: config)
        } catch {
            guard allowFallbackDefault else {
                throw error
            }
            let fallback = MLModelConfiguration()
            fallback.computeUnits = .cpuAndNeuralEngine
            return try MLModel(contentsOf: url, configuration: fallback)
        }
    }
}
