# BIL product-defect closure evidence — 2026-09-08

## Scope and source state

- Worktree: `codex/bil-community-policy-recovery-20260908`
- Source checkpoint inspected: `4bd3d1aa71a054444504503bd80a9966bb048674`
- Flutter: `3.44.6`
- Scope: handoff sections 10, 11, 18, 21, 22, 23, and 24, using non-Golden Flutter unit/widget/source-contract tests only.
- Explicitly excluded: physical-device testing, Goldens, signed builds, StoreKit/Play Billing, App Store Connect, Google Play release work, backend/Supabase, Cloudflare, and production publication.
- No commit was created by this workstream.
- No migration was added or run. No production data, user preference, entitlement, store record, or backend state was changed.

This is a focused product-defect closure report. It is not a store-release or real-device readiness claim.

## Defect status

| Area | Evidence / root cause | Closure | Status |
|---|---|---|---|
| Community Food form | The original generic snackbar made client-side validation appear to be a dead submit action. Existing shared-tree fixes provide inline per-field errors, Arabic/alternate digit parsing, finite/coherent nutrition checks, a duplicate-submit guard, retained input, inline server error, and retry. | Regressions exercised for invalid input, unrealistic nutrition, successful submit, server error, retained values, and retry. This workstream did not edit the Community form source. | Verified by focused tests |
| Food search performance | Ordinary ASCII searches adapted and ranked the full mobile catalogue even when SQLite could narrow candidates. | Narrow literal queries in SQLite across name, Arabic name, category, keywords, and barcode; preserve the full in-memory fallback for non-ASCII/fuzzy cases and preserve empty-query personalization. | Fixed and verified |
| Sleep logic and UX | A nominal local-time schedule could contradict its goal, same-time windows were ambiguous, and goal versus actual sleep was not explicit. | Added explicit validation issues, overnight local-wall-clock window calculation, 7–12 hour adult planning choices, goal-within-window validation, DST/time-zone copy, and goal-versus-recorded-actual copy. Existing source-labelled connected sleep remains source-labelled. Historical 4–6 hour v1 values remain readable rather than being silently replaced, but are not valid for a new save until corrected. | Fixed and verified |
| Weekly Digest first load | The first render could remain in a transient/failed state until route re-entry. | Stable loading/data rendering, explicit retry through provider invalidation, deterministic pending-to-data and error-to-retry regressions. A full-suite regression also found that the retry label assumed an installed BIL localization delegate; the error component now has a safe English fallback for minimal hosts without leaking the repository exception. | Fixed and verified |
| Challenge clarity | Four repeated locked tiles produced a wall of disabled controls without one clear reason. | Replaced with one semantic locked-state explanation plus four non-interactive audience chips and one lock icon. | Fixed and verified |
| Recipes/videos flicker | Recreated requests/futures and unstable delivery state can replace a stable subtree during navigation. | Existing shared-tree request cache, stable delivery futures, image fallback, video resume, and stream handling were exercised under cold/warm cache and failure/retry tests. This workstream did not edit recipe/video source. | Verified by focused tests; live-network probe intentionally opt-in |
| Goals and rounding | Scheduled macro values could expose excessive precision and locale-hostile parsing/formatting. | Locale-aware number formatting/parsing, grouped calorie values, at most one useful macro decimal, and explicit 25-locale coverage. Repository/page failure paths keep the draft and stored goal stable. | Fixed and verified |
| Meaningful app resume | Long background absence could restore an arbitrary deep page, while short interruptions must not destroy input. | Added a lifecycle coordinator with a 30-minute threshold, earliest-background timestamp, ignored `inactive` transitions, one callback per meaningful resume, and Dashboard navigation before the resumed frame. | Fixed and verified in unit/widget scope |
| Premium loading/paywall flash | Treating loading/error/local defaults as Free briefly showed an upsell to an entitled user. | Loading, error, and unverified local states now remain protected and neutral; only verified Free shows the upsell and only verified entitlement unlocks. The existing owner-scoped, bounded server-verification cache is retained. | Fixed and verified in unit/widget scope |
| Dashboard logo, steps, and One Best Action | The tester requested a larger wordmark, reliable recorded steps, and a carefully bounded action. | Existing shared-tree fixes were verified: identity header sizing, actual daily step input, connected-source visibility, recorded-data-only decision inputs, explanation, deterministic output, and release-boundary abstention. This workstream did not edit these Dashboard files. | Verified by focused tests |
| Quick Add generic food route | Log Food could inherit Dinner as an accidental context. | Existing shared-tree generic route and explicit meal choice were verified together with barcode integration and all 25 locales. Barcode/voice/photo/search entry contracts remain present. This workstream did not edit Quick Add source. | Verified by focused tests |
| Today consumed-only macros | The primary value showed consumed/target despite the owner request for consumed only. | Existing shared-tree widget behavior was verified: primary macro text is consumed-only and the target remains secondary. This workstream did not edit Today source. | Verified by focused tests |
| Error handling | Some error paths either looked dead or could replace useful UI. | Verified busy/idempotency and retained-data behavior where covered; added Weekly retry, a localization-safe error surface, Food inline retry, Goals retained draft, neutral premium verification error, and recipe cache eviction/retry. | Fixed/verified for the listed defects |

The public sleep-duration check used current non-proprietary guidance: the American Academy of Sleep Medicine adult consensus recommends at least seven hours for adults 18–60, and CDC guidance lists seven or more hours for ages 18–60, seven to nine for 61–64, and seven to eight for 65+. Sources: <https://aasm.org/resources/pdf/pressroom/adult-sleep-duration-consensus.pdf> and <https://www.cdc.gov/sleep/about/index.html>.

## Focused non-visual gates

All commands used `--no-pub`; no Golden or device test was included.

| Gate | Coverage | Result |
|---|---|---|
| Food + Community Food + performance | Community Food input/sheet regressions, search ranking, mobile catalogue, repository compatibility, real asset catalogue, performance budget | **62 passed** |
| Sleep + Weekly + Challenge + Goals | Sleep schedule/page/source aggregation, Weekly truth/fixture/streak/first-load/locale contracts, Challenge state, goal repository/page/rounding/25 locales | **78 passed** |
| Resume + premium + Quick Add + Today + Dashboard | Resume policy, verified entitlement cache, premium loading/error states, generic route/barcode/25 locales, consumed-only macros, logo/restore/steps/OBA/decision boundary | **126 passed** |
| Recipes/videos | Image request cache and delivery, library/detail/repository, video resume and stream | **45 passed, 1 skipped** |
| Epic 8 behavior | Weekly engine/report/error behavior including the previously failing repository-error case | **11 passed** |
| Architecture ceiling | Hand-maintained Dart source size guard | **1 passed** |

Focused total (disjoint batches above): **323 passed, 1 skipped, 0 failed**.

The one skip is explicit and expected: `wellness_video_stream_live_test.dart` requires opt-in via `BIL_LIVE_WORKOUT_STREAM_CHECK`; it is a live-network canary, not a hidden product-test skip. The local stream, resume, cache, and delivery gates passed.

Additional post-fix rerun:

- Architecture guard + full Epic 8 behavior + Weekly first-load suite: **16/16 passed**, with no Drift multiple-database warning.
- Focused `dart analyze --fatal-infos --fatal-warnings` on the final Weekly error files and Sleep compatibility files: **5/5 targets clean**.
- `dart format`: **22 Dart files checked; formatted**.
- Scoped `git diff --check`: **clean**.
- `flutter analyze --no-pub`: **clean, no issues found** (271.9s). An earlier run was deliberately interrupted to apply the full-suite Weekly failure fix and is not counted as a pass.

Performance sample from the successful Food gate:

```text
BIL_PERF startup_ms=361 search_samples_ms=130,6,4,4,5 search_median_ms=5
```

This is below the recorded 1500ms ceiling. Earlier isolated/consolidated checks also produced single-digit warm medians; the gate above is the final recorded sample for this report.

## Files touched by this workstream

This is the exact list of source/test files touched by this workstream. Some paths were already dirty in the shared worktree, so ownership is of the reviewed hunks, not necessarily every pre-existing diff in the file.

1. `lib/data/repositories/food_repository.dart`
2. `lib/data/repositories/food_repository_ranking.dart`
3. `lib/features/wellness/domain/sleep_schedule.dart`
4. `lib/features/wellness/presentation/sleep_tracker_experience.dart`
5. `lib/features/wellness/presentation/wellness_tools_pages.dart`
6. `lib/features/wellness/presentation/sleep_tracker_schedule.dart` (new)
7. `test/features/wellness/sleep_schedule_test.dart`
8. `lib/features/analytics/weekly_report_page.dart`
9. `lib/features/analytics/weekly_report_components.dart`
10. `lib/features/analytics/weekly_report_message.dart` (new)
11. `test/features/analytics/weekly_report_history_navigation_test.dart`
12. `test/epic8_engines_reports_behavior_test.dart`
13. `lib/features/challenges/challenges_page.dart`
14. `test/challenges_state_visual_contract_test.dart`
15. `lib/features/commerce/presentation/premium_nutrition_glass.dart`
16. `test/features/commerce/premium_nutrition_glass_test.dart`
17. `lib/app/services/app_resume_dashboard_coordinator.dart` (new)
18. `lib/main.dart`
19. `test/app_resume_dashboard_policy_test.dart` (new)
20. `lib/app/localization/runtime_copy_nutrition_goal_schedule.dart`
21. `lib/features/settings/nutrition_goal_schedule_page.dart`
22. `test/features/settings/nutrition_goal_schedule_25_locale_test.dart`
23. `docs/recovery/PRODUCT_DEFECT_CLOSURE_2026-09-08.md` (this report)

Files for Community Food, recipes/videos, Dashboard, Quick Add, and Today were exercised but are deliberately absent from this list because this workstream did not edit them.

## Architecture evidence

- `lib/data/repositories/food_repository.dart`: **692 lines**, under its 700-line ceiling. Ranking helpers live in the existing `food_repository_ranking.dart` part.
- `lib/features/wellness/presentation/sleep_tracker_experience.dart`: **775 lines**, under its reviewed 900-line ceiling. The schedule card lives in `sleep_tracker_schedule.dart`.
- `lib/features/analytics/weekly_report_components.dart`: **918 lines** after splitting its error/retry component into the 39-line `weekly_report_message.dart` part, under its reviewed ceiling.
- The architecture source-size guard passed after all three splits.

## Rollback

The worktree is shared and dirty. Roll back by reviewed hunks/files, not by a broad `git checkout`, reset, or deletion of unrelated changes.

- Food performance: reverse only the narrowed-candidate path in `food_repository.dart` and its helper in `food_repository_ranking.dart`. No database schema or catalogue asset rollback is needed.
- Sleep: reverse the domain/UI hunks and remove only the new `sleep_tracker_schedule.dart` part wiring. Do not clear `wellness_sleep_schedule_v1`; its JSON schema was not changed, and historical values were intentionally preserved.
- Weekly: reverse the loading/error/retry hunks and remove only `weekly_report_message.dart` plus its `part` directive. No report or user data is migrated.
- Challenge: reverse the single explanatory locked-state card and its contract-test changes.
- Goals/rounding: reverse only the locale parsing/formatting and schedule-page hunks. No saved-goal schema was changed.
- Resume: remove `app_resume_dashboard_coordinator.dart`, its `main.dart` lifecycle wiring, and its test. No navigation state is persisted by the coordinator.
- Premium: reverse only the neutral verification veil and related tests. Do not change or delete verified entitlement/cache data.
- Verified-only Community Food, recipes/videos, Dashboard, Quick Add, and Today areas require no rollback from this workstream because it made no source changes there.
- No backend or production-data rollback exists for this workstream.

## Remaining proof boundary

These fixes are closed at source/unit/widget level. Real-device lifecycle timing, image/layout stability after unlock, HealthKit/Health Connect source import, live network streaming, and end-to-end release behavior remain device/platform gates and must not be inferred from these results. Store, purchase, signed-build, physical-device, and Golden work were explicitly outside this workstream.
