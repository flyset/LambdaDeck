import Foundation

struct Gemma3PromptStrategy: PromptStrategy {
    let systemPolicy: LambdaDeckPromptSystemPolicy

    init(systemPolicy: LambdaDeckPromptSystemPolicy = .prefixFirstUser) {
        self.systemPolicy = systemPolicy
    }

    func render(messages: [OpenAIChatMessage]) throws -> [PromptSegment] {
        guard !messages.isEmpty else {
            throw LambdaDeckRuntimeError.invalidRequest("messages must contain at least one message")
        }

        var remainingMessages = messages
        let systemContent: String?
        if let first = messages.first, first.role == "system" {
            systemContent = first.content.trimmingCharacters(in: .whitespacesAndNewlines)
            remainingMessages = Array(messages.dropFirst())
        } else {
            systemContent = nil
        }

        guard !remainingMessages.isEmpty else {
            throw LambdaDeckRuntimeError.invalidRequest("at least one user message is required")
        }

        var segments: [PromptSegment] = [.special(.bos)]
        if systemPolicy == .ownTurn, let systemContent, !systemContent.isEmpty {
            segments.append(.special(.startOfTurn(.system)))
            segments.append(.text(systemContent))
            segments.append(.special(.endOfTurn))
        }

        let systemPrefix = systemContent.map { $0 + "\n\n" } ?? ""
        for (index, message) in remainingMessages.enumerated() {
            let expectedRole = index % 2 == 0 ? "user" : "assistant"
            guard message.role == expectedRole else {
                throw LambdaDeckRuntimeError.invalidRequest(
                    "Conversation roles must alternate user/assistant/user/assistant... for Gemma models"
                )
            }

            let role: Role = message.role == "assistant" ? .assistant : .user
            segments.append(.special(.startOfTurn(role)))

            if index == 0, systemPolicy == .prefixFirstUser, !systemPrefix.isEmpty {
                segments.append(.text(systemPrefix))
            }

            let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            segments.append(.text(content))
            segments.append(.special(.endOfTurn))
        }

        segments.append(.special(.startOfTurn(.assistant)))
        return segments
    }
}
