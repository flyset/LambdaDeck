import Foundation

enum LambdaDeckBundlePathResolver {
    static func resolveRelativePath(_ path: String, relativeTo base: URL) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path).standardizedFileURL
        }
        return URL(fileURLWithPath: path, relativeTo: base).standardizedFileURL
    }
}
