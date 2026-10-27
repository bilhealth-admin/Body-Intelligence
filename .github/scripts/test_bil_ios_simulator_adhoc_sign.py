"""Host-side fixture tests only; these do not execute Apple signing or Keychain."""
import argparse
import base64
import importlib.util
import json
from pathlib import Path
import plistlib
import shlex
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("bil_ios_simulator_adhoc_sign.py")
SPEC = importlib.util.spec_from_file_location("bil_simulator_sign", SCRIPT)
SIGN = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SIGN)


class ExactSimulatorDestination(unittest.TestCase):
    def test_legacy_default_is_unchanged(self):
        self.assertEqual(SIGN.simulator_build_destination(), ['-destination', 'generic/platform=iOS Simulator'])

    def test_exact_device_uses_only_active_architecture(self):
        device = 'AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE'
        self.assertEqual(SIGN.simulator_build_destination(device),
            ['-destination', 'platform=iOS Simulator,id=' + device, 'ONLY_ACTIVE_ARCH=YES'])

    def test_invalid_or_ambiguous_destinations_are_refused(self):
        for device in ['', 'booted', 'generic/platform=iOS Simulator', 'AAAAAAAA-' * 5]:
            with self.subTest(device=device), self.assertRaises(ValueError):
                SIGN.simulator_build_destination(device)


class SimulatorSigningFixtures(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="bil-qa-simulator-sign-")
        self.addCleanup(self.temp.cleanup)
        self.workspace = Path(self.temp.name).resolve()
        self.app = self.workspace / "build/ios/Debug-iphonesimulator/Runner.app"
        self.app.mkdir(parents=True)
        self.info = {"CFBundleIdentifier": SIGN.BUNDLE_ID, "CFBundleVersion": "37",
                     "CFBundleExecutable": "Runner", "DTPlatformName": "iphonesimulator",
                     "CFBundleSupportedPlatforms": ["iPhoneSimulator"]}
        self.write_info()
        (self.app / "Runner").write_bytes(b"synthetic executable")
        self.source = self.workspace / "ios/Runner/RunnerDebug.entitlements"
        self.source.parent.mkdir(parents=True)
        self.source.write_bytes(plistlib.dumps({"com.apple.developer.healthkit": True}))
        self.xcent = self.workspace / "build/ios/derived/Runner.app-Simulated.xcent"
        self.xcent.parent.mkdir(parents=True)
        self.simulated = {"com.apple.developer.healthkit": True,
                          "application-identifier": "QAPREFIX12." + SIGN.BUNDLE_ID}
        self.signature = {}
        self.readback = {}
        definitions = {"BIL_ENVIRONMENT": "testing", "BIL_USE_SUPABASE": "false",
                       "BIL_PAYMENTS_ENABLED": "false", "BIL_ADS_ENABLED": "false",
                       "BIL_QA_IOS_SIMULATOR": "true"}
        self.settings = {"CONFIGURATION": "Debug", "PLATFORM_NAME": "iphonesimulator",
                         "PRODUCT_BUNDLE_IDENTIFIER": SIGN.BUNDLE_ID, "DEVELOPMENT_TEAM": "QATEAM1234",
                         "AppIdentifierPrefix": "QAPREFIX12.", "CODE_SIGN_IDENTITY": "-",
                         "CODE_SIGNING_ALLOWED": "YES", "CODE_SIGNING_REQUIRED": "YES",
                         "CODE_SIGN_ENTITLEMENTS": "Runner/RunnerDebug.entitlements",
                         "PROVISIONING_PROFILE": "", "PROVISIONING_PROFILE_SPECIFIER": "",
                         "TARGET_BUILD_DIR": str(self.app.parent), "FULL_PRODUCT_NAME": "Runner.app",
                         "LD_ENTITLEMENTS_SECTION": None,
                         "FLUTTER_TARGET": "integration_test/system_crypto_bridge_integration_test.dart",
                         "FLUTTER_BUILD_NUMBER": "37",
                         "DART_DEFINES": ",".join(base64.b64encode(f"{k}={v}".encode()).decode()
                                                for k, v in definitions.items()),
                         "UNRELATED_SECRET_ENVIRONMENT_VALUE": "must-not-enter-receipt"}
        self.args = argparse.Namespace(workspace=str(self.workspace), app=str(self.app),
            output=str(self.workspace / "build/qa/simulator-sign-result.json"),
            target=self.settings["FLUTTER_TARGET"], source_head="a" * 40,
            source_tree="b" * 40, qa_simulator_only=True)
        self.commands = []
        self.built = False
        self.fail_operation = None
        self.binary_platform = "IOSSIMULATOR"
        self.before_certificate = False
        self.after_certificate = False
        self.missing_linked_section = False
        self.include_entitlements_export = True

    def write_info(self):
        (self.app / "Info.plist").write_bytes(plistlib.dumps(self.info))

    def runner(self, argv, **kwargs):
        self.assertTrue(kwargs["capture_output"])
        self.assertFalse(kwargs["check"])
        self.assertGreater(kwargs["timeout"], 0)
        self.commands.append(argv)
        operation = ("settings" if "-showBuildSettings" in argv else "build") if argv[0] == "xcodebuild" else (
            "platform" if argv[0] == "xcrun" else "verify" if "--verify" in argv else "readback")
        if operation == self.fail_operation:
            return subprocess.CompletedProcess(argv, 9, b"", b"synthetic command failure")
        if operation == "settings":
            return subprocess.CompletedProcess(argv, 0, json.dumps([
                {"target": "Runner", "buildSettings": self.settings}]).encode(), b"")
        if operation == "build":
            self.assertIn("CODE_SIGN_IDENTITY=-", argv)
            self.assertIn("CODE_SIGNING_ALLOWED=YES", argv)
            self.assertIn("CODE_SIGNING_REQUIRED=YES", argv)
            self.assertIn("FLUTTER_TARGET=" + self.args.target, argv)
            self.built = True
            self.xcent.write_bytes(plistlib.dumps(self.simulated))
            self.xcent.with_name("Runner.app.xcent").write_bytes(plistlib.dumps(self.signature))
            stdout = (f"export LD_ENTITLEMENTS_SECTION={shlex.quote(self.xcent.as_posix())}\n".encode()
                      if self.include_entitlements_export else b"synthetic Xcode build succeeded")
            return subprocess.CompletedProcess(argv, 0, stdout, b"")
        if operation == "platform":
            if argv[1] == "otool":
                content = plistlib.dumps(self.simulated)
                lines = ["Runner (architecture arm64):"]
                if not self.missing_linked_section:
                    lines.append("Contents of (__TEXT,__entitlements) section")
                    lines.extend(f"{4096 + offset:016x} {content[offset:offset+16].hex()}"
                                 for offset in range(0, len(content), 16))
                return subprocess.CompletedProcess(argv, 0, "\n".join(lines).encode(), b"")
            return subprocess.CompletedProcess(argv, 0, f"  platform {self.binary_platform}\n".encode(), b"")
        if operation == "verify":
            self.assertIn("--deep", argv)
            return subprocess.CompletedProcess(argv, 0, b"", b"synthetic valid on disk")
        details = f"Identifier={SIGN.BUNDLE_ID}\nSignature=adhoc\nTeamIdentifier=not set\n"
        if (not self.built and self.before_certificate) or (self.built and self.after_certificate):
            details += "Authority=Existing Synthetic Certificate\n"
        return subprocess.CompletedProcess(argv, 0, plistlib.dumps(self.readback), details.encode())

    def build_runner(self, argv, **kwargs):
        self.assertEqual(kwargs["timeout_seconds"], 1500)
        self.assertTrue(str(kwargs["receipt_path"]).endswith(".xcode-build-result.json"))
        result = self.runner(argv, capture_output=True, timeout=1500, check=False)
        kwargs["log_path"].write_bytes(result.stdout + result.stderr)
        return result.returncode

    def invoke(self, **kwargs):
        return SIGN.sign_simulator(self.args, run=self.runner, run_build=self.build_runner,
                                   host=kwargs.get("host", "darwin"))

    def fails(self, pattern, **kwargs):
        with self.assertRaisesRegex((ValueError, RuntimeError), pattern):
            self.invoke(**kwargs)
        receipt = json.loads(Path(self.args.output).read_text(encoding="utf-8"))
        self.assertEqual(receipt["status"], "FAIL")
        self.assertEqual(receipt["native_keychain_test_status"], "NOT_RUN_BY_HELPER")
        return receipt

    def test_xcode_keeps_simulated_capabilities_outside_host_signature(self):
        before = self.source.read_bytes()
        receipt = self.invoke()
        self.assertEqual(receipt["status"], "PASS_SIMULATOR_SIGNATURE_CHECK")
        self.assertEqual(receipt["signed_entitlements"], {})
        self.assertTrue(receipt["simulated_entitlements"]["com.apple.developer.healthkit"])
        self.assertEqual(receipt["simulated_entitlements"]["application-identifier"],
                         "QAPREFIX12." + SIGN.BUNDLE_ID)
        self.assertEqual(self.source.read_bytes(), before)
        self.assertNotIn("must-not-enter-receipt", json.dumps(receipt))
        self.assertFalse(receipt["release_app_identifier_prefix_verified"])
        self.assertFalse(receipt["simulated_launch_proven"])
        self.assertEqual(receipt["native_keychain_test_status"], "NOT_RUN_BY_HELPER")
        self.assertFalse(any(arg == "--sign" or "allowProvisioning" in arg
                             for cmd in self.commands for arg in cmd))

    def test_build39_requires_matching_xcode_settings_and_actual_bundle(self):
        self.args.build_number = '39'
        self.settings['FLUTTER_BUILD_NUMBER'] = '39'
        self.info['CFBundleVersion'] = '39'
        self.write_info()
        receipt = self.invoke()
        self.assertEqual(receipt['status'], 'PASS_SIMULATOR_SIGNATURE_CHECK')
        self.assertTrue(any('FLUTTER_BUILD_NUMBER=39' in command for command in self.commands))

    def test_old_bundle_cannot_satisfy_requested_build39(self):
        self.args.build_number = '39'
        self.settings['FLUTTER_BUILD_NUMBER'] = '39'
        self.fails('requested QA build number')

    def test_missing_setting_and_build_export_fail_closed(self):
        self.include_entitlements_export = False
        self.fails('identify exactly one generated simulated entitlements file')

    def test_conflicting_build_setting_and_build_log_paths_are_refused(self):
        self.settings['LD_ENTITLEMENTS_SECTION'] = str(
            self.workspace / 'other/Runner.app-Simulated.xcent'
        )
        self.fails('Conflicting Xcode simulated entitlements paths')

    def test_resolved_build_setting_remains_a_fallback_when_log_has_no_export(self):
        self.settings['LD_ENTITLEMENTS_SECTION'] = str(self.xcent)
        self.include_entitlements_export = False
        receipt = self.invoke()
        self.assertEqual(receipt['status'], 'PASS_SIMULATOR_SIGNATURE_CHECK')

    def test_actual_generated_prefix_is_read_not_invented_when_setting_absent(self):
        del self.settings["AppIdentifierPrefix"]
        receipt = self.invoke()
        self.assertEqual(receipt["simulated_entitlements"]["application-identifier"],
                         "QAPREFIX12." + SIGN.BUNDLE_ID)
        self.assertNotIn("QATEAM1234." + SIGN.BUNDLE_ID, json.dumps(receipt))

    def test_old_restricted_signature_reinjection_is_rejected_even_when_codesign_verify_succeeds(self):
        self.readback = dict(self.simulated, **{"get-task-allow": True,
            "keychain-access-groups": [self.simulated["application-identifier"]]})
        self.fails("Signed entitlements differ")
        self.assertTrue(any("--verify" in argv for argv in self.commands))

    def test_xcode_signature_entitlements_must_be_the_empty_simulator_host_set(self):
        self.signature = dict(self.simulated)
        self.readback = dict(self.simulated)
        self.fails("nonempty Xcode Simulator host-signature")

    def test_missing_linked_simulated_section_does_not_get_signature_reinjection(self):
        self.missing_linked_section = True
        self.fails("Every Mach-O architecture must embed")

    def test_every_universal_slice_requires_its_own_matching_simulated_section(self):
        payload = plistlib.dumps(self.simulated)
        one = ("Contents of (__TEXT,__entitlements) section\n" +
               f"0000000100004000 {payload.hex()}\n").encode()
        self.assertEqual(SIGN.verify_simulated_sections(one, self.simulated, 1), 1)
        with self.assertRaisesRegex(ValueError, "Every Mach-O architecture"):
            SIGN.verify_simulated_sections(one, self.simulated, 2)
        with self.assertRaisesRegex(ValueError, "Every Mach-O architecture"):
            SIGN.verify_simulated_sections(one, {}, 1)

    def test_simulated_capability_cannot_be_removed_to_make_launch_pass(self):
        del self.simulated["com.apple.developer.healthkit"]
        self.fails("capabilities differ")

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

    def test_exact_requested_test_and_build_are_required(self):
        self.settings["FLUTTER_TARGET"] = "lib/main.dart"
        self.fails("exact requested entrypoint")
        self.assertFalse(self.built)

    def test_offline_test_defines_must_survive_generated_configuration(self):
        self.settings["DART_DEFINES"] = ""
        self.fails("offline Simulator QA defines")
        self.assertFalse(self.built)

    def test_wrong_build_output_is_refused(self):
        self.settings["TARGET_BUILD_DIR"] = str(self.workspace / "unowned")
        self.fails("Resolved Xcode output")
        self.assertFalse(self.built)

    def test_device_bundle_is_refused(self):
        self.info["DTPlatformName"] = "iphoneos"
        self.write_info()
        self.fails("Simulator platform")

    def test_provisioned_bundle_is_refused(self):
        (self.app / "embedded.mobileprovision").write_bytes(b"forbidden")
        self.fails("provisioned device")
        self.assertFalse(self.commands)

    def test_wrong_bundle_identity_is_refused(self):
        self.info["CFBundleIdentifier"] = "com.example.unowned"
        self.write_info()
        self.fails("Bundle identity")

    def test_non_adhoc_resolved_identity_is_refused(self):
        self.settings["CODE_SIGN_IDENTITY"] = "Apple Distribution: Synthetic Forbidden"
        self.fails("certificate signing identity")
        self.assertFalse(self.built)

    def test_resolved_provisioning_profile_is_refused(self):
        self.settings["PROVISIONING_PROFILE_SPECIFIER"] = "Forbidden Profile"
        self.fails("provisioning profile")
        self.assertFalse(self.built)

    def test_signing_disabled_does_not_get_repaired_by_hand_codesign(self):
        self.settings["CODE_SIGNING_ALLOWED"] = "NO"
        self.fails("Xcode must produce")
        self.assertFalse(self.built)

    def test_conflicting_or_unexpanded_prefix_is_not_replaced_with_team(self):
        self.settings["APP_IDENTIFIER_PREFIX"] = "$(UNKNOWN)."
        self.fails("Conflicting")

    def test_missing_generated_application_identifier_is_not_guessed(self):
        del self.simulated["application-identifier"]
        self.fails("actual simulated application identifier")

    def test_missing_team_is_not_guessed(self):
        self.settings["DEVELOPMENT_TEAM"] = ""
        self.fails("must not be guessed")

    def test_shared_keychain_group_is_refused(self):
        self.simulated["keychain-access-groups"] = ["unowned.shared"]
        self.fails("private Keychain group")

    def test_shared_app_group_is_refused(self):
        self.simulated["com.apple.security.application-groups"] = ["group.shared"]
        self.fails("shared app-group")

    def test_build_failure_is_preserved_without_any_recovery_signing(self):
        self.fail_operation = "build"
        receipt = self.fails("QA command failed")
        self.assertEqual(receipt["commands"][-1]["returncode"], 9)
        self.assertFalse(self.built)
        self.assertIn(b"synthetic command failure", Path(self.args.output).with_suffix(".xcode-build.log").read_bytes())

    def test_signature_verification_failure_does_not_become_pass(self):
        self.fail_operation = "verify"
        self.fails("QA command failed")

    def test_unexpected_certificate_signature_does_not_become_pass(self):
        self.after_certificate = True
        self.fails("without a certificate")

    def test_source_team_mismatch_is_refused(self):
        self.simulated["com.apple.developer.team-identifier"] = "ANOTHER123"
        self.fails("resolved project team")

    def test_device_macho_is_refused_even_if_info_claims_simulator(self):
        self.binary_platform = "IOS"
        self.fails("actual iOS Simulator Mach-O")

    def test_existing_certificate_signature_is_not_replaced(self):
        self.before_certificate = True
        self.fails("existing certificate signature")
        self.assertFalse(self.built)

    def test_duplicate_runner_settings_are_refused(self):
        row = {"target": "Runner", "buildSettings": self.settings}
        with self.assertRaisesRegex(ValueError, "Exactly one"):
            SIGN.runner_settings(json.dumps([row, row]))

    def test_command_timeout_stays_failure_without_retry(self):
        def timeout(*args, **kwargs):
            raise subprocess.TimeoutExpired("synthetic local readback", 30)
        with self.assertRaises(subprocess.TimeoutExpired):
            SIGN.sign_simulator(self.args, run=timeout, host="darwin")
        receipt = json.loads(Path(self.args.output).read_text(encoding="utf-8"))
        self.assertEqual(receipt["status"], "FAIL")
        self.assertIn("TimeoutExpired", receipt["error"])


class SimulatorScriptWiringFixtures(unittest.TestCase):
    def test_actual_xcode_output_is_driven_and_no_retry_or_claim_is_added(self):
        script = SCRIPT.with_name("bil_ios37_native_integration.sh").read_text(encoding="utf-8")
        block = script.split('for KIND in "${KINDS[@]}"; do', 1)[1]
        self.assertIn('"$KIND-generic-config"', block)
        self.assertIn('build ios --config-only --simulator', block)
        self.assertIn('APP="$GITHUB_WORKSPACE/build/ios/Debug-iphonesimulator/Runner.app"', block)
        self.assertIn('--use-application-binary "$APP"', block)
        self.assertIn('--target "$TARGET" --source-head "$SOURCE_HEAD" --source-tree "$SOURCE_TREE"', block)
        self.assertNotIn('codesign --force', script)
        self.assertNotIn('|| true', block)
        self.assertEqual(block.count('flutter drive '), 1)
        self.assertIn('process IN {"Runner", "runningboardd", "launchd_sim", "amfid", "installd"}', script)
        self.assertIn('"$label-host-launch-diagnostics" 45', script)
        self.assertIn('"$label-installed-binary-hash" 30', script)
        self.assertIn('exit "$original_status"', script)


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
