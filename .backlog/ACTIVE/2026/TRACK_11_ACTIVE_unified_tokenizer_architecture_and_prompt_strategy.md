# TRACK 11 [ACTIVE]: unified_tokenizer_architecture_and_prompt_strategy

Problems (PORE)
- P1: As a user, I get garbled or repetitive outputs from some models, because LambdaDeck applies tokenizer and prompt behavior that is implicitly tuned for one family instead of the loaded model's tokenizer/template contract.
- P2: As a maintainer, I cannot safely add new model families, because tokenizer behavior is not isolated behind a clear runtime abstraction and family-specific assumptions leak into generic paths.
- P3: As an operator, I cannot quickly diagnose inference quality failures, because startup/runtime diagnostics do not clearly report active tokenizer/prompt strategy and often collapse root-cause model load errors into generic messages.
- P4: As a contributor, I cannot validate tokenizer correctness across model families, because there is no canonical conformance test matrix (encode/decode, special tokens, prompt rendering) tied to adapter/metadata selection.
- Reference: `.backlog/PORE.md`.

Objective
- Establish a global, clean, adapter-driven tokenizer and prompt strategy architecture so Gemma/Qwen/other ANEMLL bundles use the correct tokenizer/template path with explicit diagnostics and testable contracts.

Acceptance criteria
- [P1,P2] Runtime tokenization uses a dedicated tokenizer abstraction with family-specific implementations (at minimum Gemma-style and ByteLevel-BPE-style) selected by adapter/metadata strategy.
- [P1,P2] Prompt rendering is strategy-driven (`chat_transcript`, `gemma3_turns`, `chatml`) and no longer inferred from tokenizer token presence heuristics in generic runtime paths.
- [P1,P3] Runtime warmup/startup failures preserve and surface underlying initialization errors (not only generic wrappers), and operator signals include selected tokenizer/prompt strategy for loaded model.
- [P2,P4] Bundle metadata and adapter contracts support explicit tokenizer family/strategy declaration with validation and documented fallback rules for legacy bundles.
- [P1,P4] Conformance tests validate encode/decode behavior, special-token handling, and prompt rendering for at least Gemma and Qwen-like fixtures.
- [P1,P2,P3,P4] `swift test` remains green, and local smoke checks demonstrate coherent responses for one Gemma-family model and one Qwen-family model.

Why now / impact
- LambdaDeck's OpenAI-compatible runtime depends on model-correct tokenization and prompting for response quality; a unified architecture is now required to scale multi-model support without fragile per-model patches.

Scope
- In scope:
  - Define tokenizer abstraction interfaces and strategy selection flow.
  - Implement tokenizer families required for current model inventory (Gemma-style + ByteLevel-BPE-style baseline).
  - Wire adapter/metadata-driven prompt + tokenizer strategy into runtime.
  - Improve startup/warmup diagnostics for tokenizer/prompt strategy and root-cause load errors.
  - Add unit/integration conformance tests and operator/developer docs.
- Out of scope:
  - Full Hugging Face tokenizer feature parity for every tokenizer backend.
  - Core ML kernel/quantization redesign.
  - Client-side UI/SDK changes outside server contract and docs.

Non-negotiables
- Follow TDD/test-first for tokenizer, prompting, adapter, and diagnostics changes.
- Keep OpenAI-compatible endpoint behavior stable while improving internal strategy correctness.
- Keep tests co-located with the affected Swift modules/packages per repo conventions.

Milestones
- [ ] Milestone 1: Define tokenizer + prompt strategy contracts and adapter/metadata ownership boundaries.
- [ ] Milestone 2: Add failing conformance tests (Gemma and Qwen-like fixtures) for tokenizer/prompt behavior.
- [ ] Milestone 3: Implement tokenizer family abstractions and runtime strategy wiring until tests pass.
- [ ] Milestone 4: Add diagnostics improvements for startup/warmup root causes and active strategy visibility.
- [ ] Milestone 5: Update docs and run full validation (`swift test` + local smoke checks).

Risks / decisions
- Risk: Refactoring tokenizer/runtime boundaries can regress existing Gemma behavior; mitigate with explicit regression fixtures and golden outputs.
- Risk: Legacy bundles may not declare tokenizer family/prompt format; mitigate with deterministic fallback rules and clear validation warnings/errors.
- Risk: Overly broad tokenizer scope can stall delivery; mitigate with staged family support and strict non-goals.
- Decision (proposed): Adapter/metadata selection is source-of-truth for tokenizer + prompt strategy; runtime should execute selected strategies, not infer behavior ad hoc.
- Decision (proposed): Preserve generic `chat_transcript` fallback for unknown families only as a controlled compatibility path with explicit operator visibility.

Plan (execution steps)
- [x] Move Track 11 to ACTIVE (folder + filename + title status).
- [ ] Define tokenizer and prompt strategy interfaces/types, selection rules, and metadata/adapter mapping.
- [ ] Add failing tests for tokenizer-family conformance and prompt rendering by strategy.
- [ ] Implement tokenizer abstractions and runtime wiring until tests pass.
- [ ] Implement diagnostics improvements (root-cause warmup errors + active strategy visibility).
- [ ] Update docs (`ARCHITECTURE.md`, `docs/BUNDLE_METADATA.md`, `docs/DEVELOPMENT.md`, `docs/TROUBLESHOOTING.md`) and run validations.
- [ ] Move Track 11 to COMPLETED and capture completion notes.

Inventory
- **Current inventory**
  - Tokenizers:
    - `Sources/LambdaDeckCore/Tokenizers/GemmaBPETokenizer.swift`
  - Runtime prompt/token flow and warmup:
    - `Sources/LambdaDeckCore/Runtime/CoreMLRuntime.swift`
    - `Sources/LambdaDeckCore/Runtime/InferenceRuntime.swift`
    - `Sources/LambdaDeckCore/Runtime/RuntimeBuilder.swift`
  - Adapter contracts and selection:
    - `Sources/LambdaDeckCore/Adapters/Contracts/ModelAdapterTypes.swift`
    - `Sources/LambdaDeckCore/Adapters/Resolver/ModelAdapterResolver.swift`
    - `Sources/LambdaDeckCore/Adapters/ANEMLL/ANEMLLModelAdapter.swift`
    - `Sources/LambdaDeckCore/Adapters/LambdaDeckMetadata/LambdaDeckMetadataModelAdapter.swift`
  - Bundle metadata contracts and validation:
    - `Sources/LambdaDeckCore/Bundles/Contracts/BundleMetadataTypes.swift`
    - `Sources/LambdaDeckCore/Bundles/Validation/BundleMetadataValidator.swift`
    - `Sources/LambdaDeckCore/Bundles/Loader/BundleMetadataLoader.swift`
  - Server/operator readiness surfaces:
    - `Sources/LambdaDeckCore/Server/LambdaDeckServer.swift`
    - `Sources/LambdaDeckCLI/LambdaDeckMain.swift`
  - Tests:
    - `Tests/LambdaDeckCoreTests/LambdaDeckCoreTests.swift`
    - `Tests/LambdaDeckIntegrationTests/OpenAIContractIntegrationTests.swift`
    - `Tests/LambdaDeckCLITests/LambdaDeckCLITests.swift`
  - Documentation:
    - `ARCHITECTURE.md`
    - `docs/BUNDLE_METADATA.md`
    - `docs/DEVELOPMENT.md`
    - `docs/TROUBLESHOOTING.md`

Artifacts
- (To add) Tokenizer strategy decision table (model family -> tokenizer implementation -> prompt strategy).
- (To add) Conformance fixtures and golden encode/decode/prompt outputs.
- (To add) Smoke-check evidence for at least one Gemma and one Qwen-family bundle.

Completion notes (fill when COMPLETED/DEPRECATED)
- Pending.
