import XCTest
@testable import LambdaDeckCLI

final class LambdaDeckCLITests: XCTestCase {
    func testNoArgumentsPrintsHelp() {
        let result = LambdaDeckCLI.run(arguments: [])

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.standardError, "")
        XCTAssertTrue(result.standardOutput.contains("Usage: lambdadeck"))
    }

    func testHelpFlagPrintsHelp() {
        let result = LambdaDeckCLI.run(arguments: ["--help"])

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.standardError, "")
        XCTAssertTrue(result.standardOutput.contains("--version"))
    }

    func testVersionFlagPrintsVersion() {
        let result = LambdaDeckCLI.run(arguments: ["--version"])

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.standardError, "")
        XCTAssertTrue(result.standardOutput.hasPrefix("lambdadeck "))
    }

    func testUnknownFlagReturnsNonZero() {
        let result = LambdaDeckCLI.run(arguments: ["--unknown"])

        XCTAssertEqual(result.exitCode, 1)
        XCTAssertEqual(result.standardOutput, "")
        XCTAssertTrue(result.standardError.contains("unknown argument"))
    }
}
