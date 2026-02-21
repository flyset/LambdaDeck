# TRACK 1 [DRAFT]: coreml_openai_server

Problems (PORE)
- P1: As a developer using OpenAI-compatible clients (OpenCode, VSCode, and scripts), I cannot connect to ANEMLL models, because ANEMLL currently exposes local chat scripts instead of an OpenAI-style HTTP API.
- P2: As an end user of interactive coding/editor tools, I experience delayed and incompatible responses, because these clients expect Server-Sent Events (SSE) streaming chunks for chat completions.
- P3: As a maintainer targeting Apple platforms, I need a Swift-native runtime path, because relying only on Python wrappers is not the intended long-term deployment model for Core ML.
- Reference: `.backlog/PORE.md`.

Objective
- Build a local Swift CLI server that exposes OpenAI-compatible endpoints, including streaming `POST /v1/chat/completions`, and can run against an ANEMLL Core ML model bundle.

Acceptance criteria
- [P1] `GET /v1/models` returns at least one configured model id in OpenAI-compatible shape.
- [P1,P2] `POST /v1/chat/completions` with `stream=false` returns a valid assistant message for multi-turn `messages` input.
- [P1,P2] `POST /v1/chat/completions` with `stream=true` emits valid SSE `data:` chunks and terminates with `data: [DONE]`.
- [P2] Streaming supports cancellation on client disconnect without leaking background generation tasks.
- [P3] Implementation builds and runs via Swift toolchain on macOS; server is runnable from the terminal (manual start/stop).
- [P1,P2] Server can run in a deterministic "stub" generation mode suitable for CI and contract tests (no model required).
- [P3] Server supports a configured `--model-path` (or equivalent) to load one selected `.mlmodelc` bundle when model assets are available locally.

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
- [ ] Milestone 1: Server skeleton + config + model discovery.
- [ ] Milestone 2: Non-streaming `chat/completions` parity for one model.
- [ ] Milestone 3: SSE streaming correctness (`data` chunks + `[DONE]` + cancellation).
- [ ] Milestone 4: Client interoperability check with at least one OpenAI-compatible editor/tool.

Risks / decisions
- Risk: Tokenizer/chat template parity in Swift may differ from current Python behavior.
- Risk: Core ML model execution details may require backend-specific shape/state handling.
- Decision: v1 is headless/manual (CLI server only); no UI.
- Decision: Start with a stub generator to lock the HTTP + SSE contract in CI before wiring full Core ML execution.
- Dependency: Track 2 establishes the SwiftPM build system + CI + test harness needed to implement and validate this Track.
- Decision: Start with one model target and a minimal API subset before expanding features.
- Decision: Prefer strict wire compatibility for chat completions over broad endpoint coverage in v1.

Plan (execution steps)
- [ ] Move Track 1 to ACTIVE (folder + filename + title status).
- [ ] Define build/distribution pipeline (SwiftPM targets, CI checks, local dev commands).
- [ ] Capture current inventory of candidate implementation paths (Swift package layout, model assets, tokenizer assets).
- [ ] Define OpenAI wire-contract DTOs and error schema for `/v1/models` and `/v1/chat/completions`.
- [ ] Implement `GET /v1/models` and add contract tests (stub mode).
- [ ] Implement non-streaming `POST /v1/chat/completions` path and add integration tests (stub mode).
- [ ] Implement streaming SSE chunks with graceful cancellation and add integration tests (stub mode).
- [ ] Add CI workflow to run build + tests on macOS.
- [ ] Run interoperability checks with curl and one OpenAI-compatible client.
- [ ] Move Track 1 to COMPLETED and capture completion notes.

Inventory
- **Current inventory**
  - Root docs: `AGENTS.md`, `.backlog/README.md`, `.backlog/PORE.md`, `.backlog/AGENTS.md`.
  - Model distributions: `Models/<model>/` bundles (typically includes `meta.yaml`, tokenizer assets, `*.mlmodelc`; ignored from git; local-only artifacts).
  - Default model discovery root: `./Models` (repo-relative), with a flag/env override planned.

Artifacts
- Placeholder: design notes, API examples, test logs, and future PR links will be listed here.

Completion notes (fill when COMPLETED/DEPRECATED)
- Pending.
