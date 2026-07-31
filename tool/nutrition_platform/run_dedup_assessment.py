from __future__ import annotations

import argparse
import json
from pathlib import Path

from tool.nutrition_platform.dedup_engine import DeduplicationPolicy, FoodFingerprint


def main() -> int:
    parser = argparse.ArgumentParser(description="Evaluate one BIL food duplicate pair")
    parser.add_argument("--left", required=True, type=Path)
    parser.add_argument("--right", required=True, type=Path)
    args = parser.parse_args()
    left = FoodFingerprint(**json.loads(args.left.read_text(encoding="utf-8")))
    right = FoodFingerprint(**json.loads(args.right.read_text(encoding="utf-8")))
    print(DeduplicationPolicy().evaluate(left, right).to_json())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
