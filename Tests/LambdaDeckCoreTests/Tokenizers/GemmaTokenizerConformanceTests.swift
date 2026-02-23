import Foundation
import XCTest
@testable import LambdaDeckCore

final class GemmaTokenizerConformanceTests: XCTestCase {
    func testGemmaTokenizerEncodesSegmentsWithSpecialTokens() throws {
        try withTemporaryDirectory { directory in
            try createTokenizerAssets(in: directory)
            let tokenizer = try GemmaBPETokenizer(directory: directory)

            let segments: [PromptSegment] = [
                .special(.bos),
                .text("A"),
                .special(.eos)
            ]

            let tokenIDs = try tokenizer.encode(segments: segments)

            XCTAssertEqual(tokenIDs, [1, 6, 2])
        }
    }

    private func withTemporaryDirectory(_ operation: (URL) throws -> Void) throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LambdaDeckTokenizerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        try operation(directory)
    }

    private func createTokenizerAssets(in root: URL) throws {
        let tokenizerJSON = """
        {
          "model": {
            "vocab": {
              "<unk>": 0,
              "<bos>": 1,
              "<eos>": 2,
              "<start_of_turn>": 3,
              "<end_of_turn>": 4,
              "▁": 5,
              "A": 6,
              "B": 7,
              "<0x41>": 8,
              "<0x42>": 9
            },
            "merges": []
          }
        }
        """
        let tokenizerConfig = """
        {
          "bos_token": "<bos>",
          "eos_token": "<eos>"
        }
        """

        try tokenizerJSON.write(
            to: root.appendingPathComponent("tokenizer.json"),
            atomically: true,
            encoding: .utf8
        )
        try tokenizerConfig.write(
            to: root.appendingPathComponent("tokenizer_config.json"),
            atomically: true,
            encoding: .utf8
        )
    }
}
