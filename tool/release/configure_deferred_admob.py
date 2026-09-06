#!/usr/bin/env python3
"""Prepare or verify native metadata for a release with AdMob deferred.

Every operation requires one explicit path. Preparation mutates only that path;
verification is read-only. This intentionally does not alter Dart build flags,
workflows, signing settings, capabilities, or unrelated native metadata.
"""

from __future__ import annotations

import argparse
import os
import pathlib
import plistlib
import re
import sys
import tempfile
import xml.etree.ElementTree as element_tree
from collections.abc import Sequence


ANDROID_NAMESPACE = "http://schemas.android.com/apk/res/android"
TOOLS_NAMESPACE = "http://schemas.android.com/tools"
ANDROID_NAME = f"{{{ANDROID_NAMESPACE}}}name"
TOOLS_NODE = f"{{{TOOLS_NAMESPACE}}}node"

ANDROID_APPLICATION_ID = "com.google.android.gms.ads.APPLICATION_ID"
ANDROID_INTEGRATION_MANAGER = "com.google.android.gms.ads.INTEGRATION_MANAGER"
ANDROID_INIT_PROVIDER = "com.google.android.gms.ads.MobileAdsInitProvider"
IOS_APPLICATION_ID = "GADApplicationIdentifier"
IOS_INTEGRATION_MANAGER = "GADIntegrationManager"

FORBIDDEN_ANDROID_PERMISSIONS = frozenset(
    {
        "com.google.android.gms.permission.AD_ID",
        "android.permission.ACCESS_ADSERVICES_AD_ID",
        "android.permission.ACCESS_ADSERVICES_ATTRIBUTION",
        "android.permission.ACCESS_ADSERVICES_TOPICS",
    }
)

_ADMOB_IDENTIFIER = re.compile(
    r"ca-app-pub-[0-9]{16}(?:~|/)[0-9]{10}",
    flags=re.ASCII,
)


class DeferredAdMobError(RuntimeError):
    """Raised when deferred native metadata cannot be proven."""


def _local_name(tag: object) -> str:
    return tag.rsplit("}", 1)[-1] if isinstance(tag, str) else ""


def _parse_android(path: pathlib.Path) -> element_tree.ElementTree:
    parser = element_tree.XMLParser(
        target=element_tree.TreeBuilder(insert_comments=True)
    )
    try:
        return element_tree.parse(path, parser=parser)
    except (OSError, element_tree.ParseError) as error:
        raise DeferredAdMobError(
            f"Unable to read Android manifest: {error}"
        ) from error


def _android_application(root: element_tree.Element) -> element_tree.Element:
    applications = [
        child for child in root if _local_name(child.tag) == "application"
    ]
    if len(applications) != 1:
        raise DeferredAdMobError(
            "Android manifest must contain exactly one application element."
        )
    return applications[0]


def _atomic_write_bytes(path: pathlib.Path, payload: bytes) -> None:
    try:
        descriptor, temporary_name = tempfile.mkstemp(
            prefix=f".{path.name}.",
            suffix=".tmp",
            dir=path.parent,
        )
        temporary_path = pathlib.Path(temporary_name)
        try:
            with os.fdopen(descriptor, "wb") as handle:
                handle.write(payload)
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temporary_path, path)
        finally:
            temporary_path.unlink(missing_ok=True)
    except OSError as error:
        raise DeferredAdMobError(f"Unable to update native metadata: {error}") from error


def _serialize_android(tree: element_tree.ElementTree) -> bytes:
    element_tree.register_namespace("android", ANDROID_NAMESPACE)
    element_tree.register_namespace("tools", TOOLS_NAMESPACE)
    element_tree.indent(tree, space="    ")
    root = tree.getroot()
    body = element_tree.tostring(root, encoding="utf-8", xml_declaration=True)
    return body + (b"" if body.endswith(b"\n") else b"\n")


def prepare_android_source_manifest(path: pathlib.Path) -> None:
    tree = _parse_android(path)
    application = _android_application(tree.getroot())

    integration_entries = [
        child
        for child in application
        if _local_name(child.tag) == "meta-data"
        and child.get(ANDROID_NAME) == ANDROID_INTEGRATION_MANAGER
    ]
    if integration_entries:
        raise DeferredAdMobError(
            "Android INTEGRATION_MANAGER bypass is forbidden in deferred mode."
        )

    for child in list(application):
        if (
            _local_name(child.tag) == "meta-data"
            and child.get(ANDROID_NAME) == ANDROID_APPLICATION_ID
        ):
            application.remove(child)

    matching_providers = [
        child
        for child in application
        if _local_name(child.tag) == "provider"
        and child.get(ANDROID_NAME) == ANDROID_INIT_PROVIDER
    ]
    insertion_index = (
        list(application).index(matching_providers[0])
        if matching_providers
        else 0
    )
    for provider in matching_providers:
        application.remove(provider)
    removal = element_tree.Element(
        "provider",
        {
            ANDROID_NAME: ANDROID_INIT_PROVIDER,
            TOOLS_NODE: "remove",
        },
    )
    application.insert(insertion_index, removal)

    _atomic_write_bytes(path, _serialize_android(tree))


def _load_plist(path: pathlib.Path) -> tuple[dict[str, object], plistlib.PlistFormat]:
    try:
        raw = path.read_bytes()
        payload = plistlib.loads(raw)
    except (OSError, plistlib.InvalidFileException) as error:
        raise DeferredAdMobError(f"Unable to read iOS plist: {error}") from error
    if not isinstance(payload, dict):
        raise DeferredAdMobError("iOS plist root must be a dictionary.")
    format_value = (
        plistlib.FMT_BINARY if raw.startswith(b"bplist00") else plistlib.FMT_XML
    )
    return payload, format_value


def prepare_ios_source_plist(path: pathlib.Path) -> None:
    payload, format_value = _load_plist(path)
    if IOS_INTEGRATION_MANAGER in payload:
        raise DeferredAdMobError(
            "iOS GADIntegrationManager bypass is forbidden in deferred mode."
        )
    payload.pop(IOS_APPLICATION_ID, None)
    encoded = plistlib.dumps(payload, fmt=format_value, sort_keys=False)
    _atomic_write_bytes(path, encoded)


def _android_metadata(application: element_tree.Element, name: str) -> list[element_tree.Element]:
    return [
        child
        for child in application
        if _local_name(child.tag) == "meta-data" and child.get(ANDROID_NAME) == name
    ]


def verify_android_merged_manifest(path: pathlib.Path) -> None:
    tree = _parse_android(path)
    root = tree.getroot()
    application = _android_application(root)

    if _android_metadata(application, ANDROID_APPLICATION_ID):
        raise DeferredAdMobError(
            "Final Android manifest still contains AdMob APPLICATION_ID metadata."
        )
    if _android_metadata(application, ANDROID_INTEGRATION_MANAGER):
        raise DeferredAdMobError(
            "Final Android manifest contains forbidden INTEGRATION_MANAGER metadata."
        )

    providers = [
        element
        for element in application.iter()
        if _local_name(element.tag) == "provider"
        and (element.get(ANDROID_NAME) or "").endswith(".MobileAdsInitProvider")
    ]
    if providers:
        raise DeferredAdMobError(
            "Final Android manifest still contains MobileAdsInitProvider."
        )

    present_permissions = {
        element.get(ANDROID_NAME)
        for element in root
        if _local_name(element.tag) in {"uses-permission", "uses-permission-sdk-23"}
        and element.get(ANDROID_NAME) in FORBIDDEN_ANDROID_PERMISSIONS
    }
    if present_permissions:
        raise DeferredAdMobError(
            "Final Android manifest contains deferred-advertising permissions: "
            + ", ".join(sorted(present_permissions))
        )

    configured_identifiers = [
        value
        for element in root.iter()
        for value in element.attrib.values()
        if _ADMOB_IDENTIFIER.fullmatch(value.strip())
    ]
    if configured_identifiers:
        raise DeferredAdMobError(
            "Final Android manifest still contains a configured AdMob identifier."
        )


def verify_ios_final_plist(path: pathlib.Path) -> None:
    payload, _ = _load_plist(path)
    if IOS_APPLICATION_ID in payload:
        raise DeferredAdMobError(
            "Final iOS Info.plist still contains GADApplicationIdentifier."
        )
    if IOS_INTEGRATION_MANAGER in payload:
        raise DeferredAdMobError(
            "Final iOS Info.plist contains forbidden GADIntegrationManager."
        )
    configured_identifiers = [
        value
        for value in _plist_strings(payload)
        if _ADMOB_IDENTIFIER.fullmatch(value.strip())
    ]
    if configured_identifiers:
        raise DeferredAdMobError(
            "Final iOS Info.plist still contains a configured AdMob identifier."
        )


def _plist_strings(value: object) -> list[str]:
    if isinstance(value, str):
        return [value]
    if isinstance(value, dict):
        return [
            string
            for nested in value.values()
            for string in _plist_strings(nested)
        ]
    if isinstance(value, (list, tuple)):
        return [
            string
            for nested in value
            for string in _plist_strings(nested)
        ]
    return []


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Prepare or verify one explicit deferred-AdMob native file."
    )
    operation = parser.add_mutually_exclusive_group(required=True)
    operation.add_argument(
        "--prepare-android-source-manifest",
        type=pathlib.Path,
        metavar="PATH",
    )
    operation.add_argument(
        "--prepare-ios-source-plist",
        type=pathlib.Path,
        metavar="PATH",
    )
    operation.add_argument(
        "--verify-android-merged-manifest",
        type=pathlib.Path,
        metavar="PATH",
    )
    operation.add_argument(
        "--verify-ios-final-plist",
        type=pathlib.Path,
        metavar="PATH",
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        if args.prepare_android_source_manifest is not None:
            prepare_android_source_manifest(args.prepare_android_source_manifest)
            print("ADMOB_DEFERRED_ANDROID_SOURCE_PREPARE=PASS")
            print("ADMOB_DEFERRED_ANDROID_APPLICATION_ID=REMOVED")
            print("ADMOB_DEFERRED_ANDROID_INIT_PROVIDER=REMOVE_AT_MERGE")
        elif args.prepare_ios_source_plist is not None:
            prepare_ios_source_plist(args.prepare_ios_source_plist)
            print("ADMOB_DEFERRED_IOS_SOURCE_PREPARE=PASS")
            print("ADMOB_DEFERRED_IOS_APPLICATION_ID=REMOVED")
        elif args.verify_android_merged_manifest is not None:
            verify_android_merged_manifest(args.verify_android_merged_manifest)
            print("ADMOB_DEFERRED_ANDROID_FINAL_MANIFEST_GATE=PASS")
            print("ADMOB_DEFERRED_ANDROID_APPLICATION_ID=ABSENT")
            print("ADMOB_DEFERRED_ANDROID_INIT_PROVIDER=ABSENT")
            print("ADMOB_DEFERRED_ANDROID_AD_PERMISSIONS=ABSENT")
        else:
            verify_ios_final_plist(args.verify_ios_final_plist)
            print("ADMOB_DEFERRED_IOS_FINAL_PLIST_GATE=PASS")
            print("ADMOB_DEFERRED_IOS_APPLICATION_ID=ABSENT")
    except DeferredAdMobError as error:
        print(f"ADMOB_DEFERRED_NATIVE_GATE=FAIL: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
