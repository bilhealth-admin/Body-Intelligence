"""BIL39 strict evidence validator. PASS is evidence-bound, not a test execution."""
from __future__ import annotations
import argparse
import json
import re
from pathlib import Path

BASE = "155b079696430919f8272df934371f033fb11be2"
WORKERS = (17, 18, 19, 20, 21, 22)
GATES = (
 "SOURCE_FORMAT_ANALYZE", "TARGETED_P0", "FOCUSED", "GOLDENS_REVIEWED",
 "BROAD", "FULL_EIGHT_SHARDS", "NEGATIVE_ADVERSARIAL", "DEEPLINK_LIFECYCLE",
 "ACCOUNT_ISOLATION", "CLOUD_RLS_LOCAL", "SECURITY", "PRIVACY_STORE_POLICY",
 "IOS_NATIVE_IPHONE_IPAD", "ANDROID_NATIVE", "ACCESSIBILITY",
 "PERFORMANCE_RESILIENCE", "BUILD39_SIGNED_IDENTITY", "STORE_READONLY",
 "PHYSICAL_DEVICE_ACCEPTANCE",
)
ANDROID = ("26", "29", "33", "34", "35", "36")
IOS = ("iphone", "ipad")
CASES = tuple(
 [f"BIL-{i:02d}" for i in range(1, 28)]
 + [f"COACH-ADD-{i:02d}" for i in range(1, 11)]
 + [f"QA-COACH-{i:02d}" for i in range(1, 19)]
 + ["VIDEO-SOURCE-01", "CLOUD-COACH-01", "CLOUD-COACH-02"]
 + [f"CC-1009-{i:02d}" for i in range(1, 11)]
)
EXPECTED = "https://github.com/bilhealth-admin/Body-Intelligence/"
HEX40 = re.compile(r"^[0-9a-f]{40}$")
SAFE_FLAGS = (
 "mutated_ios38", "mutated_app_review", "mutated_production",
 "made_real_purchase", "changed_payment_cta", "merged_pr"
)


def proof(p, sha):
    return bool(
        sha and isinstance(p, dict) and p.get("status") == "PASS"
        and p.get("source_sha") == sha
        and str(p.get("url", "")).startswith("https://")
        and p.get("unexpected_skips", 0) == 0
    )


def evaluate(s):
    if not isinstance(s, dict):
        return {"decision": "INVALID_SNAPSHOT", "errors": ["not an object"], "blockers": []}
    problems, errors = [], []
    if s.get("schema") != "bil39.strict.qa.snapshot.v1":
        errors.append("invalid schema")
    if s.get("base_sha") != BASE:
        problems.append("protected iOS38 baseline SHA mismatch")
    prs = s.get("prs", {})
    if not isinstance(prs, dict):
        prs = {}
        errors.append("invalid prs")
    paths = {}
    for n in WORKERS:
        p = prs.get(str(n))
        if not isinstance(p, dict):
            problems.append(f"missing PR #{n}")
            continue
        head = p.get("head_sha")
        if not isinstance(head, str) or not HEX40.fullmatch(head):
            problems.append(f"PR #{n} invalid SHA")
        if p.get("base_sha") != BASE or p.get("draft") is not True or p.get("state") != "open":
            problems.append(f"PR #{n} wrong base/state")
        files = p.get("changed_files", [])
        if not isinstance(files, list) or any(not isinstance(f, str) for f in files):
            errors.append(f"PR #{n} invalid paths")
            files = []
        for f in files:
            paths.setdefault(f, []).append(n)
            if "store-purchase-cta" in f.lower() or "store_purchase_cta" in f.lower():
                problems.append(f"PR #{n} modified protected payment CTA: {f}")
        for kind in ("verify", "android_debug"):
            run = p.get(kind, {})
            if (not isinstance(run, dict) or run.get("conclusion") != "success"
                or run.get("head_sha") != head
                or not str(run.get("url", "")).startswith(EXPECTED)):
                problems.append(f"PR #{n} {kind} not green on exact SHA")
    overlap = {f: ids for f, ids in paths.items() if len(ids) > 1}
    candidate = s.get("candidate")
    sha = candidate.get("sha") if isinstance(candidate, dict) else None
    if not isinstance(sha, str) or not HEX40.fullmatch(sha):
        problems.append("no frozen integrated candidate SHA")
        sha = ""
    if not isinstance(candidate, dict) or candidate.get("human_reviewed") is not True:
        problems.append("candidate not independently reviewed")
    accepted_overlap = s.get("reviewed_overlap_resolutions", {})
    if not isinstance(accepted_overlap, dict):
        errors.append("invalid overlap resolutions")
        accepted_overlap = {}
    for file, ids in overlap.items():
        receipt = accepted_overlap.get(file, {})
        if (not isinstance(receipt, dict)
            or receipt.get("reviewed_on_candidate_sha") != sha
            or not sha
            or not str(receipt.get("url", "")).startswith(EXPECTED)):
            problems.append(f"unresolved overlap {file}: {ids}")
    coverage = s.get("coverage", {})
    if not isinstance(coverage, dict):
        errors.append("invalid coverage")
        coverage = {}
    accepted_cases = 0
    for case in CASES:
        item = coverage.get(case, {})
        if (isinstance(item, dict) and sha and item.get("status") == "FIXED_VERIFIED"
            and item.get("source_sha") == sha
            and str(item.get("url", "")).startswith("https://")):
            accepted_cases += 1
        else:
            problems.append(f"{case} has no candidate-specific proof")
    gates = s.get("gates", {})
    if not isinstance(gates, dict):
        errors.append("invalid gates")
        gates = {}
    for gate in GATES:
        if not proof(gates.get(gate), sha):
            problems.append(f"{gate} unverified on candidate")
    native = s.get("native_matrix", {})
    if not isinstance(native, dict):
        errors.append("invalid native matrix")
        native = {}
    for platform, targets in (("android", ANDROID), ("ios", IOS)):
        matrix = native.get(platform, {})
        if not isinstance(matrix, dict):
            errors.append(f"invalid {platform} matrix")
            matrix = {}
        for target in targets:
            if not proof(matrix.get(target), sha):
                problems.append(f"{platform} {target} native test unverified")
    safety = s.get("safety_flags", {})
    if not isinstance(safety, dict):
        errors.append("invalid safety flags")
        safety = {}
    for flag in SAFE_FLAGS:
        if safety.get(flag) is not False:
            problems.append(f"unsafe or missing declaration: {flag}")
    if s.get("ios_build_number") != 39:
        problems.append("iOS39 identity not verified")
    decision = "INVALID_SNAPSHOT" if errors else ("BLOCKED" if problems else "READY_FOR_INTERNAL_TESTFLIGHT_UPLOAD_ONLY")
    return {"decision": decision, "errors": sorted(set(errors)),
            "blockers": sorted(set(problems)), "conflicting_paths": overlap,
            "accepted_cases": accepted_cases, "required_cases": len(CASES),
            "candidate_sha": sha or None,
            "disclaimer": "Validates declared evidence only. It does not execute native/device/app tests."}


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--snapshot", required=True)
    p.add_argument("--output")
    p.add_argument("--audit-only", action="store_true")
    a = p.parse_args()
    try:
        s = json.loads(Path(a.snapshot).read_text(encoding="utf-8"))
    except (ValueError, OSError) as exc:
        print(str(exc))
        return 2
    report = evaluate(s)
    body = json.dumps(report, ensure_ascii=False, sort_keys=True, indent=2) + "\n"
    print(body)
    if a.output:
        Path(a.output).write_text(body, encoding="utf-8")
    if report["decision"] == "INVALID_SNAPSHOT":
        return 2
    if a.audit_only:
        return 0
    return 0 if report["decision"] == "READY_FOR_INTERNAL_TESTFLIGHT_UPLOAD_ONLY" else 1


if __name__ == "__main__":
    raise SystemExit(main())
