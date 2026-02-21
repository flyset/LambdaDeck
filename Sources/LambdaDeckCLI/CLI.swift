import Foundation
import LambdaDeckCore

public enum CLICommand: Equatable {
    case help
    case version
    case stubContract
    case invalid(String)
}

public struct CLIResult: Equatable {
    public let exitCode: Int32
    public let standardOutput: String
    public let standardError: String

    public init(exitCode: Int32, standardOutput: String, standardError: String) {
        self.exitCode = exitCode
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}

public enum LambdaDeckCLI {
    public static let helpText = """
    Usage: lambdadeck [options]

    Options:
      -h, --help           Show this help.
      -v, --version        Show lambdadeck version.
      --stub-contract      Print deterministic stub chat completion JSON.
    """

    public static func parse(arguments: [String]) -> CLICommand {
        guard arguments.count <= 1 else {
            return .invalid(arguments.joined(separator: " "))
        }

        guard let argument = arguments.first else {
            return .help
        }

        switch argument {
        case "-h", "--help":
            return .help
        case "-v", "--version":
            return .version
        case "--stub-contract":
            return .stubContract
        default:
            return .invalid(argument)
        }
    }

    public static func run(arguments: [String]) -> CLIResult {
        switch parse(arguments: arguments) {
        case .help:
            return CLIResult(
                exitCode: 0,
                standardOutput: "\(helpText)\n",
                standardError: ""
            )
        case .version:
            return CLIResult(
                exitCode: 0,
                standardOutput: "lambdadeck \(LambdaDeckVersion.current)\n",
                standardError: ""
            )
        case .stubContract:
            do {
                let payload = try StubContractGenerator.chatCompletionJSON()
                return CLIResult(exitCode: 0, standardOutput: "\(payload)\n", standardError: "")
            } catch {
                return CLIResult(
                    exitCode: 1,
                    standardOutput: "",
                    standardError: "error: failed to generate stub contract output\n"
                )
            }
        case .invalid(let value):
            return CLIResult(
                exitCode: 1,
                standardOutput: "",
                standardError: "error: unknown argument '\(value)'\n\(helpText)\n"
            )
        }
    }
}
