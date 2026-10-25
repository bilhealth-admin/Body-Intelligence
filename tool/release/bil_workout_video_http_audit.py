#!/usr/bin/env python3
"""Read-only BIL premium workout media HTTP contract audit.

Only probes the one release-pinned Cloudflare URL. Reads at most 1024 response
body bytes per GET and never prints the optional Supabase user bearer token.
No object writes, cache invalidation or deployment operations are performed.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import socket
import sys
import urllib.error
import urllib.request
from pathlib import Path

URL = (
    "https://workouts.bilhealth.com/v2/objects/workouts/v1/gym-six-month/"
    "movements/resistance-upper-body-dumbbell-biceps-curl-technique.mp4"
)
ORIGIN = "https://www.bilhealth.com"
RANGE = "bytes=0-1023"
HEADER_NAMES = (
    "content-type", "content-length", "content-range", "accept-ranges",
    "cache-control", "etag", "age", "cf-cache-status", "cache-status",
    "vary", "server", "location", "access-control-allow-origin",
    "access-control-allow-headers", "access-control-allow-methods",
    "access-control-expose-headers", "www-authenticate",
)


class RefuseRedirects(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, newurl):
        return None


def probe(name: str, method: str, headers: dict[str, str], token: str = "") -> dict:
    request_headers = {
        "Accept-Encoding": "identity",
        "User-Agent": "BIL-Workout-HTTP-Audit/2026-10-25",
        **headers,
    }
    if token:
        request_headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request(URL, method=method, headers=request_headers)
    opener = urllib.request.build_opener(RefuseRedirects)
    try:
        try:
            response = opener.open(req, timeout=15)
        except urllib.error.HTTPError as error:
            # Preserve status and server headers on 4xx and 5xx; HTTPError is
            # also a readable response. Never follow redirects with credentials.
            response = error
        with response:
            result = {
                "name": name,
                "method": method,
                "status": response.status if hasattr(response, "status") else response.code,
                "headers": {
                    key: response.headers.get(key)
                    for key in HEADER_NAMES
                    if response.headers.get(key) is not None
                },
            }
            sample = response.read(1024) if method == "GET" else b""
            result["sample_size"] = len(sample)
            result["html_sample"] = (
                b"<!doctype html" in sample[:256].lower()
                or b"<html" in sample[:256].lower()
                or b"this video requires an eligible account" in sample.lower()
            )
            return result
    except (OSError, TimeoutError, socket.timeout, urllib.error.URLError) as error:
        return {"name": name, "method": method, "error": type(error).__name__,
                "error_detail": str(error)[:250]}


def validate(results: list[dict], authorized: bool) -> list[str]:
    by_name = {r["name"]: r for r in results}
    issues: list[str] = []

    def status(name: str, code: int) -> dict | None:
        r = by_name[name]
        if "error" in r:
            issues.append(f"{name}: transport error ({r['error']})")
            return None
        if r["status"] != code:
            issues.append(f"{name}: expected HTTP {code}, got {r['status']}")
        if r.get("html_sample"):
            issues.append(f"{name}: HTML body under .mp4 URL")
        return r

    for name in ("anonymous_head", "anonymous_range", "browser_like_range"):
        r = status(name, 401)
        if r:
            content_type = r["headers"].get("content-type", "").split(";", 1)[0].lower()
            if content_type != "application/json":
                issues.append(f"{name}: expected application/json error, got {content_type or 'missing type'}")
            if "no-store" not in r["headers"].get("cache-control", "").lower():
                issues.append(f"{name}: protected denial must not be cached")

    allowed = status("cors_allowed", 204)
    if allowed:
        h = allowed["headers"]
        if h.get("access-control-allow-origin") != ORIGIN:
            issues.append("cors_allowed: exact approved Origin not returned")
        for value in ("authorization", "range"):
            if value not in h.get("access-control-allow-headers", "").lower():
                issues.append(f"cors_allowed: missing {value} in allowed headers")
    status("cors_disallowed", 403)

    if authorized:
        head = status("premium_head", 200)
        partial = status("premium_range", 206)
        for name, r in (("premium_head", head), ("premium_range", partial)):
            if r is None:
                continue
            h = r["headers"]
            if h.get("content-type", "").split(";", 1)[0].lower() != "video/mp4":
                issues.append(f"{name}: missing video/mp4")
            if h.get("accept-ranges", "").lower() != "bytes":
                issues.append(f"{name}: Accept-Ranges bytes missing")
            if not h.get("etag"):
                issues.append(f"{name}: ETag missing")
            if "private" not in h.get("cache-control", "").lower():
                issues.append(f"{name}: no private cache policy")
            if "authorization" not in h.get("vary", "").lower():
                issues.append(f"{name}: Vary Authorization missing")
            if h.get("access-control-allow-origin") != ORIGIN:
                issues.append(f"{name}: approved origin not echoed")
        if head:
            size = head["headers"].get("content-length", "")
            if not size.isdecimal() or int(size) < 1024:
                issues.append("premium_head: missing/invalid full Content-Length")
        if partial:
            h = partial["headers"]
            total = head["headers"].get("content-length") if head else None
            expected = f"bytes 0-1023/{total}" if total else None
            if not re.fullmatch(r"bytes 0-1023/\d+", h.get("content-range", "")):
                issues.append("premium_range: invalid Content-Range")
            elif expected and h.get("content-range") != expected:
                issues.append("premium_range: total differs from HEAD")
            if h.get("content-length") != "1024":
                issues.append("premium_range: Content-Length must be 1024")
            if partial.get("sample_size") != 1024:
                issues.append("premium_range: response sample was not 1024 bytes")
    return issues


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="Optional JSON evidence path (no credentials)")
    args = parser.parse_args()
    token = os.getenv("BIL_AUDIT_WORKOUT_BEARER", "").strip()
    checks = [
        ("anonymous_head", "HEAD", {}, ""),
        ("anonymous_range", "GET", {"Range": RANGE, "Accept": "*/*"}, ""),
        ("browser_like_range", "GET", {"Range": RANGE, "Accept": "text/html", "User-Agent": "Mozilla/5.0"}, ""),
        ("cors_allowed", "OPTIONS", {"Origin": ORIGIN, "Access-Control-Request-Method": "GET", "Access-Control-Request-Headers": "authorization, range"}, ""),
        ("cors_disallowed", "OPTIONS", {"Origin": "https://unauthorized.example", "Access-Control-Request-Method": "GET", "Access-Control-Request-Headers": "authorization, range"}, ""),
    ]
    if token:
        checks.extend([
            ("premium_head", "HEAD", {"Origin": ORIGIN}, token),
            ("premium_range", "GET", {"Origin": ORIGIN, "Range": RANGE, "Accept": "video/mp4"}, token),
        ])
    results = [probe(*check) for check in checks]
    issues = validate(results, bool(token))
    report = {
        "utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "target": URL,
        "authorized_checks_performed": bool(token),
        "data_transfer_note": "At most 1024 bytes per GET; no redirects, no writes or uploads",
        "checks": results,
        "issues": issues,
        "result": "PASS" if not issues else "INCOMPLETE" if all("transport error" in issue for issue in issues) else "FAIL",
    }
    rendered = json.dumps(report, indent=2, ensure_ascii=False)
    print(rendered)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered + "\n", encoding="utf-8")
    return 0 if not issues else 2 if report["result"] == "INCOMPLETE" else 1


if __name__ == "__main__":
    sys.exit(main())
