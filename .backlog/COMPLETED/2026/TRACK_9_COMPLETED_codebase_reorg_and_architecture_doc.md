# TRACK 9 [COMPLETED]: codebase_reorg_and_architecture_doc

Problems (PORE)
- P1: As a contributor, I cannot add new model families cleanly, because model discovery, OpenAI HTTP, tokenization, and runtime logic are interwoven in a few files.
- P2: As an operator, I cannot quickly understand failure modes and responsibilities, because the code layout does not map to the system architecture.
- P3: As a maintainer, I cannot execute Track 7 safely, because there is no stable module boundary to attach adapters and metadata without churn.

Objective
- Reorganize `LambdaDeckCore` into responsibility-based subdirectories and add `ARCHITECTURE.md`, without changing runtime behavior.

Acceptance criteria
- [P1,P3] Code is moved into `OpenAI/`, `Server/`, `Discovery/`, `Runtime/`, `Tokenizers/`, and `Version/` with no intentional behavior changes.
- [P2] A new `ARCHITECTURE.md` documents code layout, runtime flow, and planned seams for Track 7.
- [P1,P3] `swift test` is green before and after; integration tests remain semantically unchanged.
- [P1,P3] The public API surface of `LambdaDeckCore` remains effectively unchanged at compile time (no endpoint contract changes).

Why now / impact
- Creates clean ownership boundaries that reduce refactor risk and unblock Track 7 implementation work.

Scope
- In scope:
  - File and folder moves in `Sources/LambdaDeckCore/*` with minimal import/wiring fixes.
  - Add `ARCHITECTURE.md`.
  - Update affected Track inventories/references where needed.
- Out of scope:
  - Adapter protocol or metadata spec implementation.
  - Runtime behavior changes or endpoint changes.
  - New model-family support.

Non-negotiables
- TDD/test-first for this Track; validate with `swift test` after each meaningful reorg chunk and before completion.

Milestones
- [x] Milestone 1: Finalize target directory map and move sequence.
- [x] Milestone 2: Execute file moves while keeping build/tests green.
- [x] Milestone 3: Add `ARCHITECTURE.md` and align docs with implementation.

Risks / decisions
- Risk: Mechanical reorganization introduces accidental behavior changes; mitigate via minimal diffs and immediate test validation.
- Decision: Keep Track 9 purely organizational; Track 7 carries adapter/metadata functionality.

Plan (execution steps)
- [x] Move Track 9 to ACTIVE (folder + filename + title status).
- [x] Move `LambdaDeckCore` files into target subdirectories and fix compile paths.
- [x] Add `ARCHITECTURE.md` with architecture and flow documentation.
- [x] Run `swift test`; update inventory and validations run.
- [x] Move Track 9 to COMPLETED and capture completion notes.

Inventory
- **Current inventory**
  - `Sources/LambdaDeckCore/OpenAI/OpenAIContracts.swift`
  - `Sources/LambdaDeckCore/OpenAI/StubContract.swift`
  - `Sources/LambdaDeckCore/Server/LambdaDeckServer.swift`
  - `Sources/LambdaDeckCore/Discovery/ModelResolution.swift`
  - `Sources/LambdaDeckCore/Runtime/InferenceRuntime.swift`
  - `Sources/LambdaDeckCore/Runtime/CoreMLRuntime.swift`
  - `Sources/LambdaDeckCore/Tokenizers/GemmaBPETokenizer.swift`
  - `Sources/LambdaDeckCore/Version/LambdaDeckVersion.swift`
  - `ARCHITECTURE.md`
  - `Tests/LambdaDeckCoreTests/LambdaDeckCoreTests.swift`
  - `Tests/LambdaDeckIntegrationTests/OpenAIContractIntegrationTests.swift`

- **Validations run**
  - `swift test` (pass; 36 tests, 0 failures, 1 skipped local-only real-model test)

Artifacts
- `ARCHITECTURE.md`
- (To add) PR link(s) and reorg compatibility notes.

Completion notes (fill when COMPLETED/DEPRECATED)
- Reorganized `LambdaDeckCore` into responsibility-based subdirectories (`OpenAI`, `Server`, `Discovery`, `Runtime`, `Tokenizers`, `Version`) with no intended behavior change.
- Added `ARCHITECTURE.md` documenting module boundaries, runtime flow, and Track 7 extension points.
- Verified compatibility with `swift test`; all tests passed with one expected local-only skip.
