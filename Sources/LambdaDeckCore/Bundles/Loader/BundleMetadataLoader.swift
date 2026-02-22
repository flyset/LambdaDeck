import Foundation

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

        let raw: RawBundleMetadataV1
        do {
            let data = try Data(contentsOf: metadataURL)
            raw = try JSONDecoder().decode(RawBundleMetadataV1.self, from: data)
        } catch {
            throw LambdaDeckBundleMetadataError.invalidMetadataJSON(path: metadataURL.path, message: error.localizedDescription)
        }

        return try LambdaDeckBundleMetadataValidator.validate(raw: raw, bundleURL: bundleURL)
    }
}
