"""Exercise the actual native selector and dispatch conditions without a device.

These checks do not claim iOS launch, UIKit, or Keychain runtime success.
"""
import ast
import itertools
import os
from pathlib import Path
import re
import shutil
import subprocess
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / ".github/scripts/bil_ios37_native_integration.sh"
WORKFLOW = ROOT / ".github/workflows/bil_rc_mobile_test_build.yml"


class MobileNativeScopeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.script = SCRIPT.read_text(encoding="utf-8")
        cls.workflow = WORKFLOW.read_text(encoding="utf-8")
        cls.bash = str(Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Git/bin/bash.exe") if os.name == "nt" else shutil.which("bash")
        if not cls.bash:
            raise AssertionError("Bash is required; do not skip selector behavior")

    def selected_targets(self, scope):
        selector = self.script.split('case "${BIL_NATIVE_TARGET:-all}" in\n', 1)[1].split("\nesac", 1)[0]
        targets = self.script.split('  case "$KIND" in\n', 1)[1].split("\n  esac", 1)[0]
        source = ('set -eu\nCRYPTO_DRIVER=crypto-driver.dart\ncase "${BIL_NATIVE_TARGET:-all}" in\n' + selector +
                  '\nesac\nfor KIND in "${KINDS[@]}"; do\ncase "$KIND" in\n' + targets +
                  '\nesac\nprintf "%s|%s|%s\\n" "$KIND" "$TARGET" "$DRIVER"\ndone\n')
        env = dict(os.environ)
        env.pop("BIL_NATIVE_TARGET", None)
        if scope is not None:
            env["BIL_NATIVE_TARGET"] = scope
        return subprocess.run([self.bash, "--noprofile", "--norc"], input=source, capture_output=True, text=True, env=env, timeout=20)

    def test_combined_scope_executes_both_real_entrypoint_mappings(self):
        result = self.selected_targets("crypto-and-settings")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), [
            "system-crypto|integration_test/system_crypto_bridge_integration_test.dart|crypto-driver.dart",
            "native-settings|integration_test/native_settings_polish_test.dart|test_driver/native_settings_capture_driver.dart",
        ])

    def test_existing_scope_defaults_and_rejection_are_preserved(self):
        expected = {None: ["system-crypto", "native-settings", "feature-splashes"],
                    "all": ["system-crypto", "native-settings", "feature-splashes"],
                    "system-crypto": ["system-crypto"], "native-settings": ["native-settings"],
                    "feature-splashes": ["feature-splashes"]}
        for scope, names in expected.items():
            with self.subTest(scope=scope):
                result = self.selected_targets(scope)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual([line.split("|")[0] for line in result.stdout.splitlines()], names)
        result = self.selected_targets("unknown-scope")
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, "")

    def evaluate_job(self, job, *, event, ios, notifications):
        text = self.workflow.split("\n  " + job + ":\n", 1)[1]
        expression = text.split("    if: ${{ ", 1)[1].split(" }}", 1)[0]
        expression = expression.replace("&&", " and ").replace("||", " or ")
        expression = re.sub(r"!(?!=)", " not ", expression)
        tree = ast.parse(expression.strip(), mode="eval")
        allowed = (ast.Expression, ast.BoolOp, ast.UnaryOp, ast.Compare, ast.Name,
                   ast.Attribute, ast.Constant, ast.And, ast.Or, ast.Not, ast.Eq,
                   ast.NotEq, ast.Load)
        self.assertTrue(all(isinstance(node, allowed) for node in ast.walk(tree)))
        return bool(eval(compile(tree, str(WORKFLOW), "eval"), {"__builtins__": {}}, {
            "github": SimpleNamespace(event_name=event),
            "inputs": SimpleNamespace(ios_only=ios, notification_api33_only=notifications),
        }))

    def test_actual_dispatch_conditions_preserve_full_default_and_explicit_ios_scope(self):
        jobs = ["android-emulator-artifact", "ios-simulator-artifact", "android-notification-sdk"]
        for ios, notifications in itertools.product([False, True], repeat=2):
            actual = [self.evaluate_job(job, event="workflow_dispatch", ios=ios, notifications=notifications) for job in jobs]
            expected = [False, True, False] if ios else ([False, False, True] if notifications else [True, True, True])
            self.assertEqual(actual, expected)
            self.assertEqual([self.evaluate_job(job, event="push", ios=ios, notifications=notifications) for job in jobs], [True, True, True])

    def test_native_devices_finish_before_real_qa_app_and_lifecycle_devices(self):
        names = re.findall(r"^      - name: (.+)$", self.workflow, re.MULTILINE)
        sequence = ["Run bounded iOS crypto and settings from exact simulator bundles",
                    "Rebuild QA app after integration harness",
                    "Create iPhone and iPad simulator sessions",
                    "Run verified iPhone and iPad lifecycle/deep-link matrix"]
        indices = [names.index(name) for name in sequence]
        self.assertEqual(indices, sorted(indices))
        native = self.workflow.split("      - name: " + sequence[0], 1)[1].split("      - name: ", 1)[0]
        self.assertIn("BIL_NATIVE_TARGET: crypto-and-settings", native)
        self.assertIn("run: bash .github/scripts/bil_ios37_native_integration.sh", native)
        self.assertNotIn("continue-on-error", native)
        upload = self.workflow.split("      - name: Upload iOS test artifacts", 1)[1].split("      - name:", 1)[0]
        self.assertIn("artifacts/qa/text18/ios37-simulators", upload)
        self.assertIn("if: always()", upload)
        create = self.workflow.split("      - name: " + sequence[2], 1)[1].split("      - name:", 1)[0]
        self.assertIn('xcrun simctl get_app_container "$UDID" "$BIL_APP_ID" app >/dev/null', create)

    def test_exact_bundle_driver_and_os_deadlines_remain_required(self):
        self.assertIn('--use-application-binary "$APP" --target "$TARGET" --driver "$DRIVER"', self.script)
        self.assertIn('--timeout-seconds 1800 --running-timeout-seconds 1200', self.script)
        self.assertIn('for PAIR in "iphone:$IPHONE_UDID" "ipad:$IPAD_UDID"', self.script)
        self.assertNotIn("continue-on-error", self.script)
        contracts = self.workflow.split("      - name: Resolve dependencies and iOS contracts", 1)[1].split("      - name:", 1)[0]
        self.assertIn("python3 .github/scripts/test_bil_ios_mobile_native_scope.py", contracts)
        self.assertIn("python3 .github/scripts/test_bil_native_bounded_command.py", contracts)


if __name__ == "__main__":
    unittest.main(verbosity=2)
