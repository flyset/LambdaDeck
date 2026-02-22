# TRACK 10 [DRAFT]: model_specific_prompting_and_tokenizer_strategy

Problems (PORE)
- P1: As a user, I receive repetitive or role-confused responses from some models, because LambdaDeck applies a generic transcript prompt format when the model expects a model-specific chat template.
- P2: As a maintainer, I cannot evolve prompt behavior safely, because prompt-format selection logic is embedded in runtime code instead of being adapter-driven and explicit.
- P3: As an operator, I cannot quickly diagnose response-quality issues, because the active prompt strategy for a loaded model is not explicitly modeled and documented end-to-end.
- P4: As a contributor, I cannot onboard non-Gemma instruct models cleanly, because prompt policy is inferred implicitly rather than declared through adapter and metadata contracts.

Objective
- Introduce a clean, adapter-driven prompting strategy layer (including ChatML support) so model-specific prompt behavior is explicit, testable, and extensible without runtime monolith growth.

Acceptance criteria
- [P1,P2] Prompt rendering is moved behind a dedicated prompting abstraction with at least `chat_transcript`, `gemma3_turns`, and `chatml` renderers.
- [P1,P2,P4] Adapter execution plans select prompt format explicitly; runtime consumes selected strategy rather than inferring from tokenizer token presence.
- [P1,P4] LambdaDeck bundle metadata supports and validates `prompt.format: "chatml"` alongside existing formats.
- [P1,P2] Unit tests verify renderer behavior for system/user/assistant turns and invalid conversation patterns.
- [P1,P3,P4] Integration coverage includes a non-Gemma instruct path using ChatML-style prompting and confirms stable OpenAI endpoint behavior.
- [P1,P2,P3,P4] `swift test` remains green and local smoke validation steps are documented for at least one real non-Gemma ANEMLL model.

Why now / impact
- Real model runs (for example Nanbeige) show prompt/template mismatch symptoms; fixing prompting policy is required for response quality and reliable multi-model support.

Scope
- In scope:
  - Add prompting abstraction and renderer implementations.
  - Wire adapter-selected prompt strategy into runtime generation flow.
  - Extend metadata validation/docs for `chatml` prompt format.
  - Add unit/integration tests focused on prompt strategy correctness.
  - Add operator/developer docs describing prompt strategy selection.
- Out of scope:
  - Full HuggingFace tokenizer engine parity rewrite.
  - New Core ML architecture kernels or quantization changes.
  - Broad UX/client-side prompt editing features.

Non-negotiables
- Follow TDD/test-first for prompt strategy and metadata contract changes.
- Keep OpenAI-compatible API behavior stable while improving generation behavior.

Milestones
- [ ] Milestone 1: Define prompt strategy contract and model/adapter ownership boundaries.
- [ ] Milestone 2: Implement prompting module with transcript, Gemma turns, and ChatML renderers.
- [ ] Milestone 3: Wire adapter-driven prompt strategy into runtime path.
- [ ] Milestone 4: Extend metadata validation/docs and add failing/then-passing tests.
- [ ] Milestone 5: Validate with integration tests and local real-model smoke checks.

Risks / decisions
- Risk: Prompt strategy changes can regress existing Gemma behavior; mitigate with explicit regression tests for Gemma prompt rendering.
- Risk: Heuristic prompt selection for legacy ANEMLL bundles may be imperfect; mitigate by preferring explicit metadata when available and documenting fallback behavior.
- Decision (proposed): Treat adapter-selected prompt strategy as the runtime source of truth; use metadata declaration first, heuristics only as fallback.
- Decision (proposed): Keep tokenizer engine rewrite out of this Track; isolate prompt strategy improvements first.

Plan (execution steps)
- [ ] Move Track 10 to ACTIVE (folder + filename + title status).
- [ ] Define prompt strategy interfaces/types and document mapping rules (metadata-first, fallback heuristics).
- [ ] Add failing tests for ChatML rendering and adapter-selected prompt strategy behavior.
- [ ] Implement prompting module and runtime wiring until tests pass.
- [ ] Extend metadata validation/docs for `prompt.format: chatml` and add coverage.
- [ ] Run `swift test` and local smoke checks; update inventory/validations.
- [ ] Move Track 10 to COMPLETED and capture completion notes.

Inventory
- **Current inventory**
  - Runtime prompt rendering/generation flow: `Sources/LambdaDeckCore/Runtime/CoreMLRuntime.swift`
  - Adapter contracts: `Sources/LambdaDeckCore/Adapters/Contracts/ModelAdapterTypes.swift`
  - Adapter resolver and implementations:
    - `Sources/LambdaDeckCore/Adapters/Resolver/ModelAdapterResolver.swift`
    - `Sources/LambdaDeckCore/Adapters/ANEMLL/ANEMLLModelAdapter.swift`
    - `Sources/LambdaDeckCore/Adapters/LambdaDeckMetadata/LambdaDeckMetadataModelAdapter.swift`
  - Bundle metadata contracts/validation:
    - `Sources/LambdaDeckCore/Bundles/Contracts/BundleMetadataTypes.swift`
    - `Sources/LambdaDeckCore/Bundles/Validation/BundleMetadataValidator.swift`
    - `Sources/LambdaDeckCore/Bundles/Loader/BundleMetadataLoader.swift`
  - Existing tokenizer implementation: `Sources/LambdaDeckCore/Tokenizers/GemmaBPETokenizer.swift`
  - Tests:
    - `Tests/LambdaDeckCoreTests/LambdaDeckCoreTests.swift`
    - `Tests/LambdaDeckIntegrationTests/OpenAIContractIntegrationTests.swift`
  - Docs:
    - `docs/BUNDLE_METADATA.md`
    - `ARCHITECTURE.md`
    - `docs/DEVELOPMENT.md`

Artifacts
- (To add) Prompt strategy decision table (model family to renderer).
- (To add) ChatML prompt fixtures and expected outputs.
- (To add) Real-model smoke validation notes (Nanbeige/Qwen paths).

Completion notes (fill when COMPLETED/DEPRECATED)
- Pending.
