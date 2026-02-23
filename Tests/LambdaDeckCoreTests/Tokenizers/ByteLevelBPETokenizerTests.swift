import Foundation
import XCTest
@testable import LambdaDeckCore

final class ByteLevelBPETokenizerTests: XCTestCase {
    func testByteLevelTokenizerEncodesChatMLSegments() throws {
        try withTemporaryDirectory { directory in
            let bytes = Array("user\nHi\n".utf8)
            try createByteLevelTokenizerAssets(in: directory, bytes: bytes)
            let tokenizer = try ByteLevelBPETokenizer(directory: directory)

            let segments: [PromptSegment] = [
                .special(.startOfTurn(.user)),
                .text("Hi"),
                .special(.endOfTurn)
            ]

            let tokenIDs = try tokenizer.encode(segments: segments)
            let startID = tokenizer.tokenID(for: "<|im_start|>")
            let endID = tokenizer.tokenID(for: "<|im_end|>")

            XCTAssertEqual(tokenIDs.first, startID)
            XCTAssertTrue(tokenIDs.contains(endID ?? -1))

            let decoded = tokenizer.decode(tokenIDs: tokenIDs, skipSpecialTokens: true)
            XCTAssertEqual(decoded, "user\nHi\n")
        }
    }

    func testByteLevelTokenizerEncodesAndDecodesUTF8() throws {
        try withTemporaryDirectory { directory in
            let bytes = Array("f\u{00FC}nf".utf8)
            try createByteLevelTokenizerAssets(in: directory, bytes: bytes)
            let tokenizer = try ByteLevelBPETokenizer(directory: directory)

            let tokenIDs = tokenizer.encode("f\u{00FC}nf")
            let decoded = tokenizer.decode(tokenIDs: tokenIDs, skipSpecialTokens: true)

            XCTAssertEqual(decoded, "f\u{00FC}nf")
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

    private func createByteLevelTokenizerAssets(in root: URL, bytes: [UInt8]) throws {
        var vocab: [String: Int] = [
            "<unk>": 0,
            "<|im_start|>": 1,
            "<|im_end|>": 2,
            "<|endoftext|>": 3
        ]
        var nextID = 4
        for byte in Set(bytes) {
            let scalar = ByteLevelBPETokenizer.byteEncodedScalar(for: byte)
            let token = String(scalar)
            if vocab[token] == nil {
                vocab[token] = nextID
                nextID += 1
            }
        }

        let payload: [String: Any] = [
            "model": [
                "vocab": vocab,
                "merges": []
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        let tokenizerConfig = """
        {
          "bos_token": "<|endoftext|>",
          "eos_token": "<|endoftext|>",
          "unk_token": "<unk>"
        }
        """

        try data.write(to: root.appendingPathComponent("tokenizer.json"))
        try tokenizerConfig.write(
            to: root.appendingPathComponent("tokenizer_config.json"),
            atomically: true,
            encoding: .utf8
        )
    }
}
