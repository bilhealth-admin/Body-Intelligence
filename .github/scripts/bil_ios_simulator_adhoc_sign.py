#!/usr/bin/env python3
"""Build and verify Xcode's local QA Simulator signature, never store signing.

Xcode keeps simulated iOS capabilities in its linked __entitlements section.
Do not inject those restricted capabilities into the host code signature.
Only the actual native journeys can prove launch and Keychain correctness.
"""
import argparse
import base64
import hashlib
import json
from pathlib import Path, PurePosixPath
import plistlib
import re
import shlex
import subprocess
import sys

from bil_native_bounded_command import run_bounded


BUNDLE_ID = "com.bilhealth.bodyintelligencelog"
TARGETS = {
    "integration_test/system_crypto_bridge_integration_test.dart",
    "integration_test/native_settings_polish_test.dart",
    "integration_test/native_feature_splashes_test.dart",
}
SETTING_KEYS = (
    "CONFIGURATION", "PLATFORM_NAME", "PRODUCT_BUNDLE_IDENTIFIER",
    "DEVELOPMENT_TEAM", "AppIdentifierPrefix", "APP_IDENTIFIER_PREFIX",
    "CODE_SIGN_ENTITLEMENTS", "CODE_SIGN_IDENTITY", "CODE_SIGNING_ALLOWED",
    "CODE_SIGNING_REQUIRED", "PROVISIONING_PROFILE", "PROVISIONING_PROFILE_SPECIFIER",
    "TARGET_BUILD_DIR", "FULL_PRODUCT_NAME", "LD_ENTITLEMENTS_SECTION",
    "FLUTTER_TARGET", "FLUTTER_BUILD_NUMBER",
)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def checked_path(path, root):
    path = Path(path)
    path.resolve().relative_to(root.resolve())
    if path.is_symlink():
        raise ValueError("A QA input may not be a symlink")
    return path


def runner_settings(raw):
    rows = json.loads(raw)
    if not isinstance(rows, list):
        raise ValueError("Expected Xcode JSON settings")
    matches = [row["buildSettings"] for row in rows
               if row.get("target") == "Runner" and isinstance(row.get("buildSettings"), dict)]
    if len(matches) != 1:
        raise ValueError("Exactly one resolved Runner target is required")
    settings = matches[0]
    if (settings.get("PLATFORM_NAME") != "iphonesimulator"
            or settings.get("CONFIGURATION") != "Debug"
            or settings.get("PRODUCT_BUNDLE_IDENTIFIER") != BUNDLE_ID):
        raise ValueError("Only the expected Debug iPhoneSimulator target is permitted")
    if settings.get("CODE_SIGN_IDENTITY") != "-":
        raise ValueError("A certificate signing identity is forbidden")
    if any(settings.get(key) for key in ("PROVISIONING_PROFILE", "PROVISIONING_PROFILE_SPECIFIER")):
        raise ValueError("A provisioning profile is forbidden")
    if any(settings.get(key) != "YES" for key in ("CODE_SIGNING_ALLOWED", "CODE_SIGNING_REQUIRED")):
        raise ValueError("Xcode must produce the local Simulator signature")
    defines = dict(base64.b64decode(value).decode().split("=", 1)
                   for value in settings.get("DART_DEFINES", "").split(",") if value)
    if any(defines.get(key) != value for key, value in {
        "BIL_ENVIRONMENT": "testing", "BIL_USE_SUPABASE": "false",
        "BIL_PAYMENTS_ENABLED": "false", "BIL_ADS_ENABLED": "false",
        "BIL_QA_IOS_SIMULATOR": "true",
    }.items()):
        raise ValueError("Only the existing offline Simulator QA defines are permitted")
    return {key: settings.get(key) for key in SETTING_KEYS}


def resolve_simulated_entitlements_path(settings, build_log):
    candidates = []
    configured = settings.get("LD_ENTITLEMENTS_SECTION")
    if configured is not None:
        if not isinstance(configured, str):
            raise ValueError("Xcode simulated entitlements path must be text")
        if configured.strip():
            candidates.append(configured.strip())

    log_text = build_log.decode("utf-8", errors="replace") if isinstance(build_log, bytes) else str(build_log)
    for line in log_text.splitlines():
        match = re.fullmatch(
            r"\s*export\s+LD_ENTITLEMENTS_SECTION(?:\\=|=)(.*?)\s*", line
        )
        if match is None:
            continue
        try:
            values = shlex.split(match.group(1), posix=True)
        except ValueError as error:
            raise ValueError("Xcode emitted an invalid simulated entitlements path") from error
        if not values:
            # Xcode emits an empty value while building unrelated targets.
            # Only the final nonempty Runner-generated path may be selected;
            # strict unique path, file, Mach-O and signature checks still apply.
            continue
        if len(values) != 1 or not values[0]:
            raise ValueError("Xcode must emit one simulated entitlements path")
        candidates.append(values[0])

    unique = list(dict.fromkeys(candidates))
    if not unique:
        raise ValueError("Xcode must identify exactly one generated simulated entitlements file")
    if len(unique) != 1:
        raise ValueError("Conflicting Xcode simulated entitlements paths")
    # Parse Xcode's POSIX path as POSIX even in Windows offline regression QA.
    # Convert to a filesystem Path only at the macOS-only execution boundary.
    path = PurePosixPath(unique[0]) if unique[0].startswith('/') else Path(unique[0])
    if not path.is_absolute() or path.name != "Runner.app-Simulated.xcent":
        raise ValueError("Xcode must identify the exact Runner simulated entitlements file")
    return path


def verify_simulated_entitlements(settings, source, simulated):
    if not isinstance(source, dict) or not isinstance(simulated, dict):
        raise ValueError("Source and Xcode simulated entitlements must be dictionaries")
    app_id = simulated.get("application-identifier")
    if not isinstance(app_id, str) or not re.fullmatch(r"[A-Z0-9]{10}\." + re.escape(BUNDLE_ID), app_id):
        raise ValueError("Xcode must resolve the actual simulated application identifier")
    prefix, team = app_id[:-len(BUNDLE_ID)], settings.get("DEVELOPMENT_TEAM")
    if not isinstance(team, str) or not re.fullmatch(r"[A-Z0-9]{10}", team):
        raise ValueError("The resolved project team must not be guessed")
    prefixes = {settings[key] for key in ("AppIdentifierPrefix", "APP_IDENTIFIER_PREFIX") if settings.get(key)}
    if len(prefixes) > 1 or (prefixes and prefixes != {prefix}):
        raise ValueError("Conflicting Xcode simulated application prefix")

    def expand(value):
        if isinstance(value, dict):
            return {key: expand(item) for key, item in value.items()}
        if isinstance(value, list):
            return [expand(item) for item in value]
        if isinstance(value, str):
            for key, replacement in (("AppIdentifierPrefix", prefix),
                                     ("PRODUCT_BUNDLE_IDENTIFIER", BUNDLE_ID), ("DEVELOPMENT_TEAM", team)):
                value = value.replace("$(" + key + ")", replacement)
            if "$" in value:
                raise ValueError("Unresolved source entitlement variable")
        return value

    expected = expand(source)
    if any(simulated.get(key) != value for key, value in expected.items()):
        raise ValueError("Xcode simulated capabilities differ from the project source")
    if simulated.get("com.apple.developer.team-identifier", team) != team:
        raise ValueError("Simulated team differs from the resolved project team")
    if simulated.get("keychain-access-groups") not in (None, [], [app_id]):
        raise ValueError("Only the QA app's private Keychain group is permitted")
    if simulated.get("com.apple.security.application-groups"):
        raise ValueError("This fixture must not grant shared app-group access")
    return simulated


def verify_readback(raw, details, expected):
    entitlements = plistlib.loads(raw) if raw.strip() else {}
    if not isinstance(expected, dict) or entitlements != expected:
        raise ValueError("Signed entitlements differ from Xcode's signature entitlements")
    if "Signature=adhoc" not in details or any(
            line.strip().startswith("Authority=") for line in details.splitlines()):
        raise ValueError("The Simulator signature must be ad-hoc without a certificate")
    if f"Identifier={BUNDLE_ID}" not in details.splitlines():
        raise ValueError("Signed bundle identifier does not match")
    return entitlements


def verify_simulated_sections(raw, expected, architecture_count):
    sections = []
    current = None
    section_format = None
    for line in raw.decode("utf-8").splitlines():
        if line.strip() == "Contents of (__TEXT,__entitlements) section":
            current = bytearray()
            section_format = None
            sections.append(current)
            continue
        match = re.fullmatch(r"\s*[0-9a-fA-F]{8,16}\s+([0-9a-fA-F ]+)\s*", line)
        if match is not None and current is not None:
            tokens = match.group(1).split()
            if section_format is None:
                if len(tokens)>1 and all(re.fullmatch(r"[0-9a-fA-F]{2}", t) for t in tokens):
                    section_format = "byte-pairs"
                elif len(tokens)>1 and all(re.fullmatch(r"[0-9a-fA-F]{8}", t) for t in tokens):
                    section_format = "little-endian-words"
                elif len(tokens)==1 and re.fullmatch(r"(?:[0-9a-fA-F]{2})+",tokens[0]):
                    # Existing fixture format is a single contiguous hexadecimal row.
                    section_format = "continuous-bytes"
                else:
                    raise ValueError("Unrecognized otool entitlement hex representation")
            if section_format=="byte-pairs" and tokens and all(re.fullmatch(r"[0-9a-fA-F]{2}",t) for t in tokens):
                payload = bytes.fromhex("".join(tokens))
            elif section_format=="little-endian-words" and tokens and all(re.fullmatch(r"[0-9a-fA-F]{8}",t) for t in tokens):
                payload = b"".join(bytes.fromhex(t)[::-1] for t in tokens)
            elif section_format=="continuous-bytes" and len(tokens)==1 and re.fullmatch(r"(?:[0-9a-fA-F]{2})+",tokens[0]):
                payload = bytes.fromhex(tokens[0])
            else:
                raise ValueError("Mixed or malformed otool entitlement rows")
            current.extend(payload)
        elif line.strip():
            current = None
    if len(sections) != architecture_count or any(
            plistlib.loads(bytes(section).rstrip(b"\0")) != expected for section in sections):
        raise ValueError("Every Mach-O architecture must embed Xcode's simulated entitlements")
    return len(sections)


def sign_simulator(args, *, run=subprocess.run, run_build=run_bounded, host=sys.platform):
    build_number = getattr(args, "build_number", "37")
    if build_number not in ("37", "39"):
        raise ValueError("Only the reviewed Simulator QA build numbers are permitted")
    workspace = Path(args.workspace).resolve()
    output = checked_path(args.output, workspace)
    if not any(output.resolve().is_relative_to(workspace / name) for name in ("artifacts/qa", "build/qa")):
        raise ValueError("Receipt must stay in the workspace QA evidence directories")
    output.parent.mkdir(parents=True, exist_ok=True)
    receipt = {"schema": "bil.qa.simulator-adhoc-sign.v2", "status": "FAIL",
               "source_head": args.source_head, "source_tree": args.source_tree,
               "scope": "Xcode QA Debug iPhoneSimulator local signature only; not a store signature or launch proof",
               "release_app_identifier_prefix_verified": False,
               "native_keychain_test_status": "NOT_RUN_BY_HELPER", "commands": []}

    def command(argv, *, public_readback=False, timeout=30, log_path=None, allow_failure=False):
        try:
            result = run(argv, capture_output=True, timeout=timeout, check=False)
        except subprocess.TimeoutExpired as failure:
            if log_path is not None:
                log_path.write_bytes((failure.stdout or b"") + (failure.stderr or b""))
            raise
        if log_path is not None:
            log_path.write_bytes(result.stdout + result.stderr)
        row = {"argv": argv, "returncode": result.returncode,
               "stdout_sha256": digest(result.stdout), "stderr_sha256": digest(result.stderr)}
        if public_readback:
            row.update(stdout=result.stdout.decode("utf-8", errors="replace"),
                       stderr=result.stderr.decode("utf-8", errors="replace"))
        receipt["commands"].append(row)
        if result.returncode and not allow_failure:
            raise RuntimeError(f"QA command failed ({result.returncode}): {argv[0]}")
        return result

    try:
        if host != "darwin" or not args.qa_simulator_only or args.target not in TARGETS:
            raise ValueError("This operation requires an explicit QA Simulator target on macOS")
        if not all(re.fullmatch(r"[0-9a-f]{40}", value) for value in (args.source_head, args.source_tree)):
            raise ValueError("Source HEAD and tree hashes are required")
        app = checked_path(args.app, workspace)
        if app.resolve() != workspace / "build/ios/Debug-iphonesimulator/Runner.app":
            raise ValueError("Only Xcode's exact QA Simulator output may be used")
        if app.exists():
            if any(path.name in {"embedded.mobileprovision", "embedded.provisionprofile"}
                   for path in app.rglob("*")):
                raise ValueError("A provisioned device/distribution bundle is forbidden")
            before = command(["codesign", "--display", "--verbose=4", str(app)],
                             public_readback=True, allow_failure=True)
            if any(line.strip().startswith("Authority=") for line in
                   before.stderr.decode("utf-8", errors="replace").splitlines()):
                raise ValueError("Refusing to replace an existing certificate signature")
        xcode = ["xcodebuild", "-workspace", str(workspace / "ios/Runner.xcworkspace"),
                 "-scheme", "Runner", "-configuration", "Debug", "-sdk", "iphonesimulator",
                 "-destination", "generic/platform=iOS Simulator",
                 "-clonedSourcePackagesDirPath", str(workspace / "build/ios/SourcePackages"),
                 "-disableAutomaticPackageResolution", "-skipPackageUpdates",
                 f"BUILD_DIR={workspace / 'build/ios'}", "CODE_SIGN_IDENTITY=-",
                 "CODE_SIGNING_ALLOWED=YES", "CODE_SIGNING_REQUIRED=YES",
                 "PROVISIONING_PROFILE=", "PROVISIONING_PROFILE_SPECIFIER=",
                 f"FLUTTER_TARGET={args.target}", f"FLUTTER_BUILD_NUMBER={build_number}"]
        settings = runner_settings(command(xcode + ["-showBuildSettings", "-json"], timeout=120).stdout)
        if settings["FLUTTER_TARGET"] != args.target or settings["FLUTTER_BUILD_NUMBER"] != build_number:
            raise ValueError("Xcode must build the exact requested entrypoint and QA build number")
        if (Path(settings["TARGET_BUILD_DIR"]).resolve() / settings["FULL_PRODUCT_NAME"]) != app.resolve():
            raise ValueError("Resolved Xcode output does not match the exact Simulator app")
        receipt["resolved_settings_allowlist"] = settings
        source = checked_path(workspace / "ios" / str(settings["CODE_SIGN_ENTITLEMENTS"]), workspace / "ios/Runner")
        if source.name != "RunnerDebug.entitlements":
            raise ValueError("Only the resolved RunnerDebug source entitlements may be used")
        source_bytes = source.read_bytes()
        build_command = xcode + ["build"]
        build_log = output.with_suffix(".xcode-build.log")
        build_code = run_build(
            build_command, label="xcode-simulator-local-build", log_path=build_log,
            receipt_path=output.with_suffix(".xcode-build-result.json"), timeout_seconds=1500,
        )
        receipt["commands"].append({"argv": build_command, "returncode": build_code,
                                    "log_sha256": digest(build_log.read_bytes())})
        if build_code != 0:
            raise RuntimeError(f"QA command failed ({build_code}): xcodebuild")
        if not app.is_dir():
            raise ValueError("Xcode did not produce the exact Simulator app")
        for path in app.rglob("*"):
            if path.is_symlink():
                path.resolve().relative_to(app.resolve())
            if path.name in {"embedded.mobileprovision", "embedded.provisionprofile"}:
                raise ValueError("A provisioned device/distribution bundle is forbidden")
        info_path = checked_path(app / "Info.plist", app)
        info_bytes = info_path.read_bytes()
        info = plistlib.loads(info_bytes)
        if (info.get("CFBundleIdentifier") != BUNDLE_ID or info.get("CFBundleVersion") != build_number
                or info.get("DTPlatformName") != "iphonesimulator"
                or info.get("CFBundleSupportedPlatforms") != ["iPhoneSimulator"]
                or info.get("CFBundleExecutable") != "Runner"):
            raise ValueError("Bundle identity, requested QA build number and Simulator platform must match")
        binary = checked_path(app / "Runner", app)
        receipt["binary_sha256_after"] = digest(binary.read_bytes())
        platform_result = command(["xcrun", "vtool", "-show-build", str(binary)], public_readback=True)
        platforms = re.findall(r"^\s*platform\s+(\S+)\s*$", platform_result.stdout.decode("utf-8"), re.MULTILINE)
        if not platforms or any(value != "IOSSIMULATOR" for value in platforms):
            raise ValueError("Every executable architecture must be an actual iOS Simulator Mach-O")
        simulated_path = Path(resolve_simulated_entitlements_path(settings, build_log.read_bytes()))
        # Xcode's generated build intermediates may live in DerivedData. Read
        # only its resolved xcent siblings; never create or rewrite either file.
        if not simulated_path.is_absolute() or not simulated_path.name.endswith("-Simulated.xcent"):
            raise ValueError("Xcode must identify its generated simulated entitlements")
        signature_path = simulated_path.with_name(simulated_path.name.replace("-Simulated.xcent", ".xcent"))
        if simulated_path.is_symlink() or signature_path.is_symlink():
            raise ValueError("Generated Xcode entitlements may not be symlinks")
        simulated = verify_simulated_entitlements(settings, plistlib.loads(source_bytes),
                                                  plistlib.loads(simulated_path.read_bytes()))
        linked_sections = command(["xcrun", "otool", "-s", "__TEXT", "__entitlements", str(binary)],
                                  public_readback=True)
        section_count = verify_simulated_sections(linked_sections.stdout, simulated, len(platforms))
        expected_signature = plistlib.loads(signature_path.read_bytes())
        # The restricted iOS capabilities belong to the simulated section,
        # not to the host's code signature. In this QA profile Xcode emits {}.
        if expected_signature != {}:
            raise ValueError("Unexpected nonempty Xcode Simulator host-signature entitlements")
        command(["codesign", "--verify", "--deep", "--strict", "--verbose=4", str(app)], public_readback=True)
        after = command(["codesign", "--display", "--verbose=4", "--entitlements", "-", "--xml", str(app)],
                        public_readback=True)
        signed = verify_readback(after.stdout, after.stderr.decode("utf-8", errors="replace"), expected_signature)
        if info_path.read_bytes() != info_bytes or source.read_bytes() != source_bytes:
            raise ValueError("Verification must not change Info.plist or the project entitlements")
        receipt.update(status="PASS_SIMULATOR_SIGNATURE_CHECK", executable_platforms=platforms,
                       source_entitlements_sha256=digest(source_bytes),
                       xcode_simulated_entitlements_sha256=digest(simulated_path.read_bytes()),
                       xcode_signature_entitlements_sha256=digest(signature_path.read_bytes()),
                       simulated_entitlement_sections_verified=section_count,
                       simulated_entitlements=simulated, signed_entitlements=signed,
                       signing_basis="Xcode Sign to Run Locally; separate simulated iOS capabilities",
                       simulated_launch_proven=False)
    except Exception as error:
        receipt["error"] = f"{type(error).__name__}: {error}"
        raise
    finally:
        output.write_text(json.dumps(receipt, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("workspace", "app", "output", "target", "source-head", "source-tree"):
        parser.add_argument("--" + name, required=True)
    parser.add_argument("--qa-simulator-only", action="store_true", required=True)
    parser.add_argument("--build-number", choices=("37", "39"), default="37")
    args = parser.parse_args()
    try:
        receipt = sign_simulator(args)
    except Exception as error:
        print(f"QA Simulator signing failed: {error}", file=sys.stderr)
        return 1
    print(receipt["status"] + "; native launch and Keychain validation still required")
    return 0


if __name__ == "__main__":
    sys.exit(main())
