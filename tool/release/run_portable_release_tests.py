#!/usr/bin/env python3
"""Run the release-safe Flutter suite on clean macOS/Linux checkouts.

The complete visual/evidence suite remains in the repository and in verify.yml.
Signed release jobs use this runner because the files below either compare
platform-specific raster output or require local, untracked audit artifacts.
Every other Flutter test is still executed.
"""

from __future__ import annotations

import argparse
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


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--list-only",
        action="store_true",
        help="validate and print suite counts without invoking Flutter",
    )
    args = parser.parse_args()

    all_tests, portable = discover_tests()
    print(f"PORTABLE_RELEASE_ALL_TEST_FILES={len(all_tests)}")
    print(f"PORTABLE_RELEASE_EXCLUDED_TEST_FILES={len(EXCLUDED_TESTS)}")
    print(f"PORTABLE_RELEASE_EXECUTED_TEST_FILES={len(portable)}")

    if args.list_only:
        return 0

    completed = subprocess.run(
        [
            "flutter",
            "test",
            "--no-pub",
            "--timeout",
            "30s",
            *portable,
        ],
        cwd=REPOSITORY_ROOT,
        check=False,
    )
    return completed.returncode


if __name__ == "__main__":
    sys.exit(main())
