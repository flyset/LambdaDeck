# LambdaDeck Bundle Metadata (v1)

LambdaDeck can discover and serve Core ML LLM bundles that include a LambdaDeck-owned metadata file:

- File name: `lambdadeck.bundle.json`
- Schema version: `schema_version: 1`

This spec is used for model discovery, adapter selection, and operator-facing validation.

## Required fields

```json
{
  "schema_version": 1,
  "model": {
    "id": "my-model-id"
  },
  "tokenizer": {
    "directory": "."
  },
  "adapter": {
    "kind": "coreml.monolithic"
  },
  "runtime": {
    "monolithic_model": "model.mlmodelc",
    "context_length": 2048
  }
}
```

## Field reference

- `schema_version` (`Int`, required)
  - Must be `1`.
- `model.id` (`String`, required)
  - OpenAI model id returned by `GET /v1/models`.
- `tokenizer.directory` (`String`, required)
  - Relative or absolute path to tokenizer assets.
  - Must contain both `tokenizer.json` and `tokenizer_config.json`.
- `adapter.kind` (`String`, required)
  - Supported values (v1): `coreml.monolithic`.
- `runtime.monolithic_model` (`String`, required for `coreml.monolithic`)
  - Relative or absolute path to the compiled Core ML model (`.mlmodelc`).
- `runtime.context_length` (`Int`, optional)
  - Defaults to `2048`.
- `runtime.sliding_window` (`Int`, optional)
- `runtime.batch_size` (`Int`, optional)
- `runtime.architecture` (`String`, optional)
- `prompt.format` (`String`, optional)
  - Supported values: `chat_transcript`, `gemma3_turns`.
  - Defaults to `chat_transcript` when omitted.

## Validation behavior

LambdaDeck returns explicit errors for common operator issues, including:

- missing metadata file,
- invalid JSON,
- unsupported `schema_version`,
- empty `model.id`,
- unsupported `adapter.kind`,
- missing tokenizer assets,
- missing referenced model path,
- unsupported `prompt.format`.

## Adapter selection precedence

When a model directory includes `lambdadeck.bundle.json`, LambdaDeck selects the metadata adapter path.
Otherwise, LambdaDeck falls back to the existing ANEMLL/runtime-inspector path.

## Minimal bundle layout example

```text
Models/
  my-metadata-model/
    lambdadeck.bundle.json
    tokenizer.json
    tokenizer_config.json
    model.mlmodelc/
```
