#!/usr/bin/env python3
"""Give an existing QA Simulator bundle a local signature, never store signing.

No provisioning lookup, certificate, shared Keychain, app data, or account is
used. The real integration test must still prove that Keychain works afterward.
"""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re
import subprocess
import sys


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
    return {key: settings.get(key) for key in SETTING_KEYS}


def simulator_entitlements(settings, source):
    team = settings.get("DEVELOPMENT_TEAM")
    if not isinstance(team, str) or not re.fullmatch(r"[A-Z0-9]{10}", team):
        raise ValueError("A real resolved project team value is required, never guessed")
    prefixes = {settings[key] for key in ("AppIdentifierPrefix", "APP_IDENTIFIER_PREFIX")
                if settings.get(key)}
    if len(prefixes) > 1:
        raise ValueError("Conflicting resolved AppIdentifierPrefix values")
    prefix = next(iter(prefixes), None)
    basis = "Xcode.AppIdentifierPrefix"
    if prefix is None:
        prefix = team + "."
        basis = "Xcode.DEVELOPMENT_TEAM_simulator_local_fallback"
    if not isinstance(prefix, str) or not re.fullmatch(r"[A-Z0-9]{10}\.", prefix):
        raise ValueError("The resolved AppIdentifierPrefix is invalid or unexpanded")
    app_id = prefix + BUNDLE_ID
    if not isinstance(source, dict):
        raise ValueError("Source entitlements must be a dictionary")

    def expand(value):
        if isinstance(value, dict):
            return {key: expand(item) for key, item in value.items()}
        if isinstance(value, list):
            return [expand(item) for item in value]
        if isinstance(value, str):
            for key, replacement in (("AppIdentifierPrefix", prefix),
                                     ("PRODUCT_BUNDLE_IDENTIFIER", BUNDLE_ID),
                                     ("DEVELOPMENT_TEAM", team)):
                value = value.replace("$(" + key + ")", replacement)
            if "$" in value:
                raise ValueError("Unresolved source entitlement variable")
        return value

    entitlements = expand(source)
    if entitlements.get("application-identifier", app_id) != app_id:
        raise ValueError("Source application identifier does not match resolved Simulator identity")
    if entitlements.get("com.apple.developer.team-identifier", team) != team:
        raise ValueError("Source team entitlement does not match the actual resolved project team")
    if entitlements.get("keychain-access-groups") not in (None, [], [app_id]):
        raise ValueError("Only the QA app's private Keychain group is permitted")
    if entitlements.get("com.apple.security.application-groups"):
        raise ValueError("This fixture must not grant shared app-group access")
    entitlements.update({"application-identifier": app_id,
                         "keychain-access-groups": [app_id], "get-task-allow": True})
    return entitlements, basis


def verify_readback(raw, details, expected):
    entitlements = plistlib.loads(raw)
    if entitlements != expected:
        raise ValueError("Signed entitlements differ from the exact requested set")
    if "Signature=adhoc" not in details or any(
            line.strip().startswith("Authority=") for line in details.splitlines()):
        raise ValueError("The Simulator signature must be ad-hoc without a certificate")
    if f"Identifier={BUNDLE_ID}" not in details.splitlines():
        raise ValueError("Signed bundle identifier does not match")
    if entitlements["keychain-access-groups"] != [entitlements["application-identifier"]]:
        raise ValueError("The app identifier must match its private Keychain group")


def sign_simulator(args, *, run=subprocess.run, host=sys.platform):
    workspace = Path(args.workspace).resolve()
    output = checked_path(args.output, workspace)
    if not any(output.resolve().is_relative_to(workspace / name) for name in ("artifacts/qa", "build/qa")):
        raise ValueError("Receipt must stay in the workspace QA evidence directories")
    output.parent.mkdir(parents=True, exist_ok=True)
    receipt = {"schema": "bil.qa.simulator-adhoc-sign.v1", "status": "FAIL",
               "source_head": args.source_head, "source_tree": args.source_tree,
               "scope": "QA Debug iPhoneSimulator only; not a store signature",
               "release_app_identifier_prefix_verified": False,
               "native_keychain_test_status": "NOT_RUN_BY_HELPER", "commands": []}

    def command(argv, *, allow_failure=False, public_readback=False, timeout=30):
        result = run(argv, capture_output=True, timeout=timeout, check=False)
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
        if app.resolve() != workspace / "build/ios/iphonesimulator/Runner.app" or not app.is_dir():
            raise ValueError("Only the existing generic QA Simulator app may be signed")
        for path in app.rglob("*"):
            if path.is_symlink():
                path.resolve().relative_to(app.resolve())
            if path.name in {"embedded.mobileprovision", "embedded.provisionprofile"}:
                raise ValueError("A provisioned device/distribution bundle is forbidden")
        info_path = checked_path(app / "Info.plist", app)
        info_bytes = info_path.read_bytes()
        info = plistlib.loads(info_bytes)
        if (info.get("CFBundleIdentifier") != BUNDLE_ID or info.get("CFBundleVersion") != "36"
                or info.get("DTPlatformName") != "iphonesimulator"
                or info.get("CFBundleSupportedPlatforms") != ["iPhoneSimulator"]
                or info.get("CFBundleExecutable") != "Runner"):
            raise ValueError("Bundle identity, build 36 and Simulator platform must match")
        binary = checked_path(app / "Runner", app)
        receipt["binary_sha256_before"] = digest(binary.read_bytes())
        platform_result = command(["xcrun", "vtool", "-show-build", str(binary)], public_readback=True)
        platforms = re.findall(r"^\s*platform\s+(\S+)\s*$", platform_result.stdout.decode("utf-8"), re.MULTILINE)
        if not platforms or any(value != "IOSSIMULATOR" for value in platforms):
            raise ValueError("Every executable architecture must be an actual iOS Simulator Mach-O")
        receipt["executable_platforms"] = platforms
        before = command(["codesign", "--display", "--verbose=4", "--entitlements", "-", "--xml", str(app)],
                         allow_failure=True, public_readback=True)
        receipt["before_readback_returncode"] = before.returncode
        if any(line.strip().startswith("Authority=") for line in before.stderr.decode("utf-8", errors="replace").splitlines()):
            raise ValueError("Refusing to replace an existing certificate signature")
        settings_result = command([
            "xcodebuild", "-showBuildSettings", "-json", "-workspace", str(workspace / "ios/Runner.xcworkspace"),
            "-scheme", "Runner", "-configuration", "Debug", "-sdk", "iphonesimulator",
            "-disableAutomaticPackageResolution", "-skipPackageUpdates",
            "-destination", "generic/platform=iOS Simulator", f"BUILD_DIR={workspace / 'build/ios'}",
            "CODE_SIGNING_ALLOWED=NO", "CODE_SIGNING_REQUIRED=NO", "CODE_SIGN_IDENTITY=-",
            "PROVISIONING_PROFILE=", "PROVISIONING_PROFILE_SPECIFIER=",
        ], timeout=120)
        settings = runner_settings(settings_result.stdout)
        receipt["resolved_settings_allowlist"] = settings
        source = checked_path(workspace / "ios" / str(settings["CODE_SIGN_ENTITLEMENTS"]), workspace / "ios/Runner")
        if source.name != "RunnerDebug.entitlements":
            raise ValueError("Only the resolved RunnerDebug source entitlements may be used")
        source_bytes = source.read_bytes()
        entitlements, basis = simulator_entitlements(settings, plistlib.loads(source_bytes))
        receipt.update(source_entitlements_sha256=digest(source_bytes), simulator_local_prefix_source=basis,
                       requested_entitlements=entitlements)
        entitlements_path = checked_path(output.with_suffix(".entitlements.plist"), workspace)
        entitlements_path.write_bytes(plistlib.dumps(entitlements, fmt=plistlib.FMT_XML, sort_keys=True))
        command(["codesign", "--force", "--sign", "-", "--timestamp=none", "--generate-entitlement-der",
                 "--entitlements", str(entitlements_path), str(app)], public_readback=True)
        command(["codesign", "--verify", "--strict", "--verbose=4", str(app)], public_readback=True)
        after = command(["codesign", "--display", "--verbose=4", "--entitlements", "-", "--xml", str(app)],
                        public_readback=True)
        verify_readback(after.stdout, after.stderr.decode("utf-8", errors="replace"), entitlements)
        if info_path.read_bytes() != info_bytes or source.read_bytes() != source_bytes:
            raise ValueError("Signing must not change Info.plist or the project entitlements")
        receipt.update(status="PASS_SIMULATOR_SIGNATURE_CHECK", matching_identifier_keychain_group=True,
                       binary_sha256_after=digest(binary.read_bytes()), signed_entitlements=plistlib.loads(after.stdout))
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
    args = parser.parse_args()
    try:
        receipt = sign_simulator(args)
    except Exception as error:
        print(f"QA Simulator signing failed: {error}", file=sys.stderr)
        return 1
    print(receipt["status"] + "; native Keychain validation still required")
    return 0


if __name__ == "__main__":
    sys.exit(main())
