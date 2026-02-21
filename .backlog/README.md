# Tracks Backlog (canonical)
Track = a large, outcome-driven line of AI work (strategy-level) that spawns plans/sprints for execution. This README is the single source of truth for how we define, name, and track Tracks.

## Status taxonomy
- DRAFT: stubbed; objective and outcome are being shaped.
- ACTIVE: scoped and in execution.
- BLOCKED: cannot progress until a decision/unblocker lands (note the blocker).
- COMPLETED: delivered; metrics/outcomes captured.
- DEPRECATED: intentionally stopped or superseded (record why).

## File placement and naming
- Path pattern: `.backlog/<STATUS>/<YYYY>/TRACK_<n>_<STATUS>_<title>.md`
- `<STATUS>` uses the taxonomy above (DRAFT/ACTIVE/BLOCKED/COMPLETED/DEPRECATED).
- `<YYYY>` is the file's last modified year (filesystem metadata). If a Track is updated in a new year, move it accordingly.
- `<title>` should be a short slug (e.g., `latency_reduction`), lowercase with underscores or hyphens.
- Title format: `TRACK <n> [<STATUS>]: <title>`

## Track template (use for every file)
```
# TRACK <n> [<STATUS>]: <title>

Problems (PORE)
- List the concrete problems this Track exists to solve.
- Use the format: "As a [role], I experience [problem], because [underlying reason or constraint]."
- No problem, no requirement: every objective/scope item must trace back to a problem.
- Prefix each problem with an id (`P1`, `P2`, ...). Example: `P1: As a ...`.
- Reference: `.backlog/PORE.md`.

Objective
- What we are trying to achieve in one sentence.

Acceptance criteria
- Observable checks (tests, validations, measurable outcomes) that prove the problems are resolved.
- Traceability: each criterion must reference at least one problem id, e.g. `[P1] ...` or `[P1,P2] ...`.

Why now / impact
- Why this matters for ANEMLL or stakeholders.

Scope
- In scope:
  - ...
- Out of scope:
  - ...

Non-negotiables
- Explicitly state that all development follows TDD/test-first for this Track (unit/component/integration as applicable).
- Tests should be committed in the same module/package as implementation unless repo conventions specify otherwise.

Milestones
- [ ] Milestone 1
- [ ] Milestone 2

Risks / decisions
- Risk: ...
- Decision: ...

Plan (execution steps)
- [ ] Step 1
- [ ] Step 2

Inventory
- Add a short **Current inventory** section in each Track to list concrete touch points (files/modules) and any normalization/validation behaviors under review so scope stays crisp.

Artifacts
- Design docs, prototypes, checkpoints, datasets, PRs to reference.

Completion notes (fill when COMPLETED/DEPRECATED)
- Outcomes, metrics, lessons learned.
```

## Workflow
1) Create every new Track in DRAFT and keep it in DRAFT while planning. Creating the file does not mean execution has started.
2) Start with Problems (PORE). Then co-develop objective, scope, milestones, risks, and acceptance criteria until they are crisp.
3) In `Plan (execution steps)`, do not add a step like "Create Track <n> draft" (that already happened when the Track file was created).
4) The first lifecycle plan step should be: `[ ] Move Track <n> to ACTIVE (folder + filename + title status).`
5) Move a Track to ACTIVE only when implementation starts AND the Track has at least one PORE problem statement.
6) Keep status synchronized on every transition in all three places:
   - folder: `.backlog/<STATUS>/<YYYY>/`
   - filename: `TRACK_<n>_<STATUS>_<title>.md`
   - title line: `TRACK <n> [<STATUS>]: <title>`
7) Keep implementation deltas in Plan/Milestones; keep Objective/Scope stable unless strategy changes.
8) On finish, move to COMPLETED (or DEPRECATED), capture outcomes/metrics in `Completion notes`, and close with: `[ ] Move Track <n> to COMPLETED and capture completion notes.`
9) Do not create extra files under `.backlog/` beyond `.backlog/README.md`, `.backlog/PORE.md`, `.backlog/AGENTS.md`, and Track files stored in status/year folders.

## Implementation gates (non-negotiable)
These rules exist to prevent plan drift.

- No code implementation starts until the Track is in ACTIVE and the first plan step (`Move Track <n> to ACTIVE...`) is checked.
- Each implementation session begins by reading the Track and stating the next unchecked plan step(s) being executed.
- After each meaningful implementation chunk (or PR), update the Track immediately:
  - check completed plan/checklist items
  - refresh **Current inventory** with touched files/modules
  - record tests/validations executed
- "Done" for any chunk requires both: (a) tests/validations run, (b) Track updated.
- If new work is discovered outside current scope/milestones, update the Track first (scope/milestone/plan), then proceed.
