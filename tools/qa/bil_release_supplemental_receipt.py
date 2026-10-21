#!/usr/bin/env python3
"""Exact-source outcome for supplemental audits; no release certification."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import subprocess


REQUIRED_STEPS = (
    "toolchain", "resolve", "python_checks", "source_audits",
    "node_checks", "cloudflare", "pub_advisories", "maven_advisories", "source_guard",
    "native_attention_sql",
)
REQUIRED_LOGS = (
    "toolchain.txt", "resolve.log", "python-prebuild.log", "python-qa.log",
    "python-certification.log", "epic11.log", "epic12.log", "epic13.log",
    "epic14.log", "epic16.log", "repository-audit.log", "repository_inventory.json",
    "node-source-tests.log", "cloudflare-install.log", "cloudflare-check.log",
    "cloudflare-tests.log", "cloudflare-npm-audit.json", "pub-deps.json",
    "pub-osv.json", "deno-npm-osv.json", "android-release-dependencies.txt",
    "android-maven-osv.json", "source-guard.log",
    "community-attention-native-postgres.log",
)
OSV_REPORTS = ("pub-osv.json", "deno-npm-osv.json", "android-maven-osv.json")


def final_receipt(*, source_sha: str, current_sha: str, prior_status: str,
                  outcomes: dict[str, object], available: set[str],
                  reports: dict[str, object]) -> dict[str, object]:
    """Do not promote green setup, missing evidence or partial audits to PASS."""
    problems = []
    if not re.fullmatch(r"[0-9a-f]{40}", source_sha) or current_sha != source_sha:
        problems.append("exact_source_mismatch")
    if prior_status != "success":
        problems.append("prior_job_not_success")
    steps = {}
    for name in REQUIRED_STEPS:
        raw = outcomes.get(name)
        outcome = raw.get("outcome") if isinstance(raw, dict) else None
        steps[name] = outcome
        if outcome != "success":
            problems.append(f"step_not_success:{name}")
    missing = sorted(set(REQUIRED_LOGS) - available)
    if missing:
        problems.append("missing_evidence")
    for name in OSV_REPORTS:
        report = reports.get(name)
        count = report.get("packages_checked") if isinstance(report, dict) else None
        if (not isinstance(count, int) or isinstance(count, bool) or count <= 0
                or report.get("findings") != []):
            problems.append(f"incomplete_or_flagged_advisory_report:{name}")
    npm = reports.get("cloudflare-npm-audit.json")
    metadata = npm.get("metadata") if isinstance(npm, dict) else None
    vulnerabilities = metadata.get("vulnerabilities") if isinstance(metadata, dict) else None
    total = vulnerabilities.get("total") if isinstance(vulnerabilities, dict) else None
    if not isinstance(total, int) or isinstance(total, bool) or total != 0:
        problems.append("incomplete_or_flagged_npm_report")
    inventory = reports.get("repository_inventory.json")
    if (not isinstance(inventory, dict) or any(inventory.get(key) != [] for key in
            ("secret_candidates", "conflict_candidates", "syntax_errors"))):
        problems.append("repository_candidates_or_missing_inventory")
    return {
        "schema": "bil.qa.supplemental-source-audits.v1", "source_sha": source_sha,
        "status": "PASS" if not problems else "FAIL", "steps": steps,
        "missing_evidence": missing, "problems": problems,
        "scope": ["source audits and Python/Node self-tests", "Cloudflare isolated worker tests",
                  "community attention SQL on a fresh isolated native PostgreSQL service",
                  "public dependency coordinates queried against OSV/npm registries",
                  "Gradle releaseRuntimeClasspath resolution; no APK/AAB build"],
        "not_proved": ["genuine store transactions", "physical-device integrity",
                       "transactional live backend", "signed artifacts or store readiness"],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--initialize", action="store_true")
    parser.add_argument("--prior-status", default="")
    parser.add_argument("--outcomes", default="{}")
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9a-f]{40}", args.source_sha):
        parser.error("Expected full source SHA")
    current = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    args.output.mkdir(parents=True, exist_ok=True)
    path = args.output / "supplemental-receipt.json"
    if args.initialize:
        result = {"schema": "bil.qa.supplemental-source-audits.v1",
                  "source_sha": args.source_sha, "status": "STARTED"}
        code = int(current != args.source_sha)
        if code:
            result.update(status="FAIL", problems=["exact_source_mismatch"])
    else:
        try:
            outcomes = json.loads(args.outcomes)
        except ValueError:
            outcomes = {}
        if not isinstance(outcomes, dict):
            outcomes = {}
        available, reports = set(), {}
        for name in REQUIRED_LOGS:
            file = args.output / name
            if file.is_file() and file.stat().st_size:
                available.add(name)
            if name.endswith(".json"):
                try:
                    reports[name] = json.loads(file.read_text(encoding="utf-8"))
                except (OSError, ValueError):
                    pass
        result = final_receipt(source_sha=args.source_sha, current_sha=current,
                               prior_status=args.prior_status, outcomes=outcomes,
                               available=available, reports=reports)
        code = int(result["status"] != "PASS")
    result["recorded_at"] = datetime.now(timezone.utc).isoformat()
    path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result))
    return code


if __name__ == "__main__":
    raise SystemExit(main())
