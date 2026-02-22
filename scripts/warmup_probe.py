#!/usr/bin/env python3

import argparse
import json
import time
import urllib.error
import urllib.request


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


def main() -> int:
    parser = argparse.ArgumentParser(description="Poll chat until LambdaDeck runtime warmup completes")
    parser.add_argument("--base", default="http://127.0.0.1:8080", help="Server base URL")
    parser.add_argument("--model", default="", help="Model id (defaults to first /v1/models entry)")
    parser.add_argument("--timeout", type=float, default=180, help="Total probe timeout seconds")
    parser.add_argument("--interval", type=float, default=1.0, help="Seconds to sleep between attempts")
    args = parser.parse_args()

    base = args.base.rstrip("/")
    model = args.model
    if not model:
        model = _get_model_id(base, timeout_s=5)

    payload = {
        "model": model,
        "messages": [{"role": "user", "content": "ping"}],
        "max_tokens": 1,
        "stream": False,
    }

    started = time.time()
    attempt = 0
    while True:
        attempt += 1
        elapsed = time.time() - started
        if elapsed >= args.timeout:
            print(
                json.dumps(
                    {
                        "base": base,
                        "model": model,
                        "ready": False,
                        "attempts": attempt,
                        "elapsed_ms": int(elapsed * 1000),
                    }
                )
            )
            return 2

        req = urllib.request.Request(
            base + "/v1/chat/completions",
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"},
        )
        t0 = time.time()
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                _ = r.read()
                status = r.status
        except urllib.error.HTTPError as e:
            status = e.code

        dt_ms = int((time.time() - t0) * 1000)
        if status == 200:
            print(
                json.dumps(
                    {
                        "base": base,
                        "model": model,
                        "ready": True,
                        "attempt": attempt,
                        "attempt_ms": dt_ms,
                        "elapsed_ms": int((time.time() - started) * 1000),
                    }
                )
            )
            return 0

        if status != 503:
            print(
                json.dumps(
                    {
                        "base": base,
                        "model": model,
                        "ready": False,
                        "attempt": attempt,
                        "status": status,
                        "attempt_ms": dt_ms,
                        "elapsed_ms": int((time.time() - started) * 1000),
                    }
                )
            )
            return 1

        time.sleep(args.interval)


if __name__ == "__main__":
    raise SystemExit(main())
