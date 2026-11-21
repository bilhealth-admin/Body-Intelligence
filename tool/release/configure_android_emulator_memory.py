#!/usr/bin/env python3
"""Set and read back the API29 CI guest memory before installing BIL.

This provisions the disposable AVD only. It neither changes application memory
settings nor dismisses OS failures, retries startup, or accepts app execution.
The AOSP hardware property is vm.heapSize, not hw.heapSize.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

SUPPORTED_APIS = (26, 29, 33, 34, 35, 36)
API29_MEMORY = {"hw.ramSize": "2048", "vm.heapSize": "256"}
# For this fixed API29 pixel_2 lane, the emulator minimum is RAM / 4.
# The requested config.ini value is 256 MiB; the boot value is 512 MiB.
API29_BOOT_HEAP_MIB = int(API29_MEMORY["hw.ramSize"]) // 4
READ_TIMEOUT_SECONDS = 8


class MemoryContractError(ValueError):
    def __init__(self, message: str, receipt: dict | None = None):
        super().__init__(message)
        self.receipt = receipt or {}


def memory_settings(api: int) -> dict[str, str] | None:
    if type(api) is not int or api not in SUPPORTED_APIS:
        raise MemoryContractError("Unsupported Android API")
    return dict(API29_MEMORY) if api == 29 else None


def configure_memory(api: int, config: Path) -> dict:
    expected = memory_settings(api)
    if expected is None:
        return {"status": "UNCHANGED_API", "api_level": api, "changed": False}
    if config.name != "config.ini" or not config.parent.name.endswith(".avd"):
        raise MemoryContractError("Expected the owned AVD config.ini")
    for entry in (config, *config.parents):
        if entry.is_symlink():
            raise MemoryContractError("Refusing a symbolic AVD configuration path")
    if not config.is_file():
        raise MemoryContractError("AVD configuration is missing")
    original = config.read_bytes()
    if len(original) > 1024 * 1024:
        raise MemoryContractError("AVD configuration exceeds the bounded limit")
    text = original.decode("utf-8")
    newline = "\r\n" if "\r\n" in text else "\n"
    lines = text.splitlines(keepends=True)
    before_values = {}
    for key, value in expected.items():
        pattern = re.compile(r"^\s*" + re.escape(key) + r"\s*=", re.MULTILINE)
        matches = [i for i, line in enumerate(lines) if pattern.match(line)]
        if len(matches) > 1:
            raise MemoryContractError("Ambiguous AVD memory property: " + key)
        before_values[key] = lines[matches[0]].strip() if matches else None
    for key, value in expected.items():
        pattern = re.compile(r"^\s*" + re.escape(key) + r"\s*=")
        matches = [i for i, line in enumerate(lines) if pattern.match(line)]
        if matches:
            lines[matches[0]] = key + "=" + value + newline
        else:
            if lines and not lines[-1].endswith(("\r", "\n")):
                lines[-1] += newline
            lines.append(key + "=" + value + newline)
    configured = "".join(lines).encode("utf-8")
    if configured != original:
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(dir=config.parent,
                                             prefix=".bil-memory-", delete=False) as stream:
                temporary = Path(stream.name)
                stream.write(configured)
            os.chmod(temporary, config.stat().st_mode & 0o777)
            os.replace(temporary, config)
        finally:
            if temporary is not None and temporary.exists():
                temporary.unlink()
    actual = config.read_bytes()
    for key, value in expected.items():
        values = re.findall(r"^\s*" + re.escape(key) + r"\s*=\s*([^\r\n]*)",
                            actual.decode("utf-8"), re.MULTILINE)
        if values != [value]:
            raise MemoryContractError("AVD memory configuration readback differs")
    return {
        "status": "CONFIGURED", "api_level": api, "changed": actual != original,
        "config_path": str(config), "memory": expected,
        "original_memory_lines": before_values,
        "before_sha256": hashlib.sha256(original).hexdigest(),
        "after_sha256": hashlib.sha256(actual).hexdigest(),
    }


def verify_runtime_memory(api: int, run=subprocess.run) -> dict:
    if memory_settings(api) is None:
        return {"status": "UNCHANGED_API", "api_level": api, "commands": []}
    commands = (
        ("sdk", ["adb", "shell", "getprop", "ro.build.version.sdk"]),
        ("boot_heap", ["adb", "shell", "getprop", "ro.kernel.qemu.dalvik.vm.heapsize"]),
        ("heap", ["adb", "shell", "getprop", "dalvik.vm.heapsize"]),
        ("growth", ["adb", "shell", "getprop", "dalvik.vm.heapgrowthlimit"]),
        ("memory", ["adb", "shell", "cat", "/proc/meminfo"]),
    )
    receipt = {"api_level": api, "commands": []}
    outputs = {}
    try:
        for key, argv in commands:
            try:
                result = run(argv, capture_output=True, text=True, check=False,
                             timeout=READ_TIMEOUT_SECONDS)
            except subprocess.TimeoutExpired as error:
                receipt["commands"].append({"command": argv, "status": "TIMEOUT",
                                            "timeout_seconds": READ_TIMEOUT_SECONDS})
                raise MemoryContractError("Guest memory readback timed out") from error
            if len(result.stdout) + len(result.stderr) > 16384:
                raise MemoryContractError("Guest memory readback exceeded its limit")
            receipt["commands"].append({
                "command": argv, "return_code": result.returncode,
                "stdout": result.stdout, "stderr": result.stderr,
                "timeout_seconds": READ_TIMEOUT_SECONDS,
            })
            if result.returncode:
                raise MemoryContractError("Guest memory readback command failed")
            outputs[key] = result.stdout.replace("\r", "").strip()
        if outputs["sdk"] != "29":
            raise MemoryContractError("Guest did not report API29")
        expected_heap = f"{API29_BOOT_HEAP_MIB}m"
        if outputs["boot_heap"].lower() != expected_heap:
            raise MemoryContractError(f"Expected API29 emulator boot heap {expected_heap}")
        if outputs["heap"].lower() != expected_heap:
            raise MemoryContractError(f"Expected API29 dalvik.vm.heapsize {expected_heap}")
        growth = outputs["growth"].lower()
        if growth not in ("", "0"):
            match = re.fullmatch(r"([1-9][0-9]*)m", growth)
            if match is None or not 64 <= int(match[1]) <= 256:
                raise MemoryContractError("Guest heap growth limit is inadequate or ambiguous")
        totals = re.findall(r"^MemTotal:\s+([0-9]+)\s+kB$", outputs["memory"],
                            re.MULTILINE)
        if len(totals) != 1 or not 1536 * 1024 <= int(totals[0]) <= 2304 * 1024:
            raise MemoryContractError("Guest RAM does not match the 2048 MiB AVD")
        receipt.update(status="MATCHED", heap_mib=API29_BOOT_HEAP_MIB,
                       requested_avd_heap_mib=int(API29_MEMORY["vm.heapSize"]),
                       boot_heap_property=outputs["boot_heap"],
                       heap_growth_property=growth, mem_total_kib=int(totals[0]))
        return receipt
    except MemoryContractError as error:
        raise MemoryContractError(str(error), receipt) from error


def main(arguments=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("configure", "verify-runtime"))
    parser.add_argument("--api-level", type=int, choices=SUPPORTED_APIS, required=True)
    parser.add_argument("--config", type=Path)
    parser.add_argument("--evidence-dir", type=Path, required=True)
    args = parser.parse_args(arguments)
    name = "avd-memory-config.json" if args.operation == "configure" else "runtime-memory.json"
    try:
        if args.operation == "configure":
            if args.config is None:
                raise MemoryContractError("Configure requires an AVD config path")
            receipt = configure_memory(args.api_level, args.config)
        else:
            receipt = verify_runtime_memory(args.api_level)
        code = 0
    except (OSError, ValueError) as error:
        receipt = dict(getattr(error, "receipt", {}), status="FAILED",
                       api_level=args.api_level, error=str(error))
        code = 5
    receipt["app_startup_proven"] = False
    args.evidence_dir.mkdir(parents=True, exist_ok=True)
    (args.evidence_dir / name).write_text(json.dumps(receipt, indent=2) + "\n",
                                         encoding="utf-8")
    print(json.dumps(receipt))
    return code


if __name__ == "__main__":
    raise SystemExit(main())
