# BIL PR11 — guarded Golden and protected-route review (2026-10-09)

## Evidence and scope

Source commit before this fix: `837eded443d69e190bb9698be0e943654a1b3ca3`. Verify CI run: https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37948273910 ; Android Debug: https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37948273909 . This is **not a finished QA signoff**.

Actual artifacts inspected (CI-generated, **not real-device captures**): production `11625596241`, data `11624054848`, store `11624309795`. Each contains `masterImage`, `testImage`, `isolatedDiff`, `maskedDiff`. The canonical 125-case list remains https://github.com/bilhealth-admin/Body-Intelligence/pull/11#issuecomment-6084589759 .

Strict focused failures: Store **18**, Data **19**, Production **88**. Splash and transaction queue successful; format/analyze successful; eight full shards not run because focused stage failed. Pixel-array comparison of each of the 125 pairs yields **5 Production matches differing under 1%** (recipe detail and workout routine builder), but most differences affect substantial areas of the image; percentage is a *diagnostic*, **not** a Golden authorization. 37/88 Production pairs have at least 90% of pixels unequal. Antialias or tiny RGB differences can contribute to high percent; strong-change and human visual review must also be used.

## First manual visual triage

- `visual_closure_help_center_phone`: **Owner correction supersedes the previous triage.** An icon isn't required just because a row can have one; the eight Help items are clear as text-and-chevron. Remove unnecessary leading glyphs entirely, and retain a strict widget assertion that all eight have null leading. No Golden was altered.
- `visual_closure_sharing_privacy_phone`: the updated view has additional rows, new line breaks and rearranged content, not only icon changes. Needs behavior/content audit before accepting a baseline.
- `visual_closure_progress_steps_month_phone`: selector surfaces have different glyph treatment, chart/card sizing and spacing. Requires design/accessibility review.
- `epic15_iphone_69_en_00_onboarding`: priority rows and top imagery positioning changed. Review UX behavior before accepting.
- `epic15_iphone_69_ar_03_progress_dark`: visually sizable dark-theme changes, **not** a few antialiased pixels.
- `visual_closure_recipe_discovery_phone`, `visual_closure_workout_log_phone` and `epic15_evidence_en_recipe_library`: visually meaningful layout/image/copy differences; no blanket adoption.
- Legal Help/Privacy pages show substantive typography/row/layout differences requiring accessibility and navigation checks.

No Golden PNG files were modified by this patch. The tests, thresholds and mandatory focused→8-shard CI sequencing are preserved.

## Protected Home / Log Food source verification

All of the following were verified byte-equal across base `a5af21e5`, QUALITY `386d00a6`, UX `bccce73c` and integrated `837eded4` before any write:
`lib/features/dashboard/dashboard_page.dart`,
`lib/features/daily_log/daily_log_page.dart`,
`lib/features/daily_log/food_log_page.dart`,
`lib/features/daily_log/daily_log_meal_search.dart`,
`lib/features/daily_log/daily_water_page.dart`,
`lib/features/daily_log/daily_log_meal_entry.dart`,
`lib/features/nutrition/food_page.dart`,
`lib/app/theme/bil_flagship_theme.dart`,
`lib/app/router/app_router.dart`.

Inventory correction: the **12** `/daily-log` reference rows previously claimed source-level UX changes that had been reverted. They are now explicitly marked protected, not complete and not visually certified.

## Required remaining gates

1. Do **not** accept the 125 failed Goldens in bulk. Check actual screenshot against each app/design reference and verify any intentional, nonprotected change, then update approved images individually with provenance.
2. Compare unreviewed PR9/PR10 overlaps including Settings and strict test fixtures; prefer QUALITY's verified behavior until UX proof exists.
3. Re-run strict 5-suite focused checks; then eight complete shards **only after** focused green; require successful aggregate and Android Debug on the same commit.
4. Source test passing is not native visual parity: record 146 reference before/after pairs on real devices, English/Arabic and dark/light accessibility states. The original `مقترح جديد .zip` file with 146 source images is not available in this working session; inventory descriptions are **not** substitute images.
5. Verify server-backed Coach logging/edits, account isolation, nutrition accuracy, protected food actions, Community operations, SQL in disposable staging and Play reviewer access separately. No Production, prices, Trial or store publication in QA scope.

**Review state: OPEN / DRAFT / NOT MERGE-READY.**
