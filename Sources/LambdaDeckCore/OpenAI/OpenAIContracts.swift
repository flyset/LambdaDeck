import Foundation

public struct OpenAIChatMessage: Codable, Equatable, Sendable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public struct OpenAIStreamOptions: Codable, Equatable, Sendable {
    public let includeUsage: Bool?

    public init(includeUsage: Bool? = nil) {
        self.includeUsage = includeUsage
    }

    enum CodingKeys: String, CodingKey {
        case includeUsage = "include_usage"
    }
}

public enum OpenAIStop: Codable, Equatable, Sendable {
    case single(String)
    case multiple([String])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let single = try? container.decode(String.self) {
            self = .single(single)
            return
        }
        if let multiple = try? container.decode([String].self) {
            self = .multiple(multiple)
            return
        }
        throw DecodingError.typeMismatch(
            OpenAIStop.self,
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected string or [string] for stop")
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .single(let value):
            try container.encode(value)
        case .multiple(let values):
            try container.encode(values)
        }
    }
}

public struct OpenAIChatCompletionsRequest: Codable, Equatable, Sendable {
    public let model: String
    public let messages: [OpenAIChatMessage]
    public let temperature: Double?
    public let maxTokens: Int?
    public let topP: Double?
    public let n: Int?
    public let stop: OpenAIStop?
    public let user: String?
    public let stream: Bool?
    public let streamOptions: OpenAIStreamOptions?

    public init(
        model: String,
        messages: [OpenAIChatMessage],
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        topP: Double? = nil,
        n: Int? = nil,
        stop: OpenAIStop? = nil,
        user: String? = nil,
        stream: Bool? = nil,
        streamOptions: OpenAIStreamOptions? = nil
    ) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.topP = topP
        self.n = n
        self.stop = stop
        self.user = user
        self.stream = stream
        self.streamOptions = streamOptions
    }

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
        case topP = "top_p"
        case n
        case stop
        case user
        case stream
        case streamOptions = "stream_options"
    }
}

public struct OpenAIChatCompletionChoice: Codable, Equatable, Sendable {
    public let index: Int
    public let message: OpenAIChatMessage
    public let finishReason: String

    public init(index: Int, message: OpenAIChatMessage, finishReason: String) {
        self.index = index
        self.message = message
        self.finishReason = finishReason
    }

    enum CodingKeys: String, CodingKey {
        case index
        case message
        case finishReason = "finish_reason"
    }
}

public struct OpenAIUsage: Codable, Equatable, Sendable {
    public let promptTokens: Int
    public let completionTokens: Int
    public let totalTokens: Int

    public init(promptTokens: Int, completionTokens: Int, totalTokens: Int) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
    }

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

public struct OpenAIChatCompletionResponse: Codable, Equatable, Sendable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [OpenAIChatCompletionChoice]
    public let usage: OpenAIUsage

    public init(
        id: String,
        object: String,
        created: Int,
        model: String,
        choices: [OpenAIChatCompletionChoice],
        usage: OpenAIUsage
    ) {
        self.id = id
        self.object = object
        self.created = created
        self.model = model
        self.choices = choices
        self.usage = usage
    }
}

public struct OpenAIChatCompletionChunkDelta: Codable, Equatable, Sendable {
    public let role: String?
    public let content: String?

    public init(role: String? = nil, content: String? = nil) {
        self.role = role
        self.content = content
    }
}

public struct OpenAIChatCompletionChunkChoice: Codable, Equatable, Sendable {
    public let index: Int
    public let delta: OpenAIChatCompletionChunkDelta
    public let finishReason: String?

    public init(index: Int, delta: OpenAIChatCompletionChunkDelta, finishReason: String?) {
        self.index = index
        self.delta = delta
        self.finishReason = finishReason
    }

    enum CodingKeys: String, CodingKey {
        case index
        case delta
        case finishReason = "finish_reason"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.index = try container.decode(Int.self, forKey: .index)
        self.delta = try container.decode(OpenAIChatCompletionChunkDelta.self, forKey: .delta)
        self.finishReason = try container.decodeIfPresent(String.self, forKey: .finishReason)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.index, forKey: .index)
        try container.encode(self.delta, forKey: .delta)
        if let finishReason = self.finishReason {
            try container.encode(finishReason, forKey: .finishReason)
        } else {
            try container.encodeNil(forKey: .finishReason)
        }
    }
}

public struct OpenAIChatCompletionChunk: Codable, Equatable, Sendable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [OpenAIChatCompletionChunkChoice]

    public init(id: String, object: String, created: Int, model: String, choices: [OpenAIChatCompletionChunkChoice]) {
        self.id = id
        self.object = object
        self.created = created
        self.model = model
        self.choices = choices
    }
}

public struct OpenAIModelCard: Codable, Equatable, Sendable {
    public let id: String
    public let object: String
    public let created: Int
    public let ownedBy: String

    public init(id: String, object: String = "model", created: Int = 0, ownedBy: String = "lambdadeck") {
        self.id = id
        self.object = object
        self.created = created
        self.ownedBy = ownedBy
    }

    enum CodingKeys: String, CodingKey {
        case id
        case object
        case created
        case ownedBy = "owned_by"
    }
}

public struct OpenAIModelListResponse: Codable, Equatable, Sendable {
    public let object: String
    public let data: [OpenAIModelCard]

    public init(object: String = "list", data: [OpenAIModelCard]) {
        self.object = object
        self.data = data
    }
}

public struct OpenAIErrorBody: Codable, Equatable, Sendable {
    public let message: String
    public let type: String
    public let param: String?
    public let code: String?

    public init(message: String, type: String, param: String? = nil, code: String? = nil) {
        self.message = message
        self.type = type
        self.param = param
        self.code = code
    }
}

public struct OpenAIErrorResponse: Codable, Equatable, Sendable {
    public let error: OpenAIErrorBody

    public init(error: OpenAIErrorBody) {
        self.error = error
    }
}

public enum LambdaDeckReadinessStatus: String, Codable, Equatable, Sendable {
    case warmingUp = "warming_up"
    case ready
    case failed
}

public struct LambdaDeckReadinessResponse: Codable, Equatable, Sendable {
    public let status: LambdaDeckReadinessStatus
    public let model: String
    public let elapsedMilliseconds: Int
    public let error: String?

    public init(
        status: LambdaDeckReadinessStatus,
        model: String,
        elapsedMilliseconds: Int,
        error: String? = nil
    ) {
        self.status = status
        self.model = model
        self.elapsedMilliseconds = elapsedMilliseconds
        self.error = error
    }

    enum CodingKeys: String, CodingKey {
        case status
        case model
        case elapsedMilliseconds = "elapsed_ms"
        case error
    }
}

public enum OpenAIJSON {
    public static func encodeToString(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        return String(decoding: data, as: UTF8.self)
    }
}

public enum StubChatFixtures {
    public static let modelID = "stub-model"
    public static let completionID = "chatcmpl-stub-0001"
    public static let completionText = "Stub response from LambdaDeck."

    public static func completionResponse(
        model: String = StubChatFixtures.modelID,
        content: String = StubChatFixtures.completionText
    ) -> OpenAIChatCompletionResponse {
        OpenAIChatCompletionResponse(
            id: completionID,
            object: "chat.completion",
            created: 0,
            model: model,
            choices: [
                OpenAIChatCompletionChoice(
                    index: 0,
                    message: OpenAIChatMessage(role: "assistant", content: content),
                    finishReason: "stop"
                )
            ],
            usage: OpenAIUsage(promptTokens: 0, completionTokens: 0, totalTokens: 0)
        )
    }

    public static func completionChunks(model: String = StubChatFixtures.modelID) -> [OpenAIChatCompletionChunk] {
        [
            OpenAIChatCompletionChunk(
                id: completionID,
                object: "chat.completion.chunk",
                created: 0,
                model: model,
                choices: [
                    OpenAIChatCompletionChunkChoice(
                        index: 0,
                        delta: OpenAIChatCompletionChunkDelta(role: "assistant"),
                        finishReason: nil
                    )
                ]
            ),
            OpenAIChatCompletionChunk(
                id: completionID,
                object: "chat.completion.chunk",
                created: 0,
                model: model,
                choices: [
                    OpenAIChatCompletionChunkChoice(
                        index: 0,
                        delta: OpenAIChatCompletionChunkDelta(content: "Stub response "),
                        finishReason: nil
                    )
                ]
            ),
            OpenAIChatCompletionChunk(
                id: completionID,
                object: "chat.completion.chunk",
                created: 0,
                model: model,
                choices: [
                    OpenAIChatCompletionChunkChoice(
                        index: 0,
                        delta: OpenAIChatCompletionChunkDelta(content: "from LambdaDeck."),
                        finishReason: nil
                    )
                ]
            ),
            OpenAIChatCompletionChunk(
                id: completionID,
                object: "chat.completion.chunk",
                created: 0,
                model: model,
                choices: [
                    OpenAIChatCompletionChunkChoice(
                        index: 0,
                        delta: OpenAIChatCompletionChunkDelta(),
                        finishReason: "stop"
                    )
                ]
            )
        ]
    }

    public static func sseEvents(model: String = StubChatFixtures.modelID) throws -> [String] {
        let chunkEvents = try completionChunks(model: model).map { chunk in
            "data: \(try OpenAIJSON.encodeToString(chunk))\n\n"
        }
        return chunkEvents + ["data: [DONE]\n\n"]
    }
}
