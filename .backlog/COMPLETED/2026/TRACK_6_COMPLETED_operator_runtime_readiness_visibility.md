# TRACK 6 [COMPLETED]: operator_runtime_readiness_visibility

Problems (PORE)
- P1: As a command-line operator running `lambdadeck serve`, I cannot tell whether model/runtime warmup has started or finished, because startup output does not clearly expose warmup lifecycle states.
- P2: As an operator integrating health checks, I cannot reliably distinguish "server is listening" from "runtime is ready for chat," because there is no explicit readiness endpoint and warmup is only inferred from chat `503` responses.
- P3: As a maintainer debugging startup delays, I lack concrete warmup phase timing at the operator boundary, because startup/warmup transitions are not surfaced as explicit, observable events.
- Reference: `.backlog/PORE.md`.

Objective
- Provide clear operator-visible readiness signals (logs + health/readiness surface) so users can understand and automate LambdaDeck startup and warmup states.

Acceptance criteria
- [P1] `lambdadeck serve` prints clear lifecycle status messages for startup and runtime warmup, including a "runtime ready" signal with elapsed time.
- [P1,P3] Warmup state transitions are observable in stderr output in a deterministic, human-readable format.
- [P2] Add an explicit readiness endpoint (for example `/readyz` or `/health`) that reports `warming_up` vs `ready` with minimal metadata.
- [P2] Readiness endpoint returns operator-friendly HTTP semantics: `200` when ready and `503` while warming up or failed.
- [P2] Readiness endpoint includes explicit failed state metadata when runtime initialization fails.
- [P2] Documentation includes operator guidance for interpreting readiness and handling warmup-time `503` chat responses.
- [P3] Tests cover readiness state behavior and ensure no regressions in existing server contracts.
- [P1,P2,P3] `swift test` remains green.

Why now / impact
- Track 4 introduced asynchronous runtime warmup and bounded `503` responses, which improved startup behavior but made operator-state visibility less obvious. Clear readiness signaling now unblocks reliable operations and scripting.

Scope
- In scope:
  - Operator-facing startup/warmup lifecycle logs for `serve`.
  - Explicit readiness endpoint design and implementation.
  - Basic readiness metadata (status and elapsed/uptime context).
  - Test coverage for readiness behavior and startup-state transitions.
  - Docs updates for startup/warmup operational workflow.
- Out of scope:
  - Core inference performance changes (TTFT/decode throughput).
  - OpenAI API expansion beyond existing v1 model/chat contract.
  - Multi-tenant orchestration or external monitoring stack integrations.

Non-negotiables
- Follow TDD/test-first for behavior changes and keep tests in the same module/package as implementation.
- Preserve existing API contract behavior for `/v1/models` and `/v1/chat/completions` while adding readiness visibility.
- Keep warmup behavior backward-compatible (clients that retry on `503` continue to work).

Milestones
- [x] Milestone 1: Define operator readiness UX (log phases + endpoint schema).
- [x] Milestone 2: Implement lifecycle logging for startup and warmup completion.
- [x] Milestone 3: Implement readiness endpoint and wire runtime-provider state reporting.
- [x] Milestone 4: Add/adjust tests for readiness and lifecycle behavior.
- [x] Milestone 5: Update docs and finalize operational runbook notes.

Risks / decisions
- Risk: Overly verbose startup logs can create noise; need concise, stable messaging.
- Risk: Readiness endpoint shape may need future extension; keep initial contract minimal.
- Risk: Exposing detailed timing may vary across environments; avoid overpromising absolute values.
- Decision: Prefer explicit readiness semantics (`warming_up` vs `ready`) over implicit inference from chat response codes.
- Decision: `GET /readyz` returns `200` when runtime is ready and `503` while warming up or failed; failed payload includes an `error` field.

Plan (execution steps)
- [x] Move Track 6 to ACTIVE (folder + filename + title status).
- [x] Define and document readiness contract (endpoint path, payload, status semantics).
- [x] Implement startup/warmup lifecycle logging in CLI/server boundary.
- [x] Implement readiness endpoint and runtime provider state plumbing.
- [x] Add/update tests for readiness states and existing contract safety.
- [x] Update `README.md`, `docs/DEVELOPMENT.md`, and `docs/TROUBLESHOOTING.md` with readiness guidance.
- [x] Run `swift test`, record artifacts, and move Track 6 to COMPLETED.

Inventory
- **Current inventory**
  - Readiness DTO + status contract: `Sources/LambdaDeckCore/OpenAIContracts.swift`.
  - Runtime warmup provider/readiness snapshot state: `Sources/LambdaDeckCore/InferenceRuntime.swift`.
  - HTTP routing and response behavior: `Sources/LambdaDeckCore/LambdaDeckServer.swift`.
  - CLI startup lifecycle logs and warmup monitor: `Sources/LambdaDeckCLI/LambdaDeckMain.swift`.
  - Integration behavior tests (`/readyz` ready/warming/failed + existing chat contracts): `Tests/LambdaDeckIntegrationTests/OpenAIContractIntegrationTests.swift`.
  - CLI log-format determinism tests: `Tests/LambdaDeckCLITests/LambdaDeckCLITests.swift`.
  - Operator docs: `README.md`, `docs/DEVELOPMENT.md`, `docs/TROUBLESHOOTING.md`.
  - Operator script alignment: `scripts/warmup_probe.py`.

Artifacts
- Finalized readiness contract:
  - Endpoint: `GET /readyz`.
  - Ready: HTTP `200` + `{"status":"ready","model":"<id>","elapsed_ms":<int>}`.
  - Warming: HTTP `503` + `{"status":"warming_up","model":"<id>","elapsed_ms":<int>}`.
  - Failed warmup: HTTP `503` + `{"status":"failed","model":"<id>","elapsed_ms":<int>,"error":"<message>"}`.
  - `elapsed_ms` semantics: wall-clock milliseconds since runtime warmup/preload started, as observed by `LambdaDeckRuntimeProvider`.
- Proposed lifecycle log phases draft:
  - `startup: resolving configuration`
  - `startup: server listening ...`
  - `startup: runtime warmup started`
  - `startup: runtime ready (elapsed=...ms)`
- Validation checklist (to fill when ACTIVE/COMPLETED):
  - [x] Readiness endpoint behavior in warming, ready, and failed states.
  - [x] Warmup-time chat `503` behavior remains intact.
  - [x] `swift test` summary and any local smoke checks.
  - Validation run (2026-02-22): `swift test` passed (36 tests, 0 failures, 1 skipped local-only real-inference test).

Completion notes (fill when COMPLETED/DEPRECATED)
- Delivered explicit operator readiness surface via `GET /readyz` with deterministic semantics: `200` when ready, `503` during warmup, and `503` with `status=failed` plus error details on warmup failure.
- Added runtime readiness state plumbing in `LambdaDeckRuntimeProvider`, including elapsed warmup timing and failure-state reporting.
- Added startup lifecycle logs in `lambdadeck serve` with deterministic warmup transitions and runtime-ready elapsed timing output.
- Expanded integration coverage for readiness states while preserving existing `/v1/models` and `/v1/chat/completions` contracts and warmup-time chat `503` behavior.
- Updated operator docs and warmup probe workflow to use readiness-first checks.
