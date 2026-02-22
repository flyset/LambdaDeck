# PERFORMANCE

This document covers LambdaDeck performance characteristics and measurement, with emphasis on TTFT (time-to-first-token).

## Definitions

- TTFT: request start -> first streamed `delta.content` (for `stream=true`).
- Prefill: the phase where the model processes the entire prompt and populates its attention cache (KV cache).
- Decode: the phase where the model generates new tokens one at a time.

In the Swift Core ML runtime, the prompt cache state lives inside Core ML `MLState` and is updated as the runtime steps through tokens.

## Why TTFT is often the bottleneck

TTFT is dominated by prefill. If the system prompt is large and mostly static (for example: OpenCode agent instructions, tool schemas, repo docs pasted into the system role), every request pays that prefill cost again.

If decode throughput is fine once generation starts but TTFT is high, focus on:

- prompt size (especially static system text)
- prefill call count (token-by-token vs batched)
- per-step allocations (masks/tensors/feature providers)

## What Track 4 implemented

For Gemma3 chunked bundles (FFN chunks with `prefill` / `prefill_rotate` functions):

- Hybrid batched prefill:
  - process full 64-token blocks using the dedicated `prefill*` functions
  - process the remainder (tail) token-by-token to avoid padded-token artifacts
- Token-step input reuse:
  - reuse the token-step MLMultiArrays and update the causal mask incrementally for infer steps
- Server warmup behavior:
  - runtime initialization happens in the background
  - chat requests can return `503` with an OpenAI-shaped error while the runtime is warming up

See: `.backlog/COMPLETED/2026/TRACK_4_COMPLETED_swift_coreml_ttft_optimization.md`.

## Practical guidance for OpenCode-style prompts

If you are seeing very high TTFT with OpenCode:

- Reduce what is injected into the system message. Large blocks like `AGENTS.md` content can dominate TTFT.
- Prefer short, stable system prompts that reference local docs instead of embedding them.

## Measurement recipe (local)

Run the server with a real model and measure streaming TTFT.

Example:

```bash
swift run lambdadeck serve --model-path "Models/<bundle-dir-or-mlmodelc>" --port 8080
```

Then measure TTFT with a large system prompt vs a stripped one. The repo includes tracked prompt fixtures under `prompts/` and stdlib-only scripts under `scripts/`.

```bash
python3 scripts/compare_ttft.py \
  --base http://127.0.0.1:8080 \
  --system-a prompts/system/opencode_like_full.txt \
  --system-b prompts/system/opencode_like_stripped.txt \
  --user prompts/user/latency_8_lines.txt \
  --max-tokens 256
```

Observed example (machine-dependent, using the tracked fixtures under `prompts/`):

- Full system prompt (`prompts/system/opencode_like_full.txt`, ~4.0k chars): TTFT ~76s
- Stripped system prompt (`prompts/system/opencode_like_stripped.txt`, ~0.4k chars): TTFT ~1.8s

These numbers depend on OS, model bundle, and whether the runtime is already warm.
