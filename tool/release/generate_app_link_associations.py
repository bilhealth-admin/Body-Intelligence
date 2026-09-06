#!/usr/bin/env python3
"""Generate production AASA and Digital Asset Links from owner-supplied IDs.

This tool deliberately contains no Apple Team ID and no signing-certificate
fingerprint. Both values must come from the production account owner at run
time; generated files are deployment inputs and are intentionally gitignored.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import re
import tempfile


BUNDLE_ID = "com.bilhealth.bodyintelligencelog"
ANDROID_PACKAGE_NAME = "com.bilhealth.bodyintelligencelog"
APP_LINK_PATHS = ("/auth/callback", "/auth/reset-password")
_TEAM_ID_PATTERN = re.compile(r"^[A-Z0-9]{10}$")
_SHA256_PATTERN = re.compile(r"^[A-F0-9]{64}$")
_REJECTED_MARKERS = ("EXAMPLE", "PLACEHOLDER", "REPLACE", "YOUR_")


class InputError(ValueError):
    pass


def _apple_team_id(raw: str | None) -> str:
    value = (raw or "").strip().upper()
    if not value:
        raise InputError("OWNER_INPUT_REQUIRED: APPLE_TEAM_ID")
    if not _TEAM_ID_PATTERN.fullmatch(value):
        raise InputError(
            "APPLE_TEAM_ID must be the exact 10-character production Team ID."
        )
    if any(marker in value for marker in _REJECTED_MARKERS):
        raise InputError("APPLE_TEAM_ID contains a placeholder marker.")
    return value


def _play_app_signing_fingerprint(raw: str | None) -> str:
    if not (raw or "").strip():
        raise InputError("OWNER_INPUT_REQUIRED: PLAY_APP_SIGNING_SHA256")
    compact = re.sub(r"[:\s]", "", raw or "").upper()
    if not _SHA256_PATTERN.fullmatch(compact):
        raise InputError(
            "PLAY_APP_SIGNING_SHA256 must be the 32-byte SHA-256 certificate "
            "fingerprint from Play Console > App integrity."
        )
    if len(set(compact)) < 4:
        raise InputError(
            "PLAY_APP_SIGNING_SHA256 looks like placeholder data; use the Play "
            "App Signing certificate, not the upload certificate."
        )
    return ":".join(compact[index : index + 2] for index in range(0, 64, 2))


def _documents(*, team_id: str, fingerprint: str) -> tuple[object, object]:
    app_id = f"{team_id}.{BUNDLE_ID}"
    aasa = {
        "applinks": {
            "details": [
                {
                    "appIDs": [app_id],
                    "components": [
                        {"/": path, "comment": "BIL authenticated return"}
                        for path in APP_LINK_PATHS
                    ],
                }
            ]
        }
    }
    assetlinks = [
        {
            "relation": ["delegate_permission/common.handle_all_urls"],
            "target": {
                "namespace": "android_app",
                "package_name": ANDROID_PACKAGE_NAME,
                "sha256_cert_fingerprints": [fingerprint],
            },
        }
    ]
    return aasa, assetlinks


def _write_json_atomic(path: pathlib.Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.tmp")
    temporary.write_text(
        json.dumps(value, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    temporary.replace(path)


def _validate_outputs(
    *,
    aasa_path: pathlib.Path,
    assetlinks_path: pathlib.Path,
    team_id: str,
    fingerprint: str,
) -> None:
    aasa = json.loads(aasa_path.read_text(encoding="utf-8"))
    assetlinks = json.loads(assetlinks_path.read_text(encoding="utf-8"))
    expected_aasa, expected_assetlinks = _documents(
        team_id=team_id,
        fingerprint=fingerprint,
    )
    if aasa != expected_aasa or assetlinks != expected_assetlinks:
        raise InputError("Generated association documents failed exact read-back.")


def _generate(
    *,
    output_dir: pathlib.Path,
    apple_team_id: str | None,
    play_app_signing_sha256: str | None,
) -> tuple[pathlib.Path, pathlib.Path]:
    team_id = _apple_team_id(apple_team_id)
    fingerprint = _play_app_signing_fingerprint(play_app_signing_sha256)
    aasa, assetlinks = _documents(team_id=team_id, fingerprint=fingerprint)
    aasa_path = output_dir / "apple-app-site-association"
    assetlinks_path = output_dir / "assetlinks.json"
    _write_json_atomic(aasa_path, aasa)
    _write_json_atomic(assetlinks_path, assetlinks)
    _validate_outputs(
        aasa_path=aasa_path,
        assetlinks_path=assetlinks_path,
        team_id=team_id,
        fingerprint=fingerprint,
    )
    return aasa_path, assetlinks_path


def _self_test() -> None:
    fixture_team_id = "A1B2C3D4E5"
    fixture_fingerprint = hashlib.sha256(
        b"BIL association generator unit-test fixture only"
    ).hexdigest()
    with tempfile.TemporaryDirectory(prefix="bil-app-links-") as temp_dir:
        aasa_path, assetlinks_path = _generate(
            output_dir=pathlib.Path(temp_dir),
            apple_team_id=fixture_team_id,
            play_app_signing_sha256=fixture_fingerprint,
        )
        if not aasa_path.is_file() or not assetlinks_path.is_file():
            raise AssertionError("association generator did not create both files")
    for rejected in (None, "", "YOUR_TEAM"):
        try:
            _apple_team_id(rejected)
        except InputError:
            continue
        raise AssertionError("invalid Apple Team ID was accepted")
    try:
        _play_app_signing_fingerprint("00" * 32)
    except InputError:
        return
    raise AssertionError("placeholder fingerprint was accepted")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output-dir",
        type=pathlib.Path,
        default=pathlib.Path("public_site/.well-known"),
    )
    parser.add_argument(
        "--apple-team-id",
        default=os.environ.get("APPLE_TEAM_ID"),
        help="production Apple Team ID; defaults to APPLE_TEAM_ID",
    )
    parser.add_argument(
        "--play-app-signing-sha256",
        default=os.environ.get("PLAY_APP_SIGNING_SHA256"),
        help=(
            "Play App Signing certificate SHA-256; defaults to "
            "PLAY_APP_SIGNING_SHA256"
        ),
    )
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        _self_test()
        print("SELF_TEST=PASS")
        return 0

    try:
        aasa_path, assetlinks_path = _generate(
            output_dir=args.output_dir,
            apple_team_id=args.apple_team_id,
            play_app_signing_sha256=args.play_app_signing_sha256,
        )
    except (InputError, OSError, json.JSONDecodeError) as error:
        raise SystemExit(str(error)) from error

    print(f"AASA_OUTPUT={aasa_path}")
    print(f"ASSETLINKS_OUTPUT={assetlinks_path}")
    print("PUBLIC_APP_LINK_ASSOCIATIONS_GATE=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
