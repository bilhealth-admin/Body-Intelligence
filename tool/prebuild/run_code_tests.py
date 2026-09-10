"""Run all reviewed host-only Flutter tests, never golden/capture/device tests.

This separate audit runner does not alter or skip any test in the release suite.
Prohibited cases are recorded as NOT RUN, not passed. Mixed files are selected
by test name, preserving their executable non-visual regression assertions.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil

from run_gate import EVIDENCE, ROOT, run_gate


NOT_RUN = {
    "test/epic11_locale_golden_test.dart": "pixel comparisons",
    "test/epic15_store_screenshot_golden_test.dart": "screenshots and pixel comparisons",
    "test/features/commerce/apple_review_product_screenshot_test.dart": "screenshots",
    "test/features/commerce/bil_store_plans_light_visual_test.dart": "pixel comparisons",
    "test/features/onboarding/onboarding_visual_golden_test.dart": "pixel comparisons",
    "test/features/wellness/workout_reference_golden_test.dart": "pixel comparisons",
    "test/personal_health_ai_panel_test.dart": "pixel comparison in the only test",
    "test/visual_closure/actual_data_pages_golden_test.dart": "screenshots and pixel comparisons",
    "test/visual_closure/actual_production_pages_golden_test.dart": "screenshots and pixel comparisons",
    "test/visual_closure/quick_add_golden_test.dart": "pixel comparisons",
    "test/features/wellness/wellness_video_stream_live_test.dart": "opt-in live media request, not a pure integration test",
    "test/features/meal_planner/generated_recipe_assets_test.dart": "image asset content and hash comparison",
    "test/features/commerce/apple_review_asset_package_contract_test.dart": "store image file validation",
    "test/release_metadata_test.dart": "combined metadata and image content comparison; reviewed statically instead",
    "test/splash_video_contract_test.dart": "binary video and fallback image validation",
}

# Negative matches are limited to the reviewed visual test names in these files.
MIXED_NAMES = {
    "test/epic3_visual_matrix_golden_test.dart": r"^(?!Epic 3 visual matrix).*$",
    "test/epic8_weekly_report_golden_test.dart": r"^(?!.*(?:golden|evidence)).*$",
    "test/premium_dashboard_benchmark_test.dart": r"^(?!.*golden).*$",
    "test/premium_splash_experience_test.dart": r"^(?!native launch continuity).*$",
    "test/features/commerce/premium_ai_market_gate_widget_test.dart": r"^(?!premium route glass visual proof).*$",
    "test/features/wellness/recipe_library_polish_test.dart": r"^grid adapts from one to two columns at large text scale$",
    "test/features/wellness/static_workout_artwork_contract_test.dart": r"^six static workout covers are centralized and locally available$",
    "test/features/dashboard/dashboard_identity_header_layout_test.dart": r"^(?!a member photo).*$",
    "test/shared/widgets/bil_account_avatar_test.dart": r"^uses a neutral account fallback and never the AI Coach$",
    "test/features/meal_planner/existing_recipe_canonical_seeds_test.dart": r"^(?!content and image fingerprints).*$",
    "test/features/commerce/ai_boost_coach_artwork_test.dart": r"^(?!production AI Boost artwork matches).*$",
    "test/launch_readiness/splash_identity_asset_contract_test.dart": r"^iOS launch metadata preserves the complete approved identity$",
    "test/launch_readiness/epic15_store_materials_contract_test.dart": r"^(?!rights manifest preserves current art).*$",
    "test/android_launch_readiness/android_launch_contract_test.dart": r"^(?!Flutter hands native blue).*$",
    "test/launch_readiness/visual_reference_evidence_truth_contract_test.dart": r"^artifact existence never upgrades visual-equivalence status$",
}

# Capture and real-photo cache seeding in these files are explicitly opt-in.
CAPTURE_GUARDED = {
    "test/features/community/community_review_regression_test.dart": "BIL_CAPTURE_COMMUNITY_REVIEW",
    "test/connected_health/health_devices_review_regression_test.dart": "BIL_CAPTURE_HEALTH_REVIEW",
}
NON_VISUAL_BYTE_TESTS = {
    "test/launch_readiness/release_source_hygiene_classifier_contract_test.dart":
        "base64-encoded text fixtures for the secret scanner, not images",
}
VISUAL_CALL = re.compile(
    r"matchesGoldenFile\s*\(|screenMatchesGolden\s*\(|\.toImage\s*\("
    r"|captureScreenshot\s*\(|takeScreenshot\s*\(|image\.decodeImage\s*\("
    r"|base64Decode\s*\(|instantiateImageCodec\s*\(|decodeImageFromList\s*\("
    r"|verifyVisualReferenceEvidence\s*\("
)


def flutter_test_command(flutter: str) -> list[str]:
    # Never pass regex test-name filters through flutter.bat/cmd.exe: cmd
    # consumes pipes and parentheses even when Popen receives an argv list.
    # Invoke Flutter's own Dart entrypoint directly, with no shell involved.
    binary = Path(flutter).resolve().parent
    dart = binary / 'cache/dart-sdk/bin' / ('dart.exe' if os.name == 'nt' else 'dart')
    snapshot = binary / 'cache/flutter_tools.snapshot'
    if not dart.is_file() or not snapshot.is_file():
        raise ValueError('A populated Flutter SDK is required for shell-free name filtering')
    return [str(dart), str(snapshot), 'test', '--no-pub', '--concurrency', '1', '--reporter', 'expanded',
            '--dart-define=BIL_CAPTURE_COMMUNITY_REVIEW=false',
            '--dart-define=BIL_CAPTURE_HEALTH_REVIEW=false']


def discover() -> tuple[list[str], list[str]]:
    all_tests = sorted(p.relative_to(ROOT).as_posix()
                       for p in (ROOT / "test").rglob("*_test.dart"))
    classifications = (set(NOT_RUN) | set(MIXED_NAMES) | set(CAPTURE_GUARDED)
                       | set(NON_VISUAL_BYTE_TESTS))
    missing = classifications - set(all_tests)
    if missing:
        raise ValueError(f"Audit classifications refer to missing tests: {missing}")
    for name in all_tests:
        source = (ROOT / name).read_text(encoding="utf-8")
        if VISUAL_CALL.search(source) and name not in classifications:
            raise ValueError(f"New unreviewed visual operation: {name}")
    ordinary = [p for p in all_tests if p not in NOT_RUN and p not in MIXED_NAMES]
    return all_tests, ordinary


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=["baseline", "final"])
    parser.add_argument("--list-only", action="store_true")
    parser.add_argument("--fail-fast", action="store_true",
                        help="Stop after the first failing group, preserving its evidence")
    parser.add_argument("--resume-baseline", action="store_true",
                        help="Keep completed baseline evidence; never reuse it for the final gate")
    args = parser.parse_args()
    all_tests, ordinary = discover()
    excluded = dict(NOT_RUN)
    excluded.update({p.relative_to(ROOT).as_posix(): "device integration harness"
                     for p in (ROOT / "integration_test").rglob("*_test.dart")})
    plan = {"discovered_unit_files": len(all_tests), "ordinary": ordinary,
            "mixed_name_filters": MIXED_NAMES, "NOT RUN": excluded,
            "capture_defines_forced_false": list(CAPTURE_GUARDED.values())}
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    (EVIDENCE / f"{args.phase}_test_plan.json").write_text(
        json.dumps(plan, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"files": len(all_tests), "ordinary": len(ordinary),
                      "mixed": len(MIXED_NAMES), "NOT RUN": len(excluded)}), flush=True)
    if args.list_only:
        return 0
    if args.resume_baseline and args.phase != "baseline":
        parser.error("Final gates must run from scratch")

    completed = set()
    if args.resume_baseline:
        for path in EVIDENCE.glob("baseline_flutter_*.json"):
            result = json.loads(path.read_text(encoding="utf-8"))
            if not isinstance(result, dict) or "command" not in result:
                continue
            # Preserve FAIL as FAIL in the original evidence. Resume does not
            # claim success for these files; every file is rerun in final.
            completed.update(arg for arg in result["command"] if arg.endswith("_test.dart"))
        ordinary = [path for path in ordinary if path not in completed]

    spec = importlib.util.spec_from_file_location(
        "portable_tests", ROOT / "tool/release/run_portable_release_tests.py")
    assert spec is not None and spec.loader is not None
    portable = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(portable)
    flutter = shutil.which("flutter.bat") or shutil.which("flutter")
    if flutter is None:
        raise ValueError("Flutter is not on PATH")
    command = flutter_test_command(flutter)
    performance = "test/performance_budget_test.dart"
    if performance in ordinary:
        ordinary.remove(performance)
    # Keep the timing gate isolated in its own process. Running it last lets
    # unrelated baseline static scans finish before this latency measurement.
    batches = [*portable.partition_test_batches(command, ordinary)]
    results = []
    suffix = "_resume" if args.resume_baseline else ""
    summary_path = EVIDENCE / f"{args.phase}_flutter{suffix}_summary.json"

    def stop_after_failure() -> bool:
        if not args.fail_fast or results[-1]["exit_code"] == 0:
            return False
        summary_path.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
        print(f"STOPPED_AFTER_FAILED_GROUP={results[-1]['gate']}; remaining groups NOT RUN",
              flush=True)
        return True

    for index, batch in enumerate(batches):
        suffix = "resume_" if args.resume_baseline else ""
        name = f"{args.phase}_flutter_{suffix}{index:02d}"
        code = run_gate(name, [*command, *batch])
        results.append({"gate": name, "exit_code": code, "files": batch})
        if stop_after_failure():
            return 1
    for index, (path, pattern) in enumerate(MIXED_NAMES.items()):
        if path in completed:
            continue
        name = f"{args.phase}_flutter_mixed_{index:02d}"
        code = run_gate(name, [*command, path, "--name", pattern])
        results.append({"gate": name, "exit_code": code, "files": [path], "name": pattern})
        if stop_after_failure():
            return 1
    name = f"{args.phase}_flutter_performance"
    code = run_gate(name, [*command, performance])
    results.append({"gate": name, "exit_code": code, "files": [performance]})
    summary_path.write_text(
        json.dumps(results, indent=2) + "\n", encoding="utf-8")
    return int(any(r["exit_code"] != 0 for r in results))


if __name__ == "__main__":
    raise SystemExit(main())
