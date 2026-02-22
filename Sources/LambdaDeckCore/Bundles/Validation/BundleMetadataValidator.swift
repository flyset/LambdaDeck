import Foundation

enum LambdaDeckBundleMetadataValidator {
    static func validate(raw: RawBundleMetadataV1, bundleURL: URL) throws -> LambdaDeckResolvedBundleMetadata {
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
        let tokenizerDirectory = LambdaDeckBundlePathResolver.resolveRelativePath(
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
        let monolithicModelPath = LambdaDeckBundlePathResolver.resolveRelativePath(monolithicModelInput, relativeTo: bundleURL)
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
}
