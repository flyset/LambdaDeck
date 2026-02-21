import Foundation

public typealias StubChatMessage = OpenAIChatMessage
public typealias StubChatChoice = OpenAIChatCompletionChoice
public typealias StubChatUsage = OpenAIUsage
public typealias StubChatCompletionResponse = OpenAIChatCompletionResponse

public enum StubContractGenerator {
    public static func chatCompletionResponse(
        model: String = StubChatFixtures.modelID,
        content: String = StubChatFixtures.completionText
    ) -> StubChatCompletionResponse {
        StubChatFixtures.completionResponse(model: model, content: content)
    }

    public static func chatCompletionJSON(
        model: String = StubChatFixtures.modelID,
        content: String = StubChatFixtures.completionText
    ) throws -> String {
        try OpenAIJSON.encodeToString(chatCompletionResponse(model: model, content: content))
    }
}
