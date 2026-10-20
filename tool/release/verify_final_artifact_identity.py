#!/usr/bin/env python3
"""Read final iOS/Android artifact identity, never infer it from build inputs.

This does not verify signing, store processing, ATT runtime or reviewer access.
The iOS inventory records declared privacy information, not observed data flows.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import plistlib
import xml.etree.ElementTree as ET
import zipfile

ANDROID = "{http://schemas.android.com/apk/res/android}"


def _expected_version(version: str, build: str) -> None:
    if not version or not build.isdecimal() or int(build) < 1:
        raise ValueError("Expected version/build are invalid")


def android_identity(raw: bytes, *, package: str, version: str, build: str) -> dict:
    _expected_version(version, build)
    root = ET.fromstring(raw)
    if root.tag != "manifest":
        raise ValueError("Android evidence is not a manifest")
    actual = {"package": root.get("package"),
              "version": root.get(ANDROID + "versionName"),
              "build": root.get(ANDROID + "versionCode")}
    if actual != {"package": package, "version": version, "build": build}:
        raise ValueError("Final Android artifact identity mismatch")
    return {"status": "FINAL_ARTIFACT_IDENTITY_PASS", "platform": "android",
            **actual, "signing_verified_by_this_check": False,
            "reviewer_access_verified": False}


def ios_info_identity(raw: bytes, *, package: str, version: str, build: str) -> dict:
    _expected_version(version, build)
    info = plistlib.loads(raw)
    if not isinstance(info, dict):
        raise ValueError("Final iOS Info.plist is not a dictionary")
    actual = {"package": info.get("CFBundleIdentifier"),
              "version": info.get("CFBundleShortVersionString"),
              "build": info.get("CFBundleVersion")}
    if actual != {"package": package, "version": version, "build": build}:
        raise ValueError("Final iOS artifact identity mismatch")
    return {"status": "FINAL_ARTIFACT_IDENTITY_PASS", "platform": "ios",
            **actual, "signing_verified_by_this_check": False,
            "reviewer_access_verified": False,
            "att_usage_description_present": bool(info.get("NSUserTrackingUsageDescription")),
            "admob_app_id_present": bool(info.get("GADApplicationIdentifier"))}


def ios_archive(path: pathlib.Path, *, package: str, version: str, build: str) -> dict:
    with zipfile.ZipFile(path) as archive:
        names = [item.filename for item in archive.infolist() if not item.is_dir()]
        if len(names) != len(set(names)) or len(names) != len({x.casefold() for x in names}):
            raise ValueError("IPA has duplicate/case-colliding paths")
        for name in names:
            part = pathlib.PurePosixPath(name)
            if part.is_absolute() or ".." in part.parts or "\\" in name:
                raise ValueError("IPA has an unsafe path")
        app_infos = [name for name in names if len(pathlib.PurePosixPath(name).parts) == 3
                     and name.startswith("Payload/") and name.endswith(".app/Info.plist")]
        if len(app_infos) != 1:
            raise ValueError("IPA needs exactly one top-level app Info.plist")
        root = app_infos[0].removesuffix("Info.plist")
        result = ios_info_identity(archive.read(app_infos[0]), package=package,
                                   version=version, build=build)
        app_privacy = root + "PrivacyInfo.xcprivacy"
        if app_privacy not in names:
            raise ValueError("Final IPA app privacy manifest is missing")
        privacy = []
        frameworks = []
        for name in sorted(names):
            if not name.startswith(root):
                continue
            if name.endswith("/Info.plist") and ".framework/" in name:
                data = plistlib.loads(archive.read(name))
                if not isinstance(data, dict):
                    raise ValueError("Framework Info.plist is not a dictionary")
                frameworks.append({"path": name.removeprefix(root),
                                   "bundle_id": data.get("CFBundleIdentifier"),
                                   "version": data.get("CFBundleShortVersionString"),
                                   "build": data.get("CFBundleVersion")})
            if name.endswith("/PrivacyInfo.xcprivacy"):
                raw = archive.read(name)
                data = plistlib.loads(raw)
                if not isinstance(data, dict):
                    raise ValueError("Embedded privacy manifest is not a dictionary")
                tracking = data.get("NSPrivacyTracking")
                if tracking is not None and type(tracking) is not bool:
                    raise ValueError("Embedded NSPrivacyTracking is not Boolean")
                arrays = {}
                for key in ("NSPrivacyTrackingDomains", "NSPrivacyCollectedDataTypes",
                            "NSPrivacyAccessedAPITypes"):
                    value = data.get(key, [])
                    if not isinstance(value, list):
                        raise ValueError("Embedded privacy declaration is not an array")
                    arrays[key] = value
                if not all(isinstance(domain, str) for domain in arrays["NSPrivacyTrackingDomains"]):
                    raise ValueError("Embedded tracking domains contain a non-string")
                privacy.append({"path": name.removeprefix(root),
                                "sha256": hashlib.sha256(raw).hexdigest(),
                                "declared_tracking": tracking,
                                "declared_tracking_domains_count": len(arrays["NSPrivacyTrackingDomains"]),
                                "declared_tracking_domains": arrays["NSPrivacyTrackingDomains"],
                                "declared_collected_data": arrays["NSPrivacyCollectedDataTypes"],
                                "declared_required_reason_apis": arrays["NSPrivacyAccessedAPITypes"],
                                "additional_manifest_keys": sorted(set(data) - {
                                    "NSPrivacyTracking", "NSPrivacyTrackingDomains",
                                    "NSPrivacyCollectedDataTypes", "NSPrivacyAccessedAPITypes"})})
        with path.open("rb") as handle:
            ipa_digest = hashlib.file_digest(handle, "sha256").hexdigest()
        result.update({"ipa_sha256": ipa_digest,
                       "frameworks": frameworks, "privacy_manifests": privacy,
                       "privacy_runtime_verified": False,
                       "app_privacy_console_reconciled": False,
                       "static_linked_sdk_completeness_verified": False,
                       "scope": "Final archive identity and declared manifest inventory only; not a privacy-compliance verdict"})
        return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--ipa", type=pathlib.Path)
    source.add_argument("--ios-info", type=pathlib.Path)
    source.add_argument("--android-manifest", type=pathlib.Path)
    parser.add_argument("--package", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--build", required=True)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    args = parser.parse_args()
    expected = {"package": args.package, "version": args.version, "build": args.build}
    if args.ipa:
        result = ios_archive(args.ipa, **expected)
    elif args.ios_info:
        result = ios_info_identity(args.ios_info.read_bytes(), **expected)
    else:
        result = android_identity(args.android_manifest.read_bytes(), **expected)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: result[key] for key in ("status", "platform", "package", "version", "build")}))


if __name__ == "__main__":
    main()
