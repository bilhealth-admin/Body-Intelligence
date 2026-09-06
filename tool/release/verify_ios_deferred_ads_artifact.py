#!/usr/bin/env python3
"""Reject native ads code in an iOS artifact built without an AdMob app ID.

Read-only: inspect the final signed .app or IPA, not a source plist. Both
dynamic frameworks and statically linked Objective-C SDK/plugin markers are
checked. This is an artifact gate, not a substitute for an actual launch test.
"""

from __future__ import annotations

import argparse
import contextlib
import pathlib
import plistlib
import sys
import zipfile
from collections.abc import Callable, Iterator
from typing import BinaryIO


MACHO_MAGICS = frozenset(
    bytes.fromhex(value)
    for value in (
        "feedface", "cefaedfe", "feedfacf", "cffaedfe",
        "cafebabe", "bebafeca", "cafebabf", "bfbafeca",
    )
)
FORBIDDEN_COMPONENTS = frozenset(
    {"google_mobile_ads", "googlemobileads", "usermessagingplatform"}
)
FORBIDDEN_NATIVE_MARKERS = (
    b"FLTGoogleMobileAdsPlugin",
    b"GADApplicationVerifyPublisherInitializedCorrectly",
    b"GADInvalidInitializationException",
    b"GADMobileAds",
    b"GoogleMobileAds",
    b"google_mobile_ads",
    b"UserMessagingPlatform",
    b"_OBJC_CLASS_$_GAD",
    b"_OBJC_METACLASS_$_GAD",
    b"_OBJC_CLASS_$_UMP",
    b"_OBJC_METACLASS_$_UMP",
)
DART_API_NAMES = frozenset((b"GoogleMobileAds", b"google_mobile_ads", b"UserMessagingPlatform"))
DART_SNAPSHOT_MARKERS = (
    b"_kDartVmSnapshotData", b"_kDartVmSnapshotInstructions",
    b"_kDartIsolateSnapshotData", b"_kDartIsolateSnapshotInstructions",
)


class ArtifactError(RuntimeError):
    """The final artifact does not establish native deferred-ads isolation."""


def _safe_relative(name: str) -> pathlib.PurePosixPath:
    path = pathlib.PurePosixPath(name)
    if not name or path.is_absolute() or ".." in path.parts or "\\" in name:
        raise ArtifactError("Artifact contains an unsafe path.")
    return path


def _scan_native(stream: BinaryIO, *, flutter_aot: bool = False) -> tuple[bool, str | None]:
    first = stream.read(4)
    if first not in MACHO_MAGICS:
        return False, None
    if flutter_aot:
        # The exact Flutter AOT image retains Dart source URIs/channel names even
        # when its platform plugin is absent. These are not Objective-C linkage.
        # Require all snapshot markers, and still reject native SDK classes and
        # bootstrap symbols here. All other binaries keep the full marker set.
        data = first + stream.read()
        if not all(marker in data for marker in DART_SNAPSHOT_MARKERS):
            raise ArtifactError("Flutter App.framework is not an identified Dart AOT image.")
        for marker in FORBIDDEN_NATIVE_MARKERS:
            if marker not in DART_API_NAMES and marker in data:
                return True, marker.decode("ascii")
        return True, None
    carry = first
    overlap = max(map(len, FORBIDDEN_NATIVE_MARKERS)) - 1
    while chunk := stream.read(1024 * 1024):
        data = carry + chunk
        for marker in FORBIDDEN_NATIVE_MARKERS:
            if marker in data:
                return True, marker.decode("ascii")
        carry = data[-overlap:]
    return True, None


def _verify_path(name: str) -> None:
    path = _safe_relative(name)
    if any(
        part.lower().split(".")[0] in FORBIDDEN_COMPONENTS
        or part.lower().startswith("google_mobile_ads_")
        for part in path.parts
    ):
        raise ArtifactError(f"Deferred artifact retains ads framework/plugin: {name}")


def _verify_files(
    names: list[str],
    open_file: Callable[[str], contextlib.AbstractContextManager[BinaryIO]],
    *,
    expected_build: str | None = None,
) -> int:
    if len(names) != len(set(names)) or len(names) != len({n.casefold() for n in names}):
        raise ArtifactError("Artifact contains duplicate/case-colliding paths.")
    for name in names:
        _verify_path(name)
    if "Info.plist" not in names:
        raise ArtifactError("Final app Info.plist is missing.")
    with open_file("Info.plist") as handle:
        info = plistlib.load(handle)
    if not isinstance(info, dict):
        raise ArtifactError("Final app Info.plist is not a dictionary.")
    if "GADApplicationIdentifier" in info or "GADIntegrationManager" in info:
        raise ArtifactError("Deferred artifact retains AdMob ID or integration bypass.")
    if expected_build is not None and info.get("CFBundleVersion") != expected_build:
        raise ArtifactError("Final app build number does not match the requested build.")
    executable = info.get("CFBundleExecutable")
    if not isinstance(executable, str) or _safe_relative(executable).name != executable:
        raise ArtifactError("Final app executable identity is malformed.")
    if executable not in names:
        raise ArtifactError("Final app executable is missing.")

    native_count = 0
    runner_native = False
    for name in names:
        with open_file(name) as handle:
            native, marker = _scan_native(
                handle, flutter_aot=name == "Frameworks/App.framework/App"
            )
        if marker:
            raise ArtifactError(f"Deferred artifact retains native ads code in {name}: {marker}")
        native_count += int(native)
        if name == executable:
            runner_native = native
    if not runner_native:
        raise ArtifactError("Final app executable is not Mach-O.")
    return native_count


def verify_app(app: pathlib.Path, *, expected_build: str | None = None) -> int:
    root = app.resolve(strict=True)
    if not root.is_dir() or root.suffix != ".app":
        raise ArtifactError("Expected one existing final .app directory.")
    paths: dict[str, pathlib.Path] = {}
    for path in root.rglob("*"):
        resolved = path.resolve(strict=True)
        if not resolved.is_relative_to(root):
            raise ArtifactError("Final app contains a path outside its bundle.")
        if path.is_file():
            paths[path.relative_to(root).as_posix()] = path

    @contextlib.contextmanager
    def open_file(name: str) -> Iterator[BinaryIO]:
        with paths[name].open("rb") as handle:
            yield handle

    return _verify_files(list(paths), open_file, expected_build=expected_build)


def verify_ipa(ipa: pathlib.Path, *, expected_build: str | None = None) -> int:
    with zipfile.ZipFile(ipa) as archive:
        files = [entry for entry in archive.infolist() if not entry.is_dir()]
        all_names = [entry.filename for entry in files]
        if len(all_names) != len({name.casefold() for name in all_names}):
            raise ArtifactError("IPA contains duplicate/case-colliding paths.")
        for entry in files:
            _verify_path(entry.filename)
        roots = {
            path.parts[1]
            for entry in files
            if len((path := pathlib.PurePosixPath(entry.filename)).parts) >= 3
            and path.parts[0] == "Payload"
            and path.parts[1].endswith(".app")
        }
        if len(roots) != 1:
            raise ArtifactError("IPA must contain exactly one Payload application.")
        prefix = f"Payload/{next(iter(roots))}/"
        app_files = [entry for entry in files if entry.filename.startswith(prefix)]
        names = [entry.filename[len(prefix):] for entry in app_files]
        entries = dict(zip(names, app_files))

        @contextlib.contextmanager
        def open_file(name: str) -> Iterator[BinaryIO]:
            with archive.open(entries[name]) as handle:
                yield handle

        return _verify_files(names, open_file, expected_build=expected_build)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--app", type=pathlib.Path)
    source.add_argument("--ipa", type=pathlib.Path)
    parser.add_argument("--expected-build")
    args = parser.parse_args()
    try:
        verifier = verify_app if args.app else verify_ipa
        count = verifier(args.app or args.ipa, expected_build=args.expected_build)
    except (ArtifactError, OSError, ValueError, zipfile.BadZipFile, plistlib.InvalidFileException) as error:
        print(f"IOS_DEFERRED_ADS_ARTIFACT_GATE=FAIL: {error}", file=sys.stderr)
        return 1
    print("IOS_DEFERRED_ADS_ARTIFACT_GATE=PASS")
    print("IOS_DEFERRED_ADS_NATIVE_SDK=ABSENT")
    print(f"IOS_DEFERRED_ADS_MACHO_FILES_SCANNED={count}")
    print("IOS_DEFERRED_ADS_LAUNCH_GATE=NOT_ESTABLISHED_BY_STATIC_SCAN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
