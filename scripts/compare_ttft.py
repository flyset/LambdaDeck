#!/usr/bin/env python3

import argparse
import json

from bench_stream_ttft import _get_model_id, _read_text, stream_ttft


def main() -> int:
    parser = argparse.ArgumentParser(description="Compare streaming TTFT for two system prompts")
    parser.add_argument("--base", default="http://127.0.0.1:8080", help="Server base URL")
    parser.add_argument("--model", default="", help="Model id (defaults to first /v1/models entry)")
    parser.add_argument("--system-a", required=True, help="Path to system prompt A")
    parser.add_argument("--system-b", required=True, help="Path to system prompt B")
    parser.add_argument("--user", required=True, help="Path to user prompt")
    parser.add_argument("--max-tokens", type=int, default=256, help="max_tokens for completion")
    parser.add_argument("--timeout", type=float, default=900, help="Request timeout seconds")
    args = parser.parse_args()

    base = args.base.rstrip("/")
    model = args.model
    if not model:
        model = _get_model_id(base, timeout_s=5)

    user_prompt = _read_text(args.user).strip()
    system_a = _read_text(args.system_a)
    system_b = _read_text(args.system_b)

    res_a = stream_ttft(
        base=base,
        model=model,
        system_prompt=system_a,
        user_prompt=user_prompt,
        max_tokens=args.max_tokens,
        timeout_s=args.timeout,
    )
    res_b = stream_ttft(
        base=base,
        model=model,
        system_prompt=system_b,
        user_prompt=user_prompt,
        max_tokens=args.max_tokens,
        timeout_s=args.timeout,
    )

    out = {
        "base": base,
        "model": model,
        "user": {"path": args.user, "chars": len(user_prompt)},
        "a": {"path": args.system_a, "chars": len(system_a), "result": res_a},
        "b": {"path": args.system_b, "chars": len(system_b), "result": res_b},
    }
    print(json.dumps(out))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
