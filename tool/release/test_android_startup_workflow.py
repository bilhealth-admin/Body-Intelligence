#!/usr/bin/env python3
"""Offline regression checks for the startup workflow's boolean API selector.

The selector parser accepts only the checked-in two-branch expression grammar,
then decodes its real JSON payloads. It does not emulate arbitrary GitHub syntax
or need Flutter, an emulator, network access, or third-party Python packages.
"""

from __future__ import annotations

import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github/workflows/bil_android_isolated_emulator_smoke.yml"


def selected_matrix(source: str, api36_only: bool | None) -> dict:
    expression = re.search(
        r"^      matrix: \$\{\{ fromJSON\(\s*"
        r"inputs\.api36_only == true &&\s*'([^']+)'\s*"
        r"\|\|\s*'([^']+)'\s*\) \}\}\s*$",
        source,
        re.MULTILINE,
    )
    if expression is None:
        raise ValueError("Startup matrix requires review: unknown selector grammar")
    return json.loads(expression.group(1 if api36_only is True else 2))


class AndroidStartupWorkflowTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source = WORKFLOW.read_text(encoding="utf-8")

    def test_opt_in_is_a_typed_boolean_and_defaults_to_all_apis(self) -> None:
        dispatch = re.search(
            r"^  workflow_dispatch:\n(.*?)(?=^\S)",
            self.source,
            re.MULTILINE | re.DOTALL,
        )
        self.assertIsNotNone(dispatch)
        self.assertRegex(dispatch.group(1), r"(?m)^      api36_only:\s*$")
        self.assertRegex(dispatch.group(1), r"(?m)^        type: boolean\s*$")
        self.assertRegex(dispatch.group(1), r"(?m)^        required: false\s*$")
        self.assertRegex(dispatch.group(1), r"(?m)^        default: false\s*$")

    def test_push_without_dispatch_input_keeps_all_six_apis(self) -> None:
        rows = selected_matrix(self.source, None)["include"]
        self.assertEqual([row["api-level"] for row in rows], [26, 29, 33, 34, 35, 36])

    def test_explicit_false_keeps_the_same_default_matrix(self) -> None:
        self.assertEqual(
            selected_matrix(self.source, False), selected_matrix(self.source, None)
        )

    def test_true_selects_only_api36_without_include_augmentation(self) -> None:
        matrix = selected_matrix(self.source, True)
        self.assertEqual(set(matrix), {"include"})
        self.assertEqual(
            matrix["include"],
            [{"api-level": 36, "profile": "pixel_6", "ram-size": "4096M"}],
        )

    def test_full_matrix_has_no_other_axes_or_duplicate_api_jobs(self) -> None:
        matrix = selected_matrix(self.source, False)
        self.assertEqual(set(matrix), {"include"})
        apis = [row["api-level"] for row in matrix["include"]]
        self.assertEqual(len(apis), len(set(apis)))

    def test_full_matrix_preserves_profiles_and_explicit_newer_api_memory(self) -> None:
        rows = {row["api-level"]: row for row in selected_matrix(self.source, False)["include"]}
        self.assertEqual({api: row["profile"] for api, row in rows.items()}, {
            26: "pixel_2", 29: "pixel_2", 33: "pixel_6",
            34: "pixel_6", 35: "pixel_6", 36: "pixel_6",
        })
        for api in (34, 35, 36):
            with self.subTest(api=api):
                self.assertEqual(rows[api]["ram-size"], "4096M")
        for api in (26, 29, 33):
            with self.subTest(api=api):
                self.assertNotIn("ram-size", rows[api])

    def test_selector_cannot_change_startup_gates_or_existing_time_budgets(self) -> None:
        for required in (
            "  cancel-in-progress: false",
            "    timeout-minutes: 90",
            "      fail-fast: false",
            "          cores: 2",
            "          emulator-boot-timeout: 900",
            "          ram-size: ${{ matrix.ram-size }}",
            "          script: BIL_ANDROID_EMULATOR_API=${{ matrix.api-level }} bash tool/release/run_android_emulator_smoke.sh",
        ):
            with self.subTest(setting=required.strip()):
                self.assertIn(required + "\n", self.source)

    def test_unknown_selector_logic_requires_review_instead_of_guessing(self) -> None:
        changed = self.source.replace("inputs.api36_only == true", "inputs.api36_only != false")
        with self.assertRaisesRegex(ValueError, "unknown selector grammar"):
            selected_matrix(changed, None)

    def test_display_is_configured_in_the_actual_prelaunch_hook(self) -> None:
        hook = self.source.split('          pre-emulator-launch-script: |\n', 1)[1].split('          script:', 1)[0]
        self.assertIn('configure_android_emulator_display.py configure --api-level ${{ matrix.api-level }}', hook)
        self.assertIn('--config "$ANDROID_AVD_HOME/test.avd/config.ini"', hook)
        self.assertLess(hook.index('configure_android_emulator_display.py'), hook.index('adb kill-server'))
        self.assertIn("test_configure_android_emulator_display.py", self.source)

    def test_existing_anr_gate_retains_priority_and_display_readback_precedes_app(self) -> None:
        script = (ROOT / 'tool/release/run_android_emulator_smoke.sh').read_text(encoding='utf-8')
        self.assertLess(script.index('--verify-emulator-before-launch'), script.index('configure_android_emulator_display.py verify-runtime'))
        self.assertLess(script.index('configure_android_emulator_display.py verify-runtime'), script.index('adb install "$apk"'))
        self.assertLess(script.index('--verify-emulator-before-launch'), script.index('adb install "$apk"'))
        self.assertIn('--window-health-only --require-app-focus', script)
        self.assertIn('if (( window_exit >= 20 && window_exit <= 22 )); then', script)

    def test_api34_local_action_is_conditional_and_preserves_other_api_inputs(self) -> None:
        steps = re.split(r'(?m)^      - name: ', self.source)[1:]
        original = next(step for step in steps if
                        'uses: reactivecircus/android-emulator-runner@' in step)
        local = next((step for step in steps if
                      'uses: ./artifacts/tooling/bil-api34-emulator-action' in step), None)
        self.assertIsNotNone(local, 'API34 must avoid the pinned action\'s unconditional MENU')
        self.assertIn('if: ${{ matrix.api-level != 34 }}', original)
        self.assertIn('if: ${{ matrix.api-level == 34 }}', local)
        self.assertEqual(original.split('        with:\n', 1)[1],
                         local.split('        with:\n', 1)[1])
        self.assertIn('repository: ReactiveCircus/android-emulator-runner', self.source)
        self.assertIn('ref: 4c44018e59b437e86cdfc41da381398f93ed8808', self.source)
        self.assertIn('test_prepare_api34_emulator_action.py', self.source)
        self.assertIn('test_android_api34_unlock.py', self.source)

    def test_owned_checkout_is_conditional_pinned_and_prepared_before_use(self) -> None:
        steps = re.split(r'(?m)^      - name: ', self.source)[1:]
        checkout = next(step for step in steps if
                        'repository: ReactiveCircus/android-emulator-runner' in step)
        prepared = next(step for step in steps if
                        'python3 tool/release/prepare_api34_emulator_action.py' in step)
        local = next(step for step in steps if
                     'uses: ./artifacts/tooling/bil-api34-emulator-action' in step)
        self.assertIn('if: ${{ matrix.api-level == 34 }}', checkout)
        self.assertIn('if: ${{ matrix.api-level == 34 }}', prepared)
        self.assertIn('persist-credentials: false', checkout)
        self.assertIn('path: artifacts/tooling/bil-api34-emulator-action', checkout)
        self.assertLess(steps.index(checkout), steps.index(prepared))
        self.assertLess(steps.index(prepared), steps.index(local))
        self.assertEqual(self.source.count('uses: reactivecircus/android-emulator-runner@'), 1)
        self.assertEqual(self.source.count('uses: ./artifacts/tooling/bil-api34-emulator-action'), 1)


if __name__ == "__main__":
    unittest.main()
