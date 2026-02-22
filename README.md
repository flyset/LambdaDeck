# LambdaDeck

LambdaDeck is a local, on-device LLM runtime/server effort. The near-term goal is a Swift-native, OpenAI-compatible HTTP API that can run against local Core ML model bundles.

Status:
- Build + test pipeline (SwiftPM + CI) is in place.
- OpenAI-compatible `/v1/models` and `/v1/chat/completions` (non-stream + SSE) are implemented.
- Swift Core ML runtime integration is available for local model bundles via `--model-path`.
- Real inference TTFT is improved for Gemma3 chunked bundles via hybrid batched prefill; server may return `503` while the runtime is warming up (clients should retry).

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
swift run lambdadeck --version
swift test
```

### Model-less contract hook (CI-safe)

```bash
swift run lambdadeck --stub-contract
```

This prints deterministic, OpenAI-shaped `chat.completion` JSON intended for contract/integration testing without any model assets.

## Models

Put local model bundles under `Models/` (repo-relative). Model artifacts are intentionally excluded from git and are not assumed to exist in CI.

## Tracks

- Track 2 (build system pipeline): completed.
- Track 1 (OpenAI-compatible server contract): completed.
- Track 3 (Swift Core ML inference runtime): completed.
- Track 4 (Swift Core ML TTFT optimization): completed.

## License

Apache License 2.0. See `LICENSE`.
