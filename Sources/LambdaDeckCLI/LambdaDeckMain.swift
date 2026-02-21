import Darwin
import Foundation
import LambdaDeckCore

@main
struct LambdaDeckMain {
    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let command = LambdaDeckCLI.parse(arguments: arguments)

        if case .serve(let options) = command {
            do {
                let configuration = try LambdaDeckServerBootstrap.resolveConfiguration(options: options)
                try await LambdaDeckServer.run(configuration: configuration) { activePort in
                    let line = "lambdadeck listening on http://\(configuration.host):\(activePort) model=\(configuration.resolvedModel.modelID) source=\(configuration.resolvedModel.source.rawValue)\n"
                    FileHandle.standardError.write(Data(line.utf8))
                }
                exit(0)
            } catch {
                let line = "error: \(error.localizedDescription)\n"
                FileHandle.standardError.write(Data(line.utf8))
                exit(1)
            }
        }

        let result = LambdaDeckCLI.run(command: command)

        if !result.standardOutput.isEmpty {
            FileHandle.standardOutput.write(Data(result.standardOutput.utf8))
        }

        if !result.standardError.isEmpty {
            FileHandle.standardError.write(Data(result.standardError.utf8))
        }

        exit(result.exitCode)
    }
}
