import argparse
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest

from bil_ios_simulator_spawn_diagnostic import BUNDLE_ID, PREDICATE, diagnose, digest, environment_evidence, sanitize


class SpawnDiagnosticTests(unittest.TestCase):
    def fixture(self, root):
        workspace = Path(root)
        app = workspace / "build/ios/iphonesimulator/Runner.app"
        app.mkdir(parents=True)
        (app / "Info.plist").write_bytes(plistlib.dumps({"CFBundleIdentifier": BUNDLE_ID, "CFBundleVersion": "37",
            "DTPlatformName": "iphonesimulator", "CFBundleSupportedPlatforms": ["iPhoneSimulator"]}))
        for name in ("Runner", "Runner.debug.dylib"):
            (app / name).write_bytes(bytes.fromhex("cffaedfe") + name.encode())
        return argparse.Namespace(workspace=str(workspace), app=str(app), output=str(workspace / "artifacts/qa/spawn"),
            source_head="a"*40, expected_main_sha256=digest((app / "Runner").read_bytes()),
            device="12345678-1234-1234-1234-123456789012", runtime="com.apple.CoreSimulator.SimRuntime.iOS-26-5",
            device_type="com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro", device_label="iphone", entrypoint_kind="system-crypto",
            qa_simulator_only=True, retain_exact_bundle=False)

    def runner(self, args, commands, *, launch_exit=1, install_exit=0, mutate=False, checkout=None):
        def run(argv, **kwargs):
            commands.append(argv)
            out, code = b"", 0
            if argv[:3] == ["git", "rev-parse", "HEAD"]:
                out = ((checkout or args.source_head) + "\n").encode()
            elif argv[:3] == ["xcrun", "simctl", "create"]:
                out = b"87654321-4321-4321-4321-210987654321\n"
            elif argv[:3] == ["xcrun", "simctl", "install"]:
                code = install_exit
                if mutate:
                    (Path(args.app) / "Runner").write_bytes(b"changed")
            elif argv[:3] == ["xcrun", "simctl", "launch"]:
                code = launch_exit
                out = b"Launchd job spawn failed\nAuthorization: Bearer sensitive-value\n"
            return subprocess.CompletedProcess(argv, code, out, b"")
        return run

    def test_one_exact_bundle_replay_preserves_failure_and_no_signing_or_rebuild(self):
        with tempfile.TemporaryDirectory() as root:
            args = self.fixture(root)
            commands = []
            result = diagnose(args, run=self.runner(args, commands), host="darwin", environ={})
            self.assertEqual(result["fresh_replay_attempts"], 1)
            self.assertEqual(result["fresh_replay_status"], "LAUNCH_FAILED")
            self.assertTrue(result["bundle_bytes_unchanged"])
            self.assertFalse(result["native_tests_passed_by_this_diagnostic"])
            self.assertEqual(len(result["macho_inventory"]), 2)
            self.assertEqual(sum(command[:3] == ["xcrun", "simctl", "launch"] for command in commands), 1)
            self.assertTrue(any(command[:3] == ["xcrun", "simctl", "delete"] for command in commands))
            self.assertFalse(any("--sign" in command or "build" in command or command[0] == "env" for command in commands))
            log = (Path(args.output) / "fresh-launch-once.log").read_text()
            self.assertIn("Launchd job spawn failed", log)
            self.assertNotIn("sensitive-value", log)

    def test_successful_launch_is_explicitly_not_native_test_acceptance(self):
        with tempfile.TemporaryDirectory() as root:
            args = self.fixture(root)
            result = diagnose(args, run=self.runner(args, [], launch_exit=0), host="darwin", environ={})
            self.assertEqual(result["fresh_replay_status"], "LAUNCH_COMMAND_RETURNED_ZERO_NOT_TEST_PASS")
            self.assertFalse(result["native_tests_passed_by_this_diagnostic"])

    def test_ipad_failure_uses_ipad_type_and_keeps_failed_entrypoint(self):
        with tempfile.TemporaryDirectory() as root:
            args = self.fixture(root)
            args.device_label = "ipad"
            args.entrypoint_kind = "feature-splashes"
            args.device_type = "com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M4-16GB"
            commands = []
            result = diagnose(args, run=self.runner(args, commands), host="darwin", environ={})
            create = next(command for command in commands if command[:3] == ["xcrun", "simctl", "create"])
            self.assertIn(args.device_type, create)
            self.assertEqual(result["original_device_label"], "ipad")
            self.assertEqual(result["original_entrypoint_kind"], "feature-splashes")

    def test_wrong_hash_cannot_trigger_fresh_replay(self):
        with tempfile.TemporaryDirectory() as root:
            args = self.fixture(root)
            args.expected_main_sha256 = "f"*64
            commands = []
            result = diagnose(args, run=self.runner(args, commands), host="darwin", environ={})
            self.assertEqual(result["fresh_replay_status"], "BLOCKED_PRE_DRIVE_BINARY_HASH_MISMATCH")
            self.assertEqual(result["fresh_replay_attempts"], 0)
            self.assertFalse(any(command[:3] == ["xcrun", "simctl", "create"] for command in commands))

    def test_install_failure_does_not_retry_or_claim_launch(self):
        with tempfile.TemporaryDirectory() as root:
            args = self.fixture(root)
            commands = []
            result = diagnose(args, run=self.runner(args, commands, install_exit=1), host="darwin", environ={})
            self.assertEqual(result["fresh_replay_attempts"], 0)
            self.assertFalse(any(command[:3] == ["xcrun", "simctl", "launch"] for command in commands))
            self.assertTrue(any(command[:3] == ["xcrun", "simctl", "delete"] for command in commands))

    def test_changed_bundle_or_wrong_source_is_fail_closed(self):
        for fault in ("bytes", "source"):
            with self.subTest(fault=fault), tempfile.TemporaryDirectory() as root:
                args = self.fixture(root)
                commands = []
                run = self.runner(args, commands, mutate=fault == "bytes", checkout="b"*40 if fault == "source" else None)
                with self.assertRaises(ValueError):
                    diagnose(args, run=run, host="darwin", environ={})
                receipt = json.loads((Path(args.output) / "spawn-diagnostic.json").read_text())
                self.assertEqual(receipt["diagnostic_collection_status"], "INCOMPLETE")
                self.assertFalse(receipt["native_tests_passed_by_this_diagnostic"])

    def test_host_profile_and_platform_guards(self):
        for fault in ("host", "profile", "platform"):
            with self.subTest(fault=fault), tempfile.TemporaryDirectory() as root:
                args = self.fixture(root)
                if fault == "profile":
                    (Path(args.app) / "embedded.mobileprovision").write_bytes(b"must not use")
                elif fault == "platform":
                    info = plistlib.loads((Path(args.app) / "Info.plist").read_bytes())
                    info["DTPlatformName"] = "iphoneos"
                    (Path(args.app) / "Info.plist").write_bytes(plistlib.dumps(info))
                with self.assertRaises(ValueError):
                    diagnose(args, run=self.runner(args, []), host="linux" if fault == "host" else "darwin", environ={})

    def test_environment_evidence_never_dumps_values(self):
        value = "/private/sensitive/codeql/libtrace.dylib:/secret-value"
        evidence = environment_evidence({"DYLD_INSERT_LIBRARIES": value, "UNRELATED_SECRET": "do-not-copy"})
        text = json.dumps(evidence)
        self.assertNotIn(value, text)
        self.assertNotIn("secret-value", text)
        self.assertNotIn("do-not-copy", text)
        self.assertTrue(evidence["DYLD_INSERT_LIBRARIES"]["mentions_codeql_or_semmle"])
        self.assertEqual(evidence["DYLD_INSERT_LIBRARIES"]["dylib_basenames"], ["libtrace.dylib"])

    def test_fixed_predicate_and_secret_url_redaction(self):
        for process in ("launchd", "launchd_sim", "amfid", "dyld", "runningboardd"):
            self.assertIn('process == "' + process + '"', PREDICATE)
        clean = sanitize(b'Library not loaded\nhttps://user:pass@example.test/x?q=sensitive\napi_key=secret\n')
        self.assertIn("Library not loaded", clean)
        for value in ("user:pass", "sensitive", "api_key=secret"):
            self.assertNotIn(value, clean)


if __name__ == "__main__":
    unittest.main()
