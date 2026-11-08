#!/usr/bin/env python3
"""Run every declared RunnerTests XCTest and require named execution evidence.

These tests include App Attest key-store logic with an in-memory backend
and every declared native UI XCTest from the same checked-out source.
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
ORIGINAL_TEST_NAMES = frozenset({
    'testAppAttestKeyStoreKeepsAccountsIsolated',
    'testAppAttestKeyStoreMigratesLegacyAccountsOneAtATime',
    'testAppAttestLegacyEntrySurvivesFailedKeychainMigration',
    'testAppAttestKeyStoreDeletesOnlyTheExpectedAccountKey',
    'testAppAttestDiscardCannotResurrectAnOlderLegacyKey',
})


def _swift_code(source):
    """Remove Swift comments/literals before inspecting actual declarations."""
    output = list(source)
    index, length = 0, len(source)
    while index < length:
        start = index
        if source.startswith('//', index):
            end = source.find('\n', index)
            index = length if end < 0 else end
        elif source.startswith('/*', index):
            index += 2
            nesting = 1
            while index < length and nesting:
                if source.startswith('/*', index):
                    nesting += 1
                    index += 2
                elif source.startswith('*/', index):
                    nesting -= 1
                    index += 2
                else:
                    index += 1
            if nesting:
                raise ValueError('Unclosed Swift comment in XCTest source')
        else:
            opening = re.match(r'(#+)?("""|")', source[index:])
            if opening is None:
                index += 1
                continue
            hashes, quotes = opening.group(1) or '', opening.group(2)
            closing = quotes + hashes
            index += len(opening.group())
            while index < length:
                if source.startswith('\\' + hashes, index):
                    index += len(hashes) + 2
                elif source.startswith(closing, index):
                    index += len(closing)
                    break
                else:
                    index += 1
            else:
                raise ValueError('Unclosed Swift literal in XCTest source')
        output[start:index] = ['\n' if value == '\n' else ' ' for value in source[start:index]]
    return ''.join(output)


def expected_tests(source):
    code = _swift_code(source)
    classes = list(re.finditer(r'\bclass\s+RunnerTests\s*:\s*(?:XCTest\.)?XCTestCase\s*\{', code))
    if len(classes) != 1 or code[:classes[0].start()].count('{') != code[:classes[0].start()].count('}'):
        raise ValueError('Exactly one actual RunnerTests XCTestCase class is required')
    scopes = classes + list(re.finditer(r'\bextension\s+RunnerTests\s*\{', code))
    names = []
    for scope in scopes:
        depth = 1
        for token in re.finditer(r'[{}]|\bfunc\s+(test[A-Za-z0-9_]+)\b', code[scope.end():]):
            if token.group() == '{':
                depth += 1
            elif token.group() == '}':
                depth -= 1
                if depth == 0:
                    break
            elif depth == 1:
                tail = code[scope.end() + token.end():]
                if re.match(r'\s*\(\s*\)\s*(?:(?:async|throws|rethrows)\s*)*(?:->\s*Void\s*)?\{', tail) is None:
                    raise ValueError('Unsupported XCTest declaration requires source review')
                names.append(token.group(1))
        if depth != 0:
            raise ValueError('Unclosed actual RunnerTests source scope')
    if not ORIGINAL_TEST_NAMES.issubset(names) or len(names) != len(set(names)):
        raise ValueError('Every original named XCTest and unique declared new test is mandatory')
    return set(names)


def verified_summary(raw_summary, execution_log, names):
    if not ORIGINAL_TEST_NAMES.issubset(names) or any(not re.fullmatch(r'test[A-Za-z0-9_]+', name) for name in names):
        raise ValueError('Actual complete named XCTest source registry required')
    summary = json.loads(raw_summary)
    if not isinstance(summary, dict):
        raise ValueError("Expected an actual xcresult test summary")
    counts = {key: summary.get(key) for key in (
        "totalTestCount", "passedTests", "failedTests", "skippedTests")}
    if any(type(value) is not int for value in counts.values()):
        raise ValueError("Missing or invalid XCTest summary counts")
    if counts != {"totalTestCount": len(names), "passedTests": len(names),
                  "failedTests": 0, "skippedTests": 0}:
        raise ValueError("RunnerTests must report every declared test without failures or skips")
    if type(summary.get("expectedFailures", 0)) is not int or summary.get("expectedFailures", 0) != 0:
        raise ValueError("Expected failures cannot stand in for successful tests")
    passed = []
    for line in execution_log.splitlines():
        match = re.match(r"\s*Test Case '-\[(?:RunnerTests\.)?RunnerTests (test[A-Za-z0-9_]+)\]' passed\b", line)
        if match is None:
            match = re.match(r"\s*Test case 'RunnerTests\.(test[A-Za-z0-9_]+)\(\)' passed\b", line)
        if match is not None:
            passed.append(match.group(1))
        elif re.match(r'\s*Test [Cc]ase .*\bpassed\b', line):
            raise ValueError('An unexpected XCTest class cannot supply execution evidence')
    if set(passed) != names or len(passed) != len(names):
        raise ValueError("The execution log must identify each exact RunnerTests pass once")
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
        "status": "RUNNING", "stage": "xcodebuild-test", "expected_test_count": len(names),
        "scope": "All declared source XCTests, including original in-memory App Attest and native UI rendering; iOS Simulator, not real-device App Attest proof",
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
        receipt["stage"] = "verify-all-declared-named-tests"
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
