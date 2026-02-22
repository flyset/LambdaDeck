import Foundation

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
