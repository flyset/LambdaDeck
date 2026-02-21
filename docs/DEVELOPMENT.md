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
