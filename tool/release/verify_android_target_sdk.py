#!/usr/bin/env python3
"""Verify targetSdkVersion from bundletool's final-AAB manifest dump."""

from __future__ import annotations

import argparse
import json
import pathlib
import tempfile
import xml.etree.ElementTree as ET


ANDROID_NAMESPACE = "http://schemas.android.com/apk/res/android"
EXPECTED_TARGET_SDK = 36
OFFICIAL_REQUIREMENT = (
    "https://developer.android.com/google/play/requirements/target-sdk"
)


class GateError(ValueError):
    pass


def _target_sdk_from_manifest(raw: bytes) -> int:
    try:
        root = ET.fromstring(raw)
    except ET.ParseError as error:
        raise GateError("bundletool manifest evidence is not valid XML.") from error

    uses_sdk_nodes = [
        child for child in root if child.tag.rsplit("}", 1)[-1] == "uses-sdk"
    ]
    if len(uses_sdk_nodes) != 1:
        raise GateError(
            "Final AAB base manifest must contain exactly one uses-sdk element."
        )

    value = uses_sdk_nodes[0].get(f"{{{ANDROID_NAMESPACE}}}targetSdkVersion")
    if value is None or not value.strip():
        raise GateError("Final AAB base manifest has no targetSdkVersion.")
    try:
        return int(value, 0)
    except ValueError as error:
        raise GateError(
            f"Final AAB targetSdkVersion is not numeric: {value!r}."
        ) from error


def _verified_target_sdk(raw: bytes) -> int:
    actual_target_sdk = _target_sdk_from_manifest(raw)
    if actual_target_sdk != EXPECTED_TARGET_SDK:
        raise GateError(
            "Final AAB targetSdkVersion must be exactly "
            f"{EXPECTED_TARGET_SDK}; got {actual_target_sdk}."
        )
    return actual_target_sdk


def _write_evidence(
    *,
    text_path: pathlib.Path,
    json_path: pathlib.Path,
    status: str,
    actual_target_sdk: int | None,
    error: str | None,
) -> None:
    payload = {
        "status": status,
        "source": "bundletool dump manifest from final signed AAB base module",
        "expectedTargetSdkVersion": EXPECTED_TARGET_SDK,
        "actualTargetSdkVersion": actual_target_sdk,
        "officialRequirement": OFFICIAL_REQUIREMENT,
        "error": error,
    }
    lines = [
        f"ANDROID_FINAL_AAB_TARGET_SDK_GATE={status}",
        "SOURCE=FINAL_SIGNED_AAB_BASE_MANIFEST_VIA_PINNED_BUNDLETOOL",
        f"EXPECTED_TARGET_SDK_VERSION={EXPECTED_TARGET_SDK}",
        "ACTUAL_TARGET_SDK_VERSION="
        + ("UNAVAILABLE" if actual_target_sdk is None else str(actual_target_sdk)),
        f"OFFICIAL_REQUIREMENT={OFFICIAL_REQUIREMENT}",
    ]
    if error is not None:
        lines.append(f"ERROR={error}")

    text_path.parent.mkdir(parents=True, exist_ok=True)
    json_path.parent.mkdir(parents=True, exist_ok=True)
    text_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    json_path.write_text(
        json.dumps(payload, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def _self_test() -> None:
    valid = b'''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <uses-sdk android:minSdkVersion="26" android:targetSdkVersion="36" />
</manifest>'''
    if _verified_target_sdk(valid) != EXPECTED_TARGET_SDK:
        raise AssertionError("valid target SDK fixture was not accepted")

    invalid_cases = (
        valid.replace(b'targetSdkVersion="36"', b'targetSdkVersion="35"'),
        valid.replace(b' android:targetSdkVersion="36"', b""),
        valid.replace(
            b"</manifest>",
            b'  <uses-sdk android:targetSdkVersion="36" />\n</manifest>',
        ),
        b"<manifest>",
    )
    for raw in invalid_cases:
        try:
            _verified_target_sdk(raw)
        except GateError:
            continue
        raise AssertionError("invalid target SDK fixture was accepted")

    with tempfile.TemporaryDirectory(prefix="bil-target-sdk-") as temp_dir:
        text_path = pathlib.Path(temp_dir) / "evidence.txt"
        json_path = pathlib.Path(temp_dir) / "evidence.json"
        _write_evidence(
            text_path=text_path,
            json_path=json_path,
            status="PASS",
            actual_target_sdk=EXPECTED_TARGET_SDK,
            error=None,
        )
        if "ANDROID_FINAL_AAB_TARGET_SDK_GATE=PASS" not in text_path.read_text(
            encoding="utf-8"
        ):
            raise AssertionError("text evidence was not written")
        if json.loads(json_path.read_text(encoding="utf-8"))["status"] != "PASS":
            raise AssertionError("JSON evidence was not written")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=pathlib.Path)
    parser.add_argument("--text-evidence", type=pathlib.Path)
    parser.add_argument("--json-evidence", type=pathlib.Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        _self_test()
        print("SELF_TEST=PASS")
        return 0
    if args.manifest is None:
        parser.error("--manifest is required unless --self-test is used")
    if args.text_evidence is None or args.json_evidence is None:
        parser.error("--text-evidence and --json-evidence are required")

    actual_target_sdk: int | None = None
    try:
        raw_manifest = args.manifest.read_bytes()
        actual_target_sdk = _target_sdk_from_manifest(raw_manifest)
        _verified_target_sdk(raw_manifest)
    except (OSError, GateError) as error:
        _write_evidence(
            text_path=args.text_evidence,
            json_path=args.json_evidence,
            status="FAIL",
            actual_target_sdk=actual_target_sdk,
            error=str(error),
        )
        raise SystemExit(str(error)) from error

    _write_evidence(
        text_path=args.text_evidence,
        json_path=args.json_evidence,
        status="PASS",
        actual_target_sdk=actual_target_sdk,
        error=None,
    )
    print("ANDROID_FINAL_AAB_TARGET_SDK_GATE=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
