#!/usr/bin/env python3
"""Read-only HEAD smoke for the 20 approved public workout preview groups.

This is a CDN diagnostic, not video downloading, credential use or playback
certification. One GET of 32 bytes is covered by the existing Flutter smoke.
"""
from __future__ import annotations

import concurrent.futures
import json
import os
import pathlib
import re
import sys
import urllib.error
import urllib.request

BASE = "https://workouts.bilhealth.com/v2/objects/"
CATALOG = pathlib.Path(
    "artifacts/workout_media/cloudflare_runtime_v2/free_preview_keys_v1.json"
)
PATH_PATTERN = re.compile(
    r"^workouts/v1/(?:home|gym-six-month)/movements/"
    r"[a-z0-9]+(?:-[a-z0-9]+)*\.mp4$"
)


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, newurl):
        return None


def check_preview(group: dict[str, object]) -> tuple[str, str]:
    group_id = str(group["groupId"])
    object_path = str(group["videoObjectKey"])
    size = group["videoSizeBytes"]
    if not PATH_PATTERN.fullmatch(object_path):
        return group_id, "invalid_catalog_object_path"
    if not isinstance(size, int) or size < 1024:
        return group_id, "invalid_catalog_size"
    request = urllib.request.Request(
        BASE + object_path,
        method="HEAD",
        headers={"User-Agent": "BIL-Isolated-CDN-ReadOnly-QA/1"},
    )
    try:
        with urllib.request.build_opener(NoRedirect).open(
            request, timeout=12
        ) as response:
            if response.status != 200:
                return group_id, f"status_{response.status}"
            headers = response.headers
            if headers.get("Content-Type", "").split(";", 1)[0] != "video/mp4":
                return group_id, "non_mp4_content_type"
            if headers.get("Content-Length") != str(size):
                return group_id, "incorrect_byte_length"
            if headers.get("Accept-Ranges", "").strip().lower() != "bytes":
                return group_id, "missing_byte_ranges"
            etag = headers.get("ETag", "").strip()
            if len(etag) < 3 or not etag.startswith('"') or not etag.endswith('"'):
                return group_id, "missing_strong_etag"
        return group_id, "PASS"
    except urllib.error.HTTPError as error:
        return group_id, f"http_{error.code}"
    except (urllib.error.URLError, TimeoutError, OSError):
        return group_id, "network_or_timeout"


def main() -> int:
    if os.getenv("BIL_ALLOW_PUBLIC_WORKOUT_HEAD") != "1":
        print("BIL_PUBLIC_WORKOUT_HEAD=NOT_RUN_EXPLICIT_OPT_IN_REQUIRED")
        return 0
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    groups = data["groups"]
    if data["groupCount"] != 20 or len(groups) != 20:
        raise ValueError("Expected exactly 20 approved preview groups")
    # Each public group has its own declared video. Do not synthesize a URL
    # from a user or from unreviewed remote input.
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        results = list(pool.map(check_preview, groups))
    failures = [(name, status) for name, status in results if status != "PASS"]
    print("BIL_PUBLIC_WORKOUT_HEAD_CHECK_COUNT=" + str(len(results)))
    print("BIL_PUBLIC_WORKOUT_HEAD_PASSED=" + str(len(results) - len(failures)))
    for name, status in failures:
        print(f"GROUP={name} RESULT={status}", file=sys.stderr)
    if failures:
        print("BIL_PUBLIC_WORKOUT_HEAD=FAIL", file=sys.stderr)
        return 1
    print("BIL_PUBLIC_WORKOUT_HEAD=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
