# TRACK 1 [COMPLETED]: coreml_openai_server

Problems (PORE)
- P1: As a developer using OpenAI-compatible clients (OpenCode, VSCode, and scripts), I cannot connect to ANEMLL models, because ANEMLL currently exposes local chat scripts instead of an OpenAI-style HTTP API.
- P2: As an end user of interactive coding/editor tools, I experience delayed and incompatible responses, because these clients expect Server-Sent Events (SSE) streaming chunks for chat completions.
- P3: As a maintainer targeting Apple platforms, I need a Swift-native runtime path, because relying only on Python wrappers is not the intended long-term deployment model for Core ML.
- Reference: `.backlog/PORE.md`.

Objective
- Build a local Swift CLI server that exposes OpenAI-compatible endpoints, including streaming `POST /v1/chat/completions`, with deterministic stub-mode behavior suitable for CI/contract tests.

Acceptance criteria
- [P1] `GET /v1/models` returns at least one configured model id in OpenAI-compatible shape.
- [P1,P2] `POST /v1/chat/completions` with `stream=false` returns a valid assistant message for multi-turn `messages` input (deterministic stub mode).
- [P1,P2] `POST /v1/chat/completions` with `stream=true` emits valid SSE `data:` chunks and terminates with `data: [DONE]` (deterministic stub mode).
- [P1,P2] Canonical in-repo stub fixtures are frozen for `/v1/chat/completions`: request fixtures (minimal + multi-turn), one non-stream `chat.completion` response fixture, and one streaming `chat.completion.chunk` sequence ending with `data: [DONE]`; contract tests assert exact schema/field compatibility and stream framing order.
- [P2] Streaming supports cancellation on client disconnect without leaking background generation tasks.
- [P3] Implementation builds and runs via Swift toolchain on macOS; server is runnable from the terminal (manual start/stop).
- [P1,P2] Server can run in a deterministic "stub" generation mode suitable for CI and contract tests (no model required).
- [P3] Server supports a configured `--model-path` (or equivalent) to load one selected model bundle when model assets are available locally. A model bundle may be either (a) a directory containing `meta.yaml` that references one or more `.mlmodelc` parts plus tokenizer assets, or (b) a single `.mlmodelc` when the selected runtime uses a single compiled bundle.
- [P2,P3] Swift Core ML inference (tokenization + generation) is tracked in Track 3: `.backlog/DRAFT/2026/TRACK_3_DRAFT_swift_coreml_inference_runtime.md`.

Why now / impact
- This unlocks direct integration with OpenAI-compatible tooling while preserving ANEMLL's on-device Core ML path.
- It reduces custom client glue and makes local, private inference usable from mainstream developer workflows.

Scope
- In scope:
  - Swift Package Manager build layout producing a `lambdadeck` executable.
  - Headless/manual runtime (CLI server only) for v1.
  - Server configuration (host/port/model path) via flags and/or config file.
  - OpenAI-compatible `GET /v1/models` and `POST /v1/chat/completions` (non-streaming + streaming).
  - SSE streaming framing + cancellation semantics matching common OpenAI-compatible clients.
  - Minimal chat-template handling needed for one target model family.
  - Basic observability: request ids, latency, token counts (best effort), and structured errors.
  - CI pipeline for build + tests; contract/integration tests that do not require model artifacts (stub mode).
- Out of scope:
  - Full OpenAI API surface (`responses`, `embeddings`, `audio`, `images`, etc.).
  - Multi-model dynamic routing and advanced tenancy/auth.
  - Function/tool calling in first iteration.
  - iOS app embedding work.
  - Settings UI (planned as a later Track).

Non-negotiables
- Development follows TDD/test-first for endpoint contracts and stream framing behavior.
- Every implementation chunk includes automated validation (unit/integration) and manual curl verification for both stream and non-stream flows.

Milestones
- [x] Milestone 1: Server skeleton + config + model discovery.
- [x] Milestone 2: Non-streaming `chat/completions` stub-mode contract + integration tests.
- [x] Milestone 3: SSE streaming correctness in stub mode (`data` chunks + `[DONE]` + cancellation).
- [x] Milestone 4: Split Swift Core ML inference runtime into Track 3.

Risks / decisions
- Risk: Tokenizer/chat template parity in Swift may differ from current Python behavior.
- Risk: Core ML model execution details may require backend-specific shape/state handling.
- Decision: v1 is headless/manual (CLI server only); no UI.
- Decision: Start with a stub generator to lock the HTTP + SSE contract in CI before wiring full Core ML execution.
- Dependency: Track 2 establishes the SwiftPM build system + CI + test harness needed to implement and validate this Track.
- Decision: Start with one model target and a minimal API subset before expanding features.
- Decision: Prefer strict wire compatibility for chat completions over broad endpoint coverage in v1.
- Decision: Use the OpenAI documented OpenAPI spec as the schema baseline for `/v1/chat/completions` and freeze local stub fixtures (non-stream + SSE chunk flow) before Core ML runtime wiring.
- Decision: HTTP stack: Hummingbird (SwiftNIO-based) to keep dependency weight low while still providing a robust SSE + cancellation foundation.
- Decision: Model selection precedence (highest to lowest): (1) stub mode flag ignores model config, (2) `--model-path`, (3) env `LAMBDADECK_MODEL_PATH`, (4) discover under models root (`--models-root` > env `LAMBDADECK_MODELS_ROOT` > default `./Models`); if discovery yields 0 or >1 candidates, return a clear error instructing the user to pass `--model-path`. `--model-path` accepts either a model bundle directory (preferred; includes `meta.yaml` + tokenizer + one or more `.mlmodelc` parts) or a single `.mlmodelc` when applicable.

Plan (execution steps)
- [x] Move Track 1 to ACTIVE (folder + filename + title status).
- [x] Define build/distribution pipeline (SwiftPM targets, CI checks, local dev commands).
- [x] Capture current inventory of candidate implementation paths (Swift package layout, model assets, tokenizer assets).
- [x] Lock HTTP server stack choice (Hummingbird) and record dependency plan for SwiftPM.
- [x] Freeze canonical OpenAI-compatible chat completion fixtures (request/response JSON + SSE chunk sequence + `[DONE]`) for deterministic stub-mode contract testing.
- [x] Define model-path and models-root configuration rules (flags/env/defaults) and validate precedence with tests in stub mode.
- [x] Define OpenAI wire-contract DTOs and error schema for `/v1/models` and `/v1/chat/completions`.
- [x] Implement `GET /v1/models` and add contract tests (stub mode).
- [x] Implement non-streaming `POST /v1/chat/completions` path and add integration tests (stub mode).
- [x] Implement streaming SSE chunks with graceful cancellation and add integration tests (stub mode).
- [x] Add CI workflow to run build + tests on macOS.
- [x] Manual verification (curl) for `GET /v1/models`, non-stream `POST /v1/chat/completions`, and stream `POST /v1/chat/completions` ending with `data: [DONE]`.
- [x] Defer OpenAI-compatible client interoperability checks until real inference is wired (moved to Track 3).
- [x] Move Track 1 to COMPLETED and capture completion notes.

Inventory
- **Current inventory**
  - Swift package and deps: `Package.swift` now includes `hummingbird` dependency and `HummingbirdTesting` for integration tests.
  - Server/runtime: `Sources/LambdaDeckCore/LambdaDeckServer.swift` (stub-mode OpenAI-compatible routes, SSE framing, disconnect-safe stream writer).
  - Configuration/model selection: `Sources/LambdaDeckCore/ModelResolution.swift` (precedence and discovery rules: `--stub`, `--model-path`, env vars, models-root fallback).
  - Wire DTOs + fixtures: `Sources/LambdaDeckCore/OpenAIContracts.swift`, `Sources/LambdaDeckCore/StubContract.swift` (frozen fixture payloads + SSE chunk sequence + `[DONE]`).
  - CLI surface: `Sources/LambdaDeckCLI/CLI.swift`, `Sources/LambdaDeckCLI/LambdaDeckMain.swift` (`serve` command + help + runtime wiring).
  - Contract/integration tests: `Tests/LambdaDeckCoreTests/LambdaDeckCoreTests.swift`, `Tests/LambdaDeckIntegrationTests/OpenAIContractIntegrationTests.swift`, `Tests/LambdaDeckCLITests/LambdaDeckCLITests.swift`.
  - Developer docs: `docs/DEVELOPMENT.md` includes stub-server runbook and curl verification commands.
  - Local model assets present for local-only manual testing; Swift Core ML inference wiring is tracked in Track 3.

Artifacts
- Wire-contract schema baseline: `https://app.stainless.com/api/spec/documented/openai/openapi.documented.yml` (focus: `/chat/completions` request/response and chunk schemas).
- Streaming behavior references: `https://cookbook.openai.com/examples/how_to_stream_completions` and `https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events#event_stream_format`.
- Validation run (2026-02-21): `swift test` (19 tests passed; includes core precedence tests + OpenAI contract integration tests).
- Manual verification (2026-02-21): `swift run lambdadeck serve --stub --port 19081` + curl checks for `GET /v1/models`, non-stream `POST /v1/chat/completions`, and stream `POST /v1/chat/completions` ending with `data: [DONE]`.
- Discovery verification (2026-02-21): `swift run lambdadeck serve --port 19082` auto-discovers local model bundle under `./Models` and returns discovered model id from `GET /v1/models`.
- Placeholder: future PR links and OpenAI-compatible editor/client interoperability logs will be listed here.

Frozen chat fixtures (draft v1)
- Objective: lock deterministic stub-mode wire contract for `/v1/chat/completions` before Core ML runtime wiring.
- Compatibility target: OpenAI-style `chat.completion` and `chat.completion.chunk` payload shapes used by OpenAI-compatible SDKs/tools.

Fixture A: request (minimal non-stream)
```json
{
  "model": "stub-model",
  "messages": [
    {
      "role": "user",
      "content": "Say hello in one short sentence."
    }
  ],
  "stream": false
}
```

Fixture B: request (multi-turn non-stream)
```json
{
  "model": "stub-model",
  "messages": [
    {
      "role": "system",
      "content": "You are concise."
    },
    {
      "role": "user",
      "content": "What is LambdaDeck?"
    },
    {
      "role": "assistant",
      "content": "A local OpenAI-compatible server for ANEMLL Core ML models."
    },
    {
      "role": "user",
      "content": "Answer in five words."
    }
  ],
  "temperature": 0,
  "max_tokens": 32,
  "stream": false
}
```

Fixture C: response (non-stream `chat.completion`)
```json
{
  "id": "chatcmpl-stub-0001",
  "object": "chat.completion",
  "created": 0,
  "model": "stub-model",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "Stub response from LambdaDeck."
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 0,
    "completion_tokens": 0,
    "total_tokens": 0
  }
}
```

Fixture D: request (streaming)
```json
{
  "model": "stub-model",
  "messages": [
    {
      "role": "user",
      "content": "Stream a short greeting."
    }
  ],
  "stream": true
}
```

Fixture E: response stream (SSE `data:` sequence)
```text
data: {"id":"chatcmpl-stub-0001","object":"chat.completion.chunk","created":0,"model":"stub-model","choices":[{"index":0,"delta":{"role":"assistant"},"finish_reason":null}]}

data: {"id":"chatcmpl-stub-0001","object":"chat.completion.chunk","created":0,"model":"stub-model","choices":[{"index":0,"delta":{"content":"Stub response "},"finish_reason":null}]}

data: {"id":"chatcmpl-stub-0001","object":"chat.completion.chunk","created":0,"model":"stub-model","choices":[{"index":0,"delta":{"content":"from LambdaDeck."},"finish_reason":null}]}

data: {"id":"chatcmpl-stub-0001","object":"chat.completion.chunk","created":0,"model":"stub-model","choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}

data: [DONE]

```

Fixture assertions (contract tests)
- Non-stream: response validates required OpenAI-style top-level fields (`id`, `object`, `created`, `model`, `choices`) and assistant message/finish reason shape.
- Streaming: response uses `Content-Type: text/event-stream`; each event is prefixed by `data: ` and separated by a blank line; final event is exactly `data: [DONE]`.
- Streaming order: role delta event first, content delta event(s) next, terminal event with `finish_reason: "stop"` before `[DONE]`.
- Stub determinism: fixture values above are stable in CI (fixed ids/timestamps/tokens/content unless Track plan explicitly updates fixtures).

Field strictness matrix (required vs optional)
| Fixture | Required fields (assert) | Optional fields (tolerated) |
| --- | --- | --- |
| A/B/D request fixtures | `model`, `messages[]`, `messages[].role`, `messages[].content`, `stream` | `temperature`, `max_tokens`, `top_p`, `n`, `stop`, `user`, `stream_options`, future OpenAI request fields not used by v1 stub |
| C non-stream response fixture | `id`, `object="chat.completion"`, `created`, `model`, `choices[0].index`, `choices[0].message.role="assistant"`, `choices[0].message.content`, `choices[0].finish_reason="stop"`, `usage.prompt_tokens`, `usage.completion_tokens`, `usage.total_tokens` | `system_fingerprint`, `service_tier`, future OpenAI top-level additions |
| E stream chunk payloads (`data: {...}`) | `id`, `object="chat.completion.chunk"`, `created`, `model`, `choices[0].index`, `choices[0].delta`, `choices[0].finish_reason`; ordered phases: role delta -> content delta(s) -> terminal stop chunk | `system_fingerprint`, usage chunk (`choices: []` + `usage`) if later enabled via `stream_options.include_usage` |
| E stream framing | `Content-Type: text/event-stream`, `data: ` prefix for each event, blank-line delimiter, terminal `data: [DONE]` | SSE comments/heartbeats are not required and are not emitted by v1 stub |

Contract test strictness levels
- Requests (A/B/D): strict-shape validation (required fields and types), not byte-for-byte literal equality.
- Non-stream (C): strict-value validation for all required fields; JSON key order is not significant.
- Streaming (E): strict-order validation for chunk phases and framing; required fields/values must match fixtures.
- Optional fields listed above do not fail tests when present unless they alter required field semantics.

Completion notes (fill when COMPLETED/DEPRECATED)
- Track 1 delivers the OpenAI-compatible HTTP/SSE contract, deterministic stub fixtures, contract/integration tests, and model selection/discovery plumbing.
- Real Core ML inference in Swift (tokenization + generation loop + streaming tokens) is intentionally split into Track 3.
