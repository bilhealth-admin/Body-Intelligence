"""Read-only policy evidence gate. Automatic checks never certify a store.

Default mode verifies source/records and preserves an explicit BLOCKED decision.
--certify-release is fail-closed: any applicable unresolved requirement exits 2.
No sign-in, deployment, signing, account mutation, or paid provider request.
"""
from __future__ import annotations

import argparse
import collections
import datetime as dt
import hashlib
import json
from pathlib import Path
import plistlib
import re
import subprocess
from urllib.parse import urlsplit
import xml.etree.ElementTree as ET

ANDROID = "{http://schemas.android.com/apk/res/android}"
TOOLS = "{http://schemas.android.com/tools}"
HEALTH = {
    "android.permission.health.READ_STEPS",
    "android.permission.health.READ_DISTANCE",
    "android.permission.health.READ_ACTIVE_CALORIES_BURNED",
}
FORBIDDEN = {
    "com.google.android.gms.permission.AD_ID",
    "android.permission.READ_MEDIA_IMAGES",
    "android.permission.READ_MEDIA_VIDEO",
    "android.permission.MANAGE_EXTERNAL_STORAGE",
}
OFFICIAL = {
    "developer.apple.com", "developer.android.com", "developers.google.com",
    "support.google.com", "play.google.com", "ai.google.dev", "firebase.google.com",
}
STATES = {"PASS", "FAIL", "BLOCKED", "NOT APPLICABLE"}
FIELDS = {
    "id", "platform", "clause", "official_urls", "read_date", "applies",
    "rationale", "implementation", "proof_test", "status", "evidence",
    "minimum_action", "needs_signed_device_console", "previous_rejection", "risk",
}


def validate_requirements(rows: list[dict]) -> None:
    if not rows:
        raise ValueError("Empty policy inventory cannot pass")
    seen = set()
    for row in rows:
        if FIELDS - row.keys():
            raise ValueError("Incomplete policy evidence fields")
        if row["id"] in seen or row["status"] not in STATES:
            raise ValueError("Duplicate policy ID or unsupported decision")
        seen.add(row["id"])
        if row["risk"] not in {"P0", "P1", "P2"}:
            raise ValueError("Missing policy risk classification")
        if row["platform"] not in {"Apple", "Google"}:
            raise ValueError("Unsupported store platform")
        if not row["official_urls"]:
            raise ValueError("Official policy source is required")
        for url in row["official_urls"]:
            parsed = urlsplit(url)
            if parsed.scheme != "https" or parsed.hostname not in OFFICIAL:
                raise ValueError("Policy citation is not an official HTTPS source")
        for key in ("clause", "rationale", "implementation", "proof_test", "evidence",
                    "minimum_action", "previous_rejection"):
            if not str(row[key]).strip():
                raise ValueError("Missing policy rationale or supporting evidence")
        if row["status"] == "NOT APPLICABLE" and row["applies"] is not False:
            raise ValueError("Not-applicable decision requires explicit applicability")
        if row["status"] == "PASS" and row.get("status_scope") != "source_only":
            # A human artifact/Console certification needs a separate verified
            # receipt, not a hand-edited PASS in a source review table.
            raise ValueError("Source records cannot assert store certification")
        dt.date.fromisoformat(row["read_date"])


def release_decision(rows: list[dict]) -> str:
    unresolved = [r for r in rows if r["status"] in {"FAIL", "BLOCKED"}]
    source_only = any(r["status"] == "PASS" for r in rows)
    return "BLOCKED" if unresolved or source_only else "PASS"


def permission_names(path: Path) -> set[str]:
    manifest = ET.parse(path).getroot()
    return {
        element.attrib[ANDROID + "name"]
        for element in manifest.findall("uses-permission")
        if element.get(TOOLS + "node") != "remove"
    }


def permission_issues(names: set[str]) -> set[str]:
    return (names & FORBIDDEN) | {
        name for name in names
        if name.startswith("android.permission.health.") and name not in HEALTH
    }


def source_checks(root: Path, require_merged: bool) -> list[dict]:
    checks = []

    def check(name: str, condition: bool, detail: str) -> None:
        checks.append({"id": name, "status": "PASS" if condition else "FAIL", "detail": detail})

    manifest = root / "android/app/src/main/AndroidManifest.xml"
    names = permission_names(manifest)
    check("android-health-source-minimum", names & HEALTH == HEALTH and not permission_issues(names),
          "Source permission scope only; final merged variants are separate checks")
    app = ET.parse(manifest).getroot().find("application")
    check("android-backup-cleartext", app.get(ANDROID + "allowBackup") == "false" and
          app.get(ANDROID + "usesCleartextTraffic") == "false", "Declared app transport/backup settings")
    gradle = (root / "android/app/build.gradle.kts").read_text(encoding="utf-8")
    check("target-sdk-source", bool(re.search(r"targetSdk\s*=\s*36\b", gradle)), "Source target API36")
    check("official-insights-pinned", 'lintChecks("com.google.play.policy.insights:insights-lint:0.1.5")' in gradle,
          "Official lint-only dependency; exact verified version")
    check("lint-no-suppression", "abortOnError = true" in gradle and "checkDependencies = true" in gradle and
          not re.search(r"(?:disable|ignoreWarnings|baseline)\s*(?:[=(]|\+=)", gradle),
          "App lint has no added disabled rule, ignoreWarnings, or baseline")
    info = plistlib.loads((root / "ios/Runner/Info.plist").read_bytes())
    ats = info.get("NSAppTransportSecurity", {})
    check("ios-ats-no-global-exception", not ats.get("NSAllowsArbitraryLoads", False), "Source ATS declaration")
    check("ios-purpose-strings", all(info.get(k) for k in
          ("NSCameraUsageDescription", "NSMicrophoneUsageDescription", "NSHealthShareUsageDescription")),
          "Purpose strings exist; native permission/consent interaction is not implied")
    privacy = plistlib.loads((root / "ios/Runner/PrivacyInfo.xcprivacy").read_bytes())
    check("ios-privacy-schema", isinstance(privacy.get("NSPrivacyTracking"), bool) and
          isinstance(privacy.get("NSPrivacyCollectedDataTypes"), list),
          "A typed Runner manifest is not evidence of SDK behavior or App Privacy alignment")
    coach = (root / "supabase/functions/ai-coach/server.ts").read_text(encoding="utf-8")
    vision = (root / "supabase/functions/analyze-meal/index.ts").read_text(encoding="utf-8")
    check("coach-disclosed-recipient-boundary", "disclosedGeminiEndpoint(" in coach and
          "fetchDisclosedProvider(fetcher, url" in coach, "Provider regression tests execute this production boundary")
    check("vision-no-redirect-boundary", "fetchDisclosedProvider(fetch, providerRequest.url" in vision,
          "Provider-image transport uses the same redirect prohibition")
    paths = sorted((root / "build/app/intermediates/merged_manifests").glob("**/AndroidManifest.xml"))
    variants = {"debug": False, "release": False}
    for path in paths:
        for variant in variants:
            if variant in path.as_posix().lower():
                variants[variant] = True
                bad = permission_issues(permission_names(path))
                check("merged-" + variant + "-" + str(len(checks)), not bad,
                      path.relative_to(root).as_posix() + "; unexpected=" + ",".join(sorted(bad)))
    if require_merged:
        for variant, found in variants.items():
            check("merged-" + variant + "-available", found, "Lint must produce both app variants; missing is not PASS")
    return checks


def implementation_input_paths(root: Path) -> list[str]:
    """Include runtime assets/native files; exclude generated failure evidence.

    NUL-separated Git paths preserve non-ASCII asset names. Git ignore rules
    keep local credentials/build caches out of the inventory; this returns
    names/hashes only and never reads credentials from ignored configuration.
    """
    raw = subprocess.check_output([
        "git", "ls-files", "-z", "--cached", "--others", "--exclude-standard", "--",
        "lib", "test", "integration_test", "test_driver", "android", "ios",
        "assets", "web", "supabase", "tools/qa",
        "tool", ".github", "pubspec.yaml", "pubspec.lock",
        "analysis_options.yaml", "devtools_options.yaml", ".gitattributes",
        ".gitignore", ".metadata", "wrangler.site.jsonc",
    ], cwd=root)
    return sorted({
        name for name in raw.decode("utf-8").split("\0") if name and
        "failures" not in Path(name).parts and (root / name).is_file()
    })


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--require-merged", action="store_true")
    parser.add_argument("--certify-release", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    record = root / "docs/qa_next/evidence/policy-gate-20261015/policy-requirements.json"
    rows = json.loads(record.read_text(encoding="utf-8"))["requirements"]
    validate_requirements(rows)
    checks = source_checks(root, args.require_merged)
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
    paths = implementation_input_paths(root)
    inputs = []
    for name in sorted(set(paths + [record.relative_to(root).as_posix()])):
        path = root / name
        if path.is_file():
            inputs.append({"path": name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    fingerprint = hashlib.sha256(json.dumps(inputs, sort_keys=True).encode()).hexdigest()
    implementation_inputs = [v for v in inputs if v["path"] != record.relative_to(root).as_posix()]
    implementation_fingerprint = hashlib.sha256(json.dumps(implementation_inputs, sort_keys=True).encode()).hexdigest()
    decision = release_decision(rows)
    failed = sum(c["status"] == "FAIL" for c in checks)
    result = {
        "gate": "BIL APPLE & GOOGLE POLICY COMPLIANCE GATE",
        "read_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "source_head": head, "source_input_fingerprint": fingerprint,
        "fingerprint_version": 2,
        "fingerprint_scope": "Git-visible implementation, native configuration, assets, test baselines and tools; excludes generated failures and ignored secrets/caches",
        "implementation_input_fingerprint": implementation_fingerprint,
        "policy_inventory_sha256": hashlib.sha256(record.read_bytes()).hexdigest(),
        "source_inputs": inputs, "checks": checks,
        "automatic_source_check_status": "FAIL" if failed else "PASS",
        "requirements_count": len(rows), "policy_status_counts": dict(collections.Counter(r["status"] for r in rows)),
        "pre_submission_certification": decision,
        "unresolved_P0": [r["id"] for r in rows if r["risk"] == "P0" and r["status"] in {"FAIL", "BLOCKED"}],
        "signed_build_created": False, "production_changed": False,
        "note": "Automation success does not certify Apple/Google compliance. BLOCKED forbids a release-readiness claim.",
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"AUTOMATIC_SOURCE_CHECKS={'FAIL' if failed else 'PASS'} count={len(checks)}")
    print(f"PRE_SUBMISSION_CERTIFICATION={decision}; requirements={len(rows)}")
    if failed:
        return 1
    return 2 if args.certify_release and decision != "PASS" else 0


if __name__ == "__main__":
    raise SystemExit(main())
