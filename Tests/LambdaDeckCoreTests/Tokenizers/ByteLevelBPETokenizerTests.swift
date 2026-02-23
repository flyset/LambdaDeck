import Foundation
import XCTest
@testable import LambdaDeckCore

final class ByteLevelBPETokenizerTests: XCTestCase {
    func testByteLevelTokenizerEncodesChatMLSegments() throws {
        try withTemporaryDirectory { directory in
            try createByteLevelTokenizerAssets(in: directory)
            let tokenizer = try ByteLevelBPETokenizer(directory: directory)

            let segments: [PromptSegment] = [
                .special(.startOfTurn(.user)),
                .text("Hi"),
                .special(.endOfTurn)
            ]

            let tokenIDs = try tokenizer.encode(segments: segments)

            XCTAssertEqual(tokenIDs, [1, 4, 5, 6, 7, 8, 9, 10, 2, 8])
        }
    }

    private func withTemporaryDirectory(_ operation: (URL) throws -> Void) throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LambdaDeckByteLevelTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        try operation(directory)
    }

    private func createByteLevelTokenizerAssets(in root: URL) throws {
        let tokenizerJSON = """
        {
          "model": {
            "vocab": {
              "<unk>": 0,
              "<|im_start|>": 1,
              "<|im_end|>": 2,
              "<|endoftext|>": 3,
              "u": 4,
              "s": 5,
              "e": 6,
              "r": 7,
              "\\n": 8,
              "H": 9,
              "i": 10
            },
            "merges": []
          }
        }
        """
        let tokenizerConfig = """
        {
          "bos_token": "<|endoftext|>",
          "eos_token": "<|endoftext|>",
          "unk_token": "<unk>"
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
