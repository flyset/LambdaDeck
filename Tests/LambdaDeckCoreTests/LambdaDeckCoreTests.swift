import XCTest
@testable import LambdaDeckCore

final class LambdaDeckCoreTests: XCTestCase {
    func testVersionLooksLikeSemver() {
        let version = LambdaDeckVersion.current
        let matches = version.range(of: #"^\d+\.\d+\.\d+$"#, options: .regularExpression) != nil

        XCTAssertTrue(matches)
    }

    func testStubContractResponseIsDeterministic() {
        let response = StubContractGenerator.chatCompletionResponse()

        XCTAssertEqual(response.id, "chatcmpl-stub-0001")
        XCTAssertEqual(response.object, "chat.completion")
        XCTAssertEqual(response.model, "stub-model")
        XCTAssertEqual(response.choices.count, 1)
        XCTAssertEqual(response.choices[0].message.role, "assistant")
        XCTAssertEqual(response.choices[0].finishReason, "stop")
    }
}
