from __future__ import annotations

import argparse
import json
import sqlite3
from pathlib import Path

from tool.nutrition_platform.quality_engine import (
    NutritionQualityEngine,
    QualityInput,
    install_quality_schema,
    persist_assessment,
)


def main() -> int:
    parser = argparse.ArgumentParser(description="Run BIL quality assessment for canonical source records.")
    parser.add_argument("--database", type=Path, required=True)
    parser.add_argument("--input-jsonl", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()

    install_quality_schema(args.database)
    engine = NutritionQualityEngine()
    counts = {"accepted": 0, "quarantined": 0, "rejected": 0}
    processed = 0

    with args.input_jsonl.open("r", encoding="utf-8") as stream:
        for line_number, raw_line in enumerate(stream, start=1):
            if not raw_line.strip():
                continue
            payload = json.loads(raw_line)
            assessment = engine.assess(QualityInput(**payload))
            persist_assessment(args.database, assessment)
            counts[assessment.validation_status] += 1
            processed += 1

    with sqlite3.connect(args.database) as conn:
        integrity = conn.execute("PRAGMA integrity_check").fetchone()[0]
        foreign_key_violations = conn.execute("PRAGMA foreign_key_check").fetchall()

    report = {
        "processed": processed,
        "counts": counts,
        "integrity_check": integrity,
        "foreign_key_violations": len(foreign_key_violations),
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2, sort_keys=True), encoding="utf-8")
    print(json.dumps(report, sort_keys=True))
    return 0 if integrity == "ok" and not foreign_key_violations else 1


if __name__ == "__main__":
    raise SystemExit(main())
