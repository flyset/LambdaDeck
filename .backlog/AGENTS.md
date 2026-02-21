# Backlog (./.backlog/) - Scoped AGENTS

Scope
- Track definitions and backlog governance.
- Root guidance lives in `AGENTS.md`.
- Canonical backlog rules live in `.backlog/README.md`.

Golden path
- Use the Track template in `.backlog/README.md` for every Track file.
- Keep all notes and inventories inside the Track file under `Inventory` or `Completion notes`.

Implementation gates
- Enforce `.backlog/README.md` "Implementation gates (non-negotiable)" whenever Track work begins:
  - ensure Track is ACTIVE + status synchronized (folder/filename/title/status line)
  - ensure the Track's plan step for moving to ACTIVE is checked before any implementation work
  - require Track updates (inventory + checks + tests run) as part of completion for each chunk

Do / Don't
- Do follow the Track placement and naming convention: `.backlog/<STATUS>/<YYYY>/TRACK_<n>_<STATUS>_<title>.md` (status in folder and filename must match).
- Do use the file's last modified year for `<YYYY>`; move the Track if the year changes.
- Do include a **Current inventory** section whenever drafting or updating a Track.
- Do keep status values limited to DRAFT/ACTIVE/BLOCKED/COMPLETED/DEPRECATED.
- Don't create non-Track files in `.backlog/` beyond `.backlog/README.md`, `.backlog/PORE.md`, and `.backlog/AGENTS.md`.
- Don't split notes into separate files; keep them inside the Track.
