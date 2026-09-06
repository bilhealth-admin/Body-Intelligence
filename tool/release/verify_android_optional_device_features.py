#!/usr/bin/env python3
"""Verify optional hardware stays optional in the final signed Android AAB."""

from __future__ import annotations

import argparse
import json
import pathlib
import tempfile
import xml.etree.ElementTree as ET


ANDROID_NAMESPACE = "http://schemas.android.com/apk/res/android"

# These declarations neutralize hardware requirements that Android/Play can
# otherwise infer from permissions. Validate the merged AAB, not only the
# source manifest, because dependency manifests can strengthen a declaration.
EXPECTED_OPTIONAL_FEATURES = (
    "android.hardware.camera",
    "android.hardware.camera.any",
    "android.hardware.camera.autofocus",
    "android.hardware.camera.flash",
    "android.hardware.microphone",
    "android.hardware.location",
    "android.hardware.location.gps",
    "android.hardware.location.network",
    "android.hardware.bluetooth",
    "android.hardware.bluetooth_le",
)

SENSITIVE_FEATURE_PREFIXES = (
    "android.hardware.camera",
    "android.hardware.microphone",
    "android.hardware.location",
    "android.hardware.bluetooth",
)


class GateError(ValueError):
    pass


def _local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def _feature_states(raw: bytes) -> dict[str, str | None]:
    try:
        root = ET.fromstring(raw)
    except ET.ParseError as error:
        raise GateError("bundletool manifest evidence is not valid XML.") from error

    states: dict[str, str | None] = {}
    for child in root:
        if _local_name(child.tag) != "uses-feature":
            continue
        name = child.get(f"{{{ANDROID_NAMESPACE}}}name")
        if name is None or not name.strip():
            raise GateError("Final AAB contains a uses-feature without a name.")
        name = name.strip()
        if name in states:
            raise GateError(
                f"Final AAB contains duplicate uses-feature declarations for {name}."
            )
        required = child.get(f"{{{ANDROID_NAMESPACE}}}required")
        states[name] = None if required is None else required.strip().lower()
    return states


def _is_sensitive_feature(name: str) -> bool:
    return any(name.startswith(prefix) for prefix in SENSITIVE_FEATURE_PREFIXES)


def _verified_feature_states(raw: bytes) -> dict[str, str | None]:
    states = _feature_states(raw)
    missing = sorted(set(EXPECTED_OPTIONAL_FEATURES).difference(states))
    if missing:
        raise GateError(
            "Final AAB is missing explicit optional hardware declarations: "
            + ", ".join(missing)
            + "."
        )

    required_or_unproven = sorted(
        name
        for name, required in states.items()
        if _is_sensitive_feature(name) and required != "false"
    )
    if required_or_unproven:
        details = ", ".join(
            f"{name}={states[name] or 'MISSING_DEFAULTS_TO_TRUE'}"
            for name in required_or_unproven
        )
        raise GateError(
            "Final AAB declares sensitive hardware as required or cannot prove "
            f"it optional: {details}."
        )
    return states


def _write_evidence(
    *,
    text_path: pathlib.Path,
    json_path: pathlib.Path,
    status: str,
    states: dict[str, str | None],
    error: str | None,
) -> None:
    sensitive_states = {
        name: ("MISSING_DEFAULTS_TO_TRUE" if required is None else required)
        for name, required in sorted(states.items())
        if _is_sensitive_feature(name)
    }
    payload = {
        "status": status,
        "source": "bundletool dump manifest from final signed AAB base module",
        "policy": "camera, microphone, location, and Bluetooth features must be explicitly optional",
        "expectedOptionalFeatures": list(EXPECTED_OPTIONAL_FEATURES),
        "sensitiveFeatureStates": sensitive_states,
        "error": error,
    }
    lines = [
        f"ANDROID_FINAL_AAB_OPTIONAL_HARDWARE_GATE={status}",
        "SOURCE=FINAL_SIGNED_AAB_BASE_MANIFEST_VIA_PINNED_BUNDLETOOL",
        "POLICY=CAMERA_MICROPHONE_LOCATION_BLUETOOTH_EXPLICIT_REQUIRED_FALSE",
    ]
    for name in sorted(sensitive_states):
        evidence_name = name.upper().replace(".", "_")
        lines.append(f"FEATURE_{evidence_name}={sensitive_states[name]}")
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
    feature_nodes = "\n".join(
        f'  <uses-feature android:name="{name}" android:required="false" />'
        for name in EXPECTED_OPTIONAL_FEATURES
    )
    valid = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
        f"{feature_nodes}\n"
        '  <uses-feature android:name="android.hardware.touchscreen" />\n'
        "</manifest>"
    ).encode()
    states = _verified_feature_states(valid)
    if states["android.hardware.camera.any"] != "false":
        raise AssertionError("valid optional-feature fixture was not accepted")

    invalid_cases = (
        valid.replace(
            b'android.hardware.camera.any" android:required="false"',
            b'android.hardware.camera.any" android:required="true"',
        ),
        valid.replace(
            b'android.hardware.microphone" android:required="false"',
            b'android.hardware.microphone"',
        ),
        valid.replace(
            b'  <uses-feature android:name="android.hardware.location" '
            b'android:required="false" />\n',
            b"",
        ),
        valid.replace(
            b"</manifest>",
            b'  <uses-feature android:name="android.hardware.camera.front" '
            b'android:required="true" />\n</manifest>',
        ),
        b"<manifest>",
    )
    for raw in invalid_cases:
        try:
            _verified_feature_states(raw)
        except GateError:
            continue
        raise AssertionError("invalid optional-feature fixture was accepted")

    with tempfile.TemporaryDirectory(prefix="bil-optional-hardware-") as temp_dir:
        text_path = pathlib.Path(temp_dir) / "evidence.txt"
        json_path = pathlib.Path(temp_dir) / "evidence.json"
        _write_evidence(
            text_path=text_path,
            json_path=json_path,
            status="PASS",
            states=states,
            error=None,
        )
        if "ANDROID_FINAL_AAB_OPTIONAL_HARDWARE_GATE=PASS" not in (
            text_path.read_text(encoding="utf-8")
        ):
            raise AssertionError("text evidence was not written")
        evidence = json.loads(json_path.read_text(encoding="utf-8"))
        if evidence["status"] != "PASS":
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
        print("ANDROID_OPTIONAL_DEVICE_FEATURES_SELF_TEST=PASS")
        return 0
    if args.manifest is None:
        parser.error("--manifest is required unless --self-test is used")
    if args.text_evidence is None or args.json_evidence is None:
        parser.error("--text-evidence and --json-evidence are required")

    states: dict[str, str | None] = {}
    try:
        raw_manifest = args.manifest.read_bytes()
        states = _feature_states(raw_manifest)
        _verified_feature_states(raw_manifest)
    except (OSError, GateError) as error:
        _write_evidence(
            text_path=args.text_evidence,
            json_path=args.json_evidence,
            status="FAIL",
            states=states,
            error=str(error),
        )
        raise SystemExit(str(error)) from error

    _write_evidence(
        text_path=args.text_evidence,
        json_path=args.json_evidence,
        status="PASS",
        states=states,
        error=None,
    )
    print("ANDROID_FINAL_AAB_OPTIONAL_HARDWARE_GATE=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
