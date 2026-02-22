import Foundation
import Hummingbird

public struct LambdaDeckServerConfiguration: Equatable, Sendable {
    public let host: String
    public let port: Int
    public let resolvedModel: LambdaDeckResolvedModel
    public let inferenceRuntime: (any LambdaDeckInferenceRuntime)?
    public let inferenceRuntimeProvider: LambdaDeckRuntimeProvider?
    public let maxRequestBodyBytes: Int
    public let runtimeWarmupTimeoutNanoseconds: UInt64
    public let streamChunkDelayNanoseconds: UInt64

    public init(
        host: String,
        port: Int,
        resolvedModel: LambdaDeckResolvedModel,
        inferenceRuntime: (any LambdaDeckInferenceRuntime)? = nil,
        inferenceRuntimeProvider: LambdaDeckRuntimeProvider? = nil,
        maxRequestBodyBytes: Int = 2_000_000,
        runtimeWarmupTimeoutNanoseconds: UInt64 = 5_000_000_000,
        streamChunkDelayNanoseconds: UInt64 = 0
    ) {
        self.host = host
        self.port = port
        self.resolvedModel = resolvedModel
        self.inferenceRuntime = inferenceRuntime
        self.inferenceRuntimeProvider = inferenceRuntimeProvider
        self.maxRequestBodyBytes = maxRequestBodyBytes
        self.runtimeWarmupTimeoutNanoseconds = runtimeWarmupTimeoutNanoseconds
        self.streamChunkDelayNanoseconds = streamChunkDelayNanoseconds
    }

    public static func == (lhs: LambdaDeckServerConfiguration, rhs: LambdaDeckServerConfiguration) -> Bool {
        lhs.host == rhs.host
            && lhs.port == rhs.port
            && lhs.resolvedModel == rhs.resolvedModel
            && ((lhs.inferenceRuntime == nil) == (rhs.inferenceRuntime == nil))
            && ((lhs.inferenceRuntimeProvider == nil) == (rhs.inferenceRuntimeProvider == nil))
            && lhs.maxRequestBodyBytes == rhs.maxRequestBodyBytes
            && lhs.runtimeWarmupTimeoutNanoseconds == rhs.runtimeWarmupTimeoutNanoseconds
            && lhs.streamChunkDelayNanoseconds == rhs.streamChunkDelayNanoseconds
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
        let inferenceRuntimeProvider = resolvedModel.isStub
            ? nil
            : LambdaDeckRuntimeProvider(resolvedModel: resolvedModel, preload: true)
        return LambdaDeckServerConfiguration(
            host: options.host,
            port: options.port,
            resolvedModel: resolvedModel,
            inferenceRuntimeProvider: inferenceRuntimeProvider
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
        let inferenceRuntime = configuration.inferenceRuntime
        let inferenceRuntimeProvider = configuration.inferenceRuntimeProvider

        router.get("v1/models") { _, _ async -> Response in
            jsonResponse(
                status: .ok,
                payload: OpenAIModelListResponse(data: [OpenAIModelCard(id: modelID)])
            )
        }

        router.get("readyz") { _, _ async -> Response in
            await readinessResponse(
                modelID: modelID,
                runtime: inferenceRuntime,
                runtimeProvider: inferenceRuntimeProvider
            )
        }

        router.post("v1/chat/completions") { request, _ async -> Response in
            await handleChatCompletions(
                request: request,
                modelID: modelID,
                runtime: inferenceRuntime,
                runtimeProvider: inferenceRuntimeProvider,
                maxRequestBodyBytes: configuration.maxRequestBodyBytes,
                runtimeWarmupTimeoutNanoseconds: configuration.runtimeWarmupTimeoutNanoseconds,
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
        runtime: (any LambdaDeckInferenceRuntime)?,
        runtimeProvider: LambdaDeckRuntimeProvider?,
        maxRequestBodyBytes: Int,
        runtimeWarmupTimeoutNanoseconds: UInt64,
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

            let resolvedRuntime: (any LambdaDeckInferenceRuntime)?
            do {
                if let runtime {
                    resolvedRuntime = runtime
                } else if let runtimeProvider {
                    resolvedRuntime = try await runtimeProvider.runtimeInstance(
                        maxWaitNanoseconds: runtimeWarmupTimeoutNanoseconds
                    )
                } else {
                    resolvedRuntime = nil
                }
            } catch let runtimeError as LambdaDeckRuntimeError {
                switch runtimeError {
                case .invalidRequest(let message):
                    return invalidRequestResponse(message)
                case .runtimeWarmingUp(let message):
                    return serviceUnavailableResponse(message)
                default:
                    return internalErrorResponse(runtimeError.localizedDescription)
                }
            } catch {
                return internalErrorResponse("runtime inference initialization failed")
            }

            if chatRequest.stream == true {
                if let resolvedRuntime {
                    return streamingResponse(
                        modelID: modelID,
                        request: chatRequest,
                        runtime: resolvedRuntime,
                        streamChunkDelayNanoseconds: streamChunkDelayNanoseconds
                    )
                }
                return streamingResponse(
                    modelID: modelID,
                    streamChunkDelayNanoseconds: streamChunkDelayNanoseconds
                )
            }

            if let resolvedRuntime {
                do {
                    let completion = try await resolvedRuntime.complete(request: chatRequest)
                    return jsonResponse(
                        status: .ok,
                        payload: OpenAIChatCompletionResponse(
                            id: "chatcmpl-\(UUID().uuidString.lowercased())",
                            object: "chat.completion",
                            created: Int(Date().timeIntervalSince1970),
                            model: modelID,
                            choices: [
                                OpenAIChatCompletionChoice(
                                    index: 0,
                                    message: OpenAIChatMessage(role: "assistant", content: completion.content),
                                    finishReason: completion.finishReason
                                )
                            ],
                            usage: completion.usage
                        )
                    )
                } catch let runtimeError as LambdaDeckRuntimeError {
                    switch runtimeError {
                    case .invalidRequest(let message):
                        return invalidRequestResponse(message)
                    default:
                        return internalErrorResponse(runtimeError.localizedDescription)
                    }
                } catch {
                    return internalErrorResponse("runtime inference failed")
                }
            }

            return jsonResponse(
                status: .ok,
                payload: StubChatFixtures.completionResponse(model: modelID)
            )
        } catch {
            return invalidRequestResponse("invalid JSON body for /v1/chat/completions")
        }
    }

    static func readinessResponse(
        modelID: String,
        runtime: (any LambdaDeckInferenceRuntime)?,
        runtimeProvider: LambdaDeckRuntimeProvider?
    ) async -> Response {
        if runtime != nil {
            return jsonResponse(
                status: .ok,
                payload: LambdaDeckReadinessResponse(
                    status: .ready,
                    model: modelID,
                    elapsedMilliseconds: 0
                )
            )
        }

        if let runtimeProvider {
            let readiness = await runtimeProvider.readinessSnapshot()
            let payload = LambdaDeckReadinessResponse(
                status: readiness.status,
                model: modelID,
                elapsedMilliseconds: readiness.elapsedMilliseconds,
                error: readiness.error
            )
            switch readiness.status {
            case .ready:
                return jsonResponse(status: .ok, payload: payload)
            case .warmingUp, .failed:
                return jsonResponse(status: .serviceUnavailable, payload: payload)
            }
        }

        return jsonResponse(
            status: .ok,
            payload: LambdaDeckReadinessResponse(
                status: .ready,
                model: modelID,
                elapsedMilliseconds: 0
            )
        )
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

    static func streamingResponse(
        modelID: String,
        request: OpenAIChatCompletionsRequest,
        runtime: any LambdaDeckInferenceRuntime,
        streamChunkDelayNanoseconds: UInt64
    ) -> Response {
        var headers = HTTPFields()
        headers[.contentType] = "text/event-stream"
        headers[.cacheControl] = "no-cache"
        headers[.connection] = "keep-alive"

        let body = ResponseBody { writer in
            do {
                try await SSEEventWriter.writeRuntimeStream(
                    runtimeStream: runtime.stream(request: request),
                    modelID: modelID,
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

    static func internalErrorResponse(_ message: String) -> Response {
        jsonResponse(
            status: .internalServerError,
            payload: OpenAIErrorResponse(
                error: OpenAIErrorBody(
                    message: message,
                    type: "server_error"
                )
            )
        )
    }

    static func serviceUnavailableResponse(_ message: String) -> Response {
        jsonResponse(
            status: .serviceUnavailable,
            payload: OpenAIErrorResponse(
                error: OpenAIErrorBody(
                    message: message,
                    type: "server_error"
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

    static func writeRuntimeStream(
        runtimeStream: AsyncThrowingStream<LambdaDeckRuntimeStreamEvent, Error>,
        modelID: String,
        chunkDelayNanoseconds: UInt64,
        writer: inout any ResponseBodyWriter
    ) async throws {
        let completionID = "chatcmpl-\(UUID().uuidString.lowercased())"
        let created = Int(Date().timeIntervalSince1970)

        let roleChunk = OpenAIChatCompletionChunk(
            id: completionID,
            object: "chat.completion.chunk",
            created: created,
            model: modelID,
            choices: [
                OpenAIChatCompletionChunkChoice(
                    index: 0,
                    delta: OpenAIChatCompletionChunkDelta(role: "assistant"),
                    finishReason: nil
                )
            ]
        )
        try await writeSingleChunk(
            roleChunk,
            chunkDelayNanoseconds: chunkDelayNanoseconds,
            writer: &writer
        )

        for try await event in runtimeStream {
            try Task.checkCancellation()

            switch event {
            case .token(let token):
                guard !token.isEmpty else {
                    continue
                }
                let contentChunk = OpenAIChatCompletionChunk(
                    id: completionID,
                    object: "chat.completion.chunk",
                    created: created,
                    model: modelID,
                    choices: [
                        OpenAIChatCompletionChunkChoice(
                            index: 0,
                            delta: OpenAIChatCompletionChunkDelta(content: token),
                            finishReason: nil
                        )
                    ]
                )
                try await writeSingleChunk(
                    contentChunk,
                    chunkDelayNanoseconds: chunkDelayNanoseconds,
                    writer: &writer
                )
            case .finished(let finishReason, _):
                let terminalChunk = OpenAIChatCompletionChunk(
                    id: completionID,
                    object: "chat.completion.chunk",
                    created: created,
                    model: modelID,
                    choices: [
                        OpenAIChatCompletionChunkChoice(
                            index: 0,
                            delta: OpenAIChatCompletionChunkDelta(),
                            finishReason: finishReason
                        )
                    ]
                )
                try await writeSingleChunk(
                    terminalChunk,
                    chunkDelayNanoseconds: chunkDelayNanoseconds,
                    writer: &writer
                )
            }
        }

        try await writeSingleEvent(
            "data: [DONE]\n\n",
            chunkDelayNanoseconds: chunkDelayNanoseconds,
            writer: &writer
        )
        try await writer.finish(nil)
    }

    private static func writeSingleChunk(
        _ chunk: OpenAIChatCompletionChunk,
        chunkDelayNanoseconds: UInt64,
        writer: inout any ResponseBodyWriter
    ) async throws {
        let payload = try OpenAIJSON.encodeToString(chunk)
        try await writeSingleEvent(
            "data: \(payload)\n\n",
            chunkDelayNanoseconds: chunkDelayNanoseconds,
            writer: &writer
        )
    }

    private static func writeSingleEvent(
        _ event: String,
        chunkDelayNanoseconds: UInt64,
        writer: inout any ResponseBodyWriter
    ) async throws {
        try Task.checkCancellation()
        if chunkDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: chunkDelayNanoseconds)
        }
        var buffer = ByteBufferAllocator().buffer(capacity: event.utf8.count)
        buffer.writeString(event)
        try await writer.write(buffer)
    }
}
