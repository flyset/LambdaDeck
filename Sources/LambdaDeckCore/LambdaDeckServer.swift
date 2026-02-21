import Foundation
import Hummingbird

public struct LambdaDeckServerConfiguration: Equatable, Sendable {
    public let host: String
    public let port: Int
    public let resolvedModel: LambdaDeckResolvedModel
    public let maxRequestBodyBytes: Int
    public let streamChunkDelayNanoseconds: UInt64

    public init(
        host: String,
        port: Int,
        resolvedModel: LambdaDeckResolvedModel,
        maxRequestBodyBytes: Int = 2_000_000,
        streamChunkDelayNanoseconds: UInt64 = 0
    ) {
        self.host = host
        self.port = port
        self.resolvedModel = resolvedModel
        self.maxRequestBodyBytes = maxRequestBodyBytes
        self.streamChunkDelayNanoseconds = streamChunkDelayNanoseconds
    }
}

public enum LambdaDeckServerBootstrap {
    public static func resolveConfiguration(
        options: LambdaDeckServeOptions,
        environment: LambdaDeckEnvironment = .processInfo,
        currentDirectory: String = FileManager.default.currentDirectoryPath
    ) throws -> LambdaDeckServerConfiguration {
        let resolvedModel = try LambdaDeckModelResolver.resolve(
            options: options,
            environment: environment,
            currentDirectory: currentDirectory
        )
        return LambdaDeckServerConfiguration(
            host: options.host,
            port: options.port,
            resolvedModel: resolvedModel
        )
    }
}

public enum LambdaDeckServer {
    public static func run(
        configuration: LambdaDeckServerConfiguration,
        onServerRunning: (@Sendable (Int) async -> Void)? = nil
    ) async throws {
        let app = makeApplication(configuration: configuration, onServerRunning: onServerRunning)
        try await app.runService()
    }

    static func makeApplication(
        configuration: LambdaDeckServerConfiguration,
        onServerRunning: (@Sendable (Int) async -> Void)? = nil
    ) -> some ApplicationProtocol {
        let router = Router()
        let modelID = configuration.resolvedModel.modelID

        router.get("v1/models") { _, _ async -> Response in
            jsonResponse(
                status: .ok,
                payload: OpenAIModelListResponse(data: [OpenAIModelCard(id: modelID)])
            )
        }

        router.post("v1/chat/completions") { request, _ async -> Response in
            await handleChatCompletions(
                request: request,
                modelID: modelID,
                maxRequestBodyBytes: configuration.maxRequestBodyBytes,
                streamChunkDelayNanoseconds: configuration.streamChunkDelayNanoseconds
            )
        }

        return Application(
            router: router,
            configuration: .init(address: .hostname(configuration.host, port: configuration.port)),
            onServerRunning: { channel in
                let activePort = channel.localAddress?.port ?? configuration.port
                await onServerRunning?(activePort)
            }
        )
    }

    static func handleChatCompletions(
        request: Request,
        modelID: String,
        maxRequestBodyBytes: Int,
        streamChunkDelayNanoseconds: UInt64
    ) async -> Response {
        do {
            let buffer = try await request.body.collect(upTo: maxRequestBodyBytes)
            let data = byteBufferToData(buffer)
            let chatRequest = try JSONDecoder().decode(OpenAIChatCompletionsRequest.self, from: data)

            guard !chatRequest.messages.isEmpty else {
                return invalidRequestResponse("messages must contain at least one message")
            }

            guard chatRequest.model == modelID else {
                return invalidRequestResponse(
                    "model '\(chatRequest.model)' is not available; configured model is '\(modelID)'"
                )
            }

            if chatRequest.stream == true {
                return streamingResponse(
                    modelID: modelID,
                    streamChunkDelayNanoseconds: streamChunkDelayNanoseconds
                )
            }

            return jsonResponse(
                status: .ok,
                payload: StubChatFixtures.completionResponse(model: modelID)
            )
        } catch {
            return invalidRequestResponse("invalid JSON body for /v1/chat/completions")
        }
    }

    static func streamingResponse(modelID: String, streamChunkDelayNanoseconds: UInt64) -> Response {
        var headers = HTTPFields()
        headers[.contentType] = "text/event-stream"
        headers[.cacheControl] = "no-cache"
        headers[.connection] = "keep-alive"

        let body = ResponseBody { writer in
            do {
                let events = try StubChatFixtures.sseEvents(model: modelID)
                try await SSEEventWriter.write(
                    events: events,
                    chunkDelayNanoseconds: streamChunkDelayNanoseconds,
                    writer: &writer
                )
            } catch {
                return
            }
        }
        return Response(status: .ok, headers: headers, body: body)
    }

    static func invalidRequestResponse(_ message: String) -> Response {
        jsonResponse(
            status: .badRequest,
            payload: OpenAIErrorResponse(
                error: OpenAIErrorBody(
                    message: message,
                    type: "invalid_request_error"
                )
            )
        )
    }

    static func jsonResponse<T: Encodable>(status: HTTPResponse.Status, payload: T) -> Response {
        do {
            let data = try JSONEncoder().encode(payload)
            var headers = HTTPFields()
            headers[.contentType] = "application/json; charset=utf-8"
            headers[.contentLength] = String(data.count)
            var buffer = ByteBufferAllocator().buffer(capacity: data.count)
            buffer.writeBytes(data)
            return Response(status: status, headers: headers, body: .init(byteBuffer: buffer))
        } catch {
            return Response(status: .internalServerError)
        }
    }

    static func byteBufferToData(_ buffer: ByteBuffer) -> Data {
        var mutable = buffer
        return mutable.readData(length: mutable.readableBytes) ?? Data()
    }
}

enum SSEEventWriter {
    static func write(
        events: [String],
        chunkDelayNanoseconds: UInt64,
        writer: inout any ResponseBodyWriter
    ) async throws {
        let allocator = ByteBufferAllocator()
        for event in events {
            try Task.checkCancellation()
            if chunkDelayNanoseconds > 0 {
                try await Task.sleep(nanoseconds: chunkDelayNanoseconds)
            }
            var buffer = allocator.buffer(capacity: event.utf8.count)
            buffer.writeString(event)
            try await writer.write(buffer)
        }
        try await writer.finish(nil)
    }
}
