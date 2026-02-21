# TRACK 4 [DRAFT]: swift_coreml_ttft_optimization

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
- [ ] Milestone 1: Add TTFT instrumentation and a repeatable local benchmark recipe.
- [ ] Milestone 2: Eliminate obvious per-step allocations in prefill (mask + arrays + feature providers) via reuse.
- [ ] Milestone 3: Implement batched prefill (or dedicated prefill functions) and validate parity.
- [ ] Milestone 4: Document results (before/after TTFT) and remaining bottlenecks.

Plan (execution steps)
- [ ] Move Track 4 to ACTIVE (folder + filename + title status).
- [ ] Establish baseline TTFT on one supported bundle (Gemma3) and record: prompt_tokens, TTFT, tokens/sec.
- [ ] Profile prefill to identify hotspots (allocations vs Core ML calls).
- [ ] Implement reuse/caching improvements; re-measure.
- [ ] Implement batched prefill if supported; re-measure.
- [ ] Add/adjust tests (unit/integration) as needed; keep local benchmarks gated.
- [ ] Move Track 4 to COMPLETED and capture completion notes.

Risks / decisions
- Risk: compiled models may not accept multi-token prefill input shapes (sequence length > 1) with the current interface.
- Risk: mask caching strategies may be model-specific; keep logic inside runtime adapter.
- Decision: prefer incremental, reversible optimizations with clear measurements over large refactors.

Inventory
- Performance-critical runtime: `Sources/LambdaDeckCore/CoreMLRuntime.swift`.
- Runtime contract and model inspection: `Sources/LambdaDeckCore/InferenceRuntime.swift`.
- Server integration (for TTFT measurement via HTTP): `Sources/LambdaDeckCore/LambdaDeckServer.swift`.

Artifacts
- Baseline/after measurements (fill when ACTIVE): pending.
