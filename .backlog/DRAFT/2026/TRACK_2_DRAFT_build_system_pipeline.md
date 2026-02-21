# TRACK 2 [DRAFT]: build_system_pipeline

Problems (PORE)
- P1: As a developer, I cannot implement Track 1, because LambdaDeck does not yet have a Swift build system/project scaffold (SwiftPM targets, entrypoints, and dependencies) to compile and run a server.
- P2: As a developer, I waste time and make mistakes, because there is no single, documented golden path (commands/scripts) to build, run, and test LambdaDeck locally.
- P3: As a maintainer, I cannot confidently merge changes, because there is no CI pipeline that proves LambdaDeck builds and tests pass on macOS.
- P4: As a contributor, I risk bloating the repo or breaking CI, because model artifacts are local-only and must not be required (or accidentally committed) for build/test.
- Reference: `.backlog/PORE.md`.

Objective
- Establish a reliable build + test + release pipeline for LambdaDeck (headless/manual CLI v1), enabling Track 1 implementation with clear local dev commands and macOS CI.

Acceptance criteria
- [P1] Repo builds via `swift build` and tests run via `swift test` with a documented golden path.
- [P1] A `lambdadeck` executable target exists and supports `--help` and `--version`.
- [P2] GitHub Actions CI runs on macOS and executes build + tests on every PR/push.
- [P2] CI includes at least one fast, model-less integration/contract test hook suitable for Track 1 (stub mode).
- [P3] A release artifact can be produced (at minimum: a zipped `lambdadeck` binary) with a documented manual install flow.
- [P4] Model artifacts are treated as local-only (ignored); docs and pipeline avoid assuming `anemll-*` is present in CI.

Why now / impact
- Track 1 (OpenAI-compatible server) needs a stable scaffold: build system, test harness, and CI gates so we can iterate without drift.

Scope
- In scope:
  - Swift Package Manager project structure (modules/targets) for LambdaDeck.
  - Local developer commands (documented; optionally a thin wrapper like Makefile/justfile).
  - GitHub Actions CI (macOS) for build + tests.
  - Versioning + release artifact plan (initially minimal).
  - Repo hygiene aligned with `.gitignore` (models out of repo).
- Out of scope:
  - Implementing the OpenAI endpoints (belongs to Track 1).
  - Packaging into Homebrew/codesigning/notarization (later milestone or Track).
  - Settings UI app (later Track).

Non-negotiables
- Test-first for pipeline-critical code (CLI parsing, config loading, basic wiring).
- CI must remain model-less.

Milestones
- [ ] Milestone 1: SwiftPM scaffold + `lambdadeck` CLI target.
- [ ] Milestone 2: CI on GitHub Actions (macOS) with build + tests.
- [ ] Milestone 3: Release artifact path documented (and optionally automated).
- [ ] Milestone 4: Developer docs: build/run/test golden path.

Risks / decisions
- Risk: Mixing SwiftPM + Xcode app targets later can complicate structure if not planned.
- Decision: v1 is headless/manual CLI; pipeline optimizes for CLI + server tests first.
- Decision: Keep CI model-less; use stub mode for integration/contract tests when Track 1 introduces them.

Plan (execution steps)
- [ ] Move Track 2 to ACTIVE (folder + filename + title status).
- [ ] Decide SwiftPM target/module layout and naming conventions.
- [ ] Create initial `Package.swift` + `lambdadeck` executable skeleton.
- [ ] Add minimal CLI parsing + `--help`/`--version` behaviors (with tests).
- [ ] Add GitHub Actions workflow for macOS build + tests.
- [ ] Document local dev commands in one canonical place.
- [ ] Define release artifact method (manual steps first; automation optional).
- [ ] Move Track 2 to COMPLETED and capture completion notes.

Inventory
- **Current inventory**
  - Governance: `.backlog/README.md`, `.backlog/PORE.md`, `.backlog/AGENTS.md`.
  - Track 1: `.backlog/DRAFT/2026/TRACK_1_DRAFT_coreml_openai_server.md`.
  - Repo hygiene: `.gitignore` ignores `Models/` (and legacy `anemll-*/`) plus common build caches.
  - Model artifacts: local-only bundles under `Models/<model>/`.

Artifacts
- CI runs, release notes, and build docs will be listed here.

Completion notes (fill when COMPLETED/DEPRECATED)
- Pending.
