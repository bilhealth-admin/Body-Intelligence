#!/usr/bin/env python3
"""Write the fail-closed BIL release certification report."""

from __future__ import annotations

import argparse
import os
from pathlib import Path


VALID = {"PASS", "FAIL", "NOT RUN"}


def env_status(name: str, default: str = "NOT RUN") -> str:
    value = os.environ.get(name, default).strip().upper()
    aliases = {
        "SUCCESS": "PASS",
        "FAILURE": "FAIL",
        "CANCELLED": "NOT RUN",
        "SKIPPED": "NOT RUN",
        "": default,
    }
    value = aliases.get(value, value)
    return value if value in VALID else "NOT RUN"


def both(a: str, b: str) -> str:
    values = {env_status(a), env_status(b)}
    if "FAIL" in values:
        return "FAIL"
    if values == {"PASS"}:
        return "PASS"
    return "NOT RUN"


def external(name: str) -> str:
    return env_status(name)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    rc = os.environ["BIL_RC_SHA"]
    manifest_sha = os.environ.get("BIL_MANIFEST_SHA256", "UNKNOWN")
    branch_stable = os.environ.get("BIL_BRANCH_STABLE", "false").lower() == "true"

    automation = [
        ("Immutable RC freeze + manifest", env_status("BIL_FREEZE_STATUS")),
        ("Static/analyze/security/dependency pass 1", env_status("BIL_STATIC_1")),
        ("All 8 full-test shards pass 1", env_status("BIL_FULL_1")),
        ("Visual + isolated cloud contracts pass 1", env_status("BIL_VISUAL_1")),
        ("Disposable live backend core pass 1", env_status("BIL_LIVE_1")),
        ("Static/analyze/security/dependency pass 2", env_status("BIL_STATIC_2")),
        ("All 8 full-test shards pass 2", env_status("BIL_FULL_2")),
        ("Visual + isolated cloud contracts pass 2", env_status("BIL_VISUAL_2")),
        ("Disposable live backend core pass 2", env_status("BIL_LIVE_2")),
        ("Apple + Google read-only store audit", env_status("BIL_STORE_READONLY")),
    ]
    if not branch_stable:
        automation[0] = (automation[0][0], "FAIL")

    auto_repeat = "PASS"
    for _name, status in automation[:9]:
        if status == "FAIL":
            auto_repeat = "FAIL"
            break
        if status != "PASS":
            auto_repeat = "NOT RUN"

    # A high-level requirement is PASS only when every part requested by the
    # release policy has evidence. Passing a narrower automated sub-check never
    # upgrades an incomplete requirement to PASS.
    gates = [
        (
            "1. Single immutable RC + manifest",
            automation[0][1],
            f"RC {rc}; manifest SHA-256 {manifest_sha}; branch stable={branch_stable}.",
        ),
        (
            "2. True end-to-end user journey",
            external("BIL_TRUE_E2E"),
            "Requires fresh-install through account deletion across the complete requested user journey; widget/unit coverage is not a substitute.",
        ),
        (
            "3. Byte/data-level cloud round-trip and two-device isolation",
            external("BIL_CLOUD_ROUNDTRIP"),
            "Requires A->cloud->B->edit->A byte/data comparison plus interruption, retry, stale/corrupt payload, key recovery and account-switch isolation evidence.",
        ),
        (
            "4. Live backend certification including fault matrix",
            external("BIL_LIVE_BACKEND_FULL"),
            "Core disposable live probes are tracked separately; PASS additionally requires 429/401/403/404/500/timeout/malformed/partial-response coverage for every required live service.",
        ),
        (
            "5. Apple/Google commerce sandbox lifecycle",
            external("BIL_COMMERCE_SANDBOX"),
            "Requires purchase, restore, reinstall, second device, upgrade/downgrade, cancellation, expiration, grace, retry, refund/revoke and notification replay/delay evidence.",
        ),
        (
            "6. Permission state matrix",
            external("BIL_PERMISSION_MATRIX"),
            "Requires not-asked/allow/deny/restricted/revoke-return behavior for camera, photos, microphone, notifications, HealthKit/Health Connect and advertising consent.",
        ),
        (
            "7. Lifecycle and chaos certification",
            external("BIL_CHAOS"),
            "Requires kill/background/lock/network transitions/latency/outages/storage/low-memory/timezone/language/orientation/text-size/theme evidence with no corruption, crash or permanent spinner.",
        ),
        (
            "8. Database migration certification",
            both("BIL_STATIC_1", "BIL_STATIC_2"),
            "PASS requires both static passes to complete the migration certification suite: representative v4/v12/v15/v16/v19 historical fixtures, file-backed installed-version upgrade coverage, preserved user rows, duplicate stable-ID checks, foreign_key_check, required-index checks and PRAGMA integrity_check.",
        ),
        (
            "9. Independent OWASP MASVS/MASTG security review",
            external("BIL_MASVS_MASTG"),
            "Automated source/security/CVE checks are sub-evidence only. Full open-book mobile/backend review and triage of live Supabase advisor warnings are still required.",
        ),
        (
            "10. Performance + stress certification",
            external("BIL_PERFORMANCE_STRESS"),
            "Performance budget tests are sub-evidence; PASS requires startup/render, large datasets, long conversations/feed, repeated navigation, memory/CPU/battery/jank/query/network measurements.",
        ),
        (
            "11. UI/visual/accessibility device matrix",
            external("BIL_UI_DEVICE_MATRIX"),
            "Requires requested iPhone/Android/tablet/OS/language/RTL/200%/VoiceOver/TalkBack/theme/keyboard/safe-area matrix on actual supported targets.",
        ),
        (
            "12. Exhaustive navigation graph crawl",
            external("BIL_NAVIGATION_CRAWL"),
            "Route tests are sub-evidence; PASS requires complete entry/back/deep-link/guard/logout/account-boundary crawl with no dead ends.",
        ),
        (
            "13. Store certification",
            external("BIL_STORE_CERT_FULL"),
            "Read-only store API audit is sub-evidence. PASS also requires final declarations/screenshots/privacy/SDK reconciliation and Google pre-launch evidence for the exact artifact.",
        ),
        (
            "14. Signed binary inspection",
            external("BIL_SIGNED_BINARY"),
            "Explicitly NOT RUN until build permission is granted. Must inspect and install the IPA/AAB built from this exact RC hash.",
        ),
        (
            "15. Two consecutive complete certification runs",
            external("BIL_TWO_DISTINCT_RUNS"),
            f"Two clean automated passes inside this run: {auto_repeat}. Final PASS requires two distinct complete Master Certification run IDs on the same RC with no flaky or unexplained critical skip.",
        ),
        (
            "16. Master GitHub certification gate",
            "PASS",
            "This workflow is fail-closed, immutable-source, evidence-producing and does not build or upload a store artifact.",
        ),
        (
            "17. Agent-readable evidence and provenance",
            "PASS" if automation[0][1] == "PASS" else "FAIL",
            "Deterministic source/dependency/config manifest, hashes, logs, shard results and evidence artifacts are generated for agent/human review.",
        ),
        (
            "18. Independent human exploratory day",
            external("BIL_HUMAN_EXPLORATORY"),
            "Requires a tester who did not develop the feature set to perform the requested full-day adversarial exploratory pass.",
        ),
    ]

    ready = all(status == "PASS" for _name, status, _detail in gates)
    overall = "READY" if ready else "NOT READY"

    lines = [
        "# BIL Release Certification Report",
        "",
        f"- **RC commit:** `{rc}`",
        f"- **RC manifest SHA-256:** `{manifest_sha}`",
        f"- **Branch remained frozen during run:** **{'YES' if branch_stable else 'NO'}**",
        f"- **Final decision:** **{overall}**",
        "",
        "## Automated evidence in this run",
        "",
        "| Evidence | Status |",
        "| --- | --- |",
    ]
    for name, status in automation:
        lines.append(f"| {name} | **{status}** |")

    lines += [
        "",
        "## Final certification gates",
        "",
        "| Gate | Status | Evidence / remaining requirement |",
        "| --- | --- | --- |",
    ]
    for name, status, detail in gates:
        safe = detail.replace("|", "\\|").replace("\n", " ")
        lines.append(f"| {name} | **{status}** | {safe} |")

    lines += [
        "",
        "## READY rule",
        "",
        "BIL may be declared **READY** only when every gate above is **PASS** and the release conditions remain: "
        "0 known crash, 0 P0, 0 P1, 0 unresolved functional defect, 0 unexplained test failure, "
        "0 unexplained skipped critical test, 0 High/Critical security issue, 0 privacy/store mismatch, "
        "cloud round-trip PASS, account isolation PASS, purchase/restore PASS, upgrade migration PASS, "
        "account deletion PASS, clean real-device PASS, clean signed-artifact PASS, and two consecutive "
        "complete certification runs PASS on the same immutable RC.",
        "",
        "A **NOT RUN** is intentionally blocking. A narrower automated PASS never substitutes for missing "
        "device, store-sandbox, signed-binary, independent-security, or human evidence.",
        "",
    ]

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(lines), encoding="utf-8")
    print(f"BIL_RELEASE_CERTIFICATION={overall}")
    return 0 if ready else 2


if __name__ == "__main__":
    raise SystemExit(main())
