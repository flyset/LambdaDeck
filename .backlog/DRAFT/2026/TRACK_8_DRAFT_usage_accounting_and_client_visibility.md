# TRACK 8 [DRAFT]: usage_accounting_and_client_visibility

Problems (PORE)
- P1: As a client developer, I can’t reliably show token usage from LambdaDeck responses, because usage accounting is not guaranteed across non-streaming and streaming chat responses.
- P2: As a client UI developer, I can’t show context-window utilization (for example "24% used"), because LambdaDeck does not expose a stable context capacity signal alongside token usage.
- P3: As an operator, I can’t observe aggregate token throughput and request/token trends over time, because there is no dedicated usage/metrics surface.
- P4: As a maintainer, I need usage visibility improvements without breaking OpenAI-compatible behavior, because client interoperability is a core project goal.

Objective
- Provide OpenAI-compatible per-request usage accounting plus minimal context-capacity and operator metrics signals so clients can render usage meters and operators can monitor token activity.

Acceptance criteria
- [P1,P4] `POST /v1/chat/completions` non-streaming responses always include deterministic `usage` (`prompt_tokens`, `completion_tokens`, `total_tokens`) for successful completions.
- [P1,P4] Streaming chat supports final usage reporting in a client-consumable way while preserving OpenAI-compatible SSE semantics.
- [P2,P4] LambdaDeck exposes model context capacity to clients in a documented, stable API shape (OpenAI-compatible where possible; extension field/header where needed).
- [P3] LambdaDeck exposes aggregate usage counters for operators (for example total requests, prompt tokens, completion tokens) via a documented endpoint.
- [P1,P2,P3,P4] Integration tests cover non-streaming usage, streaming usage, and context-capacity visibility; `swift test` remains green.

Why now / impact
- Usage and context visibility are required for first-class client UX parity (token meters and context percentages) and practical local-server operations.

Scope
- In scope:
  - Define usage accounting contract for non-streaming and streaming chat responses.
  - Define and expose context-capacity metadata for model/client meter calculations.
  - Add an operator-facing aggregate usage metrics surface.
  - Add tests and docs for usage semantics and limits/expectations.
- Out of scope:
  - Billing, invoicing, or currency cost computation.
  - Multi-tenant quotas, auth-scoped accounting, or account-level reporting.
  - Full OpenAI usage/billing endpoints outside currently supported API surface.

Non-negotiables
- Follow TDD/test-first for usage contract updates (unit/integration as applicable).
- Keep OpenAI-compatible behavior intact; any extension fields/endpoints must be clearly documented as LambdaDeck-specific.

Milestones
- [ ] Milestone 1: Specify usage accounting contract (non-stream + stream final usage) and context-capacity signaling.
- [ ] Milestone 2: Implement deterministic token accounting path in runtime/server.
- [ ] Milestone 3: Implement streaming final-usage reporting semantics.
- [ ] Milestone 4: Implement operator aggregate usage metrics endpoint.
- [ ] Milestone 5: Add tests + documentation and validate full suite.

Risks / decisions
- Risk: Token counting can diverge from client tokenizer assumptions; mitigate by documenting counting source-of-truth and testing with known fixtures.
- Risk: OpenAI-compatible streaming semantics vary by client; mitigate by explicit integration tests against expected SSE framing.
- Decision (proposed): Keep request-level `usage` as the primary client contract and treat aggregate metrics as LambdaDeck extension surfaces.

Plan (execution steps)
- [ ] Move Track 8 to ACTIVE (folder + filename + title status).
- [ ] Define and document usage/context-capacity API contract before implementation.
- [ ] Add failing tests for non-stream usage, stream final usage, and context-capacity exposure.
- [ ] Implement usage accounting + streaming usage reporting until tests pass.
- [ ] Implement aggregate metrics endpoint and validation tests.
- [ ] Update docs (`README.md`, `docs/DEVELOPMENT.md`, `docs/TROUBLESHOOTING.md`) and run `swift test`.
- [ ] Move Track 8 to COMPLETED and capture completion notes.

Inventory
- **Current inventory**
  - OpenAI response contracts: `Sources/LambdaDeckCore/OpenAIContracts.swift`
  - Chat request handling + SSE behavior: `Sources/LambdaDeckCore/LambdaDeckServer.swift`
  - Runtime completion/stream token flow: `Sources/LambdaDeckCore/InferenceRuntime.swift`
  - Integration tests for API behavior: `Tests/LambdaDeckIntegrationTests/OpenAIContractIntegrationTests.swift`
  - CLI/operator docs: `README.md`, `docs/DEVELOPMENT.md`, `docs/TROUBLESHOOTING.md`

Artifacts
- (To add) Usage/accounting API decision notes.
- (To add) Metrics endpoint schema/examples and test artifacts.

Completion notes (fill when COMPLETED/DEPRECATED)
- Pending.
