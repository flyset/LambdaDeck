import Foundation
import Hummingbird
import HummingbirdTesting
import NIOCore
import XCTest
@testable import LambdaDeckCLI
@testable import LambdaDeckCore

final class OpenAIContractIntegrationTests: XCTestCase {
    func testContractStubHookReturnsOpenAIShapedJSON() throws {
        let result = LambdaDeckCLI.run(arguments: ["contract", "stub"])

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.standardError, "")

        let data = Data(result.standardOutput.utf8)
        let payload = try JSONDecoder().decode(StubChatCompletionResponse.self, from: data)

        XCTAssertEqual(payload.object, "chat.completion")
        XCTAssertEqual(payload.choices.count, 1)
        XCTAssertEqual(payload.choices[0].message.role, "assistant")
        XCTAssertEqual(payload.choices[0].finishReason, "stop")
    }

    func testModelsEndpointReturnsOpenAIListShape() async throws {
        let configuration = try LambdaDeckServerBootstrap.resolveConfiguration(
            options: LambdaDeckServeOptions(stubMode: true)
        )
        let app = LambdaDeckServer.makeApplication(configuration: configuration)

        try await app.test(.router) { client in
            let response = try await client.execute(uri: "/v1/models", method: .get)
            XCTAssertEqual(response.status, .ok)

            let payload = try JSONDecoder().decode(OpenAIModelListResponse.self, from: data(from: response.body))
            XCTAssertEqual(payload.object, "list")
            XCTAssertEqual(payload.data.map(\.id), [StubChatFixtures.modelID])
        }
    }

    func testReadyzEndpointReturnsReadyInStubMode() async throws {
        let configuration = try LambdaDeckServerBootstrap.resolveConfiguration(
            options: LambdaDeckServeOptions(stubMode: true)
        )
        let app = LambdaDeckServer.makeApplication(configuration: configuration)

        try await app.test(.router) { client in
            let response = try await client.execute(uri: "/readyz", method: .get)
            XCTAssertEqual(response.status, .ok)

            let payload = try JSONDecoder().decode(LambdaDeckReadinessResponse.self, from: data(from: response.body))
            XCTAssertEqual(payload.status, .ready)
            XCTAssertEqual(payload.model, StubChatFixtures.modelID)
            XCTAssertGreaterThanOrEqual(payload.elapsedMilliseconds, 0)
            XCTAssertNil(payload.error)
        }
    }

    func testReadyzEndpointReturnsWarmingUpWhenRuntimeProviderIsLoading() async throws {
        let runtime = TestRuntime(
            completion: LambdaDeckRuntimeCompletion(
                content: "unused",
                finishReason: "stop",
                usage: OpenAIUsage(promptTokens: 0, completionTokens: 0, totalTokens: 0)
            ),
            streamTokens: ["unused"],
            finishReason: "stop",
            usage: OpenAIUsage(promptTokens: 0, completionTokens: 0, totalTokens: 0)
        )
        let resolvedModel = LambdaDeckResolvedModel(
            modelID: "warming-model",
            modelPath: "/tmp/warming-model",
            source: .cliModelPath
        )
        let provider = LambdaDeckRuntimeProvider(
            resolvedModel: resolvedModel,
            preload: false,
            runtimeLoader: { _ in
                try await Task.sleep(nanoseconds: 300_000_000)
                return runtime
            }
        )
        let configuration = LambdaDeckServerConfiguration(
            host: "127.0.0.1",
            port: 8080,
            resolvedModel: resolvedModel,
            inferenceRuntimeProvider: provider
        )
        let app = LambdaDeckServer.makeApplication(configuration: configuration)

        try await app.test(.router) { client in
            let response = try await client.execute(uri: "/readyz", method: .get)
            XCTAssertEqual(response.status, .serviceUnavailable)

            let payload = try JSONDecoder().decode(LambdaDeckReadinessResponse.self, from: data(from: response.body))
            XCTAssertEqual(payload.status, .warmingUp)
            XCTAssertEqual(payload.model, "warming-model")
            XCTAssertGreaterThanOrEqual(payload.elapsedMilliseconds, 0)
            XCTAssertNil(payload.error)
        }
    }

    func testReadyzEndpointReturnsReadyAfterRuntimeWarmupCompletes() async throws {
        let runtime = TestRuntime(
            completion: LambdaDeckRuntimeCompletion(
                content: "Provider runtime response.",
                finishReason: "stop",
                usage: OpenAIUsage(promptTokens: 8, completionTokens: 3, totalTokens: 11)
            ),
            streamTokens: ["unused"],
            finishReason: "stop",
            usage: OpenAIUsage(promptTokens: 8, completionTokens: 3, totalTokens: 11)
        )
        let resolvedModel = LambdaDeckResolvedModel(
            modelID: "ready-model",
            modelPath: "/tmp/ready-model",
            source: .cliModelPath
        )
        let provider = LambdaDeckRuntimeProvider(
            resolvedModel: resolvedModel,
            preload: false,
            runtimeLoader: { _ in
                runtime
            }
        )
        _ = try await provider.runtimeInstance()

        let configuration = LambdaDeckServerConfiguration(
            host: "127.0.0.1",
            port: 8080,
            resolvedModel: resolvedModel,
            inferenceRuntimeProvider: provider
        )
        let app = LambdaDeckServer.makeApplication(configuration: configuration)

        try await app.test(.router) { client in
            let response = try await client.execute(uri: "/readyz", method: .get)
            XCTAssertEqual(response.status, .ok)

            let payload = try JSONDecoder().decode(LambdaDeckReadinessResponse.self, from: data(from: response.body))
            XCTAssertEqual(payload.status, .ready)
            XCTAssertEqual(payload.model, "ready-model")
            XCTAssertGreaterThanOrEqual(payload.elapsedMilliseconds, 0)
            XCTAssertNil(payload.error)
        }
    }

    func testReadyzEndpointReturnsFailedWhenRuntimeWarmupFails() async throws {
        let resolvedModel = LambdaDeckResolvedModel(
            modelID: "failed-model",
            modelPath: "/tmp/failed-model",
            source: .cliModelPath
        )
        let provider = LambdaDeckRuntimeProvider(
            resolvedModel: resolvedModel,
            preload: false,
            runtimeLoader: { _ in
                throw LambdaDeckRuntimeError.runtimeFailure("simulated warmup failure")
            }
        )

        do {
            _ = try await provider.runtimeInstance()
            XCTFail("Expected runtime warmup failure")
        } catch let runtimeError as LambdaDeckRuntimeError {
            XCTAssertEqual(runtimeError, .runtimeFailure("simulated warmup failure"))
        }

        let configuration = LambdaDeckServerConfiguration(
            host: "127.0.0.1",
            port: 8080,
            resolvedModel: resolvedModel,
            inferenceRuntimeProvider: provider
        )
        let app = LambdaDeckServer.makeApplication(configuration: configuration)

        try await app.test(.router) { client in
            let response = try await client.execute(uri: "/readyz", method: .get)
            XCTAssertEqual(response.status, .serviceUnavailable)

            let payload = try JSONDecoder().decode(LambdaDeckReadinessResponse.self, from: data(from: response.body))
            XCTAssertEqual(payload.status, .failed)
            XCTAssertEqual(payload.model, "failed-model")
            XCTAssertGreaterThanOrEqual(payload.elapsedMilliseconds, 0)
            XCTAssertEqual(payload.error, "simulated warmup failure")
        }
    }

    func testChatCompletionsNonStreamReturnsFixture() async throws {
        let configuration = try LambdaDeckServerBootstrap.resolveConfiguration(
            options: LambdaDeckServeOptions(stubMode: true)
        )
        let app = LambdaDeckServer.makeApplication(configuration: configuration)
        let requestBody = try chatRequestBody(
            OpenAIChatCompletionsRequest(
                model: StubChatFixtures.modelID,
                messages: [OpenAIChatMessage(role: "user", content: "Say hello in one short sentence.")],
                stream: false
            )
        )

        try await app.test(.router) { client in
            let response = try await client.execute(
                uri: "/v1/chat/completions",
                method: .post,
                headers: [.contentType: "application/json"],
                body: requestBody
            )

            XCTAssertEqual(response.status, .ok)
            let payload = try JSONDecoder().decode(OpenAIChatCompletionResponse.self, from: data(from: response.body))
            XCTAssertEqual(payload, StubChatFixtures.completionResponse())
        }
    }

    func testChatCompletionsAcceptsMultiTurnMessages() async throws {
        let configuration = try LambdaDeckServerBootstrap.resolveConfiguration(
            options: LambdaDeckServeOptions(stubMode: true)
        )
        let app = LambdaDeckServer.makeApplication(configuration: configuration)
        let requestBody = try chatRequestBody(
            OpenAIChatCompletionsRequest(
                model: StubChatFixtures.modelID,
                messages: [
                    OpenAIChatMessage(role: "system", content: "You are concise."),
                    OpenAIChatMessage(role: "user", content: "What is LambdaDeck?"),
                    OpenAIChatMessage(role: "assistant", content: "A local OpenAI-compatible server for ANEMLL Core ML models."),
                    OpenAIChatMessage(role: "user", content: "Answer in five words.")
                ],
                temperature: 0,
                maxTokens: 32,
                stream: false
            )
        )

        try await app.test(.router) { client in
            let response = try await client.execute(
                uri: "/v1/chat/completions",
                method: .post,
                headers: [.contentType: "application/json"],
                body: requestBody
            )

            XCTAssertEqual(response.status, .ok)
            let payload = try JSONDecoder().decode(OpenAIChatCompletionResponse.self, from: data(from: response.body))
            XCTAssertEqual(payload, StubChatFixtures.completionResponse())
        }
    }

    func testChatCompletionsStreamReturnsSSEChunksInOrder() async throws {
        let configuration = try LambdaDeckServerBootstrap.resolveConfiguration(
            options: LambdaDeckServeOptions(stubMode: true)
        )
        let app = LambdaDeckServer.makeApplication(configuration: configuration)
        let requestBody = try chatRequestBody(
            OpenAIChatCompletionsRequest(
                model: StubChatFixtures.modelID,
                messages: [OpenAIChatMessage(role: "user", content: "Stream a short greeting.")],
                stream: true
            )
        )

        try await app.test(.router) { client in
            let response = try await client.execute(
                uri: "/v1/chat/completions",
                method: .post,
                headers: [.contentType: "application/json"],
                body: requestBody
            )

            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(response.headers[.contentType], "text/event-stream")

            let events = string(from: response.body)
                .components(separatedBy: "\n\n")
                .filter { !$0.isEmpty }

            XCTAssertEqual(events.count, 5)
            XCTAssertTrue(events[0].contains("\"finish_reason\":null"))
            XCTAssertTrue(events[1].contains("\"finish_reason\":null"))
            XCTAssertTrue(events[2].contains("\"finish_reason\":null"))
            XCTAssertTrue(events[3].contains("\"finish_reason\":\"stop\""))

            let expectedChunks = StubChatFixtures.completionChunks()
            for (index, expectedChunk) in expectedChunks.enumerated() {
                let event = events[index]
                XCTAssertTrue(event.hasPrefix("data: "))
                let jsonPayload = String(event.dropFirst(6))
                let chunk = try JSONDecoder().decode(
                    OpenAIChatCompletionChunk.self,
                    from: Data(jsonPayload.utf8)
                )
                XCTAssertEqual(chunk, expectedChunk)
            }

            XCTAssertEqual(events[4], "data: [DONE]")
        }
    }

    func testStreamingResponseSwallowsClientDisconnectErrors() async throws {
        let response = LambdaDeckServer.streamingResponse(
            modelID: StubChatFixtures.modelID,
            streamChunkDelayNanoseconds: 0
        )
        let writer = DisconnectingWriter()

        try await response.body.write(writer)
        XCTAssertEqual(writer.writeCount, 1)
    }

    func testChatCompletionsNonStreamUsesRuntimeWhenConfigured() async throws {
        let runtime = TestRuntime(
            completion: LambdaDeckRuntimeCompletion(
                content: "Real runtime response.",
                finishReason: "stop",
                usage: OpenAIUsage(promptTokens: 10, completionTokens: 3, totalTokens: 13)
            ),
            streamTokens: ["Real ", "runtime ", "stream."],
            finishReason: "stop",
            usage: OpenAIUsage(promptTokens: 10, completionTokens: 3, totalTokens: 13)
        )
        let configuration = LambdaDeckServerConfiguration(
            host: "127.0.0.1",
            port: 8080,
            resolvedModel: LambdaDeckResolvedModel(
                modelID: "real-model",
                modelPath: "/tmp/real-model",
                source: .cliModelPath
            ),
            inferenceRuntime: runtime
        )
        let app = LambdaDeckServer.makeApplication(configuration: configuration)
        let requestBody = try chatRequestBody(
            OpenAIChatCompletionsRequest(
                model: "real-model",
                messages: [OpenAIChatMessage(role: "user", content: "Say hello")],
                stream: false
            )
        )

        try await app.test(.router) { client in
            let response = try await client.execute(
                uri: "/v1/chat/completions",
                method: .post,
                headers: [.contentType: "application/json"],
                body: requestBody
            )

            XCTAssertEqual(response.status, .ok)
            let payload = try JSONDecoder().decode(OpenAIChatCompletionResponse.self, from: data(from: response.body))
            XCTAssertEqual(payload.model, "real-model")
            XCTAssertEqual(payload.choices.first?.message.role, "assistant")
            XCTAssertEqual(payload.choices.first?.message.content, "Real runtime response.")
            XCTAssertEqual(payload.choices.first?.finishReason, "stop")
            XCTAssertEqual(payload.usage, OpenAIUsage(promptTokens: 10, completionTokens: 3, totalTokens: 13))
        }
    }

    func testChatCompletionsStreamUsesRuntimeWhenConfigured() async throws {
        let runtime = TestRuntime(
            completion: LambdaDeckRuntimeCompletion(
                content: "unused",
                finishReason: "stop",
                usage: OpenAIUsage(promptTokens: 0, completionTokens: 0, totalTokens: 0)
            ),
            streamTokens: ["Alpha", " Beta"],
            finishReason: "stop",
            usage: OpenAIUsage(promptTokens: 7, completionTokens: 2, totalTokens: 9)
        )
        let configuration = LambdaDeckServerConfiguration(
            host: "127.0.0.1",
            port: 8080,
            resolvedModel: LambdaDeckResolvedModel(
                modelID: "real-model",
                modelPath: "/tmp/real-model",
                source: .cliModelPath
            ),
            inferenceRuntime: runtime
        )
        let app = LambdaDeckServer.makeApplication(configuration: configuration)
        let requestBody = try chatRequestBody(
            OpenAIChatCompletionsRequest(
                model: "real-model",
                messages: [OpenAIChatMessage(role: "user", content: "Stream")],
                stream: true
            )
        )

        try await app.test(.router) { client in
            let response = try await client.execute(
                uri: "/v1/chat/completions",
                method: .post,
                headers: [.contentType: "application/json"],
                body: requestBody
            )

            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(response.headers[.contentType], "text/event-stream")

            let events = string(from: response.body)
                .components(separatedBy: "\n\n")
                .filter { !$0.isEmpty }

            XCTAssertEqual(events.count, 5)
            XCTAssertEqual(events.last, "data: [DONE]")
            XCTAssertTrue(events[1].contains("\"content\":\"Alpha\""))
            XCTAssertTrue(events[2].contains("\"content\":\" Beta\""))
            XCTAssertTrue(events[3].contains("\"finish_reason\":\"stop\""))
        }
    }

    func testChatCompletionsUsesRuntimeProviderWhenConfigured() async throws {
        let runtime = TestRuntime(
            completion: LambdaDeckRuntimeCompletion(
                content: "Provider runtime response.",
                finishReason: "stop",
                usage: OpenAIUsage(promptTokens: 8, completionTokens: 3, totalTokens: 11)
            ),
            streamTokens: ["unused"],
            finishReason: "stop",
            usage: OpenAIUsage(promptTokens: 8, completionTokens: 3, totalTokens: 11)
        )
        let resolvedModel = LambdaDeckResolvedModel(
            modelID: "provider-model",
            modelPath: "/tmp/provider-model",
            source: .cliModelPath
        )
        let provider = LambdaDeckRuntimeProvider(
            resolvedModel: resolvedModel,
            preload: false,
            runtimeLoader: { _ in runtime }
        )
        let configuration = LambdaDeckServerConfiguration(
            host: "127.0.0.1",
            port: 8080,
            resolvedModel: resolvedModel,
            inferenceRuntimeProvider: provider
        )
        let app = LambdaDeckServer.makeApplication(configuration: configuration)
        let requestBody = try chatRequestBody(
            OpenAIChatCompletionsRequest(
                model: "provider-model",
                messages: [OpenAIChatMessage(role: "user", content: "Say hello")],
                stream: false
            )
        )

        try await app.test(.router) { client in
            let response = try await client.execute(
                uri: "/v1/chat/completions",
                method: .post,
                headers: [.contentType: "application/json"],
                body: requestBody
            )

            XCTAssertEqual(response.status, .ok)
            let payload = try JSONDecoder().decode(OpenAIChatCompletionResponse.self, from: data(from: response.body))
            XCTAssertEqual(payload.model, "provider-model")
            XCTAssertEqual(payload.choices.first?.message.content, "Provider runtime response.")
            XCTAssertEqual(payload.usage, OpenAIUsage(promptTokens: 8, completionTokens: 3, totalTokens: 11))
        }
    }

    func testChatCompletionsReturnsServiceUnavailableWhenRuntimeProviderIsWarmingUp() async throws {
        let runtime = TestRuntime(
            completion: LambdaDeckRuntimeCompletion(
                content: "unused",
                finishReason: "stop",
                usage: OpenAIUsage(promptTokens: 0, completionTokens: 0, totalTokens: 0)
            ),
            streamTokens: ["unused"],
            finishReason: "stop",
            usage: OpenAIUsage(promptTokens: 0, completionTokens: 0, totalTokens: 0)
        )
        let resolvedModel = LambdaDeckResolvedModel(
            modelID: "warming-model",
            modelPath: "/tmp/warming-model",
            source: .cliModelPath
        )
        let runtimeLoaderGate = RuntimeLoaderGate()
        defer {
            Task {
                await runtimeLoaderGate.open()
            }
        }
        let provider = LambdaDeckRuntimeProvider(
            resolvedModel: resolvedModel,
            preload: false,
            runtimeLoader: { _ in
                await runtimeLoaderGate.wait()
                return runtime
            }
        )
        let configuration = LambdaDeckServerConfiguration(
            host: "127.0.0.1",
            port: 8080,
            resolvedModel: resolvedModel,
            inferenceRuntimeProvider: provider,
            runtimeWarmupTimeoutNanoseconds: 10_000_000
        )
        let app = LambdaDeckServer.makeApplication(configuration: configuration)
        let requestBody = try chatRequestBody(
            OpenAIChatCompletionsRequest(
                model: "warming-model",
                messages: [OpenAIChatMessage(role: "user", content: "Say hello")],
                stream: false
            )
        )

        try await app.test(.router) { client in
            let readinessResponse = try await client.execute(uri: "/readyz", method: .get)
            XCTAssertEqual(readinessResponse.status, .serviceUnavailable)

            let readinessPayload = try JSONDecoder().decode(
                LambdaDeckReadinessResponse.self,
                from: data(from: readinessResponse.body)
            )
            XCTAssertEqual(readinessPayload.status, .warmingUp)

            let response = try await client.execute(
                uri: "/v1/chat/completions",
                method: .post,
                headers: [.contentType: "application/json"],
                body: requestBody
            )

            XCTAssertEqual(response.status, .serviceUnavailable)
            let payload = try JSONDecoder().decode(OpenAIErrorResponse.self, from: data(from: response.body))
            XCTAssertEqual(payload.error.message, "runtime is still initializing; retry shortly")
            XCTAssertEqual(payload.error.type, "server_error")
        }
    }

    func testNonANEMLLMetadataBundleServesModelsAndChatWithStubRuntime() async throws {
        let bundle = try createLambdaDeckMetadataBundle(modelID: "metadata-e2e")
        defer {
            try? FileManager.default.removeItem(at: bundle.deletingLastPathComponent())
        }

        let adapter = try LambdaDeckModelAdapterResolver.resolve(
            modelPath: bundle.path,
            fallbackModelID: "fallback-model"
        )
        let resolvedModel = LambdaDeckResolvedModel(
            modelID: adapter.descriptor.modelID,
            modelPath: bundle.path,
            source: .cliModelPath
        )
        let configuration = LambdaDeckServerConfiguration(
            host: "127.0.0.1",
            port: 8080,
            resolvedModel: resolvedModel,
            inferenceRuntime: StubInferenceRuntime()
        )
        let app = LambdaDeckServer.makeApplication(configuration: configuration)

        let requestBody = try chatRequestBody(
            OpenAIChatCompletionsRequest(
                model: "metadata-e2e",
                messages: [OpenAIChatMessage(role: "user", content: "Say hello")],
                stream: false
            )
        )

        try await app.test(.router) { client in
            let modelsResponse = try await client.execute(uri: "/v1/models", method: .get)
            XCTAssertEqual(modelsResponse.status, .ok)
            let modelList = try JSONDecoder().decode(OpenAIModelListResponse.self, from: data(from: modelsResponse.body))
            XCTAssertEqual(modelList.data.map(\.id), ["metadata-e2e"])

            let response = try await client.execute(
                uri: "/v1/chat/completions",
                method: .post,
                headers: [.contentType: "application/json"],
                body: requestBody
            )
            XCTAssertEqual(response.status, .ok)
            let payload = try JSONDecoder().decode(OpenAIChatCompletionResponse.self, from: data(from: response.body))
            XCTAssertEqual(payload.model, "metadata-e2e")
            XCTAssertEqual(payload.choices[0].message.content, StubChatFixtures.completionText)
        }
    }

    func testLocalOnlyRealInferenceHarnessSkipsWithoutModelPath() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let modelPath = environment["LAMBDADECK_REAL_MODEL_PATH"], !modelPath.isEmpty else {
            throw XCTSkip("Set LAMBDADECK_REAL_MODEL_PATH to run local real-inference integration checks")
        }

        let configuration = try LambdaDeckServerBootstrap.resolveConfiguration(
            options: LambdaDeckServeOptions(modelPath: modelPath)
        )
        let app = LambdaDeckServer.makeApplication(configuration: configuration)
        let requestBody = try chatRequestBody(
            OpenAIChatCompletionsRequest(
                model: configuration.resolvedModel.modelID,
                messages: [OpenAIChatMessage(role: "user", content: "Reply in five words.")],
                maxTokens: 16,
                stream: false
            )
        )

        try await app.test(.router) { client in
            let response = try await client.execute(
                uri: "/v1/chat/completions",
                method: .post,
                headers: [.contentType: "application/json"],
                body: requestBody
            )

            XCTAssertEqual(response.status, .ok)
            let payload = try JSONDecoder().decode(OpenAIChatCompletionResponse.self, from: data(from: response.body))
            XCTAssertEqual(payload.model, configuration.resolvedModel.modelID)
            XCTAssertFalse(payload.choices[0].message.content.isEmpty)
            XCTAssertNotEqual(payload.choices[0].message.content, StubChatFixtures.completionText)
        }
    }

    private func chatRequestBody(_ request: OpenAIChatCompletionsRequest) throws -> ByteBuffer {
        let data = try JSONEncoder().encode(request)
        var buffer = ByteBufferAllocator().buffer(capacity: data.count)
        buffer.writeBytes(data)
        return buffer
    }

    private func data(from buffer: ByteBuffer) -> Data {
        var mutable = buffer
        return mutable.readData(length: mutable.readableBytes) ?? Data()
    }

    private func string(from buffer: ByteBuffer) -> String {
        String(decoding: data(from: buffer), as: UTF8.self)
    }

    private func createLambdaDeckMetadataBundle(modelID: String) throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LambdaDeckMetadataIntegration-\(UUID().uuidString)")
        let bundle = root.appendingPathComponent(modelID)
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)

        let tokenizerJSON = """
        {
          "model": {
            "vocab": {
              "<unk>": 0,
              "<bos>": 1,
              "<eos>": 2,
              "▁": 3,
              "A": 4
            },
            "merges": []
          }
        }
        """
        let tokenizerConfig = """
        {
          "bos_token": "<bos>",
          "eos_token": "<eos>"
        }
        """
        let metadata = """
        {
          "schema_version": 1,
          "model": {
            "id": "\(modelID)"
          },
          "tokenizer": {
            "directory": "."
          },
          "adapter": {
            "kind": "coreml.monolithic"
          },
          "runtime": {
            "monolithic_model": "model.mlmodelc",
            "context_length": 2048
          },
          "prompt": {
            "format": "chat_transcript"
          }
        }
        """

        try tokenizerJSON.write(to: bundle.appendingPathComponent("tokenizer.json"), atomically: true, encoding: .utf8)
        try tokenizerConfig.write(to: bundle.appendingPathComponent("tokenizer_config.json"), atomically: true, encoding: .utf8)
        try metadata.write(to: bundle.appendingPathComponent("lambdadeck.bundle.json"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: bundle.appendingPathComponent("model.mlmodelc"), withIntermediateDirectories: true)
        return bundle
    }
}

private struct TestRuntime: LambdaDeckInferenceRuntime {
    let completion: LambdaDeckRuntimeCompletion
    let streamTokens: [String]
    let finishReason: String
    let usage: OpenAIUsage

    func complete(request: OpenAIChatCompletionsRequest) async throws -> LambdaDeckRuntimeCompletion {
        self.completion
    }

    func stream(request: OpenAIChatCompletionsRequest) -> AsyncThrowingStream<LambdaDeckRuntimeStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            for token in self.streamTokens {
                continuation.yield(.token(token))
            }
            continuation.yield(.finished(finishReason: self.finishReason, usage: self.usage))
            continuation.finish()
        }
    }
}

private final class DisconnectingWriter: ResponseBodyWriter {
    private(set) var writeCount: Int = 0

    func write(_ buffer: ByteBuffer) async throws {
        self.writeCount += 1
        throw CancellationError()
    }

    func finish(_ trailingHeaders: HTTPFields?) async throws {}
}

private actor RuntimeLoaderGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !self.isOpen else {
            return
        }

        await withCheckedContinuation { continuation in
            if self.isOpen {
                continuation.resume()
                return
            }
            self.waiters.append(continuation)
        }
    }

    func open() {
        guard !self.isOpen else {
            return
        }

        self.isOpen = true
        let continuations = self.waiters
        self.waiters.removeAll()
        for continuation in continuations {
            continuation.resume()
        }
    }
}
