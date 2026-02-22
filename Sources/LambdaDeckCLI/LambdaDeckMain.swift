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
                writeStandardErrorLine(LambdaDeckStartupLogs.resolvingConfiguration())
                let configuration = try LambdaDeckServerBootstrap.resolveConfiguration(options: options)
                try await LambdaDeckServer.run(configuration: configuration) { activePort in
                    writeStandardErrorLine(
                        LambdaDeckStartupLogs.serverListening(
                            host: configuration.host,
                            port: activePort,
                            modelID: configuration.resolvedModel.modelID,
                            source: configuration.resolvedModel.source.rawValue
                        )
                    )

                    if let runtimeProvider = configuration.inferenceRuntimeProvider {
                        writeStandardErrorLine(LambdaDeckStartupLogs.runtimeWarmupStarted())
                        Task.detached(priority: .utility) {
                            await monitorRuntimeWarmup(runtimeProvider)
                        }
                    } else {
                        writeStandardErrorLine(LambdaDeckStartupLogs.runtimeReady(elapsedMilliseconds: 0))
                    }
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

    static func monitorRuntimeWarmup(_ runtimeProvider: LambdaDeckRuntimeProvider) async {
        while true {
            let readiness = await runtimeProvider.readinessSnapshot()
            switch readiness.status {
            case .ready:
                writeStandardErrorLine(
                    LambdaDeckStartupLogs.runtimeReady(elapsedMilliseconds: readiness.elapsedMilliseconds)
                )
                return
            case .failed:
                let error = readiness.error ?? "runtime initialization failed"
                writeStandardErrorLine(
                    LambdaDeckStartupLogs.runtimeFailed(
                        elapsedMilliseconds: readiness.elapsedMilliseconds,
                        error: error
                    )
                )
                return
            case .warmingUp:
                do {
                    try await Task.sleep(nanoseconds: 250_000_000)
                } catch {
                    return
                }
            }
        }
    }

    static func writeStandardErrorLine(_ line: String) {
        FileHandle.standardError.write(Data("\(line)\n".utf8))
    }
}

enum LambdaDeckStartupLogs {
    static func resolvingConfiguration() -> String {
        "startup: resolving configuration"
    }

    static func serverListening(host: String, port: Int, modelID: String, source: String) -> String {
        "startup: server listening on http://\(host):\(port) model=\(modelID) source=\(source)"
    }

    static func runtimeWarmupStarted() -> String {
        "startup: runtime warmup started"
    }

    static func runtimeReady(elapsedMilliseconds: Int) -> String {
        "startup: runtime ready (elapsed=\(elapsedMilliseconds)ms)"
    }

    static func runtimeFailed(elapsedMilliseconds: Int, error: String) -> String {
        let sanitizedError = error.replacingOccurrences(of: "\n", with: " ")
        return "startup: runtime failed (elapsed=\(elapsedMilliseconds)ms error=\(sanitizedError))"
    }
}
