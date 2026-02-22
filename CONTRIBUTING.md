# Contributing

Thanks for helping improve LambdaDeck.

## Development (golden path)

```bash
swift build
swift test
```

## Running the server

Stub mode (CI-safe):

```bash
swift run lambdadeck serve --stub --port 8080
```

Real inference (local-only, requires model assets):

```bash
swift run lambdadeck serve --model-path "Models/<bundle-dir-or-mlmodelc>" --port 8080
```

Model bundles under `Models/` are local-only artifacts and are ignored by git.

## Performance benchmarking

Tracked prompt fixtures live under `prompts/` and stdlib-only benchmark scripts live under `scripts/`.

Example (compare TTFT for large vs stripped system prompt):

```bash
python3 scripts/compare_ttft.py \
  --base http://127.0.0.1:8080 \
  --system-a prompts/system/opencode_like_full.txt \
  --system-b prompts/system/opencode_like_stripped.txt \
  --user prompts/user/latency_8_lines.txt \
  --max-tokens 256
```

## Project conventions

Directory naming:

- Keep SwiftPM conventions: `Sources/`, `Tests/`.
- Keep model root naming: `Models/`.
- Use lowercase for new support directories.

## Tracks and backlog workflow

For non-trivial work, use the Tracks backlog under `.backlog/`.

- Track rules: `.backlog/README.md`
- PORE reference: `.backlog/PORE.md`

Do not start implementation for a Track until it is moved to `ACTIVE`.
