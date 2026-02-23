import Foundation

struct ChatMLPromptStrategy: PromptStrategy {
    let systemPolicy: LambdaDeckPromptSystemPolicy

    init(systemPolicy: LambdaDeckPromptSystemPolicy = .ownTurn) {
        self.systemPolicy = systemPolicy
    }

    func render(messages: [OpenAIChatMessage]) throws -> [PromptSegment] {
        guard !messages.isEmpty else {
            throw LambdaDeckRuntimeError.invalidRequest("messages must contain at least one message")
        }

        var remainingMessages = messages
        var systemContent: String?
        if let first = messages.first, first.role == "system" {
            systemContent = first.content.trimmingCharacters(in: .whitespacesAndNewlines)
            remainingMessages = Array(messages.dropFirst())
        }

        var segments: [PromptSegment] = []
        var systemContentValue = systemContent
        var systemPrefix: String? = nil
        if systemPolicy == .prefixFirstUser, let systemValue = systemContentValue, !systemValue.isEmpty {
            if remainingMessages.contains(where: { $0.role == "user" }) {
                systemPrefix = systemValue + "\n\n"
            } else {
                segments.append(.special(.startOfTurn(.system)))
                segments.append(.text(systemValue))
                segments.append(.special(.endOfTurn))
                systemContentValue = nil
            }
        }

        var appliedSystemPrefix = false
        for message in remainingMessages {
            let role = try roleForChatML(message.role)
            segments.append(.special(.startOfTurn(role)))

            var content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if role == .user, let systemPrefix, !systemPrefix.isEmpty, systemPolicy == .prefixFirstUser, !appliedSystemPrefix {
                content = systemPrefix + content
                appliedSystemPrefix = true
            }

            segments.append(.text(content))
            segments.append(.special(.endOfTurn))
        }

        if systemPolicy == .ownTurn, let systemValue = systemContentValue, !systemValue.isEmpty {
            let systemSegments: [PromptSegment] = [
                .special(.startOfTurn(.system)),
                .text(systemValue),
                .special(.endOfTurn)
            ]
            segments.insert(contentsOf: systemSegments, at: 0)
        }

        segments.append(.special(.startOfTurn(.assistant)))
        return segments
    }

    private func roleForChatML(_ role: String) throws -> Role {
        switch role {
        case "system":
            return .system
        case "user":
            return .user
        case "assistant":
            return .assistant
        default:
            throw LambdaDeckRuntimeError.invalidRequest("Unsupported role '\(role)'.")
        }
    }
}
