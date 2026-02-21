# TRACK 3 [COMPLETED]: swift_coreml_inference_runtime

Problems (PORE)
- P1: As a developer using OpenAI-compatible clients, I cannot get real model outputs from LambdaDeck, because `/v1/chat/completions` is still deterministic stub-mode only.
- P2: As a maintainer targeting Apple platforms, I cannot ship a durable on-device solution, because the runtime path currently does not execute Core ML models from Swift (tokenization, prompt rendering, state/KV cache, and decoding).
- P3: As an end user of editor tools, I cannot rely on streamed responses, because streaming currently emits stub chunks rather than tokens produced by real generation.
- Reference: `.backlog/PORE.md`.

Objective
- Implement a Swift-native Core ML inference runtime (tokenizer + prompt rendering + generation) and wire it into the existing OpenAI-compatible server while preserving deterministic stub mode for CI.

Acceptance criteria
- [P1,P2] With `--model-path <bundle-or-mlmodelc>`, `POST /v1/chat/completions` with `stream=false` returns a non-stub assistant message produced by Core ML inference.
- [P1,P3] With `stream=true`, `POST /v1/chat/completions` emits SSE chunks whose `delta.content` reflects incremental generated text and terminates with `data: [DONE]`.
- [P2] Model loading supports ANEMLL-style bundles (directory with `meta.yaml`, tokenizer assets, and one or more `*.mlmodelc` parts) and can also accept a single `.mlmodelc` when applicable.
- [P2] A minimal, model-agnostic runtime interface exists (load -> prefill -> decode step -> stop), with architecture-specific adapters selected from bundle metadata rather than hard-coded in the HTTP layer.
- [P2] Cancellation is handled end-to-end: client disconnect cancels generation without leaving background tasks running.
- [P1,P3] Stub mode remains deterministic and unchanged for contract tests/CI.

Why now / impact
- This is the missing link between the already-working OpenAI-compatible HTTP/SSE contract and real on-device inference.

Scope
- In scope:
  - Core ML model loading in Swift (compute units configuration, state/KV cache management as required by the compiled models).
  - Tokenization in Swift using the model bundle tokenizer assets.
  - Prompt rendering from OpenAI `messages[]` into a single model input string (initially for one supported model family; selection driven by bundle metadata).
  - Non-stream and SSE streaming generation wired into `Sources/LambdaDeckCore/LambdaDeckServer.swift`.
  - Local-only validations (manual runs/curl) for real inference; CI remains stub-only.
- Out of scope:
  - Expanding API surface beyond `/v1/models` and `/v1/chat/completions`.
  - Multi-tenant auth, multi-model routing beyond the already-selected `--model-path`.
  - Tool/function calling.

Non-negotiables
- Development follows TDD/test-first for runtime interface and server integration points.
- Stub-mode contract tests remain stable; real-inference tests must be gated to avoid requiring model artifacts in CI.

Milestones
- [x] Milestone 1: Define runtime interfaces and adapter selection (bundle metadata -> adapter).
- [x] Milestone 2: Implement one end-to-end adapter (tokenize -> prefill -> decode) producing real text.
- [x] Milestone 3: Wire non-stream `chat/completions` to runtime (non-stub path) with basic metrics.
- [x] Milestone 4: Wire SSE streaming to runtime with cancellation semantics.
- [x] Milestone 5: Run interoperability check with at least one OpenAI-compatible client.

Risks / decisions
- Risk: Tokenizer and chat-template parity with the reference Python runners may be non-trivial.
- Risk: Core ML model state shapes/functions may differ across model families and converter versions.
- Decision: Keep the HTTP contract stable; concentrate variability inside runtime adapters.

Plan (execution steps)
- [x] Move Track 3 to ACTIVE (folder + filename + title status).
- [x] Inventory the model bundle metadata requirements for adapter selection.
- [x] Add a runtime protocol and stub runtime implementation (unit tests).
- [x] Implement adapter #1 end-to-end (local-only validation).
- [x] Integrate runtime into `/v1/chat/completions` (non-stream) with tests (stub path unchanged).
- [x] Integrate runtime into SSE streaming path with cancellation behavior.
- [x] Add a local-only integration test harness (skipped unless a model path is provided).
- [x] Run interoperability check with one OpenAI-compatible client.
- [x] Move Track 3 to COMPLETED and capture completion notes.

Inventory
- **Current inventory**
  - Runtime protocol + adapter selection: `Sources/LambdaDeckCore/InferenceRuntime.swift` (runtime contract, stub runtime, metadata-driven adapter inspection/factory).
  - Tokenization + prompt rendering: `Sources/LambdaDeckCore/GemmaBPETokenizer.swift`, `Sources/LambdaDeckCore/CoreMLRuntime.swift`.
  - Core ML adapters: `Sources/LambdaDeckCore/CoreMLRuntime.swift` (`Gemma3CoreMLRuntime` for ANEMLL-style bundles, `MonolithicCoreMLRuntime` for single `.mlmodelc` when applicable).
  - Server integration (non-stream + SSE): `Sources/LambdaDeckCore/LambdaDeckServer.swift` (runtime path while preserving deterministic stub path).
  - Model selection/discovery (unchanged precedence): `Sources/LambdaDeckCore/ModelResolution.swift`.
  - Tests:
    - `Tests/LambdaDeckCoreTests/LambdaDeckCoreTests.swift` (runtime inspector coverage + deterministic stub runtime tests).
    - `Tests/LambdaDeckIntegrationTests/OpenAIContractIntegrationTests.swift` (runtime non-stream/stream integration tests, local-only real-inference harness).
  - Local reference runner for behavior parity checks: `Models/*/chat.py`.

Artifacts
- Wire contract baseline and SSE references are tracked in Track 1.
- Validation run (2026-02-21): `swift test` (25 tests passed, 1 local-only test skipped by default).
- Local real-inference validation (2026-02-21):
  - `swift run lambdadeck serve --model-path "Models/anemll-google-gemma-3-4b-it-qat-int4-unquantized-ctx4096_0.3.5" --port 19084`
  - `curl http://127.0.0.1:19084/v1/models`
  - non-stream `POST /v1/chat/completions` returned non-stub content (`"Hello there!"`)
  - stream `POST /v1/chat/completions` returned incremental `delta.content` chunks and terminated with `data: [DONE]`.
- OpenAI-compatible client interoperability (2026-02-21): Python OpenAI SDK (`openai`) against local server using `base_url=http://127.0.0.1:19087/v1` returned successful non-stream and stream completions.

Completion notes (fill when COMPLETED/DEPRECATED)
- Delivered Swift-native Core ML runtime wiring for `/v1/chat/completions` with deterministic stub mode preserved for CI.
- Added metadata-driven adapter selection with Gemma3 bundle runtime and monolithic `.mlmodelc` runtime path (when applicable).
- Added Swift tokenizer/prompt/render/decode flow for model bundles and integrated non-stream + SSE runtime paths with cancellation-safe stream termination.
- Contract/integration coverage remains green in model-less CI (`swift test`), and local real-inference + OpenAI SDK interoperability checks passed.
