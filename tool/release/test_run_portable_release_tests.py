"""Portable release scheduling checks; never starts Flutter."""

from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock

from tool.release import run_portable_release_tests as runner


class PortableReleaseSchedulingTest(unittest.TestCase):
    DIRECTORY_CAPTURE_FILES = {
        "test/features/commerce/personal_plan_gate_refresh_presentation_test.dart": "BIL_PREMIUM_CAPTURE_DIR",
        "test/features/community/community_profile_relationship_flow_test.dart": "BIL_REFERENCE_CAPTURE_DIR",
        "test/features/daily_log/daily_entry_theme_contrast_test.dart": "BIL_ENTRY_THEME_CAPTURE_DIR",
        "test/features/intelligence_center/coach_overview_access_stability_test.dart": "BIL_PREMIUM_CAPTURE_DIR",
        "test/features/intelligence_center/coach_overview_header_clearance_test.dart": "BIL_UI_BATCH_CAPTURE_DIR",
        "test/features/intelligence_center/coach_overview_plan_label_refresh_test.dart": "BIL_PREMIUM_CAPTURE_DIR",
        "test/features/profile/dietary_plan_navigation_widget_test.dart": "BIL_UI_BATCH_CAPTURE_DIR",
        "test/features/settings/health_sources_nutrition_targets_localization_test.dart": "BIL_UI_BATCH_CAPTURE_DIR",
        "test/shared/widgets/bil_mobile_page_intro_contrast_test.dart": "BIL_UI_BATCH_CAPTURE_DIR",
        "test/shared/widgets/chat_history_viewport_first_paint_test.dart": "BIL_CHAT_VIEWPORT_EVIDENCE_DIR",
    }
    COMPILE_DIRECTORY_FILES = {
        "test/features/settings/membership_navigation_stability_test.dart": "BIL_DASHBOARD_CAPTURE_DIR",
        "test/features/smart_plan/bil_smart_plan_sources_test.dart": "BIL_DASHBOARD_CAPTURE_DIR",
        "test/shared/widgets/bil_splash_capsule_layout_test.dart": "BIL_DASHBOARD_CAPTURE_DIR",
    }
    REQUIRED_RENDERER_FILES = {
        "test/features/dashboard/dashboard_discover_stability_test.dart",
        "test/shared/widgets/gray_wait_surface_visibility_test.dart",
    }

    def setUp(self) -> None:
        environment = mock.patch.dict(os.environ)
        environment.start()
        self.addCleanup(environment.stop)
        self.portable = [
            "test/a_test.dart",
            runner.PERFORMANCE_BUDGET_TEST,
            "test/z_test.dart",
        ]
        self.discovery = (
            sorted([*self.portable, *runner.EXCLUDED_TESTS]),
            self.portable,
        )

    def run_main(self, returncodes: list[int], argv: list[str] | None = None):
        output = io.StringIO()
        results = [subprocess.CompletedProcess([], code) for code in returncodes]
        with (
            mock.patch.object(runner, "discover_tests", return_value=self.discovery),
            mock.patch.object(runner.subprocess, "run", side_effect=results) as run,
            contextlib.redirect_stdout(output),
        ):
            code = runner.main([] if argv is None else argv)
        return code, run.call_args_list, output.getvalue()

    def test_real_inventory_is_partitioned_without_duplicates_or_omissions(self):
        all_tests, portable = runner.discover_tests()
        performance, remaining = runner.partition_tests(portable)
        scheduled = [*performance, *remaining]

        self.assertEqual(len(runner.EXCLUDED_TESTS), 29)
        self.assertEqual(performance, [runner.PERFORMANCE_BUDGET_TEST])
        self.assertEqual(len(scheduled), len(set(scheduled)))
        self.assertCountEqual(scheduled, portable)
        self.assertEqual(set(all_tests) - set(scheduled), runner.EXCLUDED_TESTS)
        self.assertNotIn(runner.PERFORMANCE_BUDGET_TEST, remaining)

    def test_coach_behavior_files_remain_scheduled_with_only_png_disabled(self):
        policy = runner.load_code_only_policy()
        _, ordinary = policy.discover()
        for path in (
            "test/features/intelligence_center/ai_coach_report_confirmation_capture_test.dart",
            "test/features/intelligence_center/coach_page_lifecycle_regression_test.dart",
        ):
            self.assertIn(path, ordinary)
            self.assertNotIn(path, policy.NOT_RUN)
            self.assertNotIn(path, policy.MIXED_NAMES)
            self.assertEqual(policy.ENV_CAPTURE_GUARDED[path], "BIL_CAPTURE_COACH_RELEASE")

    def test_bil39_visual_partition_does_not_remove_any_complete_release_test(self):
        policy = runner.load_code_only_policy()
        _, complete = runner.discover_tests()
        captures = [
            "test/bil_crystal_calendar_video_test.dart",
            "test/bil_crystal_calendar_visual_test.dart",
            "test/bil_crystal_purchase_cta_isolation_test.dart",
        ]
        mixed = {
            "test/features/analytics/analytics_weight_constant_axis_test.dart": (
                "Distinct measurements retain their actual axis bounds",
                "Narrow measured range renders ar dark=True"),
            "test/features/commerce/bil_store_activity_indicator_test.dart": (
                "one Splash indicator above checkout dark=true rtl=true reduced=false restore=true",
                "one Splash indicator above checkout dark=true rtl=true reduced=true restore=true"),
            "test/features/smart_plan/bil_smart_plan_overview_finish_test.dart": (
                "real Coach Overview and Smart Plan share finish, clipping and ink in dark RTL",
                "photographic background stays visible with the same focal crop in RTL and LTR dark=true"),
        }
        for name in [*captures, *mixed]:
            with self.subTest(file=name):
                self.assertIn(name, complete, 'The complete release suite must retain every case')
        for name in captures:
            self.assertIn(name, policy.NOT_RUN)
        for name, (behavior, capture) in mixed.items():
            with self.subTest(file=name):
                self.assertNotIn(name, policy.NOT_RUN)
                self.assertIsNotNone(re.fullmatch(policy.MIXED_NAMES[name], behavior))
                self.assertIsNone(re.fullmatch(policy.MIXED_NAMES[name], capture))

    def test_partition_preserves_the_remaining_order(self):
        self.assertEqual(
            runner.partition_tests(self.portable),
            ([runner.PERFORMANCE_BUDGET_TEST], ["test/a_test.dart", "test/z_test.dart"]),
        )

    def test_partition_rejects_missing_performance_or_duplicate_paths(self):
        for paths in (
            [],
            ["test/a_test.dart"],
            [runner.PERFORMANCE_BUDGET_TEST, runner.PERFORMANCE_BUDGET_TEST],
            [*self.portable, "test/a_test.dart"],
        ):
            with self.subTest(paths=paths), self.assertRaises(SystemExit):
                runner.partition_tests(paths)

    def test_command_batches_preserve_every_test_once(self):
        tests = ["test/a_test.dart", "test/b_test.dart", "test/c_test.dart"]
        batches = runner.partition_test_batches(
            ["flutter", "test"],
            tests,
            command_line_limit=48,
        )
        self.assertGreater(len(batches), 1)
        self.assertEqual([path for batch in batches for path in batch], tests)

    def test_performance_runs_serial_first_then_every_other_file_once(self):
        code, calls, output = self.run_main([0, 0])
        prefix = [
            runner.resolve_flutter_executable(),
            "test",
            "--no-pub",
            "--timeout",
            "30s",
        ]
        self.assertEqual(code, 0)
        self.assertEqual(
            calls,
            [
                mock.call(
                    [*prefix, "--concurrency", "1", runner.PERFORMANCE_BUDGET_TEST],
                    cwd=runner.REPOSITORY_ROOT,
                    check=False,
                ),
                mock.call(
                    [*prefix, "test/a_test.dart", "test/z_test.dart"],
                    cwd=runner.REPOSITORY_ROOT,
                    check=False,
                ),
            ],
        )
        self.assertIn("PORTABLE_RELEASE_SCHEDULED_TEST_FILES=3\n", output)
        self.assertIn("PORTABLE_RELEASE_PERFORMANCE_SCHEDULED_TEST_FILES=1\n", output)
        self.assertIn("PORTABLE_RELEASE_REMAINING_SCHEDULED_TEST_FILES=2\n", output)
        self.assertTrue(output.endswith("PORTABLE_RELEASE_EXECUTED_TEST_FILES=3\n"))

    def test_performance_failure_stops_without_retry_or_remaining_tests(self):
        code, calls, output = self.run_main([7])
        self.assertEqual(code, 7)
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0].args[0][-1], runner.PERFORMANCE_BUDGET_TEST)
        self.assertNotIn("PORTABLE_RELEASE_PHASE=remaining_portable", output)
        self.assertTrue(output.endswith("PORTABLE_RELEASE_EXECUTED_TEST_FILES=1\n"))

    def test_remaining_failure_is_preserved_without_retry(self):
        code, calls, output = self.run_main([0, 9])
        self.assertEqual(code, 9)
        self.assertEqual(len(calls), 2)
        self.assertTrue(output.endswith("PORTABLE_RELEASE_EXECUTED_TEST_FILES=3\n"))

    def test_list_only_reports_schedule_without_invoking_flutter(self):
        code, calls, output = self.run_main([], ["--list-only"])
        self.assertEqual(code, 0)
        self.assertEqual(calls, [])
        self.assertIn("PORTABLE_RELEASE_SCHEDULED_TEST_FILES=3\n", output)
        self.assertNotIn("PORTABLE_RELEASE_PHASE=", output)
        self.assertTrue(output.endswith("PORTABLE_RELEASE_EXECUTED_TEST_FILES=0\n"))

    def test_performance_only_never_starts_an_empty_flutter_invocation(self):
        self.discovery = (self.discovery[0], [runner.PERFORMANCE_BUDGET_TEST])
        code, calls, output = self.run_main([0])
        self.assertEqual(code, 0)
        self.assertEqual(len(calls), 1)
        self.assertIn("PORTABLE_RELEASE_REMAINING_SCHEDULED_TEST_FILES=0\n", output)
        self.assertTrue(output.endswith("PORTABLE_RELEASE_EXECUTED_TEST_FILES=1\n"))

    def test_code_only_preserves_default_suite_and_uses_reviewed_policy(self):
        policy = runner.load_code_only_policy()
        policy.discover()
        _, portable = runner.discover_tests()
        selected = set(portable) - set(policy.NOT_RUN)
        self.assertNotIn("test/release_metadata_test.dart", selected)
        self.assertIn("test/release_metadata_test.dart", portable)
        self.assertIn("test/premium_splash_experience_test.dart", policy.MIXED_NAMES)
        self.assertIn(runner.PERFORMANCE_BUDGET_TEST, selected)

    def test_code_only_real_policy_keeps_every_invocation_serial(self):
        code, calls, output = self.run_main([0, 0], ["--code-only"])
        self.assertEqual(code, 0)
        self.assertEqual(len(calls), 2)
        for call in calls:
            command = call.args[0]
            self.assertEqual(command.count("--concurrency"), 1)
            self.assertEqual(command[command.index("--concurrency") + 1], "1")
            self.assertFalse(command[0].endswith(".bat"))
            self.assertTrue(command[1].endswith("flutter_tools.snapshot"))
            self.assertIn("--dart-define=BIL_CAPTURE_COMMUNITY_REVIEW=false", command)
            self.assertIn("--dart-define=BIL_CAPTURE_HEALTH_REVIEW=false", command)
        self.assertEqual(calls[0].args[0][-1], runner.PERFORMANCE_BUDGET_TEST)
        self.assertEqual(calls[1].args[0][-2:], ["test/a_test.dart", "test/z_test.dart"])
        self.assertTrue(output.endswith("PORTABLE_RELEASE_EXECUTED_TEST_FILES=3\n"))

    def test_dashboard_capture_guards_keep_all_regression_tests_scheduled(self):
        policy = runner.load_code_only_policy()
        all_tests, ordinary = policy.discover()
        _, portable = runner.discover_tests()
        expected = {
            "test/features/community/community_report_visual_test.dart",
            "test/features/smart_plan/bil_smart_plan_page_test.dart",
            "test/features/smart_plan/bil_smart_plan_session_test.dart",
            "test/features/smart_plan/bil_smart_plan_conflict_panel_test.dart",
            "test/features/smart_plan/bil_smart_plan_states_visual_test.dart",
            "test/dashboard_polish/dashboard_current_preview_test.dart",
            "test/dashboard_polish/dashboard_polish_layout_review_test.dart",
            "test/dashboard_polish/icon_label_layout_review_test.dart",
            "test/features/intelligence_center/ai_coach_report_confirmation_capture_test.dart",
            "test/features/intelligence_center/coach_page_lifecycle_regression_test.dart",
        }
        self.assertEqual(set(policy.ENV_CAPTURE_GUARDED), expected)
        for name in expected:
            self.assertIn(name, all_tests)
            self.assertIn(name, ordinary)
            self.assertIn(name, portable)
            self.assertNotIn(name, policy.NOT_RUN)
            self.assertNotIn(name, policy.MIXED_NAMES)

    def test_code_only_overrides_inherited_dashboard_capture_flags(self):
        policy = runner.load_code_only_policy()
        for flag in policy.ENV_CAPTURE_GUARDED.values():
            os.environ[flag] = "1"
        code, calls, _ = self.run_main([0, 0], ["--code-only"])
        self.assertEqual(code, 0)
        self.assertEqual(len(calls), 2)
        for flag in policy.ENV_CAPTURE_GUARDED.values():
            self.assertEqual(os.environ[flag], "0")

    def test_code_only_real_policy_preserves_performance_failure(self):
        code, calls, output = self.run_main([7], ["--code-only"])
        self.assertEqual(code, 7)
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0].args[0][-1], runner.PERFORMANCE_BUDGET_TEST)
        self.assertNotIn("PORTABLE_RELEASE_PHASE=remaining_portable", output)
        self.assertTrue(output.endswith("PORTABLE_RELEASE_EXECUTED_TEST_FILES=1\n"))

    def test_code_only_mixed_files_are_filtered_and_never_use_batch_shell(self):
        policy = SimpleNamespace(
            discover=mock.Mock(), NOT_RUN={"test/z_test.dart": "image data"},
            MIXED_NAMES={"test/a_test.dart": "^(?!visual).*$"},
            flutter_test_command=lambda _: ["native-dart", "snapshot", "test", "--concurrency", "1"],
        )
        with mock.patch.object(runner, "load_code_only_policy", return_value=policy):
            code, calls, output = self.run_main([0, 0], ["--code-only"])
        self.assertEqual(code, 0)
        policy.discover.assert_called_once_with()
        self.assertEqual(len(calls), 2)
        self.assertEqual(calls[0].args[0][-1], runner.PERFORMANCE_BUDGET_TEST)
        self.assertEqual(calls[1].args[0][-3:], ["test/a_test.dart", "--name", "^(?!visual).*$"])
        self.assertTrue(all(call.args[0][0] == "native-dart" for call in calls))
        self.assertTrue(all("test/z_test.dart" not in call.args[0] for call in calls))
        self.assertIn("PORTABLE_RELEASE_NOT_RUN=test/z_test.dart", output)
        self.assertTrue(output.endswith("PORTABLE_RELEASE_EXECUTED_TEST_FILES=2\n"))

    def test_code_only_mixed_failure_is_not_converted_to_success(self):
        policy = SimpleNamespace(
            discover=mock.Mock(), NOT_RUN={},
            MIXED_NAMES={"test/a_test.dart": "^logic$", "test/z_test.dart": "^other$"},
            flutter_test_command=lambda _: ["native-dart", "snapshot", "test"],
        )
        with mock.patch.object(runner, "load_code_only_policy", return_value=policy):
            code, calls, _ = self.run_main([0, 9], ["--code-only"])
        self.assertEqual(code, 9)
        self.assertEqual(len(calls), 2)

    def test_code_only_list_does_not_start_flutter(self):
        policy = SimpleNamespace(discover=mock.Mock(), NOT_RUN={}, MIXED_NAMES={})
        with mock.patch.object(runner, "load_code_only_policy", return_value=policy):
            code, calls, output = self.run_main([], ["--code-only", "--list-only"])
        self.assertEqual((code, calls), (0, []))
        self.assertTrue(output.endswith("PORTABLE_RELEASE_EXECUTED_TEST_FILES=0\n"))

    def test_guarded_capture_files_keep_all_behavioral_tests_ordinary(self):
        policy = runner.load_code_only_policy()
        all_tests, ordinary = policy.discover()
        for mapping, expected in (
            (policy.ENV_CAPTURE_DIRECTORIES, self.DIRECTORY_CAPTURE_FILES),
            (policy.COMPILE_TIME_CAPTURE_DIRECTORIES, self.COMPILE_DIRECTORY_FILES),
        ):
            for name, flag in expected.items():
                with self.subTest(file=name):
                    self.assertEqual(mapping[name], flag)
                    self.assertIn(name, all_tests)
                    self.assertIn(name, ordinary)
                    self.assertNotIn(name, policy.NOT_RUN)
                    self.assertNotIn(name, policy.MIXED_NAMES)

    def test_capture_directories_cannot_leak_into_any_mocked_child(self):
        flags = set(self.DIRECTORY_CAPTURE_FILES.values()) | set(self.COMPILE_DIRECTORY_FILES.values())
        observed = []

        def child(command, **kwargs):
            observed.append(command)
            self.assertTrue(flags.isdisjoint(os.environ))
            self.assertIn("--dart-define=BIL_DASHBOARD_CAPTURE_DIR=", command)
            self.assertNotIn("--dart-define=BIL_DASHBOARD_CAPTURE_DIR=false", command)
            self.assertNotIn("--dart-define=BIL_DASHBOARD_CAPTURE_DIR=0", command)
            return subprocess.CompletedProcess(command, 0)

        with mock.patch.dict(os.environ, {flag: "inherited-output-must-not-leak" for flag in flags}), \
             mock.patch.object(runner, "discover_tests", return_value=self.discovery), \
             mock.patch.object(runner.subprocess, "run", side_effect=child), \
             contextlib.redirect_stdout(io.StringIO()):
            code = runner.main(["--code-only"])
        self.assertEqual(code, 0)
        self.assertEqual(len(observed), 2)

    def test_compile_directory_defines_are_empty_strings_not_boolean_false(self):
        policy = runner.load_code_only_policy()
        with tempfile.TemporaryDirectory(prefix="bil-code-only-argv-") as folder:
            binary = Path(folder) / "bin"
            dart = binary / "cache/dart-sdk/bin" / ("dart.exe" if os.name == "nt" else "dart")
            dart.parent.mkdir(parents=True)
            dart.touch()
            (binary / "cache/flutter_tools.snapshot").touch()
            flutter = binary / ("flutter.bat" if os.name == "nt" else "flutter")
            flutter.touch()
            command = policy.flutter_test_command(str(flutter))
        self.assertEqual(Path(command[0]).resolve(), dart.resolve())
        self.assertEqual(command.count("--dart-define=BIL_DASHBOARD_CAPTURE_DIR="), 1)
        for flag in set(policy.CAPTURE_GUARDED.values()):
            self.assertIn(f"--dart-define={flag}=false", command)

    def test_known_directory_guard_does_not_authorize_an_unknown_visual_file(self):
        policy = runner.load_code_only_policy()
        classifications = (set(policy.NOT_RUN) | set(policy.MIXED_NAMES)
                           | set(policy.CAPTURE_GUARDED) | set(policy.ENV_CAPTURE_GUARDED)
                           | set(policy.ENV_CAPTURE_DIRECTORIES)
                           | set(policy.COMPILE_TIME_CAPTURE_DIRECTORIES)
                           | set(policy.NON_VISUAL_BYTE_TESTS))
        with tempfile.TemporaryDirectory(prefix="bil-unknown-visual-") as folder:
            root = Path(folder)
            for name in classifications:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("// reviewed fixture\n", encoding="utf-8")
            unknown = "test/features/commerce/personal_plan_unreviewed_test.dart"
            (root / unknown).write_text(
                "void capture() { final dir = Platform.environment['BIL_PREMIUM_CAPTURE_DIR']; "
                "if (dir == null) return; boundary.toImage(); }\n", encoding="utf-8")
            with mock.patch.object(policy, "ROOT", root):
                with self.assertRaisesRegex(ValueError, "New unreviewed visual operation: " + unknown):
                    policy.discover()

    def test_exact_required_renderers_stay_in_both_complete_local_schedules(self):
        policy = runner.load_code_only_policy()
        all_tests, ordinary = policy.discover()
        self.assertEqual(set(policy.REQUIRED_RENDERER_TESTS), self.REQUIRED_RENDERER_FILES)
        from tool.release import run_full_validation_batches as complete
        complete_schedule = [name for group in complete.groups(all_tests) for name in group]
        _, default_portable = runner.discover_tests()
        for name in self.REQUIRED_RENDERER_FILES:
            with self.subTest(file=name):
                self.assertIn(name, all_tests)
                self.assertEqual(complete_schedule.count(name), 1)
                self.assertIn(name, default_portable)
                self.assertNotIn(name, ordinary)
                self.assertEqual(policy.NOT_RUN[name], policy.REQUIRED_RENDERER_TESTS[name])
                self.assertIn("verify.yml", policy.REQUIRED_RENDERER_TESTS[name])

    @staticmethod
    def complete_file_gate():
        qa = runner.REPOSITORY_ROOT / "tools/qa"
        with mock.patch.object(sys, "path", [str(qa), *sys.path]):
            spec = importlib.util.spec_from_file_location(
                "code_only_complete_file_gate", qa / "bil39_full_suite_files.py")
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
        return module

    def test_actual_eight_shard_verifier_rejects_each_missing_renderer_execution(self):
        full = self.complete_file_gate()
        files = full.inventory(runner.REPOSITORY_ROOT)
        actual_files = {p.relative_to(runner.REPOSITORY_ROOT).as_posix()
                        for p in (runner.REPOSITORY_ROOT / "test").rglob("*_test.dart")}
        self.assertEqual(set(files), actual_files)
        self.assertGreater(len(files), 1500)
        sha = "a" * 40  # Synthetic verifier fixtures, never CI execution evidence.
        with tempfile.TemporaryDirectory(prefix="bil-required-renderer-receipts-") as folder:
            artifacts = Path(folder)
            receipts = {}
            for index in range(8):
                target = artifacts / str(index)
                target.mkdir()
                plan = full.plan(files, sha=sha, index=index, total=8)
                (target / "plan.json").write_text(json.dumps(plan), encoding="utf-8")
                receipt = {"source_sha": sha, "status": "PASS", "process_exit": 0,
                           "protocol_success": True, "error_events": 0, "in_progress": [],
                           "unexpected_skips": [], "counts": {"success": len(plan["files"]), "failure": 0, "error": 0},
                           "files": {name: {"success": 1} for name in plan["files"]}}
                receipts[index] = receipt
                (target / "receipt.json").write_text(json.dumps(receipt), encoding="utf-8")
            self.assertEqual(full.verify(runner.REPOSITORY_ROOT, artifacts, sha=sha, total=8)["status"], "PASS")
            for name in self.REQUIRED_RENDERER_FILES:
                with self.subTest(file=name):
                    matches = [i for i, receipt in receipts.items() if name in receipt["files"]]
                    self.assertEqual(len(matches), 1)
                    index = matches[0]
                    broken = {**receipts[index], "files": dict(receipts[index]["files"])}
                    del broken["files"][name]
                    path = artifacts / str(index) / "receipt.json"
                    path.write_text(json.dumps(broken), encoding="utf-8")
                    with self.assertRaisesRegex(ValueError, "Actual executed files differ"):
                        full.verify(runner.REPOSITORY_ROOT, artifacts, sha=sha, total=8)
                    path.write_text(json.dumps(receipts[index]), encoding="utf-8")

    def test_required_ci_executes_complete_plan_without_name_filters_and_requires_receipts(self):
        source = (runner.REPOSITORY_ROOT / ".github/workflows/verify.yml").read_text(encoding="utf-8")
        shards = source.split("\n  shards:\n", 1)[1].split("\n  integration-tools:", 1)[0]
        command = shards.split("- name: Run complete Flutter test suite shard", 1)[1]
        command = command.split("- name: Preserve exact-source", 1)[0]
        self.assertIn("shard: [0, 1, 2, 3, 4, 5, 6, 7]", shards)
        self.assertIn("bil39_full_suite_files.py", command)
        self.assertIn("--total 8", command)
        self.assertIn("ConvertFrom-Json).files", command)
        self.assertIn("@bilTestFiles", command)
        self.assertNotRegex(command, r"--(?:plain-name|name|exclude)(?:[=\s])")
        self.assertIn("bil39_flutter_event_receipt.py", command)
        self.assertIn("--test-exit $bilFlutterExit", command)
        aggregate = source.split("\n  flutter:\n", 1)[1]
        self.assertIn("needs: [source, p0, focused, broad, shards, integration-tools]", aggregate)
        self.assertIn('$SHARDS_RESULT" != "success"', aggregate)
        self.assertIn("bil39_full_suite_files.py", aggregate)
        self.assertIn('--verify "$RUNNER_TEMP/bil39-full-coverage"', aggregate)

    def test_code_only_plan_reports_mandatory_renderers_as_not_run_not_passed(self):
        policy = runner.load_code_only_policy()
        with tempfile.TemporaryDirectory(prefix="bil-code-only-plan-") as folder, \
             mock.patch.object(policy, "EVIDENCE", Path(folder)), \
             mock.patch.object(policy, "run_gate") as gate, \
             mock.patch.object(sys, "argv", ["run_code_tests.py", "final", "--list-only"]), \
             contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(policy.main(), 0)
            plan = json.loads((Path(folder) / "final_test_plan.json").read_text())
        gate.assert_not_called()
        self.assertEqual(plan["required_renderer_in_complete_suite"], policy.REQUIRED_RENDERER_TESTS)
        for name in self.REQUIRED_RENDERER_FILES:
            self.assertIn(name, plan["NOT RUN"])
            self.assertNotIn(name, plan["ordinary"])


if __name__ == "__main__":
    unittest.main()
