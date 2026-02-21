import Foundation
import LambdaDeckCore

public enum CLICommand: Equatable {
    case help
    case serveHelp
    case version
    case stubContract
    case serve(LambdaDeckServeOptions)
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
    Usage: lambdadeck <command> [options]

    Commands:
      serve                Start OpenAI-compatible HTTP server.
      --stub-contract      Print deterministic stub chat completion JSON.
      -h, --help           Show this help.
      -v, --version        Show lambdadeck version.
    """

    public static let serveHelpText = """
    Usage: lambdadeck serve [options]

    Options:
      --host <host>        Host to bind (default: 127.0.0.1).
      --port <port>        Port to bind (default: 8080).
      --stub               Run deterministic stub mode.
      --model-path <path>  Explicit model bundle path.
      --models-root <dir>  Model discovery root (default: ./Models).
      -h, --help           Show serve help.
    """

    public static func parse(arguments: [String]) -> CLICommand {
        guard let first = arguments.first else {
            return .help
        }

        switch first {
        case "-h", "--help":
            return arguments.count == 1 ? .help : .invalid(arguments.joined(separator: " "))
        case "-v", "--version":
            return arguments.count == 1 ? .version : .invalid(arguments.joined(separator: " "))
        case "--stub-contract":
            return arguments.count == 1 ? .stubContract : .invalid(arguments.joined(separator: " "))
        case "serve":
            return parseServe(arguments: Array(arguments.dropFirst()))
        default:
            return .invalid(first)
        }
    }

    public static func run(arguments: [String]) -> CLIResult {
        run(command: parse(arguments: arguments))
    }

    public static func run(command: CLICommand) -> CLIResult {
        switch command {
        case .help:
            return CLIResult(
                exitCode: 0,
                standardOutput: "\(helpText)\n",
                standardError: ""
            )
        case .serveHelp:
            return CLIResult(
                exitCode: 0,
                standardOutput: "\(serveHelpText)\n",
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
        case .serve:
            return CLIResult(
                exitCode: 2,
                standardOutput: "",
                standardError: "error: internal CLI misuse for 'serve' command\n"
            )
        case .invalid(let value):
            return CLIResult(
                exitCode: 1,
                standardOutput: "",
                standardError: "error: unknown argument '\(value)'\n\(helpText)\n"
            )
        }
    }

    private static func parseServe(arguments: [String]) -> CLICommand {
        var options = LambdaDeckServeOptions()
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "-h", "--help":
                return .serveHelp
            case "--stub":
                options.stubMode = true
                index += 1
            case "--host":
                guard index + 1 < arguments.count else {
                    return .invalid("missing value for --host")
                }
                options.host = arguments[index + 1]
                index += 2
            case "--port":
                guard index + 1 < arguments.count else {
                    return .invalid("missing value for --port")
                }
                guard let port = Int(arguments[index + 1]), (0...65535).contains(port) else {
                    return .invalid("invalid value for --port: \(arguments[index + 1])")
                }
                options.port = port
                index += 2
            case "--model-path":
                guard index + 1 < arguments.count else {
                    return .invalid("missing value for --model-path")
                }
                options.modelPath = arguments[index + 1]
                index += 2
            case "--models-root":
                guard index + 1 < arguments.count else {
                    return .invalid("missing value for --models-root")
                }
                options.modelsRoot = arguments[index + 1]
                index += 2
            default:
                return .invalid(argument)
            }
        }
        return .serve(options)
    }
}
