#!/usr/bin/env python3
"""Read-only QA bootstrap diagnosis; never a native test or release acceptance."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys
import time

BUNDLE_ID = "com.bilhealth.bodyintelligencelog"
PROCESSES = ("SpringBoard", "launchd", "launchd_sim", "amfid", "dyld", "runningboardd", "taskgated", "kernel")
MESSAGES = (BUNDLE_ID, "Runner.app", "Runner.debug.dylib", "Launchd job spawn failed",
            "code signature", "Library not loaded", "invalid page", "posix_spawn")
PREDICATE = ('process == "Runner" OR ((' + ' OR '.join(f'process == "{p}"' for p in PROCESSES) +
             ') AND (' + ' OR '.join(f'eventMessage CONTAINS[c] "{m}"' for m in MESSAGES) + '))')
ENV_KEYS = ("DYLD_INSERT_LIBRARIES", "DYLD_LIBRARY_PATH", "DYLD_FRAMEWORK_PATH",
            "SIMCTL_CHILD_DYLD_INSERT_LIBRARIES", "SIMCTL_CHILD_DYLD_LIBRARY_PATH",
            "CODEQL_EXTRACTOR_SWIFT_RUN_UNDER", "SEMMLE_EXEC_AUTOUPDATE_ENV",
            "CODEQL_RUNNER", "CODEQL_EXTRACTOR_SWIFT_TRAP_DIR")
MAGICS = {bytes.fromhex(x) for x in ("feedface", "cefaedfe", "feedfacf", "cffaedfe", "cafebabe", "bebafeca", "cafebabf", "bfbafeca")}
UUID = re.compile(r"[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}")
SECRET_LINE = re.compile(r"authorization|bearer\s|password|api[_ -]?key|service[_ -]?role|access[_ -]?token|refresh[_ -]?token|client[_ -]?secret|eyJ[A-Za-z0-9_-]{12,}\.", re.I)


def digest(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def sanitize(raw: bytes) -> str:
    lines = []
    for line in raw.decode("utf-8", errors="replace").splitlines():
        if SECRET_LINE.search(line):
            lines.append("[redacted credential-bearing diagnostic line]")
        else:
            line = re.sub(r"(https?://)[^/@\s]+:[^/@\s]+@", r"\1[redacted]@", line)
            lines.append(re.sub(r"(https?://[^\s?'\"]+)\?[^\s'\"]+", r"\1?[redacted-query]", line))
    return "\n".join(lines) + ("\n" if lines else "")


def environment_evidence(environ: dict[str, str]) -> dict:
    evidence = {}
    for key in ENV_KEYS:
        value = environ.get(key)
        evidence[key] = {"present": value is not None}
        if value is not None:
            evidence[key].update(byte_length=len(value.encode()), sha256=digest(value.encode()),
                                 mentions_codeql_or_semmle=bool(re.search(r"codeql|semmle", value, re.I)),
                                 dylib_basenames=re.findall(r"(?:^|/)([A-Za-z0-9_.+-]+\.dylib)(?=[:\s]|$)", value))
    return evidence


def app_files(app: Path) -> list[Path]:
    files = []
    for path in sorted(app.rglob("*")):
        path.resolve().relative_to(app.resolve())
        if path.is_file() and not path.is_symlink():
            files.append(path)
    return files


def bundle_fingerprint(app: Path) -> tuple[str, list[dict]]:
    rows = [{"path": path.relative_to(app).as_posix(), "sha256": digest(path.read_bytes())}
            for path in app_files(app)]
    return digest(json.dumps(rows, sort_keys=True).encode()), rows


def diagnose(args, *, run=subprocess.run, host=sys.platform, environ=None) -> dict:
    environ = dict(os.environ if environ is None else environ)
    if host != "darwin" or not args.qa_simulator_only:
        raise ValueError("Explicit QA Simulator diagnosis on macOS is required")
    workspace = Path(args.workspace).resolve()
    app = Path(args.app).resolve()
    out = Path(args.output).resolve()
    if app != workspace / "build/ios/iphonesimulator/Runner.app" or not app.is_dir():
        raise ValueError("Only the existing generic QA Simulator bundle is allowed")
    out.relative_to(workspace / "artifacts/qa")
    if not re.fullmatch(r"[0-9a-f]{40}", args.source_head) or not re.fullmatch(r"[0-9a-f]{64}", args.expected_main_sha256):
        raise ValueError("Actual source and pre-drive executable hashes are required")
    if not UUID.fullmatch(args.device) or not re.fullmatch(r"com\.apple\.CoreSimulator\.SimRuntime\.iOS-[0-9-]+", args.runtime):
        raise ValueError("Exact existing QA device and runtime are required")
    if args.device_label not in ("iphone", "ipad") or args.entrypoint_kind not in ("system-crypto", "native-settings", "feature-splashes"):
        raise ValueError("The original failed device and entrypoint kind are required")
    prefix = "iPhone" if args.device_label == "iphone" else "iPad"
    if not re.fullmatch(r"com\.apple\.CoreSimulator\.SimDeviceType\." + prefix + r"-[A-Za-z0-9-]+", args.device_type):
        raise ValueError("The fresh replay must use the original failed device family")
    info = plistlib.loads((app / "Info.plist").read_bytes())
    if (info.get("CFBundleIdentifier") != BUNDLE_ID or info.get("CFBundleVersion") != "37" or
            info.get("DTPlatformName") != "iphonesimulator" or info.get("CFBundleSupportedPlatforms") != ["iPhoneSimulator"]):
        raise ValueError("Only build37 of the expected QA Simulator app is permitted")
    if any(p.name in ("embedded.mobileprovision", "embedded.provisionprofile") for p in app.rglob("*")):
        raise ValueError("Provisioned device/distribution apps are forbidden")
    out.mkdir(parents=True, exist_ok=True)
    deadline = time.monotonic() + 480
    receipt = {"schema": "bil.qa.ios-spawn-diagnostic.v1", "source_head": args.source_head,
               "scope": "Existing exact QA binary; read-only bootstrap diagnosis, not a native journey or final-source acceptance",
               "native_tests_passed_by_this_diagnostic": False, "signed_release_verified": False,
               "original_device_label": args.device_label, "original_entrypoint_kind": args.entrypoint_kind,
               "environment": environment_evidence(environ), "commands": [], "fresh_replay_attempts": 0}
    fresh_device = None

    def command(label, argv, seconds=30):
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError("Bounded diagnostic deadline reached")
        try:
            result = run(argv, capture_output=True, check=False, timeout=min(seconds, remaining))
            raw = result.stdout + result.stderr
            row = {"label": label, "returncode": result.returncode, "raw_sha256": digest(raw),
                   "raw_byte_length": len(raw), "timed_out": False}
        except subprocess.TimeoutExpired as error:
            raw = (error.stdout or b"") + (error.stderr or b"")
            result = subprocess.CompletedProcess(argv, 124, error.stdout or b"", error.stderr or b"")
            row = {"label": label, "returncode": 124, "raw_sha256": digest(raw),
                   "raw_byte_length": len(raw), "timed_out": True}
        (out / (label + ".log")).write_text(sanitize(raw), encoding="utf-8")
        receipt["commands"].append(row)
        return result

    def logs(label, device):
        command(label + "-simulator-launch-services", ["xcrun", "simctl", "spawn", device,
            "log", "show", "--last", "3m", "--style", "compact", "--predicate", PREDICATE], 45)
        command(label + "-host-launch-services", ["/usr/bin/log", "show", "--last", "3m", "--style", "compact",
            "--predicate", PREDICATE], 45)

    try:
        head = command("actual-checkout", ["git", "rev-parse", "HEAD"]).stdout.decode().strip()
        if head != args.source_head:
            raise ValueError("Actual checkout source differs from declared binary provenance")
        before, files = bundle_fingerprint(app)
        receipt.update(bundle_fingerprint_before=before, bundle_file_hashes=files,
                       main_sha256=digest((app / "Runner").read_bytes()), expected_main_sha256=args.expected_main_sha256)
        logs("original-failure", args.device)
        receipt["macho_inventory"] = []
        for path in app_files(app):
            with path.open("rb") as handle:
                magic = handle.read(4)
            if magic not in MAGICS:
                continue
            relative = path.relative_to(app).as_posix()
            index = len(receipt["macho_inventory"])
            record = {"path": relative, "sha256": digest(path.read_bytes())}
            for name, argv in (
                ("platform", ["xcrun", "vtool", "-show-build", str(path)]),
                ("architectures", ["xcrun", "lipo", "-archs", str(path)]),
                ("linked-images", ["xcrun", "otool", "-L", str(path)]),
                ("signature", ["codesign", "--display", "--verbose=4", str(path)]),
                ("strict-verification", ["codesign", "--verify", "--strict", "--verbose=4", str(path)])):
                result = command(f"macho-{index:03d}-{name}", argv, 15)
                record[name + "_returncode"] = result.returncode
            receipt["macho_inventory"].append(record)
        # One fresh device, exact same bytes, runtime and app identifier. No
        # environment alteration, re-sign, rebuild, runtime fallback or retry.
        if receipt["main_sha256"] != args.expected_main_sha256:
            receipt["fresh_replay_status"] = "BLOCKED_PRE_DRIVE_BINARY_HASH_MISMATCH"
        else:
            created = command("fresh-create", ["xcrun", "simctl", "create", "BIL-spawn-diagnostic-" + args.source_head[:8],
                args.device_type, args.runtime], 45)
            candidate = created.stdout.decode().strip()
            if created.returncode or not UUID.fullmatch(candidate):
                raise ValueError("Could not create the single fresh QA diagnostic device")
            fresh_device = candidate
            receipt["fresh_device"] = fresh_device
            stages = (("fresh-boot", ["xcrun", "simctl", "boot", fresh_device], 45),
                      ("fresh-bootstatus", ["xcrun", "simctl", "bootstatus", fresh_device, "-b"], 180),
                      ("fresh-install-exact-bundle", ["xcrun", "simctl", "install", fresh_device, str(app)], 90))
            for label, argv, seconds in stages:
                if command(label, argv, seconds).returncode:
                    receipt["fresh_replay_status"] = "BLOCKED_" + label.upper().replace("-", "_")
                    break
            else:
                receipt["fresh_replay_attempts"] = 1
                result = command("fresh-launch-once", ["xcrun", "simctl", "launch", fresh_device, BUNDLE_ID,
                    "--enable-dart-profiling", "--disable-vm-service-publication", "--start-paused",
                    "--enable-checked-mode", "--verify-entry-points"], 60)
                receipt["fresh_replay_status"] = "LAUNCH_COMMAND_RETURNED_ZERO_NOT_TEST_PASS" if result.returncode == 0 else "LAUNCH_FAILED"
            logs("fresh-replay", fresh_device)
        if args.retain_exact_bundle:
            result = command("retain-exact-simulator-bundle", ["/usr/bin/ditto", "-c", "-k", "--sequesterRsrc", "--keepParent",
                str(app), str(out / "exact-qa-simulator-bundle.zip")], 60)
            if result.returncode == 0:
                receipt["retained_bundle_zip_sha256"] = digest((out / "exact-qa-simulator-bundle.zip").read_bytes())
        after, _ = bundle_fingerprint(app)
        receipt["bundle_fingerprint_after"] = after
        receipt["bundle_bytes_unchanged"] = after == before
        if after != before:
            raise ValueError("Bundle bytes changed during the diagnostic")
        receipt["diagnostic_collection_status"] = "COLLECTED_NOT_TEST_ACCEPTANCE"
    except Exception as error:
        receipt["diagnostic_collection_status"] = "INCOMPLETE"
        receipt["error"] = type(error).__name__ + ": " + str(error)
        raise
    finally:
        if fresh_device:
            for label, argv in (("fresh-shutdown", ["xcrun", "simctl", "shutdown", fresh_device]),
                                ("fresh-delete", ["xcrun", "simctl", "delete", fresh_device])):
                # Cleanup has its own small bound after the diagnostic deadline.
                deadline = max(deadline, time.monotonic() + 30)
                try:
                    command(label, argv, 30)
                except Exception as error:
                    receipt.setdefault("cleanup_errors", []).append({"label": label, "error_type": type(error).__name__})
        (out / "spawn-diagnostic.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("workspace", "app", "output", "source-head", "expected-main-sha256", "device", "runtime", "device-type", "device-label", "entrypoint-kind"):
        parser.add_argument("--" + name, required=True)
    parser.add_argument("--qa-simulator-only", action="store_true", required=True)
    parser.add_argument("--retain-exact-bundle", action="store_true")
    try:
        result = diagnose(parser.parse_args())
    except Exception as error:
        print("QA spawn diagnosis incomplete: " + type(error).__name__, file=sys.stderr)
        return 1
    print(json.dumps({"diagnostic_collection_status": result["diagnostic_collection_status"],
                      "fresh_replay_status": result.get("fresh_replay_status"), "native_tests_passed": False}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
