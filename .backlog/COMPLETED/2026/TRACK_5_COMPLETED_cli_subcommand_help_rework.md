# TRACK 5 [COMPLETED]: cli_subcommand_help_rework

Problems (PORE)
- P1: As a developer using the LambdaDeck CLI, I cannot quickly discover command-specific help because top-level help does not clearly teach `lambdadeck <command> --help` and the current shape blends flags and commands.
- P2: As a developer, I can misread a one-shot utility as a server flag rather than a standalone utility command, because its behavior is command-like but its surface is option-like.
- P3: As a maintainer, evolving the CLI is harder because ad-hoc parsing/help text can drift from expected command semantics, making UX consistency difficult to preserve.
- Reference: `.backlog/PORE.md`.

Objective
- Make LambdaDeck CLI command discovery and help behavior Apple-idiomatic by moving to explicit subcommands (`serve`, `contract stub`, `help`) and removing flag-shaped utility modes.

Acceptance criteria
- [P1] `lambdadeck --help` clearly documents subcommand usage and teaches command help discovery (for example `lambdadeck help serve` and `lambdadeck serve --help`).
- [P1] `lambdadeck help`, `lambdadeck help serve`, and `lambdadeck serve --help` all return clear, non-ambiguous help text.
- [P2] `lambdadeck contract stub` is available and documented as the canonical one-shot contract output command.
- [P2] `lambdadeck --stub-contract` is removed; invoking it returns a usage error (exit 64) with a clear migration hint to `lambdadeck contract stub`.
- [P3] CLI tests cover the new subcommand tree and compatibility paths; `swift test` remains green.
- [P3] Documentation (`README.md` and `docs/DEVELOPMENT.md`) reflects the new command layout and examples.

Why now / impact
- Clarifying CLI semantics reduces first-run friction, lowers support burden, and prevents user confusion between long-running server commands and one-shot utility commands.

Scope
- In scope:
  - Redesign command surface to explicit subcommands: `serve`, `contract stub`, and `help`.
  - Remove `--stub-contract` and migrate docs/tests to `lambdadeck contract stub`.
  - Adopt `swift-argument-parser` for parsing, help generation, and error handling (accept default formatting long-term).
  - Improve help text structure (`OVERVIEW`/`USAGE`/`OPTIONS`/`SUBCOMMANDS`/`EXAMPLES`) or equivalent clear sections.
  - Add/adjust CLI tests for parsing/help/compatibility behavior.
  - Update user docs with new command examples.
- Out of scope:
  - Runtime/server inference behavior changes.
  - API contract changes for `/v1/models` or `/v1/chat/completions`.
  - New product features beyond CLI UX and command organization.

Non-negotiables
- Follow TDD/test-first development for CLI behavior changes (tests added/updated with implementation in the same module/package).
- Preserve deterministic contract fixture output behavior.
- Do not silently change the deterministic JSON contract output shape/content.

Milestones
- [x] Milestone 1: Finalize command tree and compatibility policy.
- [x] Milestone 2: Implement parser/help restructuring for new subcommands.
- [x] Milestone 3: Add/adjust CLI tests for help discovery and alias compatibility.
- [x] Milestone 4: Update docs and examples to match new command UX.
- [x] Milestone 5: Validate end-to-end behavior and complete Track.

Risks / decisions
- Risk: help text churn can break tests that assert literal strings.
- Risk: adopting `swift-argument-parser` will change help/error wording; tests should assert exit codes + stdout/stderr routing + key substrings (avoid full snapshots).
- Decision: canonical path is `lambdadeck contract stub`; `--stub-contract` is removed.
- Decision (proposed): prefer explicit command-oriented UX over mode flags for one-shot utilities.
- Decision: adopt `swift-argument-parser` and accept its default help + error formatting long-term.
- Decision: adopt Apple-like CLI output conventions:
  - help text -> stdout, exit 0
  - usage/validation errors -> stderr, exit 64 (EX_USAGE)
  - runtime/execution errors -> stderr, exit 1
- Decision: removed `--stub-contract` (no alias support).
- Decision: unknown help topic (e.g. `lambdadeck help wat`) returns exit 64 and prints `Error: ...` to stderr, plus a short hint and available help topics (optionally include a "Did you mean ..." suggestion when unambiguous).
- Decision: keep `--version` as the supported version surface (provided by ArgumentParser `CommandConfiguration(version:)`).

Plan (execution steps)
- [x] Move Track 5 to ACTIVE (folder + filename + title status).
- [x] Define and document exact command/help UX matrix (top-level, `help`, `serve --help`, `contract --help`, `contract stub --help`), including exit codes + stdout/stderr rules + migration hint behavior for removed invocations.
- [x] Add `swift-argument-parser` dependency to `Package.swift` and define the new command tree types.
- [x] Implement parser changes for `contract stub` and `help`; remove `--stub-contract`.
- [x] Update CLI output/help text and error messaging for unknown/ambiguous invocations.
- [x] Add/update unit tests in `Tests/LambdaDeckCLITests/LambdaDeckCLITests.swift` for new and compatibility paths.
- [x] Update `README.md` and `docs/DEVELOPMENT.md` command examples.
- [x] Run `swift test`, update Track inventory/artifacts, and move Track 5 to COMPLETED.

Inventory
- **Current inventory**
  - SwiftPM package definition (ArgumentParser dependency): `Package.swift`.
  - SwiftPM lockfile updates from dependency resolution: `Package.resolved`.
  - CLI command parsing/help surface: `Sources/LambdaDeckCLI/CLI.swift`.
  - CLI execution entrypoint: `Sources/LambdaDeckCLI/LambdaDeckMain.swift`.
  - Existing CLI tests: `Tests/LambdaDeckCLITests/LambdaDeckCLITests.swift`.
  - Contract stub hook integration test: `Tests/LambdaDeckIntegrationTests/OpenAIContractIntegrationTests.swift`.
  - User-facing command docs: `README.md`, `docs/DEVELOPMENT.md`.

Artifacts
- Implemented canonical UX:
  - `lambdadeck serve [options]`
  - `lambdadeck contract stub`
  - `lambdadeck help [subcommand]`
- Breaking change note:
  - `--stub-contract` is removed; use `lambdadeck contract stub`.
- Help/UX matrix (implemented and covered by tests):
  - `lambdadeck` -> top-level help (stdout), exit 0
  - `lambdadeck --help` / `lambdadeck help` -> top-level help (stdout), exit 0
  - `lambdadeck --version` -> version (stdout), exit 0
  - `lambdadeck help serve` / `lambdadeck serve --help` -> serve help (stdout), exit 0
  - `lambdadeck help contract` / `lambdadeck contract --help` -> contract help (stdout), exit 0
  - `lambdadeck help contract stub` / `lambdadeck contract stub --help` -> stub help (stdout), exit 0
  - `lambdadeck help <unknown>` -> usage error (stderr) + available topics (+ optional suggestion), exit 64
  - `lambdadeck contract stub` -> deterministic JSON (stdout), exit 0
  - `lambdadeck --stub-contract` -> usage error (stderr) + migration hint to `lambdadeck contract stub`, exit 64
  - unknown command / invalid args -> `Error: ...` (stderr) + usage hint, exit 64
  - `serve` runtime failure -> `error: ...` (stderr), exit 1
- Validation checklist (to fill when ACTIVE/COMPLETED):
  - [x] Help text/expected substring assertions updated.
  - [x] CLI parser coverage for canonical + migration invocations.
  - [x] `swift test` result summary: pass (31 tests, 0 failures, 1 skipped local-only real-inference test) on 2026-02-22.

Completion notes (fill when COMPLETED/DEPRECATED)
- Migrated CLI to `swift-argument-parser` with explicit command tree (`serve`, `contract stub`) and maintained `help` discovery UX.
- Registered `help` as an explicit subcommand so it appears under top-level `SUBCOMMANDS` and remains discoverable.
- Removed `--stub-contract`; now returns exit 64 with migration guidance to `lambdadeck contract stub`.
- Added explicit unknown-help-topic handling (`lambdadeck help <unknown>`) with available topics and exit 64.
- Updated docs and tests for the new command layout; deterministic contract JSON behavior preserved via `lambdadeck contract stub`.
