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

        var warnings: [String] = []

        let promptFormat: LambdaDeckMetadataPromptFormat?
        if let rawPromptFormat = raw.prompt?.format?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawPromptFormat.isEmpty {
            if let parsedFormat = LambdaDeckMetadataPromptFormat(rawValue: rawPromptFormat) {
                promptFormat = parsedFormat
            } else {
                warnings.append(
                    "Unsupported prompt.format '\(rawPromptFormat)'; falling back to adapter defaults."
                )
                promptFormat = nil
            }
        } else {
            promptFormat = nil
        }

        let promptSystemPolicy: LambdaDeckPromptSystemPolicy?
        if let rawPromptPolicy = raw.prompt?.systemPolicy?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawPromptPolicy.isEmpty {
            if let parsedPolicy = LambdaDeckPromptSystemPolicy(rawValue: rawPromptPolicy) {
                promptSystemPolicy = parsedPolicy
            } else {
                warnings.append(
                    "Unsupported prompt.system_policy '\(rawPromptPolicy)'; falling back to format default."
                )
                promptSystemPolicy = nil
            }
        } else {
            promptSystemPolicy = nil
        }

        let tokenizerDirectoryInput = raw.tokenizer.directory.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokenizerDirectory = LambdaDeckBundlePathResolver.resolveRelativePath(
            tokenizerDirectoryInput.isEmpty ? "." : tokenizerDirectoryInput,
            relativeTo: bundleURL
        )
        let tokenizerFamily: LambdaDeckTokenizerFamily?
        if let rawTokenizerFamily = raw.tokenizer.family?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawTokenizerFamily.isEmpty {
            if let parsedFamily = LambdaDeckTokenizerFamily(rawValue: rawTokenizerFamily) {
                tokenizerFamily = parsedFamily
            } else {
                warnings.append(
                    "Unsupported tokenizer.family '\(rawTokenizerFamily)'; falling back to adapter defaults."
                )
                tokenizerFamily = nil
            }
        } else {
            tokenizerFamily = nil
        }
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
            tokenizerFamily: tokenizerFamily,
            monolithicModelPath: monolithicModelPath,
            contextLength: contextLength,
            slidingWindow: raw.runtime.slidingWindow,
            batchSize: raw.runtime.batchSize,
            architecture: raw.runtime.architecture,
            promptFormat: promptFormat,
            promptSystemPolicy: promptSystemPolicy,
            warnings: warnings
        )
    }
}
