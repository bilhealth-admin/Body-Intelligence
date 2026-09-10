#!/usr/bin/env python3
"""Run the release-safe Flutter suite on clean macOS/Linux checkouts.

The complete visual/evidence suite remains in the repository and in verify.yml.
Signed release jobs use this runner because the files below either compare
platform-specific raster output or require local, untracked audit artifacts.
Every other Flutter test is still executed.

The performance budget runs first in its own serial invocation so concurrent
test workers cannot distort its timing measurements. Its budgets are unchanged,
and any failure stops the release suite without retries.
"""

from __future__ import annotations

import argparse
import importlib
import shutil
import subprocess
import sys
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]

# This is intentionally an exact allowlist of release-job exclusions. Keep the
# paths explicit so a newly added test can never be skipped accidentally.
EXCLUDED_TESTS = frozenset(
    {
        "test/architecture_source_file_size_guard_test.dart",
        "test/epic11_locale_golden_test.dart",
        "test/epic15_store_screenshot_golden_test.dart",
        "test/epic3_visual_matrix_golden_test.dart",
        "test/epic8_weekly_report_golden_test.dart",
        "test/epic9_cloud_completion_contract_test.dart",
        "test/features/commerce/ai_boost_coach_artwork_test.dart",
        "test/features/commerce/apple_review_product_screenshot_test.dart",
        "test/features/commerce/bil_store_plans_light_visual_test.dart",
        "test/features/commerce/premium_ai_market_gate_widget_test.dart",
        "test/features/meal_planner/existing_recipe_canonical_seeds_test.dart",
        "test/features/meal_planner/generated_recipe_assets_test.dart",
        "test/features/meal_planner/pending_nutrition_b_test.dart",
        "test/features/meal_planner/recipe_catalog_1500_contract_test.dart",
        "test/features/meal_planner/recipe_nutrition_batch_b_test.dart",
        "test/features/nutrition/existing_recipe_nutrition_batch_a_test.dart",
        "test/features/nutrition/recipe_nutrition_pending_a_test.dart",
        "test/features/onboarding/onboarding_visual_golden_test.dart",
        "test/features/wellness/recipe_library_polish_test.dart",
        "test/features/wellness/workout_reference_golden_test.dart",
        "test/launch_readiness/visual_reference_evidence_truth_contract_test.dart",
        "test/launch_readiness/webcam_vision_barcode_preparation_contract_test.dart",
        "test/personal_health_ai_panel_test.dart",
        "test/premium_dashboard_benchmark_test.dart",
        "test/release/workout_video_completion_monitor_contract_test.dart",
        "test/splash_video_contract_test.dart",
        "test/visual_closure/actual_data_pages_golden_test.dart",
        "test/visual_closure/actual_production_pages_golden_test.dart",
        "test/visual_closure/quick_add_golden_test.dart",
    }
)

PERFORMANCE_BUDGET_TEST = "test/performance_budget_test.dart"
WINDOWS_COMMAND_LINE_LIMIT = 6_000
PORTABLE_COMMAND_LINE_LIMIT = 120_000


def resolve_flutter_executable() -> str:
    candidates = ("flutter.bat", "flutter") if sys.platform == "win32" else ("flutter",)
    for candidate in candidates:
        resolved = shutil.which(candidate)
        if resolved:
            return resolved
    raise SystemExit("Flutter executable was not found on PATH.")


def partition_test_batches(
    command: list[str],
    tests: list[str],
    *,
    command_line_limit: int | None = None,
) -> list[list[str]]:
    limit = command_line_limit or (
        WINDOWS_COMMAND_LINE_LIMIT
        if sys.platform == "win32"
        else PORTABLE_COMMAND_LINE_LIMIT
    )
    batches: list[list[str]] = []
    current: list[str] = []
    for test_path in tests:
        candidate = [*command, *current, test_path]
        if current and len(subprocess.list2cmdline(candidate)) > limit:
            batches.append(current)
            current = [test_path]
        else:
            current.append(test_path)
        if len(subprocess.list2cmdline([*command, *current])) > limit:
            raise SystemExit(f"Test path exceeds the command-line limit: {test_path}")
    if current:
        batches.append(current)
    return batches


def discover_tests() -> tuple[list[str], list[str]]:
    all_tests = sorted(
        path.relative_to(REPOSITORY_ROOT).as_posix()
        for path in (REPOSITORY_ROOT / "test").rglob("*_test.dart")
        if path.is_file()
    )
    discovered = set(all_tests)
    missing_exclusions = sorted(EXCLUDED_TESTS - discovered)
    if missing_exclusions:
        joined = "\n  ".join(missing_exclusions)
        raise SystemExit(
            "Portable release exclusion list drifted; missing paths:\n  " + joined
        )

    portable = [path for path in all_tests if path not in EXCLUDED_TESTS]
    if not portable:
        raise SystemExit("Portable release test discovery returned no tests.")
    return all_tests, portable


def partition_tests(portable: list[str]) -> tuple[list[str], list[str]]:
    if len(portable) != len(set(portable)):
        raise SystemExit("Portable release test discovery returned duplicate paths.")
    if PERFORMANCE_BUDGET_TEST not in portable:
        raise SystemExit("Portable release performance budget test is missing.")
    return [PERFORMANCE_BUDGET_TEST], [
        path for path in portable if path != PERFORMANCE_BUDGET_TEST
    ]


def load_code_only_policy():
    """Reuse the audited exclusions and shell-free regex runner, not a second list."""
    policy_path = str(REPOSITORY_ROOT / "tool/prebuild")
    sys.path.insert(0, policy_path)
    try:
        return importlib.import_module("run_code_tests")
    finally:
        sys.path.remove(policy_path)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--list-only",
        action="store_true",
        help="validate and print suite counts without invoking Flutter",
    )
    parser.add_argument(
        "--code-only", action="store_true",
        help="apply the reviewed no-image/no-device audit policy; report exclusions as NOT RUN",
    )
    args = parser.parse_args(argv)

    all_tests, portable = discover_tests()
    policy = load_code_only_policy() if args.code_only else None
    mixed_names = {}
    if policy is not None:
        # Fail before execution if a new visual operation lacks a reviewed rule.
        policy.discover()
        for path in portable:
            if path in policy.NOT_RUN:
                print(f"PORTABLE_RELEASE_NOT_RUN={path}: {policy.NOT_RUN[path]}", flush=True)
        portable = [path for path in portable if path not in policy.NOT_RUN]
        mixed_names = {path: pattern for path, pattern in policy.MIXED_NAMES.items()
                       if path in portable}
        for path, pattern in mixed_names.items():
            print(f"PORTABLE_RELEASE_NAME_FILTER={path}: {pattern}; other cases NOT RUN", flush=True)
    performance_tests, remaining_tests = partition_tests(portable)
    remaining_tests = [path for path in remaining_tests if path not in mixed_names]
    print(f"PORTABLE_RELEASE_ALL_TEST_FILES={len(all_tests)}", flush=True)
    excluded_count = len(all_tests) - len(portable) if policy is not None else len(EXCLUDED_TESTS)
    print(f"PORTABLE_RELEASE_EXCLUDED_TEST_FILES={excluded_count}", flush=True)
    if policy is not None:
        print(f"PORTABLE_RELEASE_MIXED_NAME_FILTERED_FILES={len(mixed_names)}", flush=True)
    print(f"PORTABLE_RELEASE_SCHEDULED_TEST_FILES={len(portable)}", flush=True)
    print(
        f"PORTABLE_RELEASE_PERFORMANCE_SCHEDULED_TEST_FILES={len(performance_tests)}",
        flush=True,
    )
    print(
        f"PORTABLE_RELEASE_REMAINING_SCHEDULED_TEST_FILES={len(remaining_tests)}",
        flush=True,
    )

    if args.list_only:
        print("PORTABLE_RELEASE_EXECUTED_TEST_FILES=0", flush=True)
        return 0

    command = [
        resolve_flutter_executable(),
        "test",
        "--no-pub",
        "--timeout",
        "30s",
    ] if policy is None else [
        *policy.flutter_test_command(resolve_flutter_executable()),
        "--timeout", "30s",
    ]
    print("PORTABLE_RELEASE_PHASE=performance_serial", flush=True)
    performance = subprocess.run(
        [*command, *(["--concurrency", "1"] if policy is None else []), *performance_tests],
        cwd=REPOSITORY_ROOT,
        check=False,
    )
    if performance.returncode != 0 or (not remaining_tests and not mixed_names):
        print(
            f"PORTABLE_RELEASE_EXECUTED_TEST_FILES={len(performance_tests)}",
            flush=True,
        )
        return performance.returncode

    print("PORTABLE_RELEASE_PHASE=remaining_portable", flush=True)
    executed_test_files = len(performance_tests)
    batches = partition_test_batches(command, remaining_tests)
    print(f"PORTABLE_RELEASE_REMAINING_BATCHES={len(batches)}", flush=True)
    for batch in batches:
        completed = subprocess.run(
            [*command, *batch],
            cwd=REPOSITORY_ROOT,
            check=False,
        )
        executed_test_files += len(batch)
        if completed.returncode != 0:
            print(
                f"PORTABLE_RELEASE_EXECUTED_TEST_FILES={executed_test_files}",
                flush=True,
            )
            return completed.returncode
    for path, pattern in mixed_names.items():
        completed = subprocess.run(
            [*command, path, "--name", pattern],
            cwd=REPOSITORY_ROOT, check=False,
        )
        executed_test_files += 1
        if completed.returncode != 0:
            print(f"PORTABLE_RELEASE_EXECUTED_TEST_FILES={executed_test_files}", flush=True)
            return completed.returncode
    print(f"PORTABLE_RELEASE_EXECUTED_TEST_FILES={executed_test_files}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
