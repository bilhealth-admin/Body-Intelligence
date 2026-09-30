#!/usr/bin/env python3
"""Fail on unexplained skipped tests in a Sapphire full shard."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

ALLOWED = {
    (
        "test/features/wellness/wellness_video_stream_live_test.dart",
        "live public BIL stream supports pinned native range delivery",
    ): (
        "Public-network test is intentionally opt-in in the all-test shard; "
        "the Final Release Certification live-backend job executes it with "
        "BIL_LIVE_WORKOUT_STREAM_CHECK=true."
    ),
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("results", type=Path)
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()

    data = json.loads(args.results.read_text(encoding="utf-8"))
    if data.get("exit_code") != 0:
        raise SystemExit("SHARD_RESULT_EXIT_CODE_NONZERO")

    suites = {str(k): v for k, v in (data.get("suites") or {}).items()}
    skipped = []
    unexpected = []
    for test in data.get("tests") or []:
        if test.get("hidden") or not test.get("skipped"):
            continue
        suite = suites.get(str(test.get("suiteID")), {})
        path = str(suite.get("path", "")).replace("\\", "/")
        if "/test/" in path:
            path = "test/" + path.split("/test/", 1)[1]
        item = {
            "path": path,
            "name": test.get("name"),
            "reason": None,
        }
        reason = ALLOWED.get((path, test.get("name")))
        if reason is None:
            unexpected.append(item)
        else:
            item["reason"] = reason
            skipped.append(item)

    args.evidence.parent.mkdir(parents=True, exist_ok=True)
    args.evidence.write_text(
        json.dumps(
            {
                "allowed_skips": skipped,
                "unexpected_skips": unexpected,
                "policy": "Every non-hidden skip must be explicitly explained.",
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    if unexpected:
        print(json.dumps({"unexpected_skips": unexpected}, indent=2))
        return 1
    print(json.dumps({"documented_skips": skipped}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
