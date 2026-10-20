import ast
import itertools
import json
from pathlib import Path
import re
import tempfile
from types import SimpleNamespace
import unittest

import bil_ios_native_preflight as preflight


ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github/workflows/bil_codeql_security_extended.yml"


class SimulatorPreflightTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="bil native preflight ")
        self.addCleanup(self.temp.cleanup)
        self.workspace = Path(self.temp.name).resolve()
        (self.workspace / "ios/Runner.xcodeproj").mkdir(parents=True)
        self.output = self.workspace / "artifacts/native"
        self.calls = []
        self.statuses = {}
        self.settings = self.valid_settings()

    def valid_settings(self):
        return (
            "Build settings for action build and target Dependency:\n"
            "    TARGET_BUILD_DIR = /unrelated/dependency\n"
            "Build settings for action build and target Runner:\n"
            "    CONFIGURATION = Debug\n"
            "    PLATFORM_NAME = iphonesimulator\n"
            f"    PRODUCT_BUNDLE_IDENTIFIER = {preflight.BUNDLE_ID}\n"
            "    WRAPPER_NAME = Runner.app\n"
            f"    BUILD_DIR = {self.workspace / 'build/ios'}\n"
            f"    TARGET_BUILD_DIR = {self.workspace / 'build/ios/Debug-iphonesimulator'}\n"
        )

    def run_stage(self, command, **options):
        self.calls.append((command, options))
        if command[-1] == "-showBuildSettings":
            options["log_path"].write_text(self.settings, encoding="utf-8")
        return self.statuses.get(command[-1], 0)

    def invoke(self):
        code = preflight.prepare(self.workspace, self.output, run=self.run_stage, host="darwin")
        receipt = json.loads((self.output / "native-preflight.json").read_bytes())
        return code, receipt

    def test_actual_commands_share_project_sdk_destination_and_build_directory(self):
        code, receipt = self.invoke()
        self.assertEqual(code, 0)
        self.assertEqual(receipt["status"], "PREPARED")
        self.assertFalse(receipt["native_tests_proven"])
        self.assertFalse(receipt["signed_release_proven"])
        resolve, settings = (call[0] for call in self.calls)
        self.assertEqual(resolve[:-1], settings[:-1])
        self.assertEqual(resolve[-1], "-resolvePackageDependencies")
        self.assertEqual(settings[-1], "-showBuildSettings")
        self.assertEqual(resolve[:2], ["xcrun", "xcodebuild"])
        for option, expected in {
            "-project": str(self.workspace / "ios/Runner.xcodeproj"),
            "-scheme": "Runner", "-configuration": "Debug", "-sdk": "iphonesimulator",
            "-destination": "generic/platform=iOS Simulator",
            "-clonedSourcePackagesDirPath": str(self.workspace / "build/ios/SourcePackages"),
        }.items():
            self.assertEqual(resolve[resolve.index(option) + 1], expected)
        self.assertIn(f"BUILD_DIR={self.workspace / 'build/ios'}", resolve)
        self.assertNotIn("-skipPackagePluginValidation", resolve)
        self.assertNotIn("-skipPackageSignatureValidation", resolve)
        self.assertNotIn("shell", self.calls[0][1])
        self.assertEqual([options["timeout_seconds"] for _, options in self.calls], [600, 180])
        self.assertEqual(receipt["settings"]["WRAPPER_NAME"], "Runner.app")

    def test_package_failure_stops_before_settings_and_preserves_exit(self):
        self.statuses["-resolvePackageDependencies"] = 7
        code, receipt = self.invoke()
        self.assertEqual(code, 7)
        self.assertEqual(len(self.calls), 1)
        self.assertEqual(receipt["status"], "FAIL")
        self.assertEqual(receipt["stage"], "resolve-packages")
        self.assertNotIn("settings", receipt)

    def test_settings_timeout_never_falls_back_to_a_successful_stale_log(self):
        self.statuses["-showBuildSettings"] = 124
        code, receipt = self.invoke()
        self.assertEqual(code, 124)
        self.assertEqual(receipt["status"], "FAIL")
        self.assertNotIn("settings", receipt)

    def test_missing_target_directory_is_not_assumed_from_a_built_bundle(self):
        self.settings = "\n".join(line for line in self.settings.splitlines()
                                  if not line.lstrip().startswith("TARGET_BUILD_DIR ="))
        (self.workspace / "build/ios/Debug-iphonesimulator/Runner.app").mkdir(parents=True)
        code, receipt = self.invoke()
        self.assertEqual(code, 1)
        self.assertEqual(receipt["status"], "FAIL")
        self.assertNotIn("settings", receipt)

    def test_simulator_and_runner_identity_are_required(self):
        for old, new in [
            ("PLATFORM_NAME = iphonesimulator", "PLATFORM_NAME = iphoneos"),
            ("CONFIGURATION = Debug", "CONFIGURATION = Release"),
            ("WRAPPER_NAME = Runner.app", "WRAPPER_NAME = Other.app"),
            (preflight.BUNDLE_ID, "another.bundle"),
        ]:
            with self.subTest(setting=old):
                with self.assertRaises(ValueError):
                    preflight.runner_settings(self.valid_settings().replace(old, new), self.workspace)

    def test_wrong_build_directory_or_target_outside_current_build_is_rejected(self):
        for key in ["BUILD_DIR", "TARGET_BUILD_DIR"]:
            with self.subTest(key=key):
                changed = re.sub(rf"(?m)^    {key} = .+$", f"    {key} = /stale/build", self.valid_settings())
                with self.assertRaises(ValueError):
                    preflight.runner_settings(changed, self.workspace)

    def test_duplicate_or_conflicting_runner_sections_are_rejected(self):
        for changed in [self.settings + self.settings,
                        self.settings + "    WRAPPER_NAME = Other.app\n"]:
            with self.subTest(settings=changed[-50:]):
                with self.assertRaises(ValueError):
                    preflight.runner_settings(changed, self.workspace)

    def test_an_unrelated_target_cannot_supply_missing_runner_values(self):
        changed = self.settings.replace("and target Runner:", "and target Other:")
        with self.assertRaises(ValueError):
            preflight.runner_settings(changed, self.workspace)

    def test_failed_validation_receipt_does_not_copy_arbitrary_output(self):
        self.settings = "synthetic-secret-output"
        code, receipt = self.invoke()
        self.assertEqual(code, 1)
        self.assertEqual(receipt["error_type"], "ValueError")
        self.assertNotIn(b"synthetic-secret", (self.output / "native-preflight.json").read_bytes())

    def test_output_must_stay_in_the_existing_workspace(self):
        with self.assertRaises(ValueError):
            preflight.prepare(self.workspace, self.workspace.parent / "outside",
                              run=self.run_stage, host="darwin")
        self.assertEqual(self.calls, [])


class WorkflowNativeScopeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        text = WORKFLOW.read_text(encoding="utf-8")
        cls.job = text.split("\n  ios-native-integration:\n", 1)[1].split("\n  offline-mobile-static-audit:", 1)[0]
        condition = cls.job.split("    if: >-\n", 1)[1].split("\n    name:", 1)[0].strip()
        expression = condition.removeprefix("${{").removesuffix("}}").strip()
        expression = expression.replace("&&", " and ").replace("||", " or ")
        expression = re.sub(r"!(?!=)", " not ", expression)
        expression = re.sub(r"\btrue\b", "True", expression)
        expression = " ".join(expression.split())
        tree = ast.parse(expression, mode="eval")
        allowed = (ast.Expression, ast.BoolOp, ast.UnaryOp, ast.Compare, ast.Name,
                   ast.Attribute, ast.Constant, ast.And, ast.Or, ast.Not, ast.Eq,
                   ast.NotEq, ast.Load)
        if any(not isinstance(node, allowed) for node in ast.walk(tree)):
            raise AssertionError("Unexpected syntax in the actual native job condition")
        cls.condition = compile(tree, str(WORKFLOW), "eval")

    def selected(self, event="workflow_dispatch", ref="refs/heads/integration/bil-qa-media-policy-20261011", **flags):
        defaults = dict.fromkeys(["source_audit_only", "mobsf_only", "android_native_only",
                                 "ios_native_only", "android_only", "ios_only", "supabase_only"], False)
        defaults.update(flags)
        return eval(self.condition, {"__builtins__": {}},
                    {"inputs": SimpleNamespace(**defaults), "github": SimpleNamespace(event_name=event, ref=ref)})

    def test_dispatch_scope_combinations_use_the_actual_workflow_expression(self):
        # Exercise every combination of the user-selectable native/audit scopes.
        names = ["source_audit_only", "mobsf_only", "android_native_only", "ios_native_only",
                 "android_only", "ios_only", "supabase_only"]
        for values in itertools.product([False, True], repeat=len(names)):
            flags = dict(zip(names, values))
            native_scope = (flags["ios_native_only"] or flags["ios_only"] or
                            not (flags["android_only"] or flags["supabase_only"]))
            excluded = flags["source_audit_only"] or flags["mobsf_only"] or flags["android_native_only"]
            with self.subTest(**flags):
                self.assertEqual(bool(self.selected(**flags)), native_scope and not excluded)

    def test_default_main_and_pull_request_keep_native_coverage(self):
        self.assertTrue(self.selected(event="push", ref="refs/heads/main"))
        self.assertTrue(self.selected(event="pull_request", ref="refs/pull/12/merge"))
        self.assertTrue(self.selected())
        self.assertTrue(self.selected(android_only=True, ios_only=True))
        self.assertTrue(self.selected(ios_native_only=True))

    def test_integration_push_and_source_only_stay_non_native(self):
        self.assertFalse(self.selected(event="push"))
        self.assertFalse(self.selected(source_audit_only=True))
        self.assertFalse(self.selected(android_only=True))
        self.assertFalse(self.selected(supabase_only=True))

    def test_native_job_is_fresh_and_actual_journeys_remain_required(self):
        self.assertIn("runs-on: macos-26\n", self.job)
        self.assertIn("BIL_NATIVE_TARGET: ${{ inputs.native_target }}", self.job)
        self.assertIn("run: bash .github/scripts/bil_ios37_native_integration.sh", self.job)
        analyze = WORKFLOW.read_text(encoding="utf-8").split("\n  local-supabase-integration:", 1)[0]
        self.assertNotIn("run: bash .github/scripts/bil_ios37_native_integration.sh", analyze)
        self.assertIn("- name: Build iOS plugin sources for CodeQL", analyze)
        self.assertIn("uses: github/codeql-action/analyze@", analyze)

    def test_direct_xctest_requires_flutter_native_configuration_first(self):
        script = (ROOT / ".github/scripts/bil_ios37_native_integration.sh").read_text(encoding="utf-8")
        warmup = script.index("python3 .github/scripts/bil_ios_native_preflight.py")
        configuration = script.index('stage flutter-native-config 900 "$OUT/flutter-native-config.log"')
        xctest = script.index("python3 .github/scripts/bil_ios_runner_tests.py")
        self.assertLess(warmup, configuration)
        self.assertLess(configuration, xctest)
        command = script[configuration:xctest]
        self.assertIn("flutter --verbose build ios --config-only --simulator --debug --no-codesign --no-pub", command)
        self.assertIn('--build-number 37 --target lib/main.dart "${DEFINES[@]}"', command)
        self.assertNotIn("|| true", command)
        dependencies = self.job.split("- name: Resolve existing dependencies and native pods", 1)[1].split("- name: Drive each actual", 1)[0]
        sanitizer = "dart run tool/release/sanitize_flutter_release_plugins.dart --platform=ios --preserve-dev-native-plugins"
        self.assertLess(dependencies.index("flutter pub get"), dependencies.index(sanitizer))
        self.assertLess(dependencies.index(sanitizer), dependencies.index("pod install"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
