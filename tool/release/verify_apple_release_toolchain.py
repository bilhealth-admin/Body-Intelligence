#!/usr/bin/env python3
"""Fail-closed Apple release toolchain evidence gate.

The release workflow deliberately validates the Xcode selected by the runner.
It never guesses an ``/Applications/Xcode_*.app`` path or switches toolchains.
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import subprocess
import sys
from dataclasses import dataclass


MINIMUM_XCODE_MAJOR = 26
MINIMUM_IOS_SDK_MAJOR = 26
APPLE_SUBMISSION_REQUIREMENTS_URL = "https://developer.apple.com/app-store/submitting/"


class GateError(RuntimeError):
    """Raised when release evidence cannot prove the required toolchain."""


@dataclass(frozen=True)
class CommandEvidence:
    command: tuple[str, ...]
    returncode: int
    stdout: str
    stderr: str


def _run(command: list[str]) -> CommandEvidence:
    try:
        result = subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
        )
    except OSError as error:
        raise GateError(f"Unable to execute {command[0]}: {error}") from error
    evidence = CommandEvidence(
        command=tuple(command),
        returncode=result.returncode,
        stdout=result.stdout.strip(),
        stderr=result.stderr.strip(),
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or "no output"
        raise GateError(
            f"Command failed ({result.returncode}): {' '.join(command)}: {detail}"
        )
    return evidence


def _version(value: str, *, label: str) -> tuple[int, ...]:
    match = re.fullmatch(r"([0-9]+(?:\.[0-9]+){0,3})", value.strip())
    if match is None:
        raise GateError(f"{label} version is not reviewable: {value!r}")
    return tuple(int(part) for part in match.group(1).split("."))


def _xcode_version(output: str) -> str:
    match = re.search(r"(?m)^Xcode\s+([0-9]+(?:\.[0-9]+){0,3})\s*$", output)
    if match is None:
        raise GateError("xcodebuild did not report a reviewable Xcode version.")
    return match.group(1)


def _require_major(version: str, *, minimum: int, label: str) -> None:
    parsed = _version(version, label=label)
    if parsed[0] < minimum:
        raise GateError(
            f"{label} {version} is below the required major version {minimum}."
        )


def _write_evidence(
    text_path: pathlib.Path,
    json_path: pathlib.Path,
    *,
    status: str,
    values: dict[str, object],
    commands: list[CommandEvidence],
    error: str | None,
) -> None:
    text_path.parent.mkdir(parents=True, exist_ok=True)
    json_path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "gate": "APPLE_XCODE_IOS_SDK_26",
        "status": status,
        "minimumXcodeMajor": MINIMUM_XCODE_MAJOR,
        "minimumIosSdkMajor": MINIMUM_IOS_SDK_MAJOR,
        "officialRequirement": APPLE_SUBMISSION_REQUIREMENTS_URL,
        "values": values,
        "error": error,
        "commands": [
            {
                "command": list(item.command),
                "returnCode": item.returncode,
                "stdout": item.stdout,
                "stderr": item.stderr,
            }
            for item in commands
        ],
    }
    json_path.write_text(
        json.dumps(payload, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    lines = [
        "APPLE_RELEASE_TOOLCHAIN_EVIDENCE_V1",
        f"APPLE_RELEASE_TOOLCHAIN_GATE={status}",
        f"MINIMUM_XCODE_MAJOR={MINIMUM_XCODE_MAJOR}",
        f"MINIMUM_IOS_SDK_MAJOR={MINIMUM_IOS_SDK_MAJOR}",
        f"OFFICIAL_REQUIREMENT={APPLE_SUBMISSION_REQUIREMENTS_URL}",
    ]
    for key in sorted(values):
        lines.append(f"{key}={values[key]}")
    if error:
        lines.append(f"ERROR={error}")
    for index, command in enumerate(commands, start=1):
        lines.extend(
            [
                f"COMMAND_{index}={' '.join(command.command)}",
                f"COMMAND_{index}_RETURN_CODE={command.returncode}",
                f"COMMAND_{index}_STDOUT_BEGIN",
                command.stdout,
                f"COMMAND_{index}_STDOUT_END",
                f"COMMAND_{index}_STDERR_BEGIN",
                command.stderr,
                f"COMMAND_{index}_STDERR_END",
            ]
        )
    text_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _self_test() -> int:
    assert _xcode_version("Xcode 26.0.1\nBuild version 17A400") == "26.0.1"
    assert _version("26.1", label="iOS SDK") == (26, 1)
    _require_major("26.0", minimum=26, label="Xcode")
    try:
        _require_major("25.4", minimum=26, label="Xcode")
    except GateError:
        pass
    else:
        raise AssertionError("Xcode 25 must fail the Xcode 26 gate.")
    try:
        _version("26 beta", label="iOS SDK")
    except GateError:
        pass
    else:
        raise AssertionError("Ambiguous SDK version text must fail closed.")
    print("APPLE_RELEASE_TOOLCHAIN_SELF_TEST=PASS")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--text-evidence",
        type=pathlib.Path,
        default=pathlib.Path("BIL-apple-release-toolchain.txt"),
    )
    parser.add_argument(
        "--json-evidence",
        type=pathlib.Path,
        default=pathlib.Path("BIL-apple-release-toolchain.json"),
    )
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        return _self_test()

    commands: list[CommandEvidence] = []
    values: dict[str, object] = {}
    error_message: str | None = None
    try:
        if sys.platform != "darwin":
            raise GateError("Apple release toolchain verification requires macOS.")

        selected = _run(["xcode-select", "-p"])
        commands.append(selected)
        developer_dir = selected.stdout.strip()
        if not developer_dir or not os.path.isabs(developer_dir):
            raise GateError("xcode-select returned a non-absolute developer directory.")
        if not pathlib.Path(developer_dir).is_dir():
            raise GateError("The selected Xcode developer directory does not exist.")

        xcode = _run(["xcodebuild", "-version"])
        commands.append(xcode)
        xcode_version = _xcode_version(xcode.stdout)

        sdk_version_result = _run(
            ["xcrun", "--sdk", "iphoneos", "--show-sdk-version"]
        )
        commands.append(sdk_version_result)
        ios_sdk_version = sdk_version_result.stdout.strip()

        sdk_path_result = _run(["xcrun", "--sdk", "iphoneos", "--show-sdk-path"])
        commands.append(sdk_path_result)
        ios_sdk_path = sdk_path_result.stdout.strip()
        if not ios_sdk_path or not pathlib.Path(ios_sdk_path).is_dir():
            raise GateError("xcrun did not resolve an existing iPhoneOS SDK path.")

        sdk_build_result = _run(
            ["xcrun", "--sdk", "iphoneos", "--show-sdk-build-version"]
        )
        commands.append(sdk_build_result)
        clang_result = _run(["xcrun", "--sdk", "iphoneos", "--find", "clang"])
        commands.append(clang_result)
        os_result = _run(["sw_vers"])
        commands.append(os_result)
        architecture_result = _run(["uname", "-m"])
        commands.append(architecture_result)

        values.update(
            {
                "SELECTED_DEVELOPER_DIR": developer_dir,
                "XCODE_VERSION": xcode_version,
                "IOS_SDK_VERSION": ios_sdk_version,
                "IOS_SDK_BUILD_VERSION": sdk_build_result.stdout.strip(),
                "IOS_SDK_PATH": ios_sdk_path,
                "IOS_SDK_CLANG": clang_result.stdout.strip(),
                "RUNNER_ARCH": architecture_result.stdout.strip(),
            }
        )
        _require_major(
            xcode_version,
            minimum=MINIMUM_XCODE_MAJOR,
            label="Xcode",
        )
        _require_major(
            ios_sdk_version,
            minimum=MINIMUM_IOS_SDK_MAJOR,
            label="iOS SDK",
        )
    except GateError as error:
        error_message = str(error)

    status = "PASS" if error_message is None else "FAIL"
    _write_evidence(
        args.text_evidence,
        args.json_evidence,
        status=status,
        values=values,
        commands=commands,
        error=error_message,
    )
    if error_message is not None:
        print(error_message, file=sys.stderr)
        return 1
    print("APPLE_RELEASE_TOOLCHAIN_GATE=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
