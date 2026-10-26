#!/usr/bin/env python3
"""Run the five existing RunnerTests and require an actual XCTest result.

These tests exercise App Attest key-store logic with an in-memory backend.
They do not prove App Attest service support or hardware attestation.
"""

import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
import sys

from bil_native_bounded_command import run_bounded


TEST_TIMEOUT_SECONDS = 1800
SUMMARY_TIMEOUT_SECONDS = 60
EXPECTED_TEST_COUNT = 5


def expected_tests(source):
    names = re.findall(r"^\s*func (test[A-Za-z0-9_]+)\(", source, flags=re.MULTILINE)
    if len(names) != EXPECTED_TEST_COUNT or len(set(names)) != EXPECTED_TEST_COUNT:
        raise ValueError("The expected existing five RunnerTests must be reviewed if changed")
    return set(names)


def verified_summary(raw_summary, execution_log, names):
    summary = json.loads(raw_summary)
    if not isinstance(summary, dict):
        raise ValueError("Expected an actual xcresult test summary")
    counts = {key: summary.get(key) for key in (
        "totalTestCount", "passedTests", "failedTests", "skippedTests")}
    if any(type(value) is not int for value in counts.values()):
        raise ValueError("Missing or invalid XCTest summary counts")
    if counts != {"totalTestCount": EXPECTED_TEST_COUNT, "passedTests": EXPECTED_TEST_COUNT,
                  "failedTests": 0, "skippedTests": 0}:
        raise ValueError("RunnerTests must report five passes without failures or skips")
    if summary.get("expectedFailures", 0) != 0:
        raise ValueError("Expected failures cannot stand in for successful tests")
    passed = set()
    for line in execution_log.splitlines():
        if re.search(r"\bTest [Cc]ase\b", line) and re.search(r"\bpassed\b", line):
            if "RunnerTests" in line:
                passed.update(name for name in names if re.search(rf"\b{re.escape(name)}\b", line))
    if passed != names:
        raise ValueError("The execution log must identify each existing RunnerTests pass")
    return {**counts, "testNames": sorted(passed)}


def run_tests(workspace, output, device, defines, *, run=run_bounded, host=sys.platform, build_number="37"):
    if build_number not in ("37", "39"):
        raise ValueError("Only the reviewed Simulator QA build numbers are permitted")
    workspace, output = Path(workspace).resolve(), Path(output).resolve()
    output.relative_to(workspace)
    if host != "darwin" or re.fullmatch(r"[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}", device) is None:
        raise ValueError("An exact iOS Simulator UDID on macOS is required")
    project_workspace = workspace / "ios/Runner.xcworkspace"
    source = workspace / "ios/RunnerTests/RunnerTests.swift"
    if not project_workspace.is_dir() or not source.is_file():
        raise ValueError("The existing iOS workspace and RunnerTests are required")
    names = expected_tests(source.read_text(encoding="utf-8"))
    parsed_defines = dict(value.split("=", 1) for value in defines)
    if len(parsed_defines) != len(defines) or any(parsed_defines.get(key) != value for key, value in {
        "BIL_ENVIRONMENT": "testing", "BIL_USE_SUPABASE": "false",
        "BIL_PAYMENTS_ENABLED": "false", "BIL_ADS_ENABLED": "false",
        "BIL_QA_IOS_SIMULATOR": "true",
    }.items()):
        raise ValueError("RunnerTests must use the existing offline Simulator QA defines")
    build_dir = (workspace / "build/ios").resolve()
    build_dir.relative_to(workspace)
    output.mkdir(parents=True, exist_ok=True)
    bundle = output / "RunnerTests.xcresult"
    if bundle.exists():
        raise ValueError("A previous XCTest bundle cannot serve as new execution evidence")
    receipt_path = output / "runner-tests-result.json"
    receipt = {
        "status": "RUNNING", "stage": "xcodebuild-test", "expected_test_count": EXPECTED_TEST_COUNT,
        "scope": "Existing in-memory App Attest key-store unit tests on an iOS Simulator, not real-device App Attest proof",
        "real_device_attestation_proven": False, "build_number": build_number,
        "source_test_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "xcresult": str(bundle.relative_to(workspace)),
    }

    def save():
        receipt_path.write_bytes((json.dumps(receipt, indent=2) + "\n").encode("utf-8"))

    encoded_defines = ",".join(base64.b64encode(value.encode("utf-8")).decode("ascii") for value in defines)
    command = [
        "xcrun", "xcodebuild", "test", "-workspace", str(project_workspace), "-scheme", "Runner",
        "-configuration", "Debug", "-sdk", "iphonesimulator", "-destination", f"platform=iOS Simulator,id={device}",
        "-clonedSourcePackagesDirPath", str(build_dir / "SourcePackages"),
        "-skipPackageUpdates",
        "-only-testing:RunnerTests", "-parallel-testing-enabled", "NO",
        "-resultBundlePath", str(bundle), f"BUILD_DIR={build_dir}",
        "CODE_SIGN_IDENTITY=-", "CODE_SIGNING_ALLOWED=YES", "CODE_SIGNING_REQUIRED=YES",
        "PROVISIONING_PROFILE_SPECIFIER=", "FLUTTER_TARGET=lib/main.dart", f"FLUTTER_BUILD_NUMBER={build_number}",
        f"DART_DEFINES={encoded_defines}",
    ]
    log = output / "runner-tests.log"
    summary_path = output / "runner-tests-summary.json"
    try:
        save()
        code = run(command, label="ios-runner-tests", log_path=log,
                   receipt_path=output / "runner-tests-command-result.json", timeout_seconds=TEST_TIMEOUT_SECONDS)
        receipt["test_command_exit_code"] = code
        receipt["stage"] = "xcresult-summary"
        save()
        if bundle.is_dir():
            summary_code = run(
                ["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", str(bundle)],
                label="ios-runner-tests-summary", log_path=summary_path,
                receipt_path=output / "runner-tests-summary-command-result.json", timeout_seconds=SUMMARY_TIMEOUT_SECONDS,
            )
            receipt["summary_command_exit_code"] = summary_code
        else:
            summary_code = 1
            receipt["summary_missing_reason"] = "actual_xcresult_bundle_missing"
        if code != 0 or summary_code != 0:
            receipt.update(status="FAIL", exit_code=code if code != 0 else summary_code)
            save()
            return receipt["exit_code"]
        receipt["stage"] = "verify-five-executed-tests"
        receipt["summary"] = verified_summary(summary_path.read_text(encoding="utf-8"),
                                               log.read_text(encoding="utf-8"), names)
        receipt.update(status="PASS", exit_code=0)
        save()
        return 0
    except Exception as failure:
        receipt.update(status="FAIL", exit_code=1, error_type=type(failure).__name__)
        save()
        return 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--device", required=True)
    parser.add_argument("--build-number", choices=("37", "39"), default="37")
    parser.add_argument("--dart-define", action="append", required=True)
    args = parser.parse_args()
    return run_tests(args.workspace, args.output, args.device, args.dart_define, build_number=args.build_number)


if __name__ == "__main__":
    raise SystemExit(main())
