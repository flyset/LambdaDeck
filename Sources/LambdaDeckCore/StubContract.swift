import Foundation

public struct StubChatMessage: Codable, Equatable, Sendable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public struct StubChatChoice: Codable, Equatable, Sendable {
    public let index: Int
    public let message: StubChatMessage
    public let finishReason: String

    public init(index: Int, message: StubChatMessage, finishReason: String) {
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

public struct StubChatUsage: Codable, Equatable, Sendable {
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

public struct StubChatCompletionResponse: Codable, Equatable, Sendable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [StubChatChoice]
    public let usage: StubChatUsage

    public init(
        id: String,
        object: String,
        created: Int,
        model: String,
        choices: [StubChatChoice],
        usage: StubChatUsage
    ) {
        self.id = id
        self.object = object
        self.created = created
        self.model = model
        self.choices = choices
        self.usage = usage
    }
}

public enum StubContractGenerator {
    public static func chatCompletionResponse(
        model: String = "stub-model",
        content: String = "Stub response from LambdaDeck."
    ) -> StubChatCompletionResponse {
        StubChatCompletionResponse(
            id: "chatcmpl-stub-0001",
            object: "chat.completion",
            created: 0,
            model: model,
            choices: [
                StubChatChoice(
                    index: 0,
                    message: StubChatMessage(role: "assistant", content: content),
                    finishReason: "stop"
                )
            ],
            usage: StubChatUsage(promptTokens: 0, completionTokens: 0, totalTokens: 0)
        )
    }

    public static func chatCompletionJSON(
        model: String = "stub-model",
        content: String = "Stub response from LambdaDeck."
    ) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let response = chatCompletionResponse(model: model, content: content)
        let data = try encoder.encode(response)
        return String(decoding: data, as: UTF8.self)
    }
}
