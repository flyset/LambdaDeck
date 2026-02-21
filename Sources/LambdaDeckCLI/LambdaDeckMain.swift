import Darwin
import Foundation

@main
struct LambdaDeckMain {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let result = LambdaDeckCLI.run(arguments: arguments)

        if !result.standardOutput.isEmpty {
            FileHandle.standardOutput.write(Data(result.standardOutput.utf8))
        }

        if !result.standardError.isEmpty {
            FileHandle.standardError.write(Data(result.standardError.utf8))
        }

        exit(result.exitCode)
    }
}
