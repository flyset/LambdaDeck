#!/usr/bin/env python3

import argparse
import json
import time
import urllib.error
import urllib.request


def _read_text(path: str) -> str:
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def _get_model_id(base: str, timeout_s: float) -> str:
    with urllib.request.urlopen(base + "/v1/models", timeout=timeout_s) as r:
        payload = json.loads(r.read().decode("utf-8"))
    data = payload.get("data")
    if not isinstance(data, list) or not data:
        raise RuntimeError("/v1/models returned no models")
    model_id = data[0].get("id")
    if not isinstance(model_id, str) or not model_id:
        raise RuntimeError("/v1/models response is missing model id")
    return model_id


def stream_ttft(
    *,
    base: str,
    model: str,
    system_prompt: str,
    user_prompt: str,
    max_tokens: int,
    timeout_s: float,
) -> dict:
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        "max_tokens": max_tokens,
        "stream": True,
    }

    req = urllib.request.Request(
        base + "/v1/chat/completions",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )

    started = time.time()
    first_content_ms = None
    chunks = 0
    out_chars = 0

    try:
        with urllib.request.urlopen(req, timeout=timeout_s) as r:
            for raw in r:
                line = raw.decode("utf-8", "ignore").strip()
                if not line.startswith("data: "):
                    continue
                data = line[6:]
                if data == "[DONE]":
                    break
                obj = json.loads(data)
                delta = obj.get("choices", [{}])[0].get("delta", {})
                content = delta.get("content")
                if content:
                    chunks += 1
                    out_chars += len(content)
                    if first_content_ms is None:
                        first_content_ms = int((time.time() - started) * 1000)
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "ignore")
        return {
            "status": e.code,
            "error_body": body,
            "ttft_ms": None,
            "total_ms": int((time.time() - started) * 1000),
            "chunks": 0,
            "out_chars": 0,
        }

    return {
        "status": 200,
        "ttft_ms": first_content_ms,
        "total_ms": int((time.time() - started) * 1000),
        "chunks": chunks,
        "out_chars": out_chars,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Measure streaming TTFT against a LambdaDeck server")
    parser.add_argument("--base", default="http://127.0.0.1:8080", help="Server base URL")
    parser.add_argument("--model", default="", help="Model id (defaults to first /v1/models entry)")
    parser.add_argument("--system", required=True, help="Path to system prompt text file")
    parser.add_argument("--user", required=True, help="Path to user prompt text file")
    parser.add_argument("--max-tokens", type=int, default=256, help="max_tokens for completion")
    parser.add_argument("--timeout", type=float, default=900, help="Request timeout seconds")
    args = parser.parse_args()

    base = args.base.rstrip("/")
    model = args.model
    if not model:
        model = _get_model_id(base, timeout_s=5)

    system_prompt = _read_text(args.system)
    user_prompt = _read_text(args.user).strip()

    result = stream_ttft(
        base=base,
        model=model,
        system_prompt=system_prompt,
        user_prompt=user_prompt,
        max_tokens=args.max_tokens,
        timeout_s=args.timeout,
    )
    result.update(
        {
            "base": base,
            "model": model,
            "system_chars": len(system_prompt),
            "user_chars": len(user_prompt),
            "max_tokens": args.max_tokens,
        }
    )
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
