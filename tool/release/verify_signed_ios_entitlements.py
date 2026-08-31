#!/usr/bin/env python3
"""Fail-closed verifier for entitlements extracted from a signed iOS app."""

from __future__ import annotations

import argparse
import pathlib
import plistlib


_CSMAGIC_EMBEDDED_ENTITLEMENTS = 0xFADE7171
_CSMAGIC_EMBEDDED_DER_ENTITLEMENTS = 0xFADE7172
_GENERIC_BLOB_HEADER_BYTES = 8


def _decoded_entitlements(raw: bytes) -> dict[str, object]:
    if len(raw) < _GENERIC_BLOB_HEADER_BYTES:
        raise ValueError("Signed-entitlements evidence is empty or truncated.")

    magic = int.from_bytes(raw[:4], byteorder="big")
    if magic == _CSMAGIC_EMBEDDED_ENTITLEMENTS:
        declared_length = int.from_bytes(raw[4:8], byteorder="big")
        if declared_length != len(raw):
            raise ValueError("Signed-entitlements blob length is inconsistent.")
        raw = raw[_GENERIC_BLOB_HEADER_BYTES:]
    elif magic == _CSMAGIC_EMBEDDED_DER_ENTITLEMENTS:
        raise ValueError("DER-only entitlement evidence is not reviewable as a plist.")

    try:
        decoded = plistlib.loads(raw)
    except plistlib.InvalidFileException as error:
        raise ValueError("Signed-entitlements evidence is not a valid plist.") from error
    if not isinstance(decoded, dict):
        raise ValueError("Signed-entitlements plist must contain a dictionary.")
    return decoded


def _verify(
    entitlements: dict[str, object],
    *,
    team_id: str,
    bundle_id: str,
) -> None:
    expected_app_id = f"{team_id}.{bundle_id}"
    if entitlements.get("application-identifier") != expected_app_id:
        raise ValueError("Signed IPA has the wrong application identifier.")
    if entitlements.get("com.apple.developer.healthkit") is not True:
        raise ValueError("Signed IPA does not authorize HealthKit.")

    apple_sign_in = entitlements.get("com.apple.developer.applesignin")
    if not isinstance(apple_sign_in, list) or "Default" not in apple_sign_in:
        raise ValueError("Signed IPA does not authorize Sign in with Apple.")
    if entitlements.get("aps-environment") != "production":
        raise ValueError("Signed IPA does not authorize production push.")
    if entitlements.get("get-task-allow", False) is not False:
        raise ValueError("Signed IPA unexpectedly enables get-task-allow.")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--entitlements", required=True, type=pathlib.Path)
    parser.add_argument("--team-id", required=True)
    parser.add_argument("--bundle-id", required=True)
    args = parser.parse_args()

    if not args.team_id.strip():
        raise SystemExit("Apple team ID is required.")
    if not args.bundle_id.strip():
        raise SystemExit("Bundle ID is required.")

    try:
        entitlements = _decoded_entitlements(args.entitlements.read_bytes())
        _verify(
            entitlements,
            team_id=args.team_id,
            bundle_id=args.bundle_id,
        )
    except (OSError, ValueError) as error:
        raise SystemExit(str(error)) from error

    print("SIGNED_IPA_ENTITLEMENTS_GATE=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
