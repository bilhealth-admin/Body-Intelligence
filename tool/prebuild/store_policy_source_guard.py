#!/usr/bin/env python3
"""Read-only BIL Apple/Google source-policy preflight.

Run in a complete repository checkout. No credentials, network, or mutation of
app code. Outputs a policy-evidence manifest, NOT a store-approval certificate.
"""
import argparse
import json
import plistlib
import re
import subprocess
import sys
from pathlib import Path
from xml.etree import ElementTree as ET

ANDROID = "{http://schemas.android.com/apk/res/android}"
TOOLS = "{http://schemas.android.com/tools}"


def check(source, phrase, code, errors, evidence):
    if phrase not in source:
        errors.append({"code": code, "detail": f"Missing {phrase}"})
    else:
        evidence.append(code)


def run(root):
    errors, warnings, evidence = [], [], []
    source_files = list((root / "lib").rglob("*.dart"))
    native_files = [
        *list((root / "android").rglob("*.kt")),
        *list((root / "ios").rglob("*.swift")),
    ]
    dart_sources = "\n".join(
        p.read_text(encoding="utf-8-sig") for p in source_files
        if p.is_file()
    )
    files = {
        "manifest": root / "android/app/src/main/AndroidManifest.xml",
        "gradle": root / "android/app/build.gradle.kts",
        "info": root / "ios/Runner/Info.plist",
        "privacy": root / "ios/Runner/PrivacyInfo.xcprivacy",
        "pubspec": root / "pubspec.yaml",
        "review": root / "lib/app/services/store_review_prompt_service.dart",
        "paywall": root / "lib/features/commerce/presentation/commerce_paywall.dart",
        "ugc": root / "lib/features/community/presentation/community_post_card.dart",
        "policy": root / "lib/features/community/presentation/community_safety_page.dart",
    }
    missing = [str(p.relative_to(root)) for p in files.values() if not p.is_file()]
    if missing:
        return {"pass": False, "errors": [{"code": "SOURCE_MISSING", "detail": missing}],
                "warnings": [], "evidence": [], "counts": {}}

    manifest_text = files["manifest"].read_text(encoding="utf-8")
    manifest = ET.fromstring(manifest_text)
    permissions = [
        e.attrib.get(ANDROID + "name", "")
        for e in manifest.findall("uses-permission")
        if e.attrib.get(TOOLS + "node") != "remove"
    ]
    expected_health = {
        "android.permission.health.READ_STEPS",
        "android.permission.health.READ_DISTANCE",
        "android.permission.health.READ_ACTIVE_CALORIES_BURNED",
    }
    present_health = {p for p in permissions if p.startswith("android.permission.health.")}
    if present_health != expected_health:
        errors.append({
            "code": "HEALTH_CONNECT_SCOPE_MISMATCH",
            "detail": {"found": sorted(present_health),
                       "expected": sorted(expected_health)},
        })
    else:
        evidence.append("HC_THREE_ACTIVITY_READ_PERMISSIONS")

    if any(p in permissions for p in (
        "android.permission.READ_EXTERNAL_STORAGE",
        "android.permission.WRITE_EXTERNAL_STORAGE",
        "android.permission.READ_MEDIA_IMAGES",
        "android.permission.READ_MEDIA_VIDEO",
    )):
        errors.append({"code": "PHOTO_PICKER_BROAD_MEDIA_PERMISSION",
                       "detail": "Check native picker versus permission need"})

    activity_or_service = (
        "activity", "activity-alias", "receiver", "service"
    )
    for element in manifest.iter():
        if element.tag in activity_or_service and element.find("intent-filter") is not None:
            if ANDROID + "exported" not in element.attrib:
                errors.append({"code": "ANDROID_EXPORTED_MISSING",
                               "detail": element.attrib.get(ANDROID + "name", "")})
    for fragment in (
        "androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE",
        "android.intent.action.VIEW_PERMISSION_USAGE",
        "android.intent.category.HEALTH_PERMISSIONS",
    ):
        check(manifest_text, fragment, "HC_RATIONALE_" + fragment, errors, evidence)

    gradle = files["gradle"].read_text(encoding="utf-8")
    sdk_match = re.search(r"\btargetSdk\s*=\s*(\d+)", gradle)
    target = int(sdk_match.group(1)) if sdk_match else None
    if target is None or target < 35:
        errors.append({"code": "ANDROID_TARGET_SDK_AUDIT",
                       "detail": f"Found targetSdk={target}; verify current Play requirement"})
    else:
        evidence.append("ANDROID_TARGET_SDK_AT_LEAST_35")
    if "com.google.android.play:integrity" not in gradle:
        warnings.append({"code": "PLAY_INTEGRITY_NOT_VERIFIED",
                         "detail": "Verify anti-abuse controls and server outcomes"})

    with files["info"].open("rb") as f:
        ios = plistlib.load(f)
    with files["privacy"].open("rb") as f:
        privacy = plistlib.load(f)
    for key in (
        "NSCameraUsageDescription", "NSPhotoLibraryUsageDescription",
        "NSMicrophoneUsageDescription", "NSSpeechRecognitionUsageDescription",
        "NSHealthShareUsageDescription", "NSHealthUpdateUsageDescription",
        "NSBluetoothAlwaysUsageDescription",
    ):
        if not str(ios.get(key, "")).strip():
            errors.append({"code": "IOS_USAGE_DESCRIPTION_MISSING", "detail": key})
    if privacy.get("NSPrivacyTracking") is not False:
        warnings.append({"code": "IOS_TRACKING_DECLARATION_REVIEW",
                         "detail": "Audit ATT/IDFA and all embedded SDKs"})
    else:
        evidence.append("IOS_PRIVACY_MANIFEST_NO_TRACKING_DECLARED")
    if not privacy.get("NSPrivacyAccessedAPITypes"):
        warnings.append({"code": "IOS_REQUIRED_REASONS_REVIEW",
                         "detail": "Required-reason API inventory absent; inspect dependencies"})

    pubspec = files["pubspec"].read_text(encoding="utf-8")
    check(pubspec, "in_app_review:", "OFFICIAL_NATIVE_REVIEW_PLUGIN", errors, evidence)
    review = files["review"].read_text(encoding="utf-8")
    check(review, "_review.requestReview()", "NATIVE_REVIEW_GATEWAY", errors, evidence)
    check(review, "minimumExperience", "REVIEW_MINIMUM_EXPERIENCE", errors, evidence)
    check(review, "promptCooldown", "REVIEW_LOCAL_COOLDOWN", errors, evidence)
    check(review, "_canRequestNow()", "REVIEW_FOREGROUND_GUARD", errors, evidence)
    if "showDialog(" in review or "showModalBottomSheet(" in review:
        errors.append({"code": "CUSTOM_RATING_PREPROMPT",
                       "detail": "Native review should not be imitated"})
    if re.search(r"(?i)(would you rate|rate us 5 stars|do you like bil)", dart_sources):
        warnings.append({"code": "SENTIMENT_GATING_TEXT_REVIEW",
                         "detail": "Manually check context to exclude store review gating"})

    callsites = re.findall(
        r"\.recordPositiveMoment\(\s*StoreReviewMoment\.(\w+)",
        dart_sources,
    )
    if len(callsites) != 3:
        warnings.append({"code": "REVIEW_TRIGGER_COUNT_DRIFT",
                         "detail": {"expected": 3, "found": callsites}})
    else:
        evidence.append("THREE_AUDITED_SUCCESS_MOMENTS")

    paywall = files["paywall"].read_text(encoding="utf-8")
    for fragment in ("paywall-terms-link", "paywall-privacy-link", "onRestore"):
        check(paywall, fragment, "PAYWALL_" + fragment, errors, evidence)

    ugc = files["ugc"].read_text(encoding="utf-8")
    for fragment in ("'report'", "'block'"):
        check(ugc, fragment, "COMMUNITY_" + fragment, errors, evidence)
    policy = files["policy"].read_text(encoding="utf-8")
    check(policy, "acceptContentPolicy", "COMMUNITY_POLICY_ACCEPTANCE", errors, evidence)

    for critical in (
        "Account deletion must be genuinely functional on authenticated account.",
        "Play Console reviewer app-access credentials and paid entitlements must be real.",
        "Google Play app status/suspension and appeal must be verified in Console.",
        "App Store Connect privacy disclosures must match shipped SDK/network behavior.",
        "Merged Android manifest and release AAB must be inspected, not just source XML.",
        "All subscriptions need real store lifecycle tests and legally clear terms.",
        "UGC reporting/blocking requires backend enforcement and ongoing moderation.",
        "Apple Health and Android Health Connect permissions need physical-device tests.",
        "Accessibility, VoiceOver/TalkBack, locale fonts, iPad/tablet must be exercised.",
        "Google Play review UI on approved store test track and iOS development StoreKit UI must be exercised.",
        "AI medical claims must not imply diagnostic accuracy without validated evidence.",
    ):
        warnings.append({"code": "MANUAL_RELEASE_GATE", "detail": critical})

    return {
        "pass": len(errors) == 0,
        "errors": errors,
        "warnings": warnings,
        "evidence": sorted(set(evidence)),
        "counts": {
            "dart_files_scanned_for_patterns": len(source_files),
            "native_source_files_in_inventory": len(native_files),
            "android_permissions_declared_after_source_remove_directives": permissions,
            "health_permissions": sorted(present_health),
            "android_target_sdk_source": target,
            "review_success_call_sites": callsites,
            "human_review_required": len(warnings),
        },
        "meaning": "Source-only heuristics, not an approved build/store/device certificate.",
    }


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--root", type=Path, default=Path("."))
    p.add_argument("--json-out", type=Path)
    args = p.parse_args()
    root = args.root.resolve()
    result = run(root)
    rendered = json.dumps(result, indent=2, ensure_ascii=False)
    if args.json_out:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(rendered + "\n", encoding="utf-8")
    else:
        print(rendered)
    return 0 if result["pass"] else 1


if __name__ == "__main__":
    sys.exit(main())
