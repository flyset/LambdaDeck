import Foundation
import XCTest
@testable import LambdaDeckCLI
import LambdaDeckCore

final class StubContractIntegrationTests: XCTestCase {
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
}
