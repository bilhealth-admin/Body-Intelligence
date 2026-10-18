"""Host-side fixture tests only; these do not execute Apple signing or Keychain."""
import argparse
import importlib.util
import json
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("bil_ios_simulator_adhoc_sign.py")
SPEC = importlib.util.spec_from_file_location("bil_simulator_sign", SCRIPT)
SIGN = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SIGN)


class SimulatorSigningFixtures(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="bil-qa-simulator-sign-")
        self.addCleanup(self.temp.cleanup)
        self.workspace = Path(self.temp.name).resolve()
        self.app = self.workspace / "build/ios/iphonesimulator/Runner.app"
        self.app.mkdir(parents=True)
        self.info = {"CFBundleIdentifier": SIGN.BUNDLE_ID, "CFBundleVersion": "37",
                     "CFBundleExecutable": "Runner", "DTPlatformName": "iphonesimulator",
                     "CFBundleSupportedPlatforms": ["iPhoneSimulator"]}
        self.write_info()
        (self.app / "Runner").write_bytes(b"synthetic unsigned executable")
        self.source = self.workspace / "ios/Runner/RunnerDebug.entitlements"
        self.source.parent.mkdir(parents=True)
        self.source.write_bytes(plistlib.dumps({"com.apple.developer.healthkit": True}))
        self.settings = {"CONFIGURATION": "Debug", "PLATFORM_NAME": "iphonesimulator",
                         "PRODUCT_BUNDLE_IDENTIFIER": SIGN.BUNDLE_ID, "DEVELOPMENT_TEAM": "QATEAM1234",
                         "AppIdentifierPrefix": "QAPREFIX12.", "CODE_SIGN_IDENTITY": "-",
                         "CODE_SIGNING_ALLOWED": "NO", "CODE_SIGNING_REQUIRED": "NO",
                         "CODE_SIGN_ENTITLEMENTS": "Runner/RunnerDebug.entitlements",
                         "PROVISIONING_PROFILE": "", "PROVISIONING_PROFILE_SPECIFIER": "",
                         "UNRELATED_SECRET_ENVIRONMENT_VALUE": "must-not-enter-receipt"}
        self.args = argparse.Namespace(workspace=str(self.workspace), app=str(self.app),
            output=str(self.workspace / "build/qa/simulator-sign-result.json"),
            target="integration_test/system_crypto_bridge_integration_test.dart",
            source_head="a" * 40, source_tree="b" * 40, qa_simulator_only=True)
        self.commands = []
        self.signed = False
        self.fail_operation = None
        self.alter_readback = None
        self.binary_platform = "IOSSIMULATOR"
        self.before_certificate = False

    def write_info(self):
        (self.app / "Info.plist").write_bytes(plistlib.dumps(self.info))

    def runner(self, argv, **kwargs):
        self.assertTrue(kwargs["capture_output"])
        self.assertFalse(kwargs["check"])
        self.assertGreater(kwargs["timeout"], 0)
        self.commands.append(argv)
        if argv[0] == "xcrun":
            return subprocess.CompletedProcess(argv, 0, f"  platform {self.binary_platform}\n".encode(), b"")
        operation = "settings" if argv[0] == "xcodebuild" else (
            "sign" if "--sign" in argv else "verify" if "--verify" in argv else "readback")
        if operation == self.fail_operation:
            return subprocess.CompletedProcess(argv, 9, b"", b"synthetic command failure")
        if operation == "settings":
            return subprocess.CompletedProcess(argv, 0, json.dumps([
                {"target": "Runner", "buildSettings": self.settings}]).encode(), b"")
        if operation == "sign":
            self.assertEqual(argv[argv.index("--sign") + 1], "-")
            self.signed = True
            (self.app / "Runner").write_bytes(b"synthetic signed executable")
            return subprocess.CompletedProcess(argv, 0, b"", b"synthetic ad-hoc signature")
        if operation == "verify":
            return subprocess.CompletedProcess(argv, 0, b"", b"synthetic valid on disk")
        if not self.signed:
            if self.before_certificate:
                return subprocess.CompletedProcess(argv, 0, b"", b"Authority=Existing Synthetic Certificate\n")
            return subprocess.CompletedProcess(argv, 1, b"", b"code object is not signed at all")
        requested = plistlib.loads(Path(self.args.output).with_suffix(".entitlements.plist").read_bytes())
        details = f"Identifier={SIGN.BUNDLE_ID}\nSignature=adhoc\nTeamIdentifier=not set\n"
        if self.alter_readback:
            requested, details = self.alter_readback(requested, details)
        return subprocess.CompletedProcess(argv, 0, plistlib.dumps(requested), details.encode())

    def invoke(self, **kwargs):
        return SIGN.sign_simulator(self.args, run=self.runner, host=kwargs.get("host", "darwin"))

    def fails(self, pattern, **kwargs):
        with self.assertRaisesRegex((ValueError, RuntimeError), pattern):
            self.invoke(**kwargs)
        receipt = json.loads(Path(self.args.output).read_text(encoding="utf-8"))
        self.assertEqual(receipt["status"], "FAIL")
        self.assertNotIn("matching_identifier_keychain_group", receipt)
        self.assertEqual(receipt["native_keychain_test_status"], "NOT_RUN_BY_HELPER")
        return receipt

    def test_unsigned_fixture_becomes_exact_local_signature_with_real_prefix(self):
        receipt = self.invoke()
        self.assertEqual(receipt["status"], "PASS_SIMULATOR_SIGNATURE_CHECK")
        self.assertTrue(receipt["matching_identifier_keychain_group"])
        self.assertEqual(receipt["before_readback_returncode"], 1)
        self.assertEqual(receipt["simulator_local_prefix_source"], "Xcode.AppIdentifierPrefix")
        self.assertEqual(receipt["signed_entitlements"]["application-identifier"],
                         "QAPREFIX12." + SIGN.BUNDLE_ID)
        self.assertTrue(receipt["signed_entitlements"]["com.apple.developer.healthkit"])
        self.assertNotEqual(receipt["binary_sha256_before"], receipt["binary_sha256_after"])
        self.assertNotIn("must-not-enter-receipt", json.dumps(receipt))
        self.assertFalse(receipt["release_app_identifier_prefix_verified"])
        self.assertEqual(receipt["native_keychain_test_status"], "NOT_RUN_BY_HELPER")
        self.assertEqual(len(self.commands), 6)
        self.assertFalse(any("allowProvisioning" in arg for cmd in self.commands for arg in cmd))

    def test_absent_prefix_uses_declared_simulator_only_team_fallback(self):
        del self.settings["AppIdentifierPrefix"]
        receipt = self.invoke()
        self.assertEqual(receipt["simulator_local_prefix_source"],
                         "Xcode.DEVELOPMENT_TEAM_simulator_local_fallback")
        self.assertEqual(receipt["signed_entitlements"]["application-identifier"],
                         "QATEAM1234." + SIGN.BUNDLE_ID)
        self.assertFalse(receipt["release_app_identifier_prefix_verified"])

    def test_non_macos_host_is_refused_before_commands(self):
        self.fails("requires an explicit QA", host="win32")
        self.assertFalse(self.commands)

    def test_non_qa_target_is_refused_before_commands(self):
        self.args.target = "lib/main.dart"
        self.fails("requires an explicit QA")
        self.assertFalse(self.commands)

    def test_missing_qa_opt_in_is_refused(self):
        self.args.qa_simulator_only = False
        self.fails("requires an explicit QA")

    def test_source_hashes_are_required(self):
        self.args.source_head = "unknown"
        self.fails("HEAD and tree")

    def test_device_bundle_is_refused(self):
        self.info["DTPlatformName"] = "iphoneos"
        self.write_info()
        self.fails("Simulator platform")
        self.assertFalse(self.commands)

    def test_provisioned_bundle_is_refused(self):
        (self.app / "embedded.mobileprovision").write_bytes(b"synthetic forbidden profile")
        self.fails("provisioned device")
        self.assertFalse(self.commands)

    def test_wrong_bundle_identity_is_refused(self):
        self.info["CFBundleIdentifier"] = "com.example.unowned"
        self.write_info()
        self.fails("Bundle identity")

    def test_non_adhoc_resolved_identity_is_refused(self):
        self.settings["CODE_SIGN_IDENTITY"] = "Apple Distribution: Synthetic Forbidden"
        self.fails("certificate signing identity")
        self.assertFalse(self.signed)

    def test_resolved_provisioning_profile_is_refused(self):
        self.settings["PROVISIONING_PROFILE_SPECIFIER"] = "Synthetic Forbidden Profile"
        self.fails("provisioning profile")
        self.assertFalse(self.signed)

    def test_conflicting_prefix_is_not_replaced_with_team(self):
        self.settings["APP_IDENTIFIER_PREFIX"] = "ANOTHER123."
        self.fails("Conflicting")
        self.assertFalse(self.signed)

    def test_unexpanded_prefix_is_not_replaced_with_team(self):
        self.settings["AppIdentifierPrefix"] = "$(UNKNOWN)."
        self.fails("invalid or unexpanded")

    def test_missing_team_is_not_guessed(self):
        self.settings["DEVELOPMENT_TEAM"] = ""
        self.fails("never guessed")

    def test_shared_keychain_group_is_refused(self):
        self.source.write_bytes(plistlib.dumps({"keychain-access-groups": ["unowned.shared"]}))
        self.fails("private Keychain group")
        self.assertFalse(self.signed)

    def test_shared_app_group_is_refused(self):
        self.source.write_bytes(plistlib.dumps({"com.apple.security.application-groups": ["group.shared"]}))
        self.fails("shared app-group")

    def test_signing_failure_is_preserved_in_receipt(self):
        self.fail_operation = "sign"
        receipt = self.fails("QA command failed")
        self.assertEqual(receipt["commands"][-1]["returncode"], 9)
        self.assertFalse(self.signed)

    def test_signature_verification_failure_does_not_become_pass(self):
        self.fail_operation = "verify"
        receipt = self.fails("QA command failed")
        self.assertEqual(receipt["commands"][-1]["returncode"], 9)

    def test_mismatching_signed_group_does_not_become_pass(self):
        def alter(entitlements, details):
            entitlements["keychain-access-groups"] = ["unowned.shared"]
            return entitlements, details
        self.alter_readback = alter
        self.fails("Signed entitlements differ")

    def test_unexpected_certificate_signature_does_not_become_pass(self):
        self.alter_readback = lambda ent, text: (ent, text + "Authority=Synthetic Certificate\n")
        self.fails("without a certificate")

    def test_project_source_entitlements_are_never_overwritten(self):
        before = self.source.read_bytes()
        self.invoke()
        self.assertEqual(self.source.read_bytes(), before)

    def test_source_team_mismatch_is_refused(self):
        self.source.write_bytes(plistlib.dumps({"com.apple.developer.team-identifier": "ANOTHER123"}))
        self.fails("actual resolved project team")

    def test_device_macho_is_refused_even_if_info_claims_simulator(self):
        self.binary_platform = "IOS"
        self.fails("actual iOS Simulator Mach-O")
        self.assertFalse(self.signed)

    def test_existing_certificate_signature_is_not_replaced(self):
        self.before_certificate = True
        self.fails("existing certificate signature")
        self.assertFalse(self.signed)

    def test_duplicate_runner_settings_are_refused(self):
        row = {"target": "Runner", "buildSettings": self.settings}
        with self.assertRaisesRegex(ValueError, "Exactly one"):
            SIGN.runner_settings(json.dumps([row, row]))

    def test_command_timeout_stays_a_failure_and_preserves_receipt(self):
        def timeout(*args, **kwargs):
            raise subprocess.TimeoutExpired("synthetic local readback", 30)
        with self.assertRaises(subprocess.TimeoutExpired):
            SIGN.sign_simulator(self.args, run=timeout, host="darwin")
        receipt = json.loads(Path(self.args.output).read_text(encoding="utf-8"))
        self.assertEqual(receipt["status"], "FAIL")
        self.assertIn("TimeoutExpired", receipt["error"])


class SwiftPackageInventoryFixtures(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="bil-qa-swiftpm-inventory-")
        self.addCleanup(self.temp.cleanup)
        self.workspace = Path(self.temp.name).resolve()
        self.app = self.workspace / "build/ios/iphonesimulator/Runner.app"
        self.app.mkdir(parents=True)
        self.output = self.workspace / "build/qa/inventory.json"
        self.output.parent.mkdir(parents=True)
        script = SCRIPT.with_name("bil_ios37_native_integration.sh").read_text(encoding="utf-8")
        self.inventory = script.split("<<'BIL_PRIVACY_PY'\n", 1)[1].split("\nBIL_PRIVACY_PY", 1)[0]

    def write_lock(self, path, document):
        target = self.workspace / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(document), encoding="utf-8")
        return target

    def invoke(self, expected_success=True):
        result = subprocess.run([sys.executable, "-B", "-c", self.inventory,
                                 str(self.app), str(self.output), "a" * 40],
                                cwd=self.workspace, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode == 0, expected_success, result.stderr)
        return json.loads(self.output.read_text(encoding="utf-8")) if expected_success else None

    def test_current_workspace_lock_keeps_only_identity_version_revision(self):
        target = self.write_lock("ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved", {
            "version": 3, "originHash": "unneeded-origin",
            "pins": [{"identity": "swift-package-manager-google-mobile-ads",
                      "location": "https://credential@example.invalid/private.git",
                      "state": {"version": "13.11.0", "revision": "a" * 40,
                                "branch": "unneeded-branch"}}]})
        data = self.invoke()
        self.assertEqual(data["swiftpm_lock_status"], "FOUND")
        lock = data["swiftpm_resolved_locks"][0]
        self.assertEqual(lock["sha256"], SIGN.digest(target.read_bytes()))
        self.assertEqual(lock["pins"], [{"identity": "swift-package-manager-google-mobile-ads",
                                        "version": "13.11.0", "revision": "a" * 40}])
        serialized = json.dumps(data)
        self.assertNotIn("credential", serialized)
        self.assertNotIn("private.git", serialized)
        self.assertNotIn("unneeded-branch", serialized)

    def test_checkout_lock_is_not_claimed_as_final_compiled_version(self):
        self.write_lock("build/ios/SourcePackages/checkouts/vendor/Package.resolved", {
            "version": 1, "object": {"pins": [{"package": "LegacyVendor",
              "repositoryURL": "https://credential@example.invalid/vendor.git",
              "state": {"version": "13.7.0", "revision": "b" * 40}}]}})
        data = self.invoke()
        lock = data["swiftpm_resolved_locks"][0]
        self.assertEqual(lock["scope"], "checkout lock; not final app resolution")
        self.assertEqual(lock["pins"][0]["version"], "13.7.0")
        self.assertFalse(data["sdk_signatures_verified"])
        self.assertFalse(data["network_collection_verified"])

    def test_missing_resolution_is_unknown(self):
        data = self.invoke()
        self.assertEqual(data["swiftpm_lock_status"], "UNKNOWN_NO_RESOLVED_LOCK_FOUND")
        self.assertEqual(data["swiftpm_resolved_locks"], [])

    def test_unrecognized_lock_schema_is_explicitly_unknown(self):
        self.write_lock("ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved", {"version": 99})
        data = self.invoke()
        self.assertEqual(data["swiftpm_resolved_locks"][0]["status"], "UNKNOWN_SCHEMA")

    def test_malformed_pin_fails_instead_of_claiming_complete_inventory(self):
        self.write_lock("ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved", {"pins": ["bad"]})
        self.invoke(expected_success=False)


if __name__ == "__main__":
    unittest.main(verbosity=2)
