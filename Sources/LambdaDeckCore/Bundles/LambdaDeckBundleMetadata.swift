import Foundation

public enum LambdaDeckMetadataAdapterKind: String, Codable, Equatable, Sendable {
    case coreMLMonolithic = "coreml.monolithic"
}

public enum LambdaDeckMetadataPromptFormat: String, Codable, Equatable, Sendable {
    case chatTranscript = "chat_transcript"
    case gemma3Turns = "gemma3_turns"
}

public struct LambdaDeckResolvedBundleMetadata: Equatable, Sendable {
    public let modelID: String
    public let adapterKind: LambdaDeckMetadataAdapterKind
    public let tokenizerDirectory: URL
    public let monolithicModelPath: URL
    public let contextLength: Int
    public let slidingWindow: Int?
    public let batchSize: Int?
    public let architecture: String?
    public let promptFormat: LambdaDeckMetadataPromptFormat

    public init(
        modelID: String,
        adapterKind: LambdaDeckMetadataAdapterKind,
        tokenizerDirectory: URL,
        monolithicModelPath: URL,
        contextLength: Int,
        slidingWindow: Int?,
        batchSize: Int?,
        architecture: String?,
        promptFormat: LambdaDeckMetadataPromptFormat
    ) {
        self.modelID = modelID
        self.adapterKind = adapterKind
        self.tokenizerDirectory = tokenizerDirectory
        self.monolithicModelPath = monolithicModelPath
        self.contextLength = contextLength
        self.slidingWindow = slidingWindow
        self.batchSize = batchSize
        self.architecture = architecture
        self.promptFormat = promptFormat
    }
}

public enum LambdaDeckBundleMetadataError: Error, LocalizedError, Equatable, Sendable {
    case invalidBundlePath(String)
    case metadataFileMissing(String)
    case invalidMetadataJSON(path: String, message: String)
    case unsupportedSchemaVersion(Int)
    case missingModelID
    case unsupportedAdapterKind(String)
    case unsupportedPromptFormat(String)
    case missingMonolithicModelPath
    case missingTokenizerAssets(path: String)
    case referencedModelPathMissing(path: String)

    public var errorDescription: String? {
        switch self {
        case .invalidBundlePath(let path):
            return "Invalid bundle path: \(path). Expected a directory."
        case .metadataFileMissing(let path):
            return "Bundle metadata file not found: \(path)."
        case .invalidMetadataJSON(let path, let message):
            return "Invalid bundle metadata JSON at '\(path)': \(message)"
        case .unsupportedSchemaVersion(let version):
            return "Unsupported bundle metadata schema_version '\(version)'. Supported: 1."
        case .missingModelID:
            return "Bundle metadata must include a non-empty model.id field."
        case .unsupportedAdapterKind(let kind):
            return "Unsupported bundle adapter kind '\(kind)'. Supported: coreml.monolithic."
        case .unsupportedPromptFormat(let format):
            return "Unsupported prompt.format '\(format)'. Supported: chat_transcript, gemma3_turns."
        case .missingMonolithicModelPath:
            return "Bundle metadata runtime.monolithic_model is required for coreml.monolithic adapter kind."
        case .missingTokenizerAssets(let path):
            return "Tokenizer assets not found at '\(path)'. Expected tokenizer.json and tokenizer_config.json."
        case .referencedModelPathMissing(let path):
            return "Bundle metadata referenced model path does not exist: \(path)."
        }
    }
}

public enum LambdaDeckBundleMetadataLoader {
    public static let fileName = "lambdadeck.bundle.json"

    public static func loadResolved(fromBundlePath bundlePath: String) throws -> LambdaDeckResolvedBundleMetadata {
        let bundleURL = URL(fileURLWithPath: bundlePath)
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: bundleURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw LambdaDeckBundleMetadataError.invalidBundlePath(bundleURL.path)
        }

        let metadataURL = bundleURL.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            throw LambdaDeckBundleMetadataError.metadataFileMissing(metadataURL.path)
        }

        let raw: RawBundleMetadata
        do {
            let data = try Data(contentsOf: metadataURL)
            raw = try JSONDecoder().decode(RawBundleMetadata.self, from: data)
        } catch {
            throw LambdaDeckBundleMetadataError.invalidMetadataJSON(path: metadataURL.path, message: error.localizedDescription)
        }

        guard raw.schemaVersion == 1 else {
            throw LambdaDeckBundleMetadataError.unsupportedSchemaVersion(raw.schemaVersion)
        }

        let modelID = raw.model.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !modelID.isEmpty else {
            throw LambdaDeckBundleMetadataError.missingModelID
        }

        guard let adapterKind = LambdaDeckMetadataAdapterKind(rawValue: raw.adapter.kind) else {
            throw LambdaDeckBundleMetadataError.unsupportedAdapterKind(raw.adapter.kind)
        }

        let promptFormat: LambdaDeckMetadataPromptFormat
        if let rawPromptFormat = raw.prompt?.format {
            guard let parsedFormat = LambdaDeckMetadataPromptFormat(rawValue: rawPromptFormat) else {
                throw LambdaDeckBundleMetadataError.unsupportedPromptFormat(rawPromptFormat)
            }
            promptFormat = parsedFormat
        } else {
            promptFormat = .chatTranscript
        }

        let tokenizerDirectoryInput = raw.tokenizer.directory.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokenizerDirectory = resolveRelativePath(
            tokenizerDirectoryInput.isEmpty ? "." : tokenizerDirectoryInput,
            relativeTo: bundleURL
        )
        let tokenizerJSON = tokenizerDirectory.appendingPathComponent("tokenizer.json")
        let tokenizerConfig = tokenizerDirectory.appendingPathComponent("tokenizer_config.json")
        guard FileManager.default.fileExists(atPath: tokenizerJSON.path),
              FileManager.default.fileExists(atPath: tokenizerConfig.path)
        else {
            throw LambdaDeckBundleMetadataError.missingTokenizerAssets(path: tokenizerDirectory.path)
        }

        guard adapterKind == .coreMLMonolithic else {
            throw LambdaDeckBundleMetadataError.unsupportedAdapterKind(raw.adapter.kind)
        }

        let monolithicModelInput = raw.runtime.monolithicModel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !monolithicModelInput.isEmpty else {
            throw LambdaDeckBundleMetadataError.missingMonolithicModelPath
        }
        let monolithicModelPath = resolveRelativePath(monolithicModelInput, relativeTo: bundleURL)
        guard FileManager.default.fileExists(atPath: monolithicModelPath.path) else {
            throw LambdaDeckBundleMetadataError.referencedModelPathMissing(path: monolithicModelPath.path)
        }

        let contextLength = max(1, raw.runtime.contextLength ?? 2048)
        return LambdaDeckResolvedBundleMetadata(
            modelID: modelID,
            adapterKind: adapterKind,
            tokenizerDirectory: tokenizerDirectory,
            monolithicModelPath: monolithicModelPath,
            contextLength: contextLength,
            slidingWindow: raw.runtime.slidingWindow,
            batchSize: raw.runtime.batchSize,
            architecture: raw.runtime.architecture,
            promptFormat: promptFormat
        )
    }

    private static func resolveRelativePath(_ path: String, relativeTo base: URL) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path).standardizedFileURL
        }
        return URL(fileURLWithPath: path, relativeTo: base).standardizedFileURL
    }
}

private struct RawBundleMetadata: Decodable {
    struct RawModel: Decodable {
        let id: String
    }

    struct RawTokenizer: Decodable {
        let directory: String
    }

    struct RawAdapter: Decodable {
        let kind: String
    }

    struct RawRuntime: Decodable {
        let monolithicModel: String?
        let contextLength: Int?
        let slidingWindow: Int?
        let batchSize: Int?
        let architecture: String?

        enum CodingKeys: String, CodingKey {
            case monolithicModel = "monolithic_model"
            case contextLength = "context_length"
            case slidingWindow = "sliding_window"
            case batchSize = "batch_size"
            case architecture
        }
    }

    struct RawPrompt: Decodable {
        let format: String
    }

    let schemaVersion: Int
    let model: RawModel
    let tokenizer: RawTokenizer
    let adapter: RawAdapter
    let runtime: RawRuntime
    let prompt: RawPrompt?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case model
        case tokenizer
        case adapter
        case runtime
        case prompt
    }
}
