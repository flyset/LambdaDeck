# TRACK 7 [DRAFT]: coreml_llm_model_adapters_and_bundle_metadata

Problems (PORE)
- P1: As a developer, I can’t run non-ANEMLL CoreML LLM bundles through LambdaDeck, because the runtime is coupled to one bundle layout + metadata source (ANEMLL-style meta.yaml).
- P2: As a model packager, I can’t make a CoreML LLM “drop-in compatible” with LambdaDeck, because there is no stable, documented bundle metadata spec for discovery (model id, tokenizer, prompt format, capabilities).
- P3: As a contributor, I can’t add support for a new CoreML LLM family cleanly, because there is no explicit adapter interface separating HTTP/OpenAI contract from model-specific inference and I/O conventions.
- P4: As an operator, I need predictable “what models are available and what they support”, because clients depend on capability discovery and consistent errors when a bundle is incomplete or incompatible.

Objective
- Formalize a Swift-native CoreML LLM adapter layer + a minimal bundle metadata spec so LambdaDeck can support multiple CoreML LLM bundle formats (including ANEMLL bundles) without changing the OpenAI HTTP surface.

Acceptance criteria
- [P1,P3] A new `ModelAdapter` (name TBD) interface exists that cleanly encapsulates: model identity, tokenizer access, prompt formatting expectations, prefill/decode execution, and output decoding (tokens/logits).
- [P2,P4] A documented “LambdaDeck bundle metadata” spec exists (file name + fields + validation rules) enabling model discovery without ANEMLL `meta.yaml`.
- [P1,P2] LambdaDeck can serve at least one non-ANEMLL CoreML LLM bundle in tests (synthetic test bundle OK), including `/v1/models` and `/v1/chat/completions`.
- [P1] Existing ANEMLL bundle support remains working via a dedicated adapter (no regression).
- [P4] Validation errors are explicit and operator-friendly (missing tokenizer, incompatible shapes, missing required models, etc.).
- [P1,P2,P3,P4] `swift test` remains green; new tests cover adapter selection, metadata validation, and a non-ANEMLL happy path.

Why now / impact
- Expands LambdaDeck from “ANEMLL-friendly server” to a general Swift-native CoreML LLM server surface, increasing interoperability and reducing ecosystem fragmentation.

Scope
- In scope:
  - Swift-native adapter interface(s) for CoreML LLM bundles.
  - Bundle discovery + validation and a LambdaDeck-owned metadata spec.
  - Adapter selection logic (e.g., “ANEMLL meta.yaml present” vs “LambdaDeck metadata present”).
  - Tests for adapter selection, metadata validation, and a non-ANEMLL runnable case.
  - Documentation describing how to package a CoreML LLM bundle for LambdaDeck.
- Out of scope:
  - Non-LLM CoreML models (vision/audio/embeddings unless already part of an LLM bundle contract).
  - Python-based serving, FastAPI, or bridging to external runtimes.
  - Model conversion pipelines (remain external).
  - Full OpenAI API surface expansion beyond current endpoints.

Non-negotiables
- TDD/test-first for all adapter/metadata work (unit + integration where applicable).
- No implementation begins until the Track is moved to ACTIVE and the “Move Track 7 to ACTIVE” step is checked.

Milestones
- [ ] Milestone 1: Define adapter responsibilities and boundaries (public protocol + minimal types).
- [ ] Milestone 2: Define LambdaDeck bundle metadata spec + validation rules.
- [ ] Milestone 3: Implement adapter selection + ANEMLL adapter wrapper around existing behavior.
- [ ] Milestone 4: Implement a “LambdaDeck metadata” adapter path for a non-ANEMLL CoreML LLM bundle (testable).
- [ ] Milestone 5: Add docs + examples and ensure `swift test` coverage for the new system.

Risks / decisions
- Risk: “Any CoreML LLM” is too broad; mitigate by defining a strict LLM runtime contract (token-in/logits-out + state semantics) and requiring explicit adapters per family.
- Risk: Metadata spec drift; mitigate by versioning the metadata schema.
- Decision: Keep ANEMLL `meta.yaml` support as one adapter path, not as the canonical metadata format.

Plan (execution steps)
- [ ] Move Track 7 to ACTIVE (folder + filename + title status).
- [ ] Write failing tests for adapter selection + metadata validation.
- [ ] Introduce adapter protocol + shared types; wire through server bootstrap.
- [ ] Implement ANEMLL adapter (wrap current behavior) and ensure parity.
- [ ] Implement LambdaDeck metadata spec + a non-ANEMLL adapter path; make tests pass.
- [ ] Update docs; run `swift test`; move Track 7 to COMPLETED.

Inventory
- **Current inventory**
  - Server routing + OpenAI contract: `Sources/LambdaDeckCore/LambdaDeckServer.swift`, `Sources/LambdaDeckCore/OpenAIContracts.swift`
  - Runtime provider + warmup behavior: `Sources/LambdaDeckCore/InferenceRuntime.swift`
  - Bootstrap/config/model discovery: `Sources/LambdaDeckCLI/*`, `Sources/LambdaDeckCore/*` (exact files to enumerate when implementing)
  - Integration tests: `Tests/LambdaDeckIntegrationTests/OpenAIContractIntegrationTests.swift`

Artifacts
- (To add) Bundle metadata schema doc + example bundle layouts.
- (To add) PR links and any compatibility notes discovered during adapter work.

Completion notes (fill when COMPLETED/DEPRECATED)
- Pending.
