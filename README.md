# LambdaDeck

LambdaDeck is a local, on-device LLM runtime/server effort. The near-term goal is a Swift-native, OpenAI-compatible (subset) chat HTTP API that can run against local Core ML model bundles.

Status:
- Build + test pipeline (SwiftPM + CI) is in place.
- OpenAI-compatible `/v1/models` and `/v1/chat/completions` (non-stream + SSE) are implemented.
- Operator readiness endpoint `/readyz` is implemented (`200` ready, `503` warming/failed).
- Swift Core ML runtime integration is available for local model bundles via `--model-path`.
- Real inference TTFT is improved for Gemma3 chunked bundles via hybrid batched prefill; server may return `503` while the runtime is warming up (clients should retry).

Safety:
- LambdaDeck is intended for trusted local use. There is no auth layer; do not expose the server to untrusted networks.

## Repo layout

- `Package.swift`: Swift Package Manager definition.
- `Sources/LambdaDeckCore/`: shared core code (including a model-less contract generator).
- `Sources/LambdaDeckCLI/`: the `lambdadeck` executable CLI.
- `Tests/`: unit + integration tests (model-less).
- `docs/DEVELOPMENT.md`: canonical local build/run/test and minimal release steps.
- `Models/`: local model bundles (ignored by git; not required for build/test/CI).

## Build / Run / Test (golden path)

```bash
swift build
swift run lambdadeck --help
swift run lambdadeck help serve
swift run lambdadeck --version
swift test
```

### Model-less contract hook (CI-safe)

```bash
swift run lambdadeck contract stub
```

This prints deterministic, OpenAI-shaped `chat.completion` JSON intended for contract/integration testing without any model assets.

## Models

Put local model bundles under `Models/` (repo-relative). Model artifacts are intentionally excluded from git and are not assumed to exist in CI.

## API surface

Implemented (v1 subset):

- `GET /v1/models`
- `GET /readyz`
- `POST /v1/chat/completions` (non-streaming and SSE streaming via `stream=true`)

Readiness semantics:

- `GET /readyz` returns `200` with `{"status":"ready",...}` when runtime is ready.
- `GET /readyz` returns `503` with `{"status":"warming_up",...}` while runtime warmup is in progress.
- `GET /readyz` returns `503` with `{"status":"failed",...,"error":"..."}` if runtime warmup failed.

Not implemented (v1): auth, tool/function calling, and the rest of the OpenAI API surface.

Model support note: real inference is currently validated primarily for Gemma-family bundles (Gemma3 chunked is the most optimized/validated path).

## Tracks

- Track 1 (OpenAI-compatible server contract): completed.
- Track 2 (build system pipeline): completed.
- Track 3 (Swift Core ML inference runtime): completed.
- Track 4 (Swift Core ML TTFT optimization): completed.
- Track 5 (CLI subcommand/help rework): completed.
- Track 6 (operator runtime readiness visibility): completed.

## License

Apache License 2.0. See `LICENSE`.
