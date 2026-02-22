# LambdaDeck Architecture

LambdaDeck is a Swift-native, OpenAI-compatible HTTP server for on-device Core ML LLMs. The current runtime supports ANEMLL-style bundles while the server surface remains OpenAI-compatible.

## Repository Shape

- `Sources/LambdaDeckCLI/`: CLI entry points and command wiring.
- `Sources/LambdaDeckCore/`: core library used by CLI and tests.
- `Tests/`: unit and integration coverage for contracts, bootstrap, and runtime behavior.
- `.backlog/`: track planning and execution governance.

## LambdaDeckCore Organization

`Sources/LambdaDeckCore/` is organized by responsibility:

- `OpenAI/`
  - OpenAI wire contracts and fixture helpers.
  - Files: `OpenAIContracts.swift`, `StubContract.swift`.
- `Server/`
  - HTTP routing and endpoint orchestration.
  - File: `LambdaDeckServer.swift`.
- `Discovery/`
  - Model path resolution from CLI flags, env, and default roots.
  - File: `ModelResolution.swift`.
- `Runtime/`
  - Runtime selection, model inspection, warmup/provider lifecycle, and Core ML execution.
  - Files: `InferenceRuntime.swift`, `CoreMLRuntime.swift`.
- `Tokenizers/`
  - Tokenizer implementations used by runtime code.
  - File: `GemmaBPETokenizer.swift`.
- `Version/`
  - Package version constants.
  - File: `LambdaDeckVersion.swift`.

This organization is intentionally mechanical: it improves ownership boundaries without changing endpoint or runtime behavior.

## Runtime Flow (Current)

1. CLI parses command options into `LambdaDeckServeOptions`.
2. `LambdaDeckModelResolver` selects a model source (`--model-path`, env path, discovered root, or stub).
3. `LambdaDeckServerBootstrap` creates server configuration and, for non-stub mode, initializes `LambdaDeckRuntimeProvider` for background warmup.
4. `LambdaDeckServer` exposes:
   - `GET /v1/models`
   - `GET /readyz`
   - `POST /v1/chat/completions` (non-streaming and streaming)
5. For inference requests, runtime is resolved directly or from provider state, then converted to OpenAI-shaped responses.

## Track 7 Extension Points

Track 7 introduces adapter and metadata abstractions. This layout prepares clear seams for:

- bundle metadata loading and validation (planned `Bundles/`),
- model-family adapter contracts (planned `Adapters/`),
- preserving HTTP/OpenAI contract stability while expanding supported Core ML LLM bundle formats.

## Non-Goals of This Reorg

- No endpoint contract changes.
- No runtime algorithm changes.
- No new model family support in this step.
