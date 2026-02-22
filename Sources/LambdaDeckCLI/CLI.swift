import ArgumentParser
import Foundation
import LambdaDeckCore

public enum CLICommand: Equatable {
    case serve(LambdaDeckServeOptions)
    case contractStub
    case output(CLIResult)
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
    private static let removedStubContractHint = "The '--stub-contract' option was removed. Use 'lambdadeck contract stub'."
    private static let helpTopics = ["serve", "contract", "contract stub", "help"]

    public static func parse(arguments: [String]) -> CLICommand {
        if arguments.contains("--stub-contract") {
            return .output(result(for: ValidationError(removedStubContractHint)))
        }

        do {
            var command = try LambdaDeckRootCommand.parseAsRoot(arguments)

            if let serve = command as? LambdaDeckServeCommand {
                return .serve(serve.serveOptions)
            }

            if command is LambdaDeckContractStubCommand {
                return .contractStub
            }

            if let help = command as? LambdaDeckHelpCommand {
                return .output(helpResult(arguments: help.topic))
            }

            try command.run()
            return .output(CLIResult(exitCode: 0, standardOutput: "", standardError: ""))
        } catch {
            return .output(result(for: error))
        }
    }

    public static func run(arguments: [String]) -> CLIResult {
        run(command: parse(arguments: arguments))
    }

    public static func run(command: CLICommand) -> CLIResult {
        switch command {
        case .output(let result):
            return result
        case .contractStub:
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
        }
    }

    private static func helpResult(arguments: [String]) -> CLIResult {
        let helpText: String

        switch arguments {
        case []:
            helpText = LambdaDeckRootCommand.helpMessage()
        case ["serve"]:
            helpText = LambdaDeckRootCommand.helpMessage(for: LambdaDeckServeCommand.self)
        case ["contract"]:
            helpText = LambdaDeckRootCommand.helpMessage(for: LambdaDeckContractCommand.self)
        case ["contract", "stub"]:
            helpText = LambdaDeckRootCommand.helpMessage(for: LambdaDeckContractStubCommand.self)
        case ["help"]:
            helpText = LambdaDeckRootCommand.helpMessage()
        default:
            let requested = arguments.joined(separator: " ")
            let availableTopics = helpTopics.joined(separator: ", ")
            return result(
                for: ValidationError(
                    "Unknown help topic '\(requested)'. Available topics: \(availableTopics)."
                )
            )
        }

        return CLIResult(
            exitCode: 0,
            standardOutput: withTrailingNewline(helpText),
            standardError: ""
        )
    }

    private static func result(for error: Error) -> CLIResult {
        let exitCode = Int32(LambdaDeckRootCommand.exitCode(for: error).rawValue)
        let fullMessage = withTrailingNewline(LambdaDeckRootCommand.fullMessage(for: error))

        if exitCode == 0 {
            return CLIResult(exitCode: 0, standardOutput: fullMessage, standardError: "")
        }

        return CLIResult(exitCode: exitCode, standardOutput: "", standardError: fullMessage)
    }

    private static func withTrailingNewline(_ text: String) -> String {
        guard !text.isEmpty else {
            return text
        }

        return text.hasSuffix("\n") ? text : "\(text)\n"
    }
}

struct LambdaDeckRootCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "lambdadeck",
        abstract: "Run LambdaDeck local OpenAI-compatible runtime tools.",
        discussion: """
        Examples:
          lambdadeck serve --stub
          lambdadeck serve --model-path "Models/<bundle>" --port 8080
          lambdadeck contract stub
          lambdadeck help serve
        """,
        version: LambdaDeckVersion.current,
        subcommands: [
            LambdaDeckServeCommand.self,
            LambdaDeckContractCommand.self,
            LambdaDeckHelpCommand.self
        ]
    )
}

struct LambdaDeckHelpCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "help",
        abstract: "Show help for a subcommand."
    )

    @Argument(help: "Command path, for example: serve or contract stub.")
    var topic: [String] = []
}

struct LambdaDeckServeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "serve",
        abstract: "Start OpenAI-compatible HTTP server."
    )

    @Option(name: .long, help: "Host to bind.")
    var host = "127.0.0.1"

    @Option(name: .long, help: "Port to bind.")
    var port = 8080

    @Flag(name: .long, help: "Run deterministic stub mode.")
    var stub = false

    @Option(name: .long, help: "Explicit model bundle path.")
    var modelPath: String?

    @Option(name: .long, help: "Model discovery root (default: ./Models).")
    var modelsRoot: String?

    var serveOptions: LambdaDeckServeOptions {
        LambdaDeckServeOptions(
            host: host,
            port: port,
            stubMode: stub,
            modelPath: modelPath,
            modelsRoot: modelsRoot
        )
    }

    mutating func validate() throws {
        guard (0...65535).contains(port) else {
            throw ValidationError("Please provide a value between 0 and 65535 for '--port'.")
        }
    }
}

struct LambdaDeckContractCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "contract",
        abstract: "Contract and fixture utilities.",
        subcommands: [LambdaDeckContractStubCommand.self]
    )
}

struct LambdaDeckContractStubCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stub",
        abstract: "Print deterministic stub chat completion JSON."
    )
}
