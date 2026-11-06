#!/usr/bin/env python3
"""Separate explicit logcat ANR records from not-responding UI dialog text."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import sys
from xml.etree import ElementTree


# Threadtime uses 'E ActivityManager:', while brief uses
# 'E/ActivityManager(123):' (including space-padded PIDs).
# Generic phrases in another message (for example an lmkd kill reason) are not
# ActivityManager ANR records. Explicit ANR records block for every package.
LOGCAT_ANR_RECORD = re.compile(
    r"^.*?\b[VDIWEF](?:\s+|/)[^:\r\n]+:\s*"
    r"(?:ANR in\s+[\w.]+\b|Application Not Responding\b)",
    re.IGNORECASE,
)
UI_ANR_TEXT = re.compile(
    r"Application Not Responding|isn['’]t responding|is not responding|لا يستجيب",
    re.IGNORECASE,
)


def classify_anr(logcat: str, ui_xml: str) -> dict[str, object]:
    root = ElementTree.fromstring(ui_xml)  # Missing/corrupt UI evidence is fatal.
    records = [
        {"line": number, "record": line[:2048]}
        for number, line in enumerate(logcat.splitlines(), 1)
        if LOGCAT_ANR_RECORD.search(line)
    ]
    dialogs = [
        value[:512]
        for node in root.iter("node")
        for attribute in ("text", "content-desc")
        if (value := node.get(attribute, "")) and UI_ANR_TEXT.search(value)
    ]
    return {
        "status": "ANR_DETECTED" if records or dialogs else "NO_ANR_EVIDENCE",
        "logcat_anr_records": records,
        "ui_anr_text": dialogs,
        "app_startup_proven": False,  # Frame/focus/crash checks remain separate.
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--logcat", required=True, type=Path)
    parser.add_argument("--ui", required=True, type=Path)
    parser.add_argument("--evidence", required=True, type=Path)
    args = parser.parse_args()
    try:
        result = classify_anr(
            args.logcat.read_text(encoding="utf-8", errors="replace"),
            args.ui.read_text(encoding="utf-8"),
        )
    except (OSError, UnicodeError, ElementTree.ParseError) as error:
        print(f"Invalid startup ANR evidence: {error}", file=sys.stderr)
        return 2
    args.evidence.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(result["status"])
    return 1 if result["status"] == "ANR_DETECTED" else 0


if __name__ == "__main__":
    raise SystemExit(main())
