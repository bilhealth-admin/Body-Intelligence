# BIL 15-row visual REVIEW recheck — 2026-09-06

## Scope and evidence boundary

This note rechecks only the 15 visual paths left as `REVIEW` in
`BIL_PLUS8_STAGING_MANIFEST_REVIEW_COMPANION_2026-09-05.md`. The first
current-tree comparison at `2026-09-06T05:25Z` ran without
`--update-goldens`: 7 rows passed and 8 exposed current visual differences.
Those eight failure renders were inspected against the implementation and the
literal UI requests. Concrete spacing/readiness defects were corrected before
the reviewed baselines were updated in the two bounded update runs `87304`
(food, dashboard, and both sleep states) and `15113` (profile, Daily Log, More,
and Quick Nutrition). This was implementation review, not a claim of human
owner approval.

An ordinary golden pass proves deterministic Flutter widget rendering equals
the checked-in 390×844 regression baseline for that test fixture. It is not a
native iPhone/iPad/Android device result, a store screenshot approval, or proof
of parity with every external reference image. A mismatch is evidence that the
current widget tree differs; it is not automatically a product regression.

## Current ordinary-run disposition

| Baseline | Owning ordinary test | Current result | Source/visual review |
| --- | --- | --- | --- |
| `quick_add_ar_dark_phone.png` | `quick add ar_dark production visual` | PASS | Current semantic food-search, linear-barcode, voice, meal-photo, exercise, notes, and food-log actions match the BIL action inventory. Solid accent primary badges retain white glyphs. |
| `quick_add_en_light_phone.png` | `quick add en_light production visual` | PASS | Same functional mapping and layout contract as Arabic. Two adjunct iOS Quick Add scenarios also passed but are not counted among these historical 15 rows. |
| `visual_closure_ai_coach_conversation_phone.png` | `AI Coach conversation production phone capture` | PASS | Current conversation fixture equals its checked-in regression baseline. This does not prove persistence or live-provider latency on a native device. |
| `visual_closure_daily_log_empty_phone.png` | `daily log production empty day capture` | PASS after reviewed update | Calendar/preferences and meal-specific colored badges are an intentional R-093 change and their callbacks are unchanged. The new 40 px Water badge originally inherited the app-wide zero title gap; a local 12 px gap now keeps title and badge separate without changing navigation. |
| `visual_closure_dashboard_nutrient_goal_card_phone.png` | `dashboard persisted nutrient goal card capture` | PASS | The persisted nutrient-card fixture equals its current checked-in baseline. |
| `visual_closure_dashboard_phone.png` | `dashboard production populated phone capture` | PASS after reviewed update | The large initial drift was the explicitly requested centered-header/profile-action and semantic treatment work. The inspected current render retained its content and actions before its bounded baseline update. |
| `visual_closure_diary_settings_phone.png` | `diary_settings_phone production capture` | PASS | Current production settings fixture equals baseline. |
| `visual_closure_diary_sharing_phone.png` | `diary_sharing_phone production capture` | PASS | Current sharing-selection fixture equals baseline. |
| `visual_closure_food_catalog_phone.png` | `food catalog production empty state capture` | PASS after reviewed update | Scan/manual/custom actions now use central barcode/notes badges while retaining the same callbacks. The 36 px badge makes the quick-action row about 12 px taller and shifts the following content; the locked blur also changes because the protected glyphs beneath it changed. Review confirmed intact labels, search, tabs, empty state, and Add Food action with no overflow. |
| `visual_closure_more_lower_phone.png` | `More production lower capture` | PASS after reviewed update | Central per-function badges, `Sharing & Privacy`, and the real `Sync now` action intentionally differ. Local 12 px gaps keep standard, action, and sync row titles away from their badges without changing routes or access. The partly visible preceding badge is the expected result of this lower-section fixture's explicit scroll position, not missing content. |
| `visual_closure_profile_goals_phone.png` | `profile goals production lower section capture` | PASS | Current Goals fixture equals baseline. |
| `visual_closure_profile_phone.png` | `profile production populated state capture` | PASS after reviewed update | The initial render exposed a real label/ellipsis issue during the profile-header work. The corrected render keeps every current label readable; its focused profile suite also passed 10/10 before the baseline update. |
| `visual_closure_quick_nutrition_form_phone.png` | `quick nutrition production dialog capture` | PASS after reviewed update | The current header and meal/time semantic treatment implements the explicit request. A local 12 px title gap prevents Meal and Time from abutting their badges; field and action behavior is unchanged. |
| `visual_closure_sleep_phone_2.png` | `sleep production saved record capture` | PASS after reviewed update | Sleep-specific semantic glyphs are intentional. Reset mock preferences and explicit readiness assertions removed a fixture race that had rendered enabled controls as disabled. The focused sleep suite passed 11/11 before update. |
| `visual_closure_sleep_phone.png` | `sleep production page capture` | PASS after reviewed update | The empty state uses the same corrected readiness fixture and intentional sleep semantics; enabled/disabled appearance is now deterministic. |

The final ordinary run `60250` establishes **15/15 historical rows PASS** on
the current widget source. The same selection included two adjunct iOS Quick
Add captures, so the executed batch passed **17/17**. Supporting focused
evidence includes 39/39 spacing and behavior tests in `41866` (including all
six LTR/RTL badge-gap cases), 11/11 sleep tests in `32881`, and 10/10 focused
profile tests.

## Current baseline hashes

These SHA-256 values bind the exact files used by final ordinary run `60250`:

| Baseline | SHA-256 |
| --- | --- |
| `quick_add_ar_dark_phone.png` | `2b7c2dada2e11e1eef7e2fe4415401479d482de4e52e6105078a334e8efc0d18` |
| `quick_add_en_light_phone.png` | `ea00d65b75d91945e423abfa8d317dfbed09db8618aafb62a1fdd92cf0d9a395` |
| `visual_closure_ai_coach_conversation_phone.png` | `83c9fc4a9c1196952e6fdb758597475ad600fac55f0e29e4cc639b3f506eb6f5` |
| `visual_closure_daily_log_empty_phone.png` | `1ceca7b71c3961d3306556a2bde8b4e2d3060a53f7ad3a034ee73fa1f25d8013` |
| `visual_closure_dashboard_nutrient_goal_card_phone.png` | `3709791262d409d0c60aad738fa97922f7933eb6c16720a80678cee99b9af390` |
| `visual_closure_dashboard_phone.png` | `77d5cbf96c6a818a0b6eb1f9433ab635e4d806d1e1d4e5f053d7c79dd7eaa4d5` |
| `visual_closure_diary_settings_phone.png` | `33a9031623d498435ff9dbf86560da7080d516a48e7e4192d582a8b64d65c47b` |
| `visual_closure_diary_sharing_phone.png` | `77a0d215da68a0cacc018fc956f81514d7cdf6c977d45fdf66131dc7b97ceef3` |
| `visual_closure_food_catalog_phone.png` | `c80c62b228d9e539be272d2eabe2e26395d4ef29124c2e42b49956e74f34975e` |
| `visual_closure_more_lower_phone.png` | `52cc2e232ed945e3fac54babebde14958f87e94dd7d0424b0d03f3aa1de1500c` |
| `visual_closure_profile_goals_phone.png` | `cee028ba6e5b6b7b51bba34fe42bacc2b248c7284e2d6e4d5039008c79fd4029` |
| `visual_closure_profile_phone.png` | `b299b54d85ac2751fcb7b80d6e9e77c736eead5023b1859a0b96c064e7fa226c` |
| `visual_closure_quick_nutrition_form_phone.png` | `391e79aaf3f3b99f87c73b1028c3923a2810e1dd269a2eafad9be465a27cfd41` |
| `visual_closure_sleep_phone_2.png` | `1092d1e765109d0ec44f129282071e1d57a07c5da4ef9a34e693f5344792a6c3` |
| `visual_closure_sleep_phone.png` | `cdb24244cb1fe7973fb2cf11c622c47dc59143ee5412341565db0601d36e472f` |

## Exact comparison commands

Run these commands without `--update-goldens`:

```powershell
flutter test test/visual_closure/quick_add_golden_test.dart
```

```powershell
flutter test test/visual_closure/actual_data_pages_golden_test.dart --name "^(food catalog production empty state capture|dashboard production populated phone capture|dashboard persisted nutrient goal card capture|AI Coach conversation production phone capture|daily log production empty day capture|profile production populated state capture|profile goals production lower section capture|diary_settings_phone production capture|diary_sharing_phone production capture|More production lower capture)$"
```

```powershell
flutter test test/visual_closure/actual_production_pages_golden_test.dart --name "^(quick nutrition production dialog capture|sleep production page capture|sleep production saved record capture)$"
```

The narrowest spacing/behavior regression rerun is:

```powershell
flutter test test/semantic_icon_badge_spacing_test.dart
```

## Current decision

- The ordinary-test condition stated in the companion is satisfied for all 15
  current regression baselines. A future regenerated frozen manifest may
  classify these rows `INCLUDE`; the historical CSV remains unchanged.
- Do not use `--update-goldens` on future drift without the same explicit
  render inspection and implementation disposition.
- Current failure `*_testImage.png`, `*_masterImage.png`, and diff files are
  diagnostic artifacts, not release baselines.
- Current widget evidence does not remove the native-device/simulator and store
  review boundary.
