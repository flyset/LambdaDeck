# DEVELOPMENT

This file is the canonical local golden path for LambdaDeck build/run/test.

## Prerequisites

- macOS on Apple Silicon.
- Swift toolchain available in `PATH`.

## Golden path (local)

```bash
swift build
swift run lambdadeck --help
swift run lambdadeck --version
swift test
```

## Run local server (stub mode)

```bash
swift run lambdadeck serve --stub --port 8080
```

Example checks:

```bash
curl http://127.0.0.1:8080/v1/models

curl -H "content-type: application/json" \
  -d '{"model":"stub-model","messages":[{"role":"user","content":"Say hello in one short sentence."}],"stream":false}' \
  http://127.0.0.1:8080/v1/chat/completions

curl -N -H "content-type: application/json" \
  -d '{"model":"stub-model","messages":[{"role":"user","content":"Stream a short greeting."}],"stream":true}' \
  http://127.0.0.1:8080/v1/chat/completions
```

## Run local server (real inference)

Use a local ANEMLL bundle path when model artifacts are available:

```bash
swift run lambdadeck serve --model-path "Models/<bundle-dir-or-mlmodelc>" --port 8080
```

Example checks:

```bash
curl http://127.0.0.1:8080/v1/models

curl -H "content-type: application/json" \
  -d '{"model":"<resolved-model-id>","messages":[{"role":"user","content":"Say hello in one short sentence."}],"max_tokens":16,"stream":false}' \
  http://127.0.0.1:8080/v1/chat/completions

curl -N -H "content-type: application/json" \
  -d '{"model":"<resolved-model-id>","messages":[{"role":"user","content":"Count to three."}],"max_tokens":16,"stream":true}' \
  http://127.0.0.1:8080/v1/chat/completions
```

## Model selection precedence

When not using `--stub`, model selection order is:

1. `--model-path`
2. `LAMBDADECK_MODEL_PATH`
3. Discovery under models root (`--models-root` > `LAMBDADECK_MODELS_ROOT` > `./Models`)

If discovery returns zero or multiple model bundles, pass `--model-path` explicitly.

## Model-less contract hook (for Track 1 stub mode)

The CLI includes a deterministic, model-free contract output:

```bash
swift run lambdadeck --stub-contract
```

This emits a stable OpenAI-shaped `chat.completion` JSON payload and is safe to run in CI.

## CI

- Workflow: `.github/workflows/ci.yml`
- Trigger: every push and pull request.
- Jobs: `swift build` + `swift test` on `macos-latest`.

Local-only real-inference integration checks are gated in tests and skipped unless:

```bash
LAMBDADECK_REAL_MODEL_PATH="Models/<bundle-dir-or-mlmodelc>" swift test
```

## Manual release artifact (minimum viable flow)

1) Build a release binary:

```bash
swift build -c release
```

2) Create a zipped artifact:

```bash
VERSION="$(swift run lambdadeck --version | cut -d' ' -f2)"
mkdir -p release
zip -j "release/lambdadeck-${VERSION}-macos-arm64.zip" ".build/release/lambdadeck"
```

3) Install locally from the zip:

```bash
VERSION="${VERSION:-$(swift run lambdadeck --version | cut -d' ' -f2)}"
unzip -j "release/lambdadeck-${VERSION}-macos-arm64.zip" -d "$HOME/.local/bin"
chmod +x "$HOME/.local/bin/lambdadeck"
```

4) Verify install:

```bash
"$HOME/.local/bin/lambdadeck" --version
```

## Model artifacts

Model bundles stay local under `Models/` and are ignored by git.
CI and build/test flows do not require model assets.
