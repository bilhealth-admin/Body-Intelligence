#!/usr/bin/env python3
"""Fail-closed verifier for entitlements extracted from a signed iOS app."""

from __future__ import annotations

import argparse
import datetime as dt
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


def _decoded_embedded_profile(raw: bytes) -> dict[str, object]:
    try:
        decoded = plistlib.loads(raw)
    except plistlib.InvalidFileException as error:
        raise ValueError(
            "Decoded embedded provisioning-profile evidence is not a valid plist."
        ) from error
    if not isinstance(decoded, dict):
        raise ValueError(
            "Decoded embedded provisioning-profile plist must contain a dictionary."
        )
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
    associated_domains = entitlements.get("com.apple.developer.associated-domains")
    if (
        not isinstance(associated_domains, list)
        or "applinks:www.bilhealth.com" not in associated_domains
    ):
        raise ValueError(
            "Signed IPA does not authorize applinks:www.bilhealth.com."
        )
    if entitlements.get("aps-environment") != "production":
        raise ValueError("Signed IPA does not authorize production push.")
    if (
        entitlements.get(
            "com.apple.developer.devicecheck.appattest-environment"
        )
        != "production"
    ):
        raise ValueError("Signed IPA does not authorize production App Attest.")
    if entitlements.get("get-task-allow", False) is not False:
        raise ValueError("Signed IPA unexpectedly enables get-task-allow.")


def _verify_embedded_profile(
    profile: dict[str, object],
    *,
    signed_entitlements: dict[str, object],
    team_id: str,
    bundle_id: str,
) -> None:
    team_identifiers = profile.get("TeamIdentifier")
    if not isinstance(team_identifiers, list) or team_id not in team_identifiers:
        raise ValueError("Embedded profile does not belong to the expected Apple team.")

    expiry = profile.get("ExpirationDate")
    if not isinstance(expiry, dt.datetime):
        raise ValueError("Embedded profile has no reviewable expiration date.")
    if expiry.tzinfo is None:
        expiry = expiry.replace(tzinfo=dt.timezone.utc)
    if expiry <= dt.datetime.now(dt.timezone.utc):
        raise ValueError("Embedded profile is expired.")

    profile_entitlements = profile.get("Entitlements")
    if not isinstance(profile_entitlements, dict):
        raise ValueError("Embedded profile has no entitlement dictionary.")

    expected_app_id = f"{team_id}.{bundle_id}"
    if profile_entitlements.get("application-identifier") != expected_app_id:
        raise ValueError("Embedded profile has the wrong application identifier.")
    if profile_entitlements.get("com.apple.developer.healthkit") is not True:
        raise ValueError("Embedded profile does not authorize HealthKit.")

    apple_sign_in = profile_entitlements.get("com.apple.developer.applesignin")
    if not isinstance(apple_sign_in, list) or "Default" not in apple_sign_in:
        raise ValueError("Embedded profile does not authorize Sign in with Apple.")

    associated_domains = profile_entitlements.get(
        "com.apple.developer.associated-domains"
    )
    if isinstance(associated_domains, str):
        associated_domain_values = {associated_domains}
    elif isinstance(associated_domains, list):
        associated_domain_values = {
            value for value in associated_domains if isinstance(value, str)
        }
    else:
        associated_domain_values = set()
    signed_domains = signed_entitlements.get(
        "com.apple.developer.associated-domains"
    )
    if not isinstance(signed_domains, list):
        raise ValueError("Signed IPA has no reviewable Associated Domains list.")
    if "*" not in associated_domain_values and not set(signed_domains).issubset(
        associated_domain_values
    ):
        raise ValueError(
            "Embedded profile does not authorize the signed Associated Domains."
        )

    if profile_entitlements.get("aps-environment") != "production":
        raise ValueError("Embedded profile does not authorize production push.")

    app_attest = profile_entitlements.get(
        "com.apple.developer.devicecheck.appattest-environment"
    )
    if isinstance(app_attest, str):
        app_attest_environments = {app_attest}
    elif isinstance(app_attest, list):
        app_attest_environments = {
            value for value in app_attest if isinstance(value, str)
        }
    else:
        app_attest_environments = set()
    if "production" not in app_attest_environments:
        raise ValueError(
            "Embedded profile does not authorize production App Attest."
        )
    if profile_entitlements.get("get-task-allow", False) is not False:
        raise ValueError("Embedded profile unexpectedly enables get-task-allow.")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--entitlements", required=True, type=pathlib.Path)
    parser.add_argument("--embedded-profile", required=True, type=pathlib.Path)
    parser.add_argument("--team-id", required=True)
    parser.add_argument("--bundle-id", required=True)
    args = parser.parse_args()

    if not args.team_id.strip():
        raise SystemExit("Apple team ID is required.")
    if not args.bundle_id.strip():
        raise SystemExit("Bundle ID is required.")

    try:
        entitlements = _decoded_entitlements(args.entitlements.read_bytes())
        embedded_profile = _decoded_embedded_profile(
            args.embedded_profile.read_bytes()
        )
        _verify(
            entitlements,
            team_id=args.team_id,
            bundle_id=args.bundle_id,
        )
        _verify_embedded_profile(
            embedded_profile,
            signed_entitlements=entitlements,
            team_id=args.team_id,
            bundle_id=args.bundle_id,
        )
    except (OSError, ValueError) as error:
        raise SystemExit(str(error)) from error

    print("SIGNED_IPA_ENTITLEMENTS_GATE=PASS")
    print("SIGNED_IPA_EMBEDDED_PROFILE_GATE=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
