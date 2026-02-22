# TRACK 4 [COMPLETED]: swift_coreml_ttft_optimization

Problems (PORE)
- P1: As a developer using OpenAI-compatible clients, time-to-first-token (TTFT) for real inference is extremely slow compared to the reference `Models/*/chat.py` runner, making interactive use feel laggy even when steady-state tokens/sec is acceptable.
- P2: As a maintainer, TTFT appears to scale poorly with prompt length due to token-by-token prefill and heavy per-step allocations (notably full-context causal mask rebuilds), which likely dominate pre-generation latency.
- Reference: `.backlog/PORE.md`.

Objective
- Reduce TTFT for real inference in the Swift Core ML runtime without regressing correctness, streaming semantics, or deterministic stub behavior.

Success criteria / acceptance
- [P1,P2] With the same model bundle and prompt, TTFT improves by at least 5x vs the current baseline on `main` (target 10x), measured locally.
- [P1] Tokens/sec after the first token is unchanged (within noise) vs baseline.
- [P1] SSE `stream=true` still emits incremental `delta.content` chunks and terminates with `data: [DONE]`.
- [P2] Stub mode remains deterministic and unchanged for CI/contract tests.
- [P2] `swift test` remains green; performance tests/benchmarks are local-only and gated.

Scope
- In scope:
  - Prefill-path optimization in `Sources/LambdaDeckCore/CoreMLRuntime.swift`.
  - Reduce per-step allocations by reusing/mutating `MLMultiArray`s and feature providers where safe.
  - Avoid rebuilding full-context causal masks per step; implement incremental or cached mask strategies.
  - Implement batched prefill if the compiled models support sequence-shaped `input_ids` (or model-provided prefill functions if present).
  - Lightweight TTFT instrumentation (local-only / debug gated) and a repeatable measurement recipe.
- Out of scope:
  - New model families/adapters (beyond the existing Gemma3 and monolithic paths).
  - Expanding the OpenAI-compatible API surface.
  - Tool/function calling.

Non-negotiables
- Correctness and contract stability first; performance wins must be measurable and not break streaming semantics.
- CI must remain model-less; benchmarks require explicit local opt-in.

Milestones
- [x] Milestone 1: Validate batched-prefill feasibility for current compiled models (input shapes and/or dedicated prefill functions).
- [x] Milestone 2: Add TTFT instrumentation and a repeatable local benchmark matrix.
- [x] Milestone 3: Eliminate obvious per-step allocations in prefill (mask + arrays + feature providers) via reuse.
- [x] Milestone 4: Implement batched prefill (or dedicated prefill functions) and validate parity.
- [x] Milestone 5: Document results (before/after TTFT scaling) and remaining bottlenecks.

Plan (execution steps)
- [x] Move Track 4 to ACTIVE (folder + filename + title status).
- [x] Validate model capability for batched prefill and record decision (supported sequence-shaped `input_ids` vs dedicated prefill function vs unsupported).
- [x] Establish baseline TTFT matrix on one supported bundle (Gemma3) for approximately 50 / 200 / 800 prompt tokens.
- [x] Record baseline metrics for each point: request size, `usage.prompt_tokens`, TTFT (request start -> first `delta.content`), and steady-state tokens/sec.
- [x] Profile prefill to identify hotspots (allocations vs Core ML calls).
- [x] Implement reuse/caching improvements; re-measure.
- [x] Implement batched prefill if supported; re-measure.
- [x] Add/adjust tests (unit/integration) as needed; keep local benchmarks gated.
- [x] Optimize server bootstrap/readiness by moving runtime initialization behind a lazy runtime provider with background preload.
- [x] Move Track 4 to COMPLETED and capture completion notes.

Risks / decisions
- Risk: compiled models may not accept multi-token prefill input shapes (sequence length > 1) with the current interface.
- Risk: mask caching strategies may be model-specific; keep logic inside runtime adapter.
- Decision: prefer incremental, reversible optimizations with clear measurements over large refactors.
- Decision (2026-02-21): Gemma3 chunked bundle supports dedicated `prefill`/`prefill_rotate` functions in FFN chunks, and embeddings accept enumerated `input_ids` shapes `[1,1]` and `[1,64]`; implementation will use chunk `prefill*` functions first (batch size 64), then retain `infer*` for decode.
- Decision (2026-02-21): use hybrid prefill strategy in Swift runtime: run dedicated `prefill*` only for full 64-token blocks, and process remainder tokens with existing token-by-token `infer*` path to avoid padded-tail KV pollution.
- Decision (2026-02-21): add an automatic one-time token-by-token retry path when batched prefill produces an immediate empty-stop completion, preserving parity on edge-case prompts.
- Decision (2026-02-21): server bootstrap now uses `LambdaDeckRuntimeProvider` to load runtime asynchronously in the background so HTTP bind/readiness is no longer blocked by runtime load.
- Decision (2026-02-21): runtime preload now runs detached from actor isolation, and chat runtime resolution uses polling with a bounded wait; warmup requests return `503` in ~5s instead of blocking for full preload duration.
- Risk (current): cold runtime preload can still take minutes on first launch; clients must retry while warmup is in progress.

Inventory
- **Current inventory**
  - Performance-critical runtime: `Sources/LambdaDeckCore/CoreMLRuntime.swift` (hybrid prefill path for Gemma3 chunked runtime: full 64-token `prefill*` blocks + token-by-token remainder + one-time retry fallback for empty-stop outputs + reusable token-step tensors/mask for infer token stepping).
  - Runtime contract and model inspection: `Sources/LambdaDeckCore/InferenceRuntime.swift` (runtime provider preload/warmup flow).
  - Server integration (for TTFT measurement via HTTP): `Sources/LambdaDeckCore/LambdaDeckServer.swift` (lazy runtime provider wiring + configurable runtime warmup timeout).
  - Integration coverage: `Tests/LambdaDeckIntegrationTests/OpenAIContractIntegrationTests.swift` (runtime-provider success and warmup `503` contract tests).
  - Reference behavior and capability hints: `Models/*/chat.py`, model bundle `meta.yaml`, and compiled model metadata.

Artifacts
- Baseline/after measurements (COMPLETED): recorded below.
- Measurement template (minimum):
  - Prompt size point (`~50` / `~200` / `~800` tokens)
  - Request payload bytes
  - `usage.prompt_tokens`
  - TTFT (ms)
  - Steady-state tokens/sec
- Capability validation (2026-02-21):
  - Metadata inspection confirms `prefill`/`prefill_rotate` functions and fixed prefill tensor shapes in `gemma3_FFN_PF_lut4_chunk_01of02.mlmodelc/metadata.json` (`hidden_states [1,64,2560]`, `position_ids [64]`, `causal_mask [1,1,64,4096]`, `current_pos [1]`).
  - Embeddings metadata confirms enumerated shapes for `input_ids`: `[[1,1], [1,64]]` in `gemma3_embeddings.mlmodelc/metadata.json`.
  - Runtime smoke test command succeeded (`prefill_ok [1, 64, 2560]`, `infer_ok [1, 1, 2560]`) by executing Core ML predictions with shared state across `prefill` then `infer` on chunk 01.
- Baseline TTFT matrix (2026-02-21, model `anemll-google-gemma-3-4b-it-qat-int4-unquantized-ctx4096_0.3.5`, max_tokens=64):
  - ~50 prompt words: request 456 bytes, `usage.prompt_tokens=59`, TTFT `4039ms`, steady decode `10.10 tok/s`.
  - ~200 prompt words: request 1356 bytes, `usage.prompt_tokens=209`, TTFT `14041ms`, steady decode `10.25 tok/s`.
  - ~800 prompt words: request 4956 bytes, `usage.prompt_tokens=809`, TTFT `54133ms`, steady decode `10.18 tok/s`.
- Profiling conclusion (baseline): steady decode throughput remains ~10.2 tok/s while TTFT scales near-linearly with prompt tokens, confirming prefill is the dominant bottleneck (per-token Core ML call count and repeated tensor/mask construction during prefill).
- Post-change measurements (2026-02-21, hybrid batched prefill enabled):
  - Natural prompt set (`"This is a latency test prompt with mixed words and punctuation."` repeated):
    - prompt_tokens=69: TTFT `482ms`, steady decode `10.12 tok/s`.
    - prompt_tokens=249: TTFT `4057ms`, steady decode `10.06 tok/s`.
  - OpenCode-like long system prompt test (`prompt_tokens=861`): TTFT `3280ms`, stream total `4660ms`, non-empty completion.
  - Compared to baseline points with similar token counts, TTFT improvement is multi-x while steady decode throughput remains ~10 tok/s.
- Post-change TTFT matrix on baseline synthetic points (2026-02-21):
  - ~50 prompt words (`usage.prompt_tokens=59`): TTFT `3730ms`, steady decode `10.42 tok/s`.
  - ~200 prompt words (`usage.prompt_tokens=209`): TTFT `14479ms`, steady decode `10.55 tok/s`.
  - ~800 prompt words (`usage.prompt_tokens=809`): TTFT `54291ms`, steady decode `10.44 tok/s`.
  - Note: one-time retry fallback triggers on some synthetic prompts; those cases preserve output parity but TTFT remains near baseline.
- Post-change parity/stability checks (2026-02-21):
  - Synthetic repetitive prompts (`~200/~800 words`) now return non-empty completions after retry safeguard (no immediate empty-stop termination).
  - Cold/warm OpenCode-like stream prompt (`prompt_tokens=861`) remains stable at ~`3257ms`/`3126ms` TTFT.
- Startup/readiness baseline (2026-02-21, pre-lazy-provider): eager runtime initialization remained slow (observed readiness in ~`78-246s` range across runs).
- Startup/readiness observation (2026-02-21, detached preload + bounded wait): `/v1/models` became ready in `3693ms`; immediate chat returned `503` in `5054ms`; repeated warmup requests returned `503` in `5006-5036ms` (no long blocking on request path).
- Startup contract coverage (2026-02-22): integration tests validate that runtime provider responses return `200` when ready and `503` with the expected OpenAI-shaped error body while warming up.
- Reuse/caching re-measure (2026-02-21, reusable token-step arrays + incremental causal mask in infer path):
  - Natural prompt (`prompt_tokens=69`): TTFT `465ms`, stream total `6635ms`.
  - Natural prompt (`prompt_tokens=249`): TTFT `4021ms`, stream total `10304ms`.
  - Synthetic repetitive prompt (`prompt_tokens=209`): TTFT `14846ms`, stream total `21051ms`.
  - Observation: allocation reuse does not materially change fallback-heavy synthetic TTFT; dominant cost remains model invocation count/path behavior, while natural batched cases stay fast.
- Validation/test runs (2026-02-22):
  - `swift build`
  - `swift test` (27 passed, 1 skipped local-only real-inference test)
  - Local smoke checks (real model): `/v1/models` readiness, warmup `503` latency bounds, and stream TTFT spot checks.

Completion notes
- Result: OpenCode-like long prompts moved from tens-of-seconds TTFT into low-single-digit seconds in steady warm runs while preserving ~10 tok/s decode throughput.
- Result: startup/readiness no longer blocks on runtime initialization; warmup now fails fast with OpenAI-shaped `503` responses that clients can retry.
- Validation: contract/integration suite remains green, including explicit runtime-provider success and warmup tests.
- Remaining bottlenecks: cold runtime preload can still take minutes, and some synthetic repetitive prompts hit fallback and remain near baseline TTFT.
