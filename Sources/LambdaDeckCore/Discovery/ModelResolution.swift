import Foundation

public struct LambdaDeckServeOptions: Equatable, Sendable {
    public var host: String
    public var port: Int
    public var stubMode: Bool
    public var modelPath: String?
    public var modelsRoot: String?

    public init(
        host: String = "127.0.0.1",
        port: Int = 8080,
        stubMode: Bool = false,
        modelPath: String? = nil,
        modelsRoot: String? = nil
    ) {
        self.host = host
        self.port = port
        self.stubMode = stubMode
        self.modelPath = modelPath
        self.modelsRoot = modelsRoot
    }
}

public struct LambdaDeckEnvironment: Equatable, Sendable {
    public let values: [String: String]

    public init(values: [String: String]) {
        self.values = values
    }

    public static var processInfo: LambdaDeckEnvironment {
        LambdaDeckEnvironment(values: ProcessInfo.processInfo.environment)
    }

    public subscript(_ key: String) -> String? {
        self.values[key]
    }
}

public enum LambdaDeckModelSelectionSource: String, Equatable, Sendable {
    case stubFlag
    case cliModelPath
    case envModelPath
    case discoveredModelsRoot
}

public struct LambdaDeckResolvedModel: Equatable, Sendable {
    public let modelID: String
    public let modelPath: String?
    public let source: LambdaDeckModelSelectionSource

    public init(modelID: String, modelPath: String?, source: LambdaDeckModelSelectionSource) {
        self.modelID = modelID
        self.modelPath = modelPath
        self.source = source
    }

    public var isStub: Bool {
        self.modelPath == nil
    }
}

public enum LambdaDeckModelResolutionError: Error, Equatable, Sendable {
    case modelPathDoesNotExist(String)
    case invalidModelPath(String)
    case modelsRootNotFound(String)
    case discoveredNoModels(String)
    case discoveredMultipleModels(modelsRoot: String, candidates: [String])
}

extension LambdaDeckModelResolutionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .modelPathDoesNotExist(let path):
            return "Configured --model-path does not exist: \(path)"
        case .invalidModelPath(let path):
            return "Invalid model path '\(path)'. Use a model bundle directory (meta.yaml + tokenizer + .mlmodelc parts) or a single .mlmodelc bundle."
        case .modelsRootNotFound(let path):
            return "Models root not found: \(path). Pass --model-path explicitly."
        case .discoveredNoModels(let root):
            return "No model bundles discovered under '\(root)'. Pass --model-path explicitly."
        case .discoveredMultipleModels(let root, let candidates):
            let joined = candidates.joined(separator: ", ")
            return "Multiple model bundles discovered under '\(root)': \(joined). Pass --model-path explicitly."
        }
    }
}

public enum LambdaDeckModelResolver {
    public static func resolve(
        options: LambdaDeckServeOptions,
        environment: LambdaDeckEnvironment = .processInfo,
        currentDirectory: String = FileManager.default.currentDirectoryPath
    ) throws -> LambdaDeckResolvedModel {
        if options.stubMode {
            return LambdaDeckResolvedModel(
                modelID: StubChatFixtures.modelID,
                modelPath: nil,
                source: .stubFlag
            )
        }

        if let cliModelPath = options.modelPath {
            let resolvedPath = try resolveExplicitModelPath(cliModelPath, currentDirectory: currentDirectory)
            return LambdaDeckResolvedModel(
                modelID: modelID(fromPath: resolvedPath),
                modelPath: resolvedPath,
                source: .cliModelPath
            )
        }

        if let envModelPath = environment["LAMBDADECK_MODEL_PATH"], !envModelPath.isEmpty {
            let resolvedPath = try resolveExplicitModelPath(envModelPath, currentDirectory: currentDirectory)
            return LambdaDeckResolvedModel(
                modelID: modelID(fromPath: resolvedPath),
                modelPath: resolvedPath,
                source: .envModelPath
            )
        }

        let rootInput = options.modelsRoot ?? environment["LAMBDADECK_MODELS_ROOT"] ?? "./Models"
        let rootPath = normalize(path: rootInput, currentDirectory: currentDirectory)
        let candidates = try discoverModelBundles(in: rootPath)
        if candidates.isEmpty {
            throw LambdaDeckModelResolutionError.discoveredNoModels(rootPath)
        }
        if candidates.count > 1 {
            throw LambdaDeckModelResolutionError.discoveredMultipleModels(modelsRoot: rootPath, candidates: candidates)
        }

        let selectedPath = candidates[0]
        return LambdaDeckResolvedModel(
            modelID: modelID(fromPath: selectedPath),
            modelPath: selectedPath,
            source: .discoveredModelsRoot
        )
    }

    private static func resolveExplicitModelPath(_ inputPath: String, currentDirectory: String) throws -> String {
        let path = normalize(path: inputPath, currentDirectory: currentDirectory)
        var isDirectory = ObjCBool(false)
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        guard exists else {
            throw LambdaDeckModelResolutionError.modelPathDoesNotExist(path)
        }
        guard isValidModelBundle(path: path, isDirectory: isDirectory.boolValue) else {
            throw LambdaDeckModelResolutionError.invalidModelPath(path)
        }
        return path
    }

    private static func discoverModelBundles(in modelsRoot: String) throws -> [String] {
        var isDirectory = ObjCBool(false)
        let rootExists = FileManager.default.fileExists(atPath: modelsRoot, isDirectory: &isDirectory)
        guard rootExists, isDirectory.boolValue else {
            throw LambdaDeckModelResolutionError.modelsRootNotFound(modelsRoot)
        }

        let entries = try FileManager.default.contentsOfDirectory(atPath: modelsRoot)
        var candidates: [String] = []
        for entry in entries where !entry.hasPrefix(".") {
            let candidatePath = (modelsRoot as NSString).appendingPathComponent(entry)
            var entryIsDirectory = ObjCBool(false)
            guard FileManager.default.fileExists(atPath: candidatePath, isDirectory: &entryIsDirectory) else {
                continue
            }
            if isValidModelBundle(path: candidatePath, isDirectory: entryIsDirectory.boolValue) {
                candidates.append(candidatePath)
            }
        }
        return candidates.sorted()
    }

    private static func isValidModelBundle(path: String, isDirectory: Bool) -> Bool {
        if path.hasSuffix(".mlmodelc") {
            return true
        }

        guard isDirectory else {
            return false
        }

        let metaPath = (path as NSString).appendingPathComponent("meta.yaml")
        if FileManager.default.fileExists(atPath: metaPath) {
            return true
        }

        do {
            let children = try FileManager.default.contentsOfDirectory(atPath: path)
            return children.contains(where: { $0.hasSuffix(".mlmodelc") })
        } catch {
            return false
        }
    }

    private static func modelID(fromPath path: String) -> String {
        let url = URL(fileURLWithPath: path)
        if url.pathExtension == "mlmodelc" {
            return url.deletingPathExtension().lastPathComponent
        }
        return url.lastPathComponent
    }

    private static func normalize(path input: String, currentDirectory: String) -> String {
        let expanded = (input as NSString).expandingTildeInPath
        let base = URL(fileURLWithPath: currentDirectory, isDirectory: true)
        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded).standardizedFileURL.path
        }
        return URL(fileURLWithPath: expanded, relativeTo: base).standardizedFileURL.path
    }
}
