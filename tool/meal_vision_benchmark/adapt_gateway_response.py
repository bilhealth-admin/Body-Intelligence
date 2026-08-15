"""Convert saved BIL meal-image gateway responses to benchmark predictions.

Input is a JSON object keyed by case id. Each value must be the exact local
schema_version=1 gateway body plus optional `_latency_ms` and `_cost_usd`.
Provider token telemetry is copied from the normalized ``usage`` object so the
saved benchmark remains auditable per request.
No network call is made. The production response has names but no portion
amount, so amount_g remains null and amount error is truthfully unscored.
"""
import argparse
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--provider", required=True)
    parser.add_argument("--model-revision", required=True)
    args = parser.parse_args()
    saved = json.loads(Path(args.input).read_text(encoding="utf-8"))
    runs = []
    for case_id, response in saved.items():
        if response.get("schema_version") != 1 or not isinstance(response.get("candidates"), list):
            raise SystemExit(f"Invalid gateway response for {case_id}")
        usage = response.get("usage")
        if not isinstance(usage, dict):
            usage = {}
        runs.append({
            "case_id": case_id,
            "latency_ms": response.get("_latency_ms"),
            "cost_usd": response.get("_cost_usd", 0.0),
            "input_tokens": usage.get("input_tokens"),
            "output_tokens": usage.get("output_tokens"),
            "components": [{
                "name": candidate["name"],
                "amount_g": None,
                "confidence": candidate.get("confidence"),
            } for candidate in response["candidates"]],
        })
    output = {"schema_version": 1, "provider": args.provider,
              "model_revision": args.model_revision, "runs": runs}
    Path(args.output).write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
