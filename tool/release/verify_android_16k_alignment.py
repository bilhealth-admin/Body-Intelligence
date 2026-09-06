#!/usr/bin/env python3
"""Verify 16 KB packaging and ELF LOAD alignment from a final Android AAB."""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re
import shutil
import subprocess
import tempfile
import zipfile
from dataclasses import dataclass


MINIMUM_ELF_LOAD_ALIGNMENT_BYTES = 16 * 1024
REQUIRED_BUNDLE_PAGE_ALIGNMENT = "PAGE_ALIGNMENT_16K"
FORBIDDEN_BUNDLE_PAGE_ALIGNMENT = "PAGE_ALIGNMENT_4K"
ANDROID_16K_REQUIREMENTS_URL = (
    "https://developer.android.com/guide/practices/page-sizes"
)


class GateError(RuntimeError):
    """Raised when the final bundle cannot prove 16 KB compatibility."""


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


def _sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _require_bundle_alignment(config_output: str) -> None:
    if re.search(rf"\b{FORBIDDEN_BUNDLE_PAGE_ALIGNMENT}\b", config_output):
        raise GateError(
            "The final AAB requests PAGE_ALIGNMENT_4K instead of 16 KB alignment."
        )
    if not re.search(rf"\b{REQUIRED_BUNDLE_PAGE_ALIGNMENT}\b", config_output):
        raise GateError(
            "bundletool did not prove PAGE_ALIGNMENT_16K for the final AAB."
        )


def _load_alignments(readelf_output: str, *, library: str) -> list[int]:
    alignments: list[int] = []
    for line in readelf_output.splitlines():
        tokens = line.strip().split()
        if not tokens or tokens[0] != "LOAD":
            continue
        alignment_token = tokens[-1]
        if re.fullmatch(r"0x[0-9a-fA-F]+", alignment_token) is None:
            raise GateError(
                f"Unreviewable ELF LOAD alignment in {library}: {line.strip()}"
            )
        alignments.append(int(alignment_token, 16))
    if not alignments:
        raise GateError(f"No ELF LOAD segments were reported for {library}.")
    return alignments


def _write_evidence(
    evidence_dir: pathlib.Path,
    *,
    status: str,
    aab: pathlib.Path,
    bundletool_version: str,
    aab_sha256: str | None,
    bundle_commands: list[CommandEvidence],
    library_results: list[dict[str, object]],
    readelf_version: str | None,
    error: str | None,
) -> None:
    evidence_dir.mkdir(parents=True, exist_ok=True)
    bundle_text = evidence_dir / "BIL-android-16k-bundletool.txt"
    elf_text = evidence_dir / "BIL-android-16k-elf.txt"
    summary_json = evidence_dir / "BIL-android-16k-summary.json"

    bundle_lines = [
        "BIL_ANDROID_16K_BUNDLETOOL_EVIDENCE_V1",
        f"ANDROID_16K_ALIGNMENT_GATE={status}",
        f"FINAL_AAB={aab}",
        f"FINAL_AAB_SHA256={aab_sha256 or 'UNAVAILABLE'}",
        f"EXPECTED_BUNDLETOOL_VERSION={bundletool_version}",
        f"REQUIRED_PAGE_ALIGNMENT={REQUIRED_BUNDLE_PAGE_ALIGNMENT}",
        f"OFFICIAL_REQUIREMENT={ANDROID_16K_REQUIREMENTS_URL}",
    ]
    if error:
        bundle_lines.append(f"ERROR={error}")
    for index, command in enumerate(bundle_commands, start=1):
        bundle_lines.extend(
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
    bundle_text.write_text("\n".join(bundle_lines) + "\n", encoding="utf-8")

    elf_lines = [
        "BIL_ANDROID_16K_ELF_EVIDENCE_V1",
        f"ELF_LOAD_ALIGNMENT_GATE={status}",
        f"MINIMUM_ELF_LOAD_ALIGNMENT_BYTES={MINIMUM_ELF_LOAD_ALIGNMENT_BYTES}",
        f"READELF_VERSION={readelf_version or 'UNAVAILABLE'}",
    ]
    for item in library_results:
        alignments = item.get("loadAlignmentsBytes", [])
        formatted = ",".join(f"0x{int(value):x}" for value in alignments)
        elf_lines.append(
            "LIBRARY="
            f"{item.get('entry')} SHA256={item.get('sha256')} "
            f"LOAD_ALIGNMENTS={formatted} STATUS={item.get('status')}"
        )
    elf_lines.extend(
        [
            f"ELF_SHARED_LIBRARY_COUNT={len(library_results)}",
            f"ELF_LOAD_ALIGNMENT_16K={status}",
        ]
    )
    if error:
        elf_lines.append(f"ERROR={error}")
    elf_text.write_text("\n".join(elf_lines) + "\n", encoding="utf-8")

    payload = {
        "gate": "ANDROID_FINAL_AAB_16K_ALIGNMENT",
        "status": status,
        "finalAab": str(aab),
        "finalAabSha256": aab_sha256,
        "bundletoolVersion": bundletool_version,
        "requiredBundlePageAlignment": REQUIRED_BUNDLE_PAGE_ALIGNMENT,
        "minimumElfLoadAlignmentBytes": MINIMUM_ELF_LOAD_ALIGNMENT_BYTES,
        "officialRequirement": ANDROID_16K_REQUIREMENTS_URL,
        "readelfVersion": readelf_version,
        "sharedLibraryCount": len(library_results),
        "libraries": library_results,
        "error": error,
    }
    summary_json.write_text(
        json.dumps(payload, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def _self_test() -> int:
    _require_bundle_alignment("alignment: PAGE_ALIGNMENT_16K")
    for invalid in ("alignment: PAGE_ALIGNMENT_4K", "alignment: UNKNOWN"):
        try:
            _require_bundle_alignment(invalid)
        except GateError:
            pass
        else:
            raise AssertionError(f"Bundle config must fail closed: {invalid}")
    parsed = _load_alignments(
        """
  LOAD 0x000000 0x00000000 0x00000000 0x001000 0x001000 R E 0x4000
  LOAD 0x004000 0x00004000 0x00004000 0x000100 0x000100 RW  0x10000
        """,
        library="fixture.so",
    )
    assert parsed == [0x4000, 0x10000]
    print("ANDROID_16K_ALIGNMENT_SELF_TEST=PASS")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--aab", required=False, type=pathlib.Path)
    parser.add_argument("--bundletool", required=False, type=pathlib.Path)
    parser.add_argument("--bundletool-version", default="1.18.3")
    parser.add_argument("--readelf", default="readelf")
    parser.add_argument(
        "--evidence-dir",
        type=pathlib.Path,
        default=pathlib.Path("."),
    )
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        return _self_test()
    if args.aab is None:
        parser.error("--aab is required unless --self-test is used")
    if args.bundletool is None:
        parser.error("--bundletool is required unless --self-test is used")

    aab = args.aab.resolve()
    bundletool = args.bundletool.resolve()
    commands: list[CommandEvidence] = []
    libraries: list[dict[str, object]] = []
    aab_sha256: str | None = None
    readelf_version: str | None = None
    error_message: str | None = None
    try:
        if not aab.is_file() or aab.stat().st_size == 0:
            raise GateError("The final release AAB is missing or empty.")
        if not bundletool.is_file() or bundletool.stat().st_size == 0:
            raise GateError("The pinned official bundletool JAR is missing or empty.")
        java = shutil.which("java")
        if java is None:
            raise GateError("Java is required to run official bundletool.")
        readelf = shutil.which(args.readelf)
        if readelf is None:
            raise GateError(f"ELF reader was not found: {args.readelf}")

        aab_sha256 = _sha256(aab)
        version_command = _run([java, "-jar", str(bundletool), "version"])
        commands.append(version_command)
        actual_bundletool_version = version_command.stdout.strip()
        if actual_bundletool_version != args.bundletool_version:
            raise GateError(
                "Official bundletool version mismatch: expected "
                f"{args.bundletool_version}, got {actual_bundletool_version!r}."
            )

        validate_command = _run(
            [java, "-jar", str(bundletool), "validate", f"--bundle={aab}"]
        )
        commands.append(validate_command)
        config_command = _run(
            [java, "-jar", str(bundletool), "dump", "config", f"--bundle={aab}"]
        )
        commands.append(config_command)
        _require_bundle_alignment(config_command.stdout)

        readelf_version_command = _run([readelf, "--version"])
        readelf_version = readelf_version_command.stdout.splitlines()[0].strip()
        commands.append(readelf_version_command)

        try:
            bundle = zipfile.ZipFile(aab)
        except (OSError, zipfile.BadZipFile) as error:
            raise GateError(f"The final AAB is not a readable ZIP archive: {error}") from error
        with bundle, tempfile.TemporaryDirectory(prefix="bil-aab-elf-") as temp:
            native_entries = sorted(
                (
                    info
                    for info in bundle.infolist()
                    if not info.is_dir() and info.filename.lower().endswith(".so")
                ),
                key=lambda info: info.filename,
            )
            if not native_entries:
                raise GateError("The final Flutter AAB contains no shared libraries to verify.")
            temp_root = pathlib.Path(temp)
            for index, info in enumerate(native_entries):
                extracted = temp_root / f"{index:04d}-{pathlib.PurePosixPath(info.filename).name}"
                with bundle.open(info, "r") as source, extracted.open("wb") as target:
                    shutil.copyfileobj(source, target)
                readelf_command = _run([readelf, "-lW", str(extracted)])
                alignments = _load_alignments(
                    readelf_command.stdout,
                    library=info.filename,
                )
                minimum = min(alignments)
                library_result = {
                    "entry": info.filename,
                    "sha256": _sha256(extracted),
                    "loadAlignmentsBytes": alignments,
                    "minimumLoadAlignmentBytes": minimum,
                    "status": (
                        "PASS"
                        if minimum >= MINIMUM_ELF_LOAD_ALIGNMENT_BYTES
                        else "FAIL"
                    ),
                }
                libraries.append(library_result)
                if minimum < MINIMUM_ELF_LOAD_ALIGNMENT_BYTES:
                    raise GateError(
                        f"{info.filename} has an ELF LOAD alignment below 16 KB: "
                        f"0x{minimum:x}."
                    )
    except (GateError, OSError, zipfile.BadZipFile) as error:
        error_message = str(error)

    status = "PASS" if error_message is None else "FAIL"
    _write_evidence(
        args.evidence_dir,
        status=status,
        aab=aab,
        bundletool_version=args.bundletool_version,
        aab_sha256=aab_sha256,
        bundle_commands=commands,
        library_results=libraries,
        readelf_version=readelf_version,
        error=error_message,
    )
    if error_message is not None:
        print(error_message, file=sys.stderr)
        return 1
    print("ANDROID_FINAL_AAB_PAGE_ALIGNMENT_16K=PASS")
    print("ANDROID_FINAL_AAB_ELF_LOAD_ALIGNMENT_16K=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
