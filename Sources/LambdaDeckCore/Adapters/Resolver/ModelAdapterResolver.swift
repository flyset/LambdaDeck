import Foundation

public enum LambdaDeckModelAdapterResolver {
    public static func resolve(modelPath: String, fallbackModelID: String? = nil) throws -> any LambdaDeckModelAdapter {
        let normalizedModelPath = URL(fileURLWithPath: modelPath).standardizedFileURL.path
        var isDirectory = ObjCBool(false)
        let exists = FileManager.default.fileExists(atPath: normalizedModelPath, isDirectory: &isDirectory)
        guard exists else {
            throw LambdaDeckRuntimeError.unsupportedModelPath("Model path does not exist: \(normalizedModelPath)")
        }

        if isDirectory.boolValue {
            let metadataPath = URL(fileURLWithPath: normalizedModelPath)
                .appendingPathComponent(LambdaDeckBundleMetadataLoader.fileName)
            if FileManager.default.fileExists(atPath: metadataPath.path) {
                return try LambdaDeckMetadataModelAdapter(bundlePath: normalizedModelPath)
            }
        }

        return try ANEMLLModelAdapter(
            modelPath: normalizedModelPath,
            fallbackModelID: fallbackModelID ?? deriveModelID(fromPath: normalizedModelPath)
        )
    }

    private static func deriveModelID(fromPath path: String) -> String {
        let url = URL(fileURLWithPath: path)
        if url.pathExtension == "mlmodelc" {
            return url.deletingPathExtension().lastPathComponent
        }
        return url.lastPathComponent
    }
}
