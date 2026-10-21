"""Pure temporary-source/CI-receipt tests; no Flutter, GitHub or shell calls."""
from copy import deepcopy
from datetime import datetime, timezone
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import bil_release_revalidation_plan as plan


SHA = "a" * 40


def manifest():
    return {
        "workflows": [
            {"workflow_id": 101, "workflow": "full.yml", "required_jobs": ["full"],
             "inputs": {"scope": "full", "native": True}, "reason": "Full source coverage"},
            {"workflow_id": 102, "workflow": "native.yaml", "required_jobs": ["iPhone", "iPad"],
             "inputs": {}, "reason": "Actual native targets"},
        ],
        "manual_physical": [
            {"name": "signed artifact device journeys", "status": "PENDING",
             "evidence_required": ["exact artifact identity", "actual device receipt"]},
        ],
    }


def run():
    return {
        "id": 201, "workflow_id": 101, "head_sha": SHA,
        "created_at": "2026-10-20T15:00:01Z", "status": "completed",
        "conclusion": "success", "jobs": [
            {"name": "full", "status": "completed", "conclusion": "success"},
            {"name": "optional native", "status": "completed", "conclusion": "skipped"},
        ],
    }


def validate_run(receipt=None, **overrides):
    values = dict(expected_head=SHA, expected_workflow_id=101, after_run_id=200,
                  created_after="2026-10-20T15:00:00Z", required_job_names=["full"])
    values.update(overrides)
    return plan.validate_ci_run(run() if receipt is None else receipt, **values)


class InventoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "test").mkdir()

    def source(self, relative, content="void main() {}"):
        file = self.root / relative
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(content, encoding="utf-8", newline="\n")
        return file

    def ladder(self, *, p0=None, focused=None, broad=None, suffix=""):
        for file in plan.EXTRA_FOCUSED_TESTS:
            self.source(file)
        defaults = [("one", "test/one_test.dart test/two_test.dart")]
        self.source("test/one_test.dart")
        self.source("test/two_test.dart")
        self.source("tools/qa/bil_codex_test_ladder.py",
                    f"P0 = {defaults if p0 is None else p0!r}\n"
                    f"FOCUSED = {defaults if focused is None else focused!r}\n"
                    f"BROAD = {defaults if broad is None else broad!r}\n{suffix}")

    def test_direct_matchers_and_path_inventory_runs_whole_entrypoints(self):
        for index, matcher in enumerate(("matchesGoldenFile", "matchesReferenceImage",
                                        "screenMatchesGolden", "testGoldens")):
            self.source(f"test/plain_{index}_test.dart",
                        f"void main() {{ testWidgets('unnamed visual case', (_) => {matcher}()); }}")
        self.source("test/approved_goldens/plain_test.dart")
        self.source("test/no_visual_test.dart")
        self.assertEqual(plan.golden_inventory(self.root), [
            "test/approved_goldens/plain_test.dart", *[
                f"test/plain_{index}_test.dart" for index in range(4)
            ],
        ])
        self.assertTrue(all(value.endswith("_test.dart") and "--" not in value
                            for value in plan.golden_inventory(self.root)))

    def test_transitive_import_export_and_conditional_import_helpers(self):
        self.source("test/ui_test.dart", "import 'support/entry.dart'; void main() {}")
        self.source("test/support/entry.dart", "export 'middle.dart';")
        self.source("test/support/middle.dart",
                    "import 'plain.dart' if (dart.library.io) 'visual.dart';")
        self.source("test/support/plain.dart")
        self.source("test/support/visual.dart", "void compare() => matchesGoldenFile('ref.png');")
        self.assertEqual(plan.golden_inventory(self.root), ["test/ui_test.dart"])

    def test_uri_part_of_reaches_entrypoint_even_without_explicit_parent_part(self):
        self.source("test/screen_test.dart")
        self.source("test/support/screen_cases.dart",
                    "part of '../screen_test.dart'; void cases() => testGoldens('visual', (_) {});")
        self.assertEqual(plan.golden_inventory(self.root), ["test/screen_test.dart"])

    def test_named_part_of_and_explicit_part_reach_both_full_entrypoints(self):
        self.source("test/a_test.dart", "library screens; void main() {}")
        self.source("test/b_test.dart", "part 'support/cases.dart'; void main() {}")
        self.source("test/support/cases.dart",
                    "part of screens; void compare() => screenMatchesGolden('visual');")
        self.assertEqual(plan.golden_inventory(self.root), ["test/a_test.dart", "test/b_test.dart"])

    def test_import_cycles_and_encoded_paths_are_bounded_and_complete(self):
        self.source("test/z_test.dart", "import 'support/a.dart';")
        self.source("test/a_test.dart", "import 'support/helper%20visual.dart';")
        self.source("test/support/a.dart", "import 'b.dart';")
        self.source("test/support/b.dart", "import 'a.dart'; import 'helper%20visual.dart';")
        self.source("test/support/helper visual.dart", "void check() => matchesReferenceImage();")
        self.assertEqual(plan.golden_inventory(self.root), ["test/a_test.dart", "test/z_test.dart"])

    def test_golden_named_helper_propagates_without_matcher_in_entrypoint(self):
        self.source("test/neutral_test.dart", "import 'golden_support/plain.dart';")
        self.source("test/golden_support/plain.dart")
        self.assertEqual(plan.golden_inventory(self.root), ["test/neutral_test.dart"])

    def test_outside_test_helpers_are_not_followed_or_executed(self):
        self.source("test/plain_test.dart", "import '../outside.dart'; import 'package:other/cases.dart';")
        self.source("outside.dart", "throw 'never execute'; // golden")
        self.assertEqual(plan.golden_inventory(self.root), [])

    def test_inventory_rejects_missing_or_unreadable_sources(self):
        with self.assertRaises(plan.PlanValidationError):
            plan.golden_inventory(self.root / "missing")
        self.source("test/invalid_test.dart").write_bytes(b"\xff\xfe")
        with self.assertRaises(plan.PlanValidationError):
            plan.golden_inventory(self.root)

    def test_focused_union_is_complete_sorted_unique_and_never_imports_ladder(self):
        self.ladder(suffix="raise RuntimeError('NEVER IMPORT THE OLD BRANCH MAIN')\n")
        actual = plan.focused_inventory(self.root)
        self.assertEqual(actual, sorted({*plan.EXTRA_FOCUSED_TESTS,
                                         "test/one_test.dart", "test/two_test.dart"}))

    def test_focused_rejects_nonliteral_constants_without_evaluating_code(self):
        self.ladder()
        file = self.root / "tools/qa/bil_codex_test_ladder.py"
        file.write_text("P0 = dangerous()\nFOCUSED = []\nBROAD = []\n", encoding="utf-8")
        with self.assertRaisesRegex(plan.PlanValidationError, "Nonliteral"):
            plan.focused_inventory(self.root)

    def test_focused_rejects_missing_repeated_or_empty_constants(self):
        self.ladder()
        file = self.root / "tools/qa/bil_codex_test_ladder.py"
        for invalid in ("P0=[]\nFOCUSED=[]\n", "P0=[]\nFOCUSED=[]\nBROAD=[]\n",
                        "P0=[]\nP0=[]\nFOCUSED=[]\nBROAD=[]\n"):
            with self.subTest(source=invalid):
                file.write_text(invalid, encoding="utf-8")
                with self.assertRaises(plan.PlanValidationError):
                    plan.focused_inventory(self.root)

    def test_focused_rejects_test_filters_missing_files_and_unsafe_paths(self):
        for value in ("test/one_test.dart --plain-name visual", "test/missing_test.dart",
                      "test/../outside_test.dart", "test\\one_test.dart", "test/not_entry.dart"):
            with self.subTest(path=value):
                self.ladder(p0=[("invalid", value)])
                with self.assertRaises(plan.PlanValidationError):
                    plan.focused_inventory(self.root)

    def test_focused_includes_new_file_in_any_ladder_tier(self):
        self.source("test/late_added_test.dart")
        self.ladder(broad=[("late", "test/late_added_test.dart")])
        self.assertIn("test/late_added_test.dart", plan.focused_inventory(self.root))


class ManifestTests(unittest.TestCase):
    def validate(self, value=None, **kwargs):
        return plan.validate_ci_manifest(manifest() if value is None else value,
                                         required_workflow_ids=[101, 102], **kwargs)

    def test_source_audit_lane_requires_its_manual_profile_dispatch(self):
        path = Path(__file__).with_name('revalidation_ci_plan.json')
        source = json.loads(path.read_text(encoding='utf-8'))
        lane = next(row for row in source['workflows'] if row.get('lane_id') == 'source_audit')
        self.assertEqual(lane['inputs'].get('source_audit_only'), 'true')
        self.assertFalse(lane.get('reuse_push_run', False))
        self.assertFalse(lane.get('expect_push_for_this_run', False))
        self.assertIn('workflow_dispatch', lane['source_binding'])

    def test_pending_physical_allows_plan_but_never_readiness(self):
        source = manifest()
        result = self.validate(source)
        self.assertEqual(len(result), 2)
        self.assertEqual(result[0]["inputs"], source["workflows"][0]["inputs"])
        self.assertIsNot(result[0]["inputs"], source["workflows"][0]["inputs"])
        with self.assertRaisesRegex(plan.PlanValidationError, "readiness"):
            self.validate(source, require_physical_pass=True)

    def test_physical_pass_always_requires_nonempty_evidence(self):
        for missing in (None, "", "   ", [], [" "]):
            with self.subTest(evidence=missing):
                source = manifest()
                source["manual_physical"][0].update(status="PASS", evidence=missing)
                with self.assertRaisesRegex(plan.PlanValidationError, "evidence"):
                    self.validate(source)

    def test_readiness_accepts_all_pass_only_with_evidence_references(self):
        source = manifest()
        source["manual_physical"][0].update(status="PASS", evidence=["signed-device-receipt.json"])
        self.assertEqual(len(self.validate(source, require_physical_pass=True)), 2)

    def test_manifest_rejects_empty_missing_required_and_duplicate_workflows(self):
        cases = []
        source = manifest(); source["workflows"] = []; cases.append(source)
        source = manifest(); source["workflows"].pop(); cases.append(source)
        source = manifest(); source["workflows"].append(deepcopy(source["workflows"][0])); cases.append(source)
        source = manifest(); source["workflows"][1]["workflow"] = ".github/workflows/FULL.yml"; cases.append(source)
        for source in cases:
            with self.subTest(workflows=source["workflows"]):
                with self.assertRaises(plan.PlanValidationError):
                    self.validate(source)

    def test_reused_workflow_profiles_require_unique_lane_ids_and_inputs(self):
        source = manifest()
        source["workflows"][0]["lane_id"] = "security-android"
        extra = deepcopy(source["workflows"][0])
        extra.update(lane_id="security-ios", inputs={"scope": "ios", "native": True})
        source["workflows"].append(extra)
        self.assertEqual(len(self.validate(source)), 3)
        for mutation in ("same_inputs", "missing_lane", "duplicate_lane", "different_filename"):
            with self.subTest(mutation=mutation):
                invalid = deepcopy(source)
                if mutation == "same_inputs":
                    invalid["workflows"][-1]["inputs"] = {"native": True, "scope": "full"}
                elif mutation == "missing_lane":
                    del invalid["workflows"][0]["lane_id"]
                elif mutation == "duplicate_lane":
                    invalid["workflows"][-1]["lane_id"] = "security-android"
                else:
                    invalid["workflows"][-1]["workflow"] = "other.yml"
                with self.assertRaises(plan.PlanValidationError):
                    self.validate(invalid)

    def test_required_inventory_and_workflow_ids_are_strict(self):
        for values in (None, [], [101, 101], [True, 102], "101", [0, 102], [-1, 102]):
            with self.subTest(ids=values):
                with self.assertRaises(plan.PlanValidationError):
                    plan.validate_ci_manifest(manifest(), required_workflow_ids=values)
        self.assertEqual(plan.validate_ci_manifest(manifest(), required_workflow_ids=["101", "102"])[0]["workflow_id"], 101)

    def test_jobs_filename_reason_and_inputs_cannot_silently_omit_scope(self):
        changes = {"required_jobs": ([], ["full", "full"], ["full*"], "full", [" full"]),
                   "workflow": ("../full.yml", "full", ""), "reason": (None, " "),
                   "inputs": (None, {"native": []}, {"scope": float("nan")})}
        for key, values in changes.items():
            for value in values:
                with self.subTest(key=key, value=value):
                    source = manifest(); source["workflows"][0][key] = value
                    with self.assertRaises(plan.PlanValidationError):
                        self.validate(source)

    def test_physical_unknown_status_duplicate_or_absent_inventory_is_rejected(self):
        cases = []
        for value in ([], None, [{"name": "device", "status": "SKIPPED"}],
                      [{"name": "device", "status": []}]):
            source = manifest(); source["manual_physical"] = value; cases.append(source)
        source = manifest(); source["manual_physical"] *= 2; cases.append(source)
        for source in cases:
            with self.subTest(physical=source["manual_physical"]):
                with self.assertRaises(plan.PlanValidationError):
                    self.validate(source)


class CiRunTests(unittest.TestCase):
    def test_new_successful_exact_source_records_optional_skipped_scope(self):
        result = validate_run()
        self.assertEqual(result["head_sha"], SHA)
        self.assertEqual(result["required_jobs"], {"full": 1})
        self.assertEqual(result["optional_jobs"], [
            {"name": "optional native", "status": "completed", "conclusion": "skipped"},
        ])

    def test_stale_head_wrong_workflow_and_reused_run_are_rejected(self):
        for key, value in (("head_sha", "b" * 40), ("workflow_id", 102), ("id", 200)):
            with self.subTest(key=key):
                source = run(); source[key] = value
                with self.assertRaises(plan.PlanValidationError):
                    validate_run(source)

    def test_first_new_run_with_minus_one_floor_is_allowed(self):
        self.assertEqual(validate_run(after_run_id=-1)["run_id"], 201)
        with self.assertRaises(plan.PlanValidationError):
            validate_run(after_run_id=-2)

    def test_time_boundary_uses_utc_second_floor_but_rejects_earlier_second(self):
        source = run(); source["created_at"] = "2026-10-20T15:00:00Z"
        boundary = datetime(2026, 10, 20, 15, 0, 0, 999999, tzinfo=timezone.utc)
        self.assertEqual(validate_run(source, created_after=boundary)["run_id"], 201)
        source["created_at"] = "2026-10-20T17:00:00+02:00"
        self.assertEqual(validate_run(source, created_after=boundary)["run_id"], 201)
        source["created_at"] = "2026-10-20T14:59:59Z"
        with self.assertRaises(plan.PlanValidationError):
            validate_run(source, created_after=boundary)

    def test_naive_invalid_time_or_short_sha_are_rejected(self):
        for value in (datetime(2026, 10, 20), "2026-10-20T15:00:00", "invalid", None):
            with self.subTest(time=value):
                with self.assertRaises(plan.PlanValidationError):
                    validate_run(created_after=value)
        with self.assertRaises(plan.PlanValidationError):
            validate_run(expected_head="abc1234")

    def test_run_failure_cancel_or_unfinished_can_never_pass(self):
        for conclusion in (None, "failure", "cancelled", "skipped", "neutral", "timed_out"):
            source = run(); source["conclusion"] = conclusion
            with self.subTest(conclusion=conclusion), self.assertRaises(plan.PlanValidationError):
                validate_run(source)
        source = run(); source["status"] = "in_progress"
        with self.assertRaises(plan.PlanValidationError):
            validate_run(source)

    def test_missing_skipped_neutral_or_failed_required_job_rejects_green_run(self):
        for conclusion in ("skipped", "neutral", "failure", "cancelled", None):
            source = run(); source["jobs"][0]["conclusion"] = conclusion
            with self.subTest(conclusion=conclusion), self.assertRaises(plan.PlanValidationError):
                validate_run(source)
        source = run(); source["jobs"].pop(0)
        with self.assertRaisesRegex(plan.PlanValidationError, "missing"):
            validate_run(source)

    def test_every_duplicate_required_name_must_pass(self):
        source = run()
        source["jobs"].append({"name": "full", "status": "completed", "conclusion": "skipped"})
        with self.assertRaises(plan.PlanValidationError):
            validate_run(source)
        source["jobs"][-1]["conclusion"] = "success"
        self.assertEqual(validate_run(source)["required_jobs"], {"full": 2})

    def test_paginated_incomplete_jobs_and_empty_inventory_are_rejected(self):
        source = run(); values = source["jobs"]
        source["jobs"] = {"total_count": 3, "jobs": values}
        with self.assertRaisesRegex(plan.PlanValidationError, "incomplete"):
            validate_run(source)
        source["jobs"]["total_count"] = 2
        self.assertEqual(validate_run(source)["required_jobs"], {"full": 1})
        source["jobs"] = []
        with self.assertRaises(plan.PlanValidationError):
            validate_run(source)

    def test_required_names_are_explicit_without_globs_or_empty_scope(self):
        for names in ([], ["full", "full"], ["full*"], "full", [" full"]):
            with self.subTest(names=names), self.assertRaises(plan.PlanValidationError):
                validate_run(required_job_names=names)

    def test_inventories_and_validators_do_not_execute_external_processes(self):
        with patch("subprocess.run", side_effect=AssertionError("external command forbidden")):
            validate_run()
            plan.validate_ci_manifest(manifest(), required_workflow_ids=[101, 102])


if __name__ == "__main__":
    unittest.main()
