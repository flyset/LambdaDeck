import XCTest
@testable import LambdaDeckCore

final class PromptStrategyConformanceTests: XCTestCase {
    func testGemma3PromptStrategyRendersSystemUserAssistantSegments() throws {
        let messages = [
            OpenAIChatMessage(role: "system", content: "System rules"),
            OpenAIChatMessage(role: "user", content: "Hello"),
            OpenAIChatMessage(role: "assistant", content: "Hi")
        ]
        let strategy = Gemma3PromptStrategy(systemPolicy: .prefixFirstUser)

        let segments = try strategy.render(messages: messages)

        let expected: [PromptSegment] = [
            .special(.bos),
            .special(.startOfTurn(.user)),
            .text("System rules\n\n"),
            .text("Hello"),
            .special(.endOfTurn),
            .special(.startOfTurn(.assistant)),
            .text("Hi"),
            .special(.endOfTurn),
            .special(.startOfTurn(.assistant))
        ]

        XCTAssertEqual(segments, expected)
    }

    func testChatMLPromptStrategyRendersSystemAsOwnTurn() throws {
        let messages = [
            OpenAIChatMessage(role: "system", content: "System rules"),
            OpenAIChatMessage(role: "user", content: "Hello")
        ]
        let strategy = ChatMLPromptStrategy(systemPolicy: .ownTurn)

        let segments = try strategy.render(messages: messages)

        let expected: [PromptSegment] = [
            .special(.startOfTurn(.system)),
            .text("System rules"),
            .special(.endOfTurn),
            .special(.startOfTurn(.user)),
            .text("Hello"),
            .special(.endOfTurn),
            .special(.startOfTurn(.assistant))
        ]

        XCTAssertEqual(segments, expected)
    }
}
