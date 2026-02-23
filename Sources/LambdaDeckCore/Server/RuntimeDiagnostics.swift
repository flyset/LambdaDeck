import Foundation

public struct LambdaDeckRuntimeDiagnostics: Equatable, Sendable {
    public let selection: LambdaDeckStrategySelection
    public let warnings: [String]

    public init(selection: LambdaDeckStrategySelection, warnings: [String]) {
        self.selection = selection
        self.warnings = warnings
    }
}
