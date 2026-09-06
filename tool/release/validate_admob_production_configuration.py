#!/usr/bin/env python3
"""Fail closed unless one verified production AdMob owner configures both apps.

AdMob identifiers are public configuration, but this gate deliberately reports
only variable names and pass/fail labels. It never echoes account identifiers.
"""

from __future__ import annotations

import argparse
import os
import pathlib
import plistlib
import re
import sys
import xml.etree.ElementTree as element_tree
from dataclasses import dataclass
from typing import Mapping


READY_VARIABLE = "BIL_ADMOB_PRODUCTION_READY"
PUBLISHER_VARIABLE = "BIL_ADMOB_PUBLISHER_ID"
ANDROID_APP_VARIABLE = "BIL_ADMOB_ANDROID_APP_ID"
ANDROID_BANNER_VARIABLE = "BIL_ADMOB_ANDROID_BANNER_ID"
IOS_APP_VARIABLE = "BIL_ADMOB_IOS_APP_ID"
IOS_BANNER_VARIABLE = "BIL_ADMOB_IOS_BANNER_ID"
CONFIGURATION_VARIABLES = (
    PUBLISHER_VARIABLE,
    ANDROID_APP_VARIABLE,
    ANDROID_BANNER_VARIABLE,
    IOS_APP_VARIABLE,
    IOS_BANNER_VARIABLE,
)

_PUBLISHER_PATTERN = re.compile(r"pub-([0-9]{16})")
_APP_PATTERN = re.compile(r"ca-app-pub-([0-9]{16})~([0-9]{10})")
_BANNER_PATTERN = re.compile(r"ca-app-pub-([0-9]{16})/([0-9]{10})")
_ANDROID_NAMESPACE = "http://schemas.android.com/apk/res/android"
_ANDROID_ADMOB_APPLICATION_ID_NAME = "com.google.android.gms.ads.APPLICATION_ID"
_BLOCKED_PUBLISHERS = frozenset(
    {
        "0000000000000000",
        # Google's documented sample publisher must never enter production.
        "3940256099942544",
    }
)


class GateError(RuntimeError):
    """Raised when the production AdMob configuration cannot be proven."""


@dataclass(frozen=True)
class AdMobProductionConfiguration:
    publisher_id: str
    android_app_id: str
    android_banner_id: str
    ios_app_id: str
    ios_banner_id: str


def _require_exact_value(environment: Mapping[str, str], name: str) -> str:
    value = environment.get(name, "")
    if not value:
        raise GateError(f"OWNER_INPUT_REQUIRED: {name}")
    if value != value.strip():
        raise GateError(f"{name} contains leading or trailing whitespace.")
    return value


def _parse_identifier(
    *,
    name: str,
    value: str,
    pattern: re.Pattern[str],
) -> tuple[str, str | None]:
    match = pattern.fullmatch(value)
    if match is None:
        raise GateError(f"{name} is not an exact production AdMob identifier.")
    publisher = match.group(1)
    suffix = match.group(2) if match.lastindex == 2 else None
    if publisher in _BLOCKED_PUBLISHERS:
        raise GateError(f"{name} uses a zero or Google sample publisher.")
    if suffix == "0000000000":
        raise GateError(f"{name} uses a zero identifier suffix.")
    return publisher, suffix


def validate_configuration(
    environment: Mapping[str, str],
) -> AdMobProductionConfiguration:
    if environment.get(READY_VARIABLE, "") != "true":
        raise GateError(
            "OWNER_VERIFICATION_REQUIRED: BIL_ADMOB_PRODUCTION_READY must be "
            "exactly 'true' only after provider, UMP, and app-ads.txt verification."
        )

    values = {
        name: _require_exact_value(environment, name)
        for name in CONFIGURATION_VARIABLES
    }
    publisher_match = _PUBLISHER_PATTERN.fullmatch(values[PUBLISHER_VARIABLE])
    if publisher_match is None:
        raise GateError(
            "BIL_ADMOB_PUBLISHER_ID is not an exact production publisher ID."
        )
    publisher = publisher_match.group(1)
    if publisher in _BLOCKED_PUBLISHERS:
        raise GateError(
            "BIL_ADMOB_PUBLISHER_ID uses a zero or Google sample publisher."
        )

    identifier_publishers = {
        ANDROID_APP_VARIABLE: _parse_identifier(
            name=ANDROID_APP_VARIABLE,
            value=values[ANDROID_APP_VARIABLE],
            pattern=_APP_PATTERN,
        )[0],
        ANDROID_BANNER_VARIABLE: _parse_identifier(
            name=ANDROID_BANNER_VARIABLE,
            value=values[ANDROID_BANNER_VARIABLE],
            pattern=_BANNER_PATTERN,
        )[0],
        IOS_APP_VARIABLE: _parse_identifier(
            name=IOS_APP_VARIABLE,
            value=values[IOS_APP_VARIABLE],
            pattern=_APP_PATTERN,
        )[0],
        IOS_BANNER_VARIABLE: _parse_identifier(
            name=IOS_BANNER_VARIABLE,
            value=values[IOS_BANNER_VARIABLE],
            pattern=_BANNER_PATTERN,
        )[0],
    }
    mismatched = sorted(
        name
        for name, identifier_publisher in identifier_publishers.items()
        if identifier_publisher != publisher
    )
    if mismatched:
        raise GateError(
            "AdMob identifiers do not share BIL_ADMOB_PUBLISHER_ID: "
            + ", ".join(mismatched)
        )

    return AdMobProductionConfiguration(
        publisher_id=values[PUBLISHER_VARIABLE],
        android_app_id=values[ANDROID_APP_VARIABLE],
        android_banner_id=values[ANDROID_BANNER_VARIABLE],
        ios_app_id=values[IOS_APP_VARIABLE],
        ios_banner_id=values[IOS_BANNER_VARIABLE],
    )


def validate_ios_info_plist(
    path: pathlib.Path,
    configuration: AdMobProductionConfiguration,
) -> None:
    try:
        with path.open("rb") as handle:
            payload = plistlib.load(handle)
    except (OSError, plistlib.InvalidFileException) as error:
        raise GateError(f"Unable to read final iOS Info.plist: {error}") from error
    native_app_id = payload.get("GADApplicationIdentifier")
    if native_app_id != configuration.ios_app_id:
        raise GateError(
            "Final iOS Info.plist does not contain the validated "
            "BIL_ADMOB_IOS_APP_ID."
        )


def validate_android_manifest(
    path: pathlib.Path,
    configuration: AdMobProductionConfiguration,
) -> None:
    try:
        root = element_tree.parse(path).getroot()
    except (OSError, element_tree.ParseError) as error:
        raise GateError(f"Unable to read final Android manifest: {error}") from error

    name_attribute = f"{{{_ANDROID_NAMESPACE}}}name"
    value_attribute = f"{{{_ANDROID_NAMESPACE}}}value"
    matching_metadata = [
        element
        for element in root.findall(".//application/meta-data")
        if element.get(name_attribute) == _ANDROID_ADMOB_APPLICATION_ID_NAME
    ]
    if len(matching_metadata) != 1:
        raise GateError(
            "Final Android manifest must contain exactly one AdMob "
            "APPLICATION_ID metadata entry."
        )
    if matching_metadata[0].get(value_attribute) != configuration.android_app_id:
        raise GateError(
            "Final Android manifest AdMob APPLICATION_ID does not match the "
            "validated BIL_ADMOB_ANDROID_APP_ID."
        )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--ios-info-plist",
        type=pathlib.Path,
        help="also verify GADApplicationIdentifier in the final signed app",
    )
    parser.add_argument(
        "--android-manifest",
        type=pathlib.Path,
        help="also verify the AdMob application ID in the final AAB manifest",
    )
    args = parser.parse_args(argv)
    try:
        configuration = validate_configuration(os.environ)
        if args.ios_info_plist is not None:
            validate_ios_info_plist(args.ios_info_plist, configuration)
        if args.android_manifest is not None:
            validate_android_manifest(args.android_manifest, configuration)
    except GateError as error:
        print(str(error), file=sys.stderr)
        return 1

    print("ADMOB_RELEASE_INPUT_FORMAT_GATE=PASS")
    print("ADMOB_SINGLE_PUBLISHER_CONSISTENCY_GATE=PASS")
    if args.ios_info_plist is not None:
        print("ADMOB_IOS_PRODUCTION_CONFIGURATION_GATE=PASS")
    if args.android_manifest is not None:
        print("ADMOB_ANDROID_PRODUCTION_CONFIGURATION_GATE=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
