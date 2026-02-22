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
    parser = argparse.ArgumentParser(description="Poll /readyz until LambdaDeck runtime warmup completes")
    parser.add_argument("--base", default="http://127.0.0.1:8080", help="Server base URL")
    parser.add_argument("--model", default="", help="Model id (defaults to first /v1/models entry)")
    parser.add_argument("--timeout", type=float, default=180, help="Total probe timeout seconds")
    parser.add_argument("--interval", type=float, default=1.0, help="Seconds to sleep between attempts")
    args = parser.parse_args()

    base = args.base.rstrip("/")
    model = args.model
    if not model:
        model = _get_model_id(base, timeout_s=5)

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

        t0 = time.time()
        status = 0
        body = ""
        try:
            with urllib.request.urlopen(base + "/readyz", timeout=30) as r:
                body = r.read().decode("utf-8")
                status = r.status
        except urllib.error.HTTPError as e:
            status = e.code
            body = e.read().decode("utf-8", "ignore")

        dt_ms = int((time.time() - t0) * 1000)
        payload = {}
        if body:
            try:
                payload = json.loads(body)
            except json.JSONDecodeError:
                payload = {}

        readiness_status = payload.get("status")

        if status == 200 and readiness_status == "ready":
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

        if status == 503 and readiness_status == "warming_up":
            time.sleep(args.interval)
            continue

        if status == 503 and readiness_status == "failed":
            print(
                json.dumps(
                    {
                        "base": base,
                        "model": model,
                        "ready": False,
                        "attempt": attempt,
                        "status": status,
                        "readiness_status": readiness_status,
                        "error": payload.get("error", "runtime warmup failed"),
                        "attempt_ms": dt_ms,
                        "elapsed_ms": int((time.time() - started) * 1000),
                    }
                )
            )
            return 1

        if status != 503:
            print(
                json.dumps(
                    {
                        "base": base,
                        "model": model,
                        "ready": False,
                        "attempt": attempt,
                        "status": status,
                        "readiness_status": readiness_status,
                        "attempt_ms": dt_ms,
                        "elapsed_ms": int((time.time() - started) * 1000),
                    }
                )
            )
            return 1


if __name__ == "__main__":
    raise SystemExit(main())
