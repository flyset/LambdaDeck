import XCTest
@testable import LambdaDeckCLI
import LambdaDeckCore

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

    func testServeHelpFlagPrintsServeHelp() {
        let result = LambdaDeckCLI.run(arguments: ["serve", "--help"])

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.standardError, "")
        XCTAssertTrue(result.standardOutput.contains("Usage: lambdadeck serve"))
    }

    func testParseServeCommandParsesOptions() {
        let command = LambdaDeckCLI.parse(arguments: [
            "serve",
            "--stub",
            "--host", "0.0.0.0",
            "--port", "9000",
            "--model-path", "/tmp/model"
        ])

        XCTAssertEqual(
            command,
            .serve(
                LambdaDeckServeOptions(
                    host: "0.0.0.0",
                    port: 9000,
                    stubMode: true,
                    modelPath: "/tmp/model"
                )
            )
        )
    }
}
