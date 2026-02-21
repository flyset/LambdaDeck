import Foundation
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

    func testModelResolverPrioritizesStubFlag() throws {
        let resolved = try LambdaDeckModelResolver.resolve(
            options: LambdaDeckServeOptions(stubMode: true, modelPath: "/tmp/explicit"),
            environment: LambdaDeckEnvironment(values: ["LAMBDADECK_MODEL_PATH": "/tmp/env"]),
            currentDirectory: "/tmp"
        )

        XCTAssertEqual(resolved.modelID, StubChatFixtures.modelID)
        XCTAssertNil(resolved.modelPath)
        XCTAssertEqual(resolved.source, .stubFlag)
    }

    func testModelResolverPrioritizesCLIModelPathOverEnv() throws {
        try withTemporaryDirectory { directory in
            let cliModel = try createModelBundle(named: "cli-model", in: directory)
            _ = try createModelBundle(named: "env-model", in: directory)

            let resolved = try LambdaDeckModelResolver.resolve(
                options: LambdaDeckServeOptions(modelPath: cliModel.path),
                environment: LambdaDeckEnvironment(values: ["LAMBDADECK_MODEL_PATH": directory.appendingPathComponent("env-model").path]),
                currentDirectory: directory.path
            )

            XCTAssertEqual(resolved.modelPath, cliModel.path)
            XCTAssertEqual(resolved.modelID, "cli-model")
            XCTAssertEqual(resolved.source, .cliModelPath)
        }
    }

    func testModelResolverUsesEnvModelPathWhenCLIIsUnset() throws {
        try withTemporaryDirectory { directory in
            let envModel = try createModelBundle(named: "env-model", in: directory)

            let resolved = try LambdaDeckModelResolver.resolve(
                options: LambdaDeckServeOptions(),
                environment: LambdaDeckEnvironment(values: ["LAMBDADECK_MODEL_PATH": envModel.path]),
                currentDirectory: directory.path
            )

            XCTAssertEqual(resolved.modelPath, envModel.path)
            XCTAssertEqual(resolved.modelID, "env-model")
            XCTAssertEqual(resolved.source, .envModelPath)
        }
    }

    func testModelResolverDiscoversSingleModelFromModelsRoot() throws {
        try withTemporaryDirectory { directory in
            let modelsRoot = directory.appendingPathComponent("Models")
            try FileManager.default.createDirectory(at: modelsRoot, withIntermediateDirectories: true)
            _ = try createModelBundle(named: "only-model", in: modelsRoot)

            let resolved = try LambdaDeckModelResolver.resolve(
                options: LambdaDeckServeOptions(modelsRoot: modelsRoot.path),
                environment: LambdaDeckEnvironment(values: [:]),
                currentDirectory: directory.path
            )

            XCTAssertEqual(resolved.modelID, "only-model")
            XCTAssertEqual(resolved.source, .discoveredModelsRoot)
        }
    }

    func testModelResolverErrorsWhenDiscoveryFindsMultipleBundles() throws {
        try withTemporaryDirectory { directory in
            let modelsRoot = directory.appendingPathComponent("Models")
            try FileManager.default.createDirectory(at: modelsRoot, withIntermediateDirectories: true)
            _ = try createModelBundle(named: "model-a", in: modelsRoot)
            _ = try createModelBundle(named: "model-b", in: modelsRoot)

            XCTAssertThrowsError(
                try LambdaDeckModelResolver.resolve(
                    options: LambdaDeckServeOptions(modelsRoot: modelsRoot.path),
                    environment: LambdaDeckEnvironment(values: [:]),
                    currentDirectory: directory.path
                )
            ) { error in
                XCTAssertEqual(
                    error as? LambdaDeckModelResolutionError,
                    .discoveredMultipleModels(
                        modelsRoot: modelsRoot.path,
                        candidates: [
                            modelsRoot.appendingPathComponent("model-a").path,
                            modelsRoot.appendingPathComponent("model-b").path
                        ]
                    )
                )
            }
        }
    }

    func testRuntimeInspectorDetectsGemma3ChunkedBundle() throws {
        try withTemporaryDirectory { directory in
            let bundle = directory.appendingPathComponent("gemma-bundle")
            try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
            try createTokenizerAssets(in: bundle)

            let meta = """
            model_info:
              architecture: gemma3
              parameters:
                context_length: 4096
                batch_size: 64
                sliding_window: 1024
                embeddings: gemma3_embeddings.mlmodelc
                lm_head: gemma3_lm_head.mlmodelc
                ffn: gemma3_FFN_PF_chunk_01of02.mlmodelc
            """
            try meta.write(to: bundle.appendingPathComponent("meta.yaml"), atomically: true, encoding: .utf8)

            _ = try createModelDirectory(named: "gemma3_embeddings.mlmodelc", in: bundle)
            _ = try createModelDirectory(named: "gemma3_lm_head.mlmodelc", in: bundle)
            _ = try createModelDirectory(named: "gemma3_FFN_PF_chunk_01of02.mlmodelc", in: bundle)
            _ = try createModelDirectory(named: "gemma3_FFN_PF_chunk_02of02.mlmodelc", in: bundle)

            let inventory = try LambdaDeckRuntimeInspector.inspect(modelPath: bundle.path)

            XCTAssertEqual(inventory.adapterKind, .gemma3Chunked)
            XCTAssertEqual(inventory.contextLength, 4096)
            XCTAssertEqual(inventory.slidingWindow, 1024)
            XCTAssertEqual(inventory.ffnChunkPaths.count, 2)
            XCTAssertEqual(inventory.ffnChunkPaths[0].lastPathComponent, "gemma3_FFN_PF_chunk_01of02.mlmodelc")
            XCTAssertEqual(inventory.ffnChunkPaths[1].lastPathComponent, "gemma3_FFN_PF_chunk_02of02.mlmodelc")
        }
    }

    func testRuntimeInspectorDetectsSingleCompiledModelPath() throws {
        try withTemporaryDirectory { directory in
            try createTokenizerAssets(in: directory)
            let modelPath = try createModelDirectory(named: "monolithic.mlmodelc", in: directory)

            let inventory = try LambdaDeckRuntimeInspector.inspect(modelPath: modelPath.path)

            XCTAssertEqual(inventory.adapterKind, .monolithicCompiled)
            XCTAssertEqual(inventory.monolithicModelPath?.lastPathComponent, "monolithic.mlmodelc")
        }
    }

    func testStubInferenceRuntimeIsDeterministic() async throws {
        let runtime = StubInferenceRuntime()
        let request = OpenAIChatCompletionsRequest(
            model: "any",
            messages: [OpenAIChatMessage(role: "user", content: "hello")],
            stream: false
        )

        let completion = try await runtime.complete(request: request)
        XCTAssertEqual(completion.content, StubChatFixtures.completionText)
        XCTAssertEqual(completion.finishReason, "stop")

        var streamedTokens: [String] = []
        var finishReason: String?
        for try await event in runtime.stream(request: request) {
            switch event {
            case .token(let token):
                streamedTokens.append(token)
            case .finished(let reason, _):
                finishReason = reason
            }
        }

        XCTAssertEqual(streamedTokens.joined(), StubChatFixtures.completionText)
        XCTAssertEqual(finishReason, "stop")
    }

    private func withTemporaryDirectory(_ operation: (URL) throws -> Void) throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LambdaDeckTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        try operation(directory)
    }

    private func createModelBundle(named name: String, in root: URL) throws -> URL {
        let bundle = root.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        let meta = bundle.appendingPathComponent("meta.yaml")
        try "model_info:\n  name: \(name)\n".write(to: meta, atomically: true, encoding: .utf8)
        return bundle
    }

    private func createModelDirectory(named name: String, in root: URL) throws -> URL {
        let path = root.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        return path
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
