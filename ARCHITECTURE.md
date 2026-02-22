# LambdaDeck Architecture

LambdaDeck is a Swift-native, OpenAI-compatible HTTP server for on-device Core ML LLMs. The current runtime supports ANEMLL-style bundles while the server surface remains OpenAI-compatible.

## Repository Shape

- `Sources/LambdaDeckCLI/`: CLI entry points and command wiring.
- `Sources/LambdaDeckCore/`: core library used by CLI and tests.
- `Tests/`: unit and integration coverage for contracts, bootstrap, and runtime behavior.
- `.backlog/`: track planning and execution governance.

## LambdaDeckCore Organization

`Sources/LambdaDeckCore/` is organized by responsibility:

- `OpenAI/`
  - OpenAI wire contracts and fixture helpers.
  - Files: `OpenAIContracts.swift`, `StubContract.swift`.
- `Server/`
  - HTTP routing and endpoint orchestration.
  - File: `LambdaDeckServer.swift`.
- `Discovery/`
  - Model path resolution from CLI flags, env, and default roots.
  - File: `ModelResolution.swift`.
- `Runtime/`
  - Runtime selection, model inspection, warmup/provider lifecycle, and Core ML execution.
  - Files: `InferenceRuntime.swift`, `CoreMLRuntime.swift`, `RuntimeBuilder.swift`.
- `Adapters/`
  - Adapter contracts, resolver, and per-family implementations.
  - Files: `Contracts/ModelAdapterTypes.swift`, `Resolver/ModelAdapterResolver.swift`, `ANEMLL/ANEMLLModelAdapter.swift`, `LambdaDeckMetadata/LambdaDeckMetadataModelAdapter.swift`.
- `Bundles/`
  - Metadata contracts, loader, schema decode, validation, and path resolution.
  - Files: `Contracts/BundleMetadataTypes.swift`, `Loader/BundleMetadataLoader.swift`, `Schema/RawBundleMetadataV1.swift`, `Validation/BundleMetadataValidator.swift`, `Errors/BundleMetadataError.swift`, `Internal/BundlePathResolver.swift`.
- `Tokenizers/`
  - Tokenizer implementations used by runtime code.
  - File: `GemmaBPETokenizer.swift`.
- `Version/`
  - Package version constants.
  - File: `LambdaDeckVersion.swift`.

This organization is intentionally mechanical: it improves ownership boundaries without changing endpoint or runtime behavior.

## Runtime Flow (Current)

1. CLI parses command options into `LambdaDeckServeOptions`.
2. `LambdaDeckModelResolver` selects a model source (`--model-path`, env path, discovered root, or stub).
3. `LambdaDeckServerBootstrap` resolves a model adapter (metadata-first, then ANEMLL fallback), sets effective model identity, and initializes `LambdaDeckRuntimeProvider` for background warmup in non-stub mode.
4. `LambdaDeckServer` exposes:
   - `GET /v1/models`
   - `GET /readyz`
   - `POST /v1/chat/completions` (non-streaming and streaming)
5. For inference requests, runtime is resolved directly or from provider state, then converted to OpenAI-shaped responses.

## Adapter + Metadata Path

- `lambdadeck.bundle.json` enables LambdaDeck-owned bundle discovery/validation.
- `LambdaDeckModelAdapterResolver` selects:
  - LambdaDeck metadata adapter when metadata file is present,
  - ANEMLL adapter path otherwise.
- Runtime creation is delegated through adapter implementations, preserving a stable OpenAI HTTP contract while allowing model-family-specific execution behavior.
