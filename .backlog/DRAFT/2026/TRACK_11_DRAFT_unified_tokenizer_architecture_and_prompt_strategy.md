# TRACK 11 [DRAFT]: unified_tokenizer_architecture_and_prompt_strategy

Note
- Track 10 is deprecated and folded into this Track: `/.backlog/DEPRECATED/2026/TRACK_10_DEPRECATED_model_specific_prompting_and_tokenizer_strategy.md`.

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
- Decision: Introduce a Prompt IR using `PromptSegment` with `.special(.startOfTurn(role))` / `.special(.endOfTurn)` plus `.text` segments.
- Decision: PromptStrategy returns `PromptSegment` arrays; Tokenizer converts segments -> token IDs (PromptStrategy does not emit token IDs directly).
- Decision: Baseline special token set for the contract: `bos`, `eos`, `startOfTurn`, `endOfTurn`, `endOfText`, `eotID`, `pad`, `unk`, `startOfImage`, `imageSoftToken`.
- Decision: Gemma3 system policy = prefix-first-user with `\n\n` separator; assistant role label maps to `model` in prompt rendering.
- Decision: ChatML system policy = system message is its own turn.
- Decision: Metadata allowed values (v1 contract) are fixed; unrecognized values trigger fallback with explicit diagnostics.
- Open: Additional special tokens required by other families (extend via metadata + tests as needed).
- Open: Whether any target model family requires direct token-level templates beyond segments (validate during next non-Gemma onboarding).
- Open: System message handling policy for any future non-ChatML formats (if added).

Plan (execution steps)
- [ ] Move Track 11 to ACTIVE (folder + filename + title status).
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
- (To add) Conformance fixtures and golden encode/decode/prompt outputs.
- (To add) Smoke-check evidence for at least one Gemma and one Qwen-family bundle.
- Strategy decision table (draft)
  - Inputs (priority order):
    1) Bundle metadata declarations (`tokenizer.family`, `prompt.format` when present).
    2) Adapter defaults for known families (Gemma/Qwen/etc) when metadata is missing.
    3) Legacy fallback policy (`chat_transcript`) only when neither metadata nor adapter provides a strategy.
  - Outputs: Selected `TokenizerStrategy`, `PromptStrategy`, and `StopStrategy` for runtime execution.
  - Precedence rules:
    - Metadata overrides adapter defaults.
    - Adapter defaults override fallback.
    - Fallback must emit explicit diagnostics (warning + visible in operator signals).
  - Diagnostics requirements:
    - Always report selected tokenizer family + prompt format at startup/warmup.
    - If fallback is used, include a clear "FALLBACK ACTIVE" marker and the missing declaration reason.
- Metadata keys -> strategy mapping (draft)
  - Keys:
    - `tokenizer.family`: `gemma_bpe` | `bytelevel_bpe` | `unknown`
    - `prompt.format`: `gemma3_turns` | `chatml` | `chat_transcript`
    - `prompt.system_policy` (optional): `prefix_first_user` | `own_turn`
  - Allowed values (v1 contract):
    - `tokenizer.family`: `gemma_bpe`, `bytelevel_bpe`, `unknown`
    - `prompt.format`: `gemma3_turns`, `chatml`, `chat_transcript`
    - `prompt.system_policy`: `prefix_first_user`, `own_turn`
  - Defaults:
    - `prompt.system_policy` defaults to format-specific policy when omitted (Gemma3 = `prefix_first_user`, ChatML = `own_turn`).
  - Missing/unrecognized behavior:
    - Missing values use adapter defaults when available.
    - Unrecognized values trigger fallback to `chat_transcript` and emit diagnostics per decision table.
  - Precedence:
    - Metadata values override adapter defaults.
    - Adapter defaults override fallback.
    - Fallback emits explicit diagnostics (see decision table).
  - Examples:
    - Gemma3 bundle:
      - `tokenizer.family: gemma_bpe`
      - `prompt.format: gemma3_turns`
      - `prompt.system_policy: prefix_first_user`
    - ChatML bundle (non-Gemma):
      - `tokenizer.family: bytelevel_bpe`
      - `prompt.format: chatml`
      - `prompt.system_policy: own_turn`
- Prompt IR contract (final)
  ```swift
  enum PromptSegment: Equatable {
      case text(String)
      case special(SpecialToken)
  }

  enum SpecialToken: Equatable {
      case bos
      case eos
      case startOfTurn(Role)
      case endOfTurn
      case endOfText
      case eotID
      case pad
      case unk
      case startOfImage
      case imageSoftToken
  }

  enum Role: String, Equatable {
      case system
      case user
      case assistant
  }

  protocol PromptStrategy {
      func render(messages: [OpenAIChatMessage]) throws -> [PromptSegment]
  }

  protocol Tokenizer {
      var vocabularySize: Int { get }
      var specialTokenIDs: [SpecialToken: Int] { get }

      func encode(text: String) -> [Int]
      func encode(segments: [PromptSegment]) throws -> [Int]
      func decode(tokenIDs: [Int], skipSpecialTokens: Bool) -> String
      func isSpecial(tokenID: Int) -> Bool
  }

  protocol StopStrategy {
      func stopTokenIDs(tokenizer: Tokenizer) -> Set<Int>
  }
  ```
- Contract notes:
  - `PromptStrategy` is responsible for role ordering rules and system-message policy per format.
  - `encode(segments:)` must throw if a required `SpecialToken` has no mapping in `specialTokenIDs`.
  - Strategy selection yields a `(tokenizer, promptStrategy, stopStrategy)` tuple; selection happens in adapter/metadata layer and is executed by runtime without heuristics.
- Fixtures (draft)
  - Decision: Gemma3 system policy = prefix-first-user; assistant role label maps to `model`.
  - Gemma prompt rules (current parity target):
    - `.special(.startOfTurn(role))` expands to `<start_of_turn>` + role label + `\n` (Gemma uses `model` label for assistant).
    - `.special(.endOfTurn)` expands to `<end_of_turn>\n`.
    - System message is prefixed to first user content as `"<system>\n\n"` (not its own turn).
  - Gemma fixture A (system + user + assistant; expected prefill):
    ```swift
    [
        .special(.bos),
        .special(.startOfTurn(.user)),
        .text("<system>\n\n"),
        .text("<user message>"),
        .special(.endOfTurn),
        .special(.startOfTurn(.assistant)),
        .text("<assistant message>"),
        .special(.endOfTurn),
        .special(.startOfTurn(.assistant))
    ]
    ```
  - Gemma fixture B (user-only; expected prefill):
    ```swift
    [
        .special(.bos),
        .special(.startOfTurn(.user)),
        .text("<user message>"),
        .special(.endOfTurn),
        .special(.startOfTurn(.assistant))
    ]
    ```

Completion notes (fill when COMPLETED/DEPRECATED)
- Pending.
