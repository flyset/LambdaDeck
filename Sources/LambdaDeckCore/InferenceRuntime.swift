import Foundation

public struct LambdaDeckRuntimeCompletion: Sendable, Equatable {
    public let content: String
    public let finishReason: String
    public let usage: OpenAIUsage

    public init(content: String, finishReason: String, usage: OpenAIUsage) {
        self.content = content
        self.finishReason = finishReason
        self.usage = usage
    }
}

public enum LambdaDeckRuntimeStreamEvent: Sendable, Equatable {
    case token(String)
    case finished(finishReason: String, usage: OpenAIUsage)
}

public protocol LambdaDeckInferenceRuntime: Sendable {
    func complete(request: OpenAIChatCompletionsRequest) async throws -> LambdaDeckRuntimeCompletion
    func stream(request: OpenAIChatCompletionsRequest) -> AsyncThrowingStream<LambdaDeckRuntimeStreamEvent, Error>
}

public struct StubInferenceRuntime: LambdaDeckInferenceRuntime {
    public let completionText: String

    public init(completionText: String = StubChatFixtures.completionText) {
        self.completionText = completionText
    }

    public func complete(request: OpenAIChatCompletionsRequest) async throws -> LambdaDeckRuntimeCompletion {
        LambdaDeckRuntimeCompletion(
            content: self.completionText,
            finishReason: "stop",
            usage: OpenAIUsage(promptTokens: 0, completionTokens: 0, totalTokens: 0)
        )
    }

    public func stream(request: OpenAIChatCompletionsRequest) -> AsyncThrowingStream<LambdaDeckRuntimeStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.token("Stub response "))
            continuation.yield(.token("from LambdaDeck."))
            continuation.yield(
                .finished(
                    finishReason: "stop",
                    usage: OpenAIUsage(promptTokens: 0, completionTokens: 0, totalTokens: 0)
                )
            )
            continuation.finish()
        }
    }
}

public enum LambdaDeckRuntimeError: Error, LocalizedError, Sendable, Equatable {
    case unsupportedModelPath(String)
    case unsupportedArchitecture(String)
    case invalidModelBundle(String)
    case invalidRequest(String)
    case runtimeWarmingUp(String)
    case runtimeFailure(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedModelPath(let message):
            return message
        case .unsupportedArchitecture(let architecture):
            return "Unsupported runtime architecture '\(architecture)'."
        case .invalidModelBundle(let message):
            return message
        case .invalidRequest(let message):
            return message
        case .runtimeWarmingUp(let message):
            return message
        case .runtimeFailure(let message):
            return message
        }
    }
}

enum LambdaDeckRuntimeAdapterKind: Sendable, Equatable {
    case gemma3Chunked
    case monolithicCompiled
}

struct LambdaDeckRuntimeInventory: Sendable, Equatable {
    let adapterKind: LambdaDeckRuntimeAdapterKind
    let modelRoot: URL
    let tokenizerDirectory: URL
    let architecture: String?
    let contextLength: Int
    let slidingWindow: Int?
    let batchSize: Int?
    let embeddingsPath: URL?
    let lmHeadPath: URL?
    let ffnChunkPaths: [URL]
    let monolithicModelPath: URL?
}

enum LambdaDeckRuntimeInspector {
    static func inspect(modelPath: String) throws -> LambdaDeckRuntimeInventory {
        let modelURL = URL(fileURLWithPath: modelPath)
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: modelURL.path, isDirectory: &isDirectory) else {
            throw LambdaDeckRuntimeError.unsupportedModelPath("Model path does not exist: \(modelURL.path)")
        }

        if modelURL.pathExtension == "mlmodelc" {
            return try inspectCompiledModel(at: modelURL)
        }

        guard isDirectory.boolValue else {
            throw LambdaDeckRuntimeError.unsupportedModelPath(
                "Runtime only supports model bundles (directory) or single .mlmodelc paths."
            )
        }

        return try inspectBundle(at: modelURL)
    }

    private static func inspectBundle(at bundleURL: URL) throws -> LambdaDeckRuntimeInventory {
        let tokenizerDirectory = try resolveTokenizerDirectory(around: bundleURL)
        let metaURL = bundleURL.appendingPathComponent("meta.yaml")

        if FileManager.default.fileExists(atPath: metaURL.path) {
            let metaText = try String(contentsOf: metaURL, encoding: .utf8)
            let meta = SimpleMetaYAML.parse(metaText)
            let architecture = meta["model_info.architecture"]?.lowercased() ?? ""
            let contextLength = parseInt(meta["model_info.parameters.context_length"]) ?? 2048
            let slidingWindow = parseInt(meta["model_info.parameters.sliding_window"])
            let batchSize = parseInt(meta["model_info.parameters.batch_size"])

            if let monolithicRelPath = meta["model_info.parameters.monolithic_model"] {
                let monolithicPath = bundleURL.appendingPathComponent(monolithicRelPath)
                if FileManager.default.fileExists(atPath: monolithicPath.path) {
                    return LambdaDeckRuntimeInventory(
                        adapterKind: .monolithicCompiled,
                        modelRoot: bundleURL,
                        tokenizerDirectory: tokenizerDirectory,
                        architecture: architecture.isEmpty ? nil : architecture,
                        contextLength: contextLength,
                        slidingWindow: slidingWindow,
                        batchSize: batchSize,
                        embeddingsPath: nil,
                        lmHeadPath: nil,
                        ffnChunkPaths: [],
                        monolithicModelPath: monolithicPath
                    )
                }
            }

            if architecture == "gemma3" {
                let embeddingsRel = meta["model_info.parameters.embeddings"] ?? ""
                let lmHeadRel = meta["model_info.parameters.lm_head"] ?? ""
                let ffnRel = meta["model_info.parameters.ffn"] ?? ""
                let embeddingsPath = bundleURL.appendingPathComponent(embeddingsRel)
                let lmHeadPath = bundleURL.appendingPathComponent(lmHeadRel)
                let ffnPaths = try resolveChunkedFFNPaths(bundleURL: bundleURL, ffnHintRelativePath: ffnRel)

                guard !embeddingsRel.isEmpty,
                      !lmHeadRel.isEmpty,
                      FileManager.default.fileExists(atPath: embeddingsPath.path),
                      FileManager.default.fileExists(atPath: lmHeadPath.path),
                      !ffnPaths.isEmpty
                else {
                    throw LambdaDeckRuntimeError.invalidModelBundle(
                        "Gemma3 bundle is missing one or more required model parts (embeddings, FFN chunks, LM head)."
                    )
                }

                return LambdaDeckRuntimeInventory(
                    adapterKind: .gemma3Chunked,
                    modelRoot: bundleURL,
                    tokenizerDirectory: tokenizerDirectory,
                    architecture: architecture,
                    contextLength: contextLength,
                    slidingWindow: slidingWindow,
                    batchSize: batchSize,
                    embeddingsPath: embeddingsPath,
                    lmHeadPath: lmHeadPath,
                    ffnChunkPaths: ffnPaths,
                    monolithicModelPath: nil
                )
            }

            throw LambdaDeckRuntimeError.unsupportedArchitecture(architecture)
        }

        let mlmodelcChildren = try listModelChildren(in: bundleURL)
        if mlmodelcChildren.count == 1 {
            return LambdaDeckRuntimeInventory(
                adapterKind: .monolithicCompiled,
                modelRoot: bundleURL,
                tokenizerDirectory: tokenizerDirectory,
                architecture: nil,
                contextLength: 2048,
                slidingWindow: nil,
                batchSize: nil,
                embeddingsPath: nil,
                lmHeadPath: nil,
                ffnChunkPaths: [],
                monolithicModelPath: mlmodelcChildren[0]
            )
        }

        throw LambdaDeckRuntimeError.invalidModelBundle(
            "Model bundle must include meta.yaml for multi-part models, or exactly one .mlmodelc for monolithic models."
        )
    }

    private static func inspectCompiledModel(at modelURL: URL) throws -> LambdaDeckRuntimeInventory {
        let modelRoot = modelURL.deletingLastPathComponent()
        let tokenizerDirectory = try resolveTokenizerDirectory(around: modelRoot)
        let metaURL = modelRoot.appendingPathComponent("meta.yaml")

        var architecture: String?
        var contextLength = 2048
        var slidingWindow: Int?
        var batchSize: Int?

        if FileManager.default.fileExists(atPath: metaURL.path) {
            let metaText = try String(contentsOf: metaURL, encoding: .utf8)
            let meta = SimpleMetaYAML.parse(metaText)
            architecture = meta["model_info.architecture"]?.lowercased()
            contextLength = parseInt(meta["model_info.parameters.context_length"]) ?? contextLength
            slidingWindow = parseInt(meta["model_info.parameters.sliding_window"])
            batchSize = parseInt(meta["model_info.parameters.batch_size"])
        }

        return LambdaDeckRuntimeInventory(
            adapterKind: .monolithicCompiled,
            modelRoot: modelRoot,
            tokenizerDirectory: tokenizerDirectory,
            architecture: architecture,
            contextLength: contextLength,
            slidingWindow: slidingWindow,
            batchSize: batchSize,
            embeddingsPath: nil,
            lmHeadPath: nil,
            ffnChunkPaths: [],
            monolithicModelPath: modelURL
        )
    }

    private static func resolveTokenizerDirectory(around baseDirectory: URL) throws -> URL {
        let candidates = [
            baseDirectory,
            baseDirectory.appendingPathComponent("ios"),
            baseDirectory.deletingLastPathComponent(),
            baseDirectory.deletingLastPathComponent().appendingPathComponent("ios")
        ]
        for candidate in candidates {
            let tokenizerJSON = candidate.appendingPathComponent("tokenizer.json")
            let tokenizerConfig = candidate.appendingPathComponent("tokenizer_config.json")
            if FileManager.default.fileExists(atPath: tokenizerJSON.path),
               FileManager.default.fileExists(atPath: tokenizerConfig.path)
            {
                return candidate
            }
        }
        throw LambdaDeckRuntimeError.invalidModelBundle(
            "Tokenizer assets not found. Expected tokenizer.json and tokenizer_config.json near model bundle."
        )
    }

    private static func resolveChunkedFFNPaths(bundleURL: URL, ffnHintRelativePath: String) throws -> [URL] {
        if !ffnHintRelativePath.isEmpty {
            let hintedURL = bundleURL.appendingPathComponent(ffnHintRelativePath)
            if FileManager.default.fileExists(atPath: hintedURL.path) {
                if let patternRange = hintedURL.lastPathComponent.range(of: #"_chunk_\d+of\d+"#, options: .regularExpression) {
                    let prefix = String(hintedURL.lastPathComponent[..<patternRange.lowerBound])
                    let suffix = String(hintedURL.lastPathComponent[patternRange.upperBound...])
                    let children = try listModelChildren(in: bundleURL)
                    let matches = children.filter { child in
                        let name = child.lastPathComponent
                        return name.hasPrefix(prefix) && name.hasSuffix(suffix) && name.contains("_chunk_")
                    }
                    if !matches.isEmpty {
                        return sortChunkPaths(matches)
                    }
                }
                return [hintedURL]
            }
        }

        let children = try listModelChildren(in: bundleURL)
        let candidates = children.filter { url in
            let name = url.lastPathComponent.lowercased()
            return name.contains("ffn")
        }
        return sortChunkPaths(candidates)
    }

    private static func listModelChildren(in directory: URL) throws -> [URL] {
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return contents.filter { $0.pathExtension == "mlmodelc" }
    }

    private static func sortChunkPaths(_ paths: [URL]) -> [URL] {
        paths.sorted { lhs, rhs in
            let left = chunkIndex(for: lhs.lastPathComponent) ?? Int.max
            let right = chunkIndex(for: rhs.lastPathComponent) ?? Int.max
            if left == right {
                return lhs.lastPathComponent < rhs.lastPathComponent
            }
            return left < right
        }
    }

    private static func chunkIndex(for fileName: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: #"_chunk_(\d+)of\d+"#) else {
            return nil
        }
        let range = NSRange(fileName.startIndex..<fileName.endIndex, in: fileName)
        guard let match = regex.firstMatch(in: fileName, options: [], range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: fileName)
        else {
            return nil
        }
        return Int(fileName[captureRange])
    }

    private static func parseInt(_ value: String?) -> Int? {
        guard let raw = value else {
            return nil
        }
        return Int(raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

enum SimpleMetaYAML {
    static func parse(_ text: String) -> [String: String] {
        var values: [String: String] = [:]
        var stack: [(indent: Int, key: String)] = []

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            let indent = line.prefix { $0 == " " }.count
            while let last = stack.last, indent <= last.indent {
                stack.removeLast()
            }

            guard let colonIndex = trimmed.firstIndex(of: ":") else {
                continue
            }

            let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            var value = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

            if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
                value = String(value.dropFirst().dropLast())
            }

            if value.isEmpty {
                stack.append((indent: indent, key: key))
                continue
            }

            let keyPath = (stack.map(\.key) + [key]).joined(separator: ".")
            values[keyPath] = value
        }

        return values
    }
}

public enum LambdaDeckRuntimeFactory {
    public static func makeRuntime(resolvedModel: LambdaDeckResolvedModel) throws -> (any LambdaDeckInferenceRuntime)? {
        guard !resolvedModel.isStub, let modelPath = resolvedModel.modelPath else {
            return nil
        }

        guard #available(macOS 15.0, *) else {
            throw LambdaDeckRuntimeError.runtimeFailure(
                "Core ML inference runtime requires macOS 15 or newer."
            )
        }

        let inventory = try LambdaDeckRuntimeInspector.inspect(modelPath: modelPath)
        switch inventory.adapterKind {
        case .gemma3Chunked:
            return try Gemma3CoreMLRuntime(inventory: inventory)
        case .monolithicCompiled:
            return try MonolithicCoreMLRuntime(inventory: inventory)
        }
    }
}

public struct LambdaDeckRuntimeReadinessSnapshot: Sendable, Equatable {
    public let status: LambdaDeckReadinessStatus
    public let elapsedMilliseconds: Int
    public let error: String?

    public init(status: LambdaDeckReadinessStatus, elapsedMilliseconds: Int, error: String? = nil) {
        self.status = status
        self.elapsedMilliseconds = elapsedMilliseconds
        self.error = error
    }
}

public actor LambdaDeckRuntimeProvider {
    typealias RuntimeLoader = @Sendable (LambdaDeckResolvedModel) async throws -> (any LambdaDeckInferenceRuntime)?

    private let resolvedModel: LambdaDeckResolvedModel
    private let runtimeLoader: RuntimeLoader
    private var runtime: (any LambdaDeckInferenceRuntime)?
    private var preloadTask: Task<Void, Never>?
    private var preloadStartedAtNanoseconds: UInt64?
    private var isLoading: Bool
    private var cachedError: LambdaDeckRuntimeError?

    public init(resolvedModel: LambdaDeckResolvedModel, preload: Bool = true) {
        self.init(
            resolvedModel: resolvedModel,
            preload: preload,
            runtimeLoader: { resolved in
                try LambdaDeckRuntimeFactory.makeRuntime(resolvedModel: resolved)
            }
        )
    }

    init(
        resolvedModel: LambdaDeckResolvedModel,
        preload: Bool,
        runtimeLoader: @escaping RuntimeLoader
    ) {
        self.resolvedModel = resolvedModel
        self.runtimeLoader = runtimeLoader
        self.runtime = nil
        self.preloadTask = nil
        self.preloadStartedAtNanoseconds = nil
        self.isLoading = false
        self.cachedError = nil
        if preload {
            Task {
                await self.startPreloadIfNeeded()
            }
        }
    }

    public func runtimeInstance(maxWaitNanoseconds: UInt64? = nil) async throws -> (any LambdaDeckInferenceRuntime)? {
        self.startPreloadIfNeeded()

        let startedAt = DispatchTime.now().uptimeNanoseconds
        while true {
            if let runtime {
                return runtime
            }
            if let cachedError {
                throw cachedError
            }

            if !self.isLoading {
                self.startPreloadIfNeeded()
            }

            if let maxWaitNanoseconds {
                let elapsed = DispatchTime.now().uptimeNanoseconds - startedAt
                if elapsed >= maxWaitNanoseconds {
                    throw LambdaDeckRuntimeError.runtimeWarmingUp("runtime is still initializing; retry shortly")
                }
            }

            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    public func readinessSnapshot() -> LambdaDeckRuntimeReadinessSnapshot {
        self.startPreloadIfNeeded()

        let elapsedMilliseconds = self.elapsedMillisecondsSincePreloadStart()
        if self.runtime != nil {
            return LambdaDeckRuntimeReadinessSnapshot(
                status: .ready,
                elapsedMilliseconds: elapsedMilliseconds
            )
        }

        if let cachedError {
            return LambdaDeckRuntimeReadinessSnapshot(
                status: .failed,
                elapsedMilliseconds: elapsedMilliseconds,
                error: cachedError.localizedDescription
            )
        }

        return LambdaDeckRuntimeReadinessSnapshot(
            status: .warmingUp,
            elapsedMilliseconds: elapsedMilliseconds
        )
    }

    private func startPreloadIfNeeded() {
        if self.isLoading || self.runtime != nil || self.cachedError != nil {
            return
        }

        self.isLoading = true
        self.preloadStartedAtNanoseconds = DispatchTime.now().uptimeNanoseconds
        let resolvedModel = self.resolvedModel
        let runtimeLoader = self.runtimeLoader
        self.preloadTask = Task.detached(priority: .utility) {
            let result: Result<(any LambdaDeckInferenceRuntime)?, LambdaDeckRuntimeError>
            do {
                let loaded = try await runtimeLoader(resolvedModel)
                result = .success(loaded)
            } catch let runtimeError as LambdaDeckRuntimeError {
                result = .failure(runtimeError)
            } catch {
                result = .failure(.runtimeFailure("runtime inference initialization failed"))
            }

            await self.finishPreload(result: result)
        }
    }

    private func finishPreload(result: Result<(any LambdaDeckInferenceRuntime)?, LambdaDeckRuntimeError>) {
        self.isLoading = false
        self.preloadTask = nil
        switch result {
        case .success(let loadedRuntime):
            self.runtime = loadedRuntime
            self.cachedError = nil
        case .failure(let error):
            self.runtime = nil
            self.cachedError = error
        }
    }

    private func elapsedMillisecondsSincePreloadStart() -> Int {
        guard let preloadStartedAtNanoseconds else {
            return 0
        }
        let elapsedNanoseconds = DispatchTime.now().uptimeNanoseconds - preloadStartedAtNanoseconds
        return Int(elapsedNanoseconds / 1_000_000)
    }
}
