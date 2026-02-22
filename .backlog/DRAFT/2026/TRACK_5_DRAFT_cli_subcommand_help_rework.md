# TRACK 5 [DRAFT]: cli_subcommand_help_rework

Problems (PORE)
- P1: As a developer using the LambdaDeck CLI, I cannot quickly discover command-specific help because top-level help does not clearly teach `lambdadeck <command> --help` and the current shape blends flags and commands.
- P2: As a developer, I can misread `--stub-contract` as a server flag rather than a standalone utility mode, because its behavior is command-like but its surface is option-like.
- P3: As a maintainer, evolving the CLI is harder because ad-hoc parsing/help text can drift from expected command semantics, making UX consistency difficult to preserve.
- Reference: `.backlog/PORE.md`.

Objective
- Make LambdaDeck CLI command discovery and help behavior Apple-idiomatic by moving to explicit subcommands (`serve`, `contract stub`, `help`) while keeping compatibility for existing `--stub-contract` users.

Acceptance criteria
- [P1] `lambdadeck --help` clearly documents subcommand usage and teaches command help discovery (for example `lambdadeck help serve` and `lambdadeck serve --help`).
- [P1] `lambdadeck help`, `lambdadeck help serve`, and `lambdadeck serve --help` all return clear, non-ambiguous help text.
- [P2] `lambdadeck contract stub` is available and documented as the canonical one-shot contract output command.
- [P2] Existing `lambdadeck --stub-contract` remains supported as a compatibility alias (with optional deprecation wording) and preserves deterministic output behavior.
- [P3] CLI tests cover the new subcommand tree and compatibility paths; `swift test` remains green.
- [P3] Documentation (`README.md` and `docs/DEVELOPMENT.md`) reflects the new command layout and examples.

Why now / impact
- Clarifying CLI semantics reduces first-run friction, lowers support burden, and prevents user confusion between long-running server commands and one-shot utility commands.

Scope
- In scope:
  - Redesign command surface to explicit subcommands: `serve`, `contract stub`, and `help`.
  - Keep `--stub-contract` as backward-compatible alias for at least one release cycle.
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
- Backward compatibility must not silently break existing scripts using `--stub-contract`.

Milestones
- [ ] Milestone 1: Finalize command tree and compatibility policy.
- [ ] Milestone 2: Implement parser/help restructuring for new subcommands.
- [ ] Milestone 3: Add/adjust CLI tests for help discovery and alias compatibility.
- [ ] Milestone 4: Update docs and examples to match new command UX.
- [ ] Milestone 5: Validate end-to-end behavior and complete Track.

Risks / decisions
- Risk: help text churn can break tests that assert literal strings.
- Risk: introducing nested subcommands in custom parser may increase maintenance complexity.
- Decision: canonical path is `lambdadeck contract stub`; `--stub-contract` remains compatibility alias.
- Decision (proposed): prefer explicit command-oriented UX over mode flags for one-shot utilities.

Plan (execution steps)
- [ ] Move Track 5 to ACTIVE (folder + filename + title status).
- [ ] Define and document exact command/help UX matrix (top-level, `help`, `serve --help`, `contract --help`, `contract stub --help`).
- [ ] Implement parser changes for `contract stub` and `help` while retaining `--stub-contract` alias.
- [ ] Update CLI output/help text and error messaging for unknown/ambiguous invocations.
- [ ] Add/update unit tests in `Tests/LambdaDeckCLITests/LambdaDeckCLITests.swift` for new and compatibility paths.
- [ ] Update `README.md` and `docs/DEVELOPMENT.md` command examples.
- [ ] Run `swift test`, update Track inventory/artifacts, and move Track 5 to COMPLETED.

Inventory
- **Current inventory**
  - CLI command parsing/help surface: `Sources/LambdaDeckCLI/CLI.swift`.
  - CLI execution entrypoint: `Sources/LambdaDeckCLI/LambdaDeckMain.swift`.
  - Existing CLI tests: `Tests/LambdaDeckCLITests/LambdaDeckCLITests.swift`.
  - User-facing command docs: `README.md`, `docs/DEVELOPMENT.md`.

Artifacts
- Proposed canonical UX (current draft):
  - `lambdadeck serve [options]`
  - `lambdadeck contract stub`
  - `lambdadeck help [subcommand]`
- Compatibility note:
  - Keep `lambdadeck --stub-contract` functional as alias during transition.
- Validation checklist (to fill when ACTIVE/COMPLETED):
  - Help text snapshots/expected strings updated.
  - CLI parser coverage for canonical + compatibility invocations.
  - `swift test` result summary.

Completion notes (fill when COMPLETED/DEPRECATED)
- Pending.
