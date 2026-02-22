import XCTest
@testable import LambdaDeckCLI
import LambdaDeckCore

final class LambdaDeckCLITests: XCTestCase {
    func testNoArgumentsPrintsTopLevelHelp() {
        let result = LambdaDeckCLI.run(arguments: [])

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.standardError, "")
        XCTAssertTrue(result.standardOutput.contains("USAGE: lambdadeck"))
        XCTAssertTrue(result.standardOutput.contains("serve"))
        XCTAssertTrue(result.standardOutput.contains("contract"))
        XCTAssertTrue(result.standardOutput.contains("help"))
    }

    func testHelpSubcommandPrintsTopLevelHelp() {
        let result = LambdaDeckCLI.run(arguments: ["help"])

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.standardError, "")
        XCTAssertTrue(result.standardOutput.contains("USAGE: lambdadeck"))
        XCTAssertTrue(result.standardOutput.contains("SUBCOMMANDS:"))
    }

    func testVersionFlagPrintsVersion() {
        let result = LambdaDeckCLI.run(arguments: ["--version"])

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.standardError, "")
        XCTAssertTrue(result.standardOutput.contains(LambdaDeckVersion.current))
    }

    func testUnknownFlagReturnsUsageFailure() {
        let result = LambdaDeckCLI.run(arguments: ["--unknown"])

        XCTAssertEqual(result.exitCode, 64)
        XCTAssertEqual(result.standardOutput, "")
        XCTAssertTrue(result.standardError.contains("Unknown option '--unknown'"))
    }

    func testHelpServePrintsServeHelp() {
        let result = LambdaDeckCLI.run(arguments: ["help", "serve"])

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.standardError, "")
        XCTAssertTrue(result.standardOutput.contains("USAGE: lambdadeck serve"))
        XCTAssertTrue(result.standardOutput.contains("--port <port>"))
    }

    func testServeHelpFlagPrintsServeHelp() {
        let result = LambdaDeckCLI.run(arguments: ["serve", "--help"])

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.standardError, "")
        XCTAssertTrue(result.standardOutput.contains("USAGE: lambdadeck serve"))
    }

    func testHelpUnknownTopicReturnsUsageFailure() {
        let result = LambdaDeckCLI.run(arguments: ["help", "wat"])

        XCTAssertEqual(result.exitCode, 64)
        XCTAssertEqual(result.standardOutput, "")
        XCTAssertTrue(result.standardError.contains("Unknown help topic 'wat'"))
        XCTAssertTrue(result.standardError.contains("Available topics"))
    }

    func testRemovedStubContractReturnsMigrationHint() {
        let result = LambdaDeckCLI.run(arguments: ["--stub-contract"])

        XCTAssertEqual(result.exitCode, 64)
        XCTAssertEqual(result.standardOutput, "")
        XCTAssertTrue(result.standardError.contains("Use 'lambdadeck contract stub'"))
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

    func testContractStubCommandReturnsOpenAIShapedJSON() throws {
        let result = LambdaDeckCLI.run(arguments: ["contract", "stub"])

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.standardError, "")

        let payload = try JSONDecoder().decode(
            StubChatCompletionResponse.self,
            from: Data(result.standardOutput.utf8)
        )

        XCTAssertEqual(payload.object, "chat.completion")
    }
}
