import Foundation
import Hummingbird
import HummingbirdTesting
import NIOCore
import XCTest
@testable import LambdaDeckCLI
@testable import LambdaDeckCore

final class OpenAIContractIntegrationTests: XCTestCase {
    func testStubContractHookReturnsOpenAIShapedJSON() throws {
        let result = LambdaDeckCLI.run(arguments: ["--stub-contract"])

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
}

private final class DisconnectingWriter: ResponseBodyWriter {
    private(set) var writeCount: Int = 0

    func write(_ buffer: ByteBuffer) async throws {
        self.writeCount += 1
        throw CancellationError()
    }

    func finish(_ trailingHeaders: HTTPFields?) async throws {}
}
