import Foundation

struct ChatTranscriptPromptStrategy: PromptStrategy {
    func render(messages: [OpenAIChatMessage]) throws -> [PromptSegment] {
        guard !messages.isEmpty else {
            throw LambdaDeckRuntimeError.invalidRequest("messages must contain at least one message")
        }

        let transcript = messages
            .map { "\($0.role): \($0.content)" }
            .joined(separator: "\n")

        return [
            .text(transcript + "\nassistant:")
        ]
    }
}
