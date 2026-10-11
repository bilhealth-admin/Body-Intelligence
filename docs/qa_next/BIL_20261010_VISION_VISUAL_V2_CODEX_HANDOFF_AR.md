# BIL Vision Visual V2 — Handoff to Codex QA (10 October 2026)

**Scope:** UI implementation has been committed by the main development conversation. Codex owns *test repair and verification only* and must return exact results; it must not silently change product behavior.

**Repository:** bilhealth-admin/Body-Intelligence
**Branch:** qa/bil-quality-ux-integration-20261009
**PR:** https://github.com/bilhealth-admin/Body-Intelligence/pull/11
**Product + new test checkpoint:** eefe104c48ce2f635b8566d04282aeb2d48a2cb9 (the handoff document commit is a later descendant; always check branch HEAD).
**Source before these visual changes:** 6e2b4b657e67cfe59b66cdaec2c83a2e45048f05, Codex test-only handoff.

## 1. Implemented, not yet Flutter-validated
Five commits, restricted to four Vision presentation paths and one new visual test file:

1. e4bb35fa — immersive \`Dialog.fullscreen\` screen for premium meal review, RTL-isolated clock \`11:30\`, hero-first layout, food cards, meal stage and safety warning, fixed action button, never pretend image recognition is verified nutrition.
2. 2f75c4ac — real original \`imagePath\` hero enlarged (238px on tall screens), crop/zoom, empty-photo truthful fallback, inline amount + plus/minus + editable mass/count/volume unit options (g/kg/oz/lb/piece/ml/serving).
3. c33ac2ca — trusted-food match stage with quick/full **two explicit buttons**, evidence-aware **three-column** responsive macro/mineral cards and nutrient icons; \`Not available/غير متوفر\` instead of invented zero; no changes to catalog/trust/SQLite.
4. 2c121a60 — compact candidate at rest, show detailed eating/leftover, amount, alternative and exclude controls after selection; new visual contract test for RTL clock, shell, source truth and 320/390/430.
5. eefe104c — isolate full-screen glass decoration/color/safe-area into \`meal_vision_premium_glass.dart\` as a \`part\`; keep architecture guard maximum 700 source lines. Source inspected: review=653 lines, visuals=462, match=529, glass=74. Lexical bracket balancing passed, **but no Dart format/analyze/compiler/widget/device or fresh screenshot has been run in this conversation**.

**Changed files:**
- lib/features/nutrition/presentation/meal_vision_premium_review.dart
- lib/features/nutrition/presentation/meal_vision_premium_glass.dart (new part)
- lib/features/nutrition/presentation/meal_vision_premium_visuals.dart
- lib/features/nutrition/presentation/meal_vision_premium_match.dart
- test/features/nutrition/meal_vision_premium_visual_contract_test.dart (new)

**Source evidence:** Reference concept \`design/BIL_Vision_Concept.png\` inside original user-supplied \`BIL_Vision_Premium_Review_20261010.zip\`. Previous Flutter screenshots in \`tools/qa/evidence/20261010-local-test-only/0{1..4}_*.png\` are *before* this change and must not be passed off as after screenshots.

## 2. First task: pin and prove local toolchain
Use Flutter **3.44.6** / Dart **3.12.2** (same previously proven Codex environment). Work from a clean QA worktree and HEAD above or its doc-only descendant; do not reset to an earlier green SHA. Check \`git status\`, \`git log\`, and exact diff since 6e2b. Do not overwrite uncommitted user work.

Run strict \`dart format\` on the five paths above, \`flutter analyze --no-pub\` and \`flutter test --no-pub\` on the **new** visual test and these focused existing files:
- test/features/nutrition/meal_vision_premium_visual_contract_test.dart
- test/features/nutrition/meal_vision_premium_review_test.dart
- test/features/nutrition/meal_vision_flutter_capture_test.dart
- test/features/nutrition/meal_vision_verified_commit_test.dart
- test/features/nutrition/meal_declared_unit_commit_test.dart
- test/features/nutrition/meal_image_language_regression_test.dart
- test/features/intelligence_center/coach_image_source_regression_test.dart
- test/architecture_source_file_size_guard_test.dart

**Important new tests:**
- Full screen covers safe area without accidental unbounded/RenderFlex overflow, keyboard/bottom inset or blocked back. Use 320, 390, 430, tablet and portrait/landscape if supported.
- Real RTL time visually reads **11:30**, never \`30:11\` (text byte equality alone insufficient).
- Real \`imagePath\` is shown as hero and zoomed; when no source image is present there is **no substitute presented as user's photograph**. Add an explicitly labeled deterministic TEST fixture for image-path rendering; retain original capture tests rather than removing tests of no-image states.
- On initial display the ingredient shows name/confidence but controls only expand on selecting it. Confirm \`premium-vision-select-0\`, stage before/during/after, \`premium-vision-eaten-0\`, remaining, minus/plus/unit, alternatives, exclusion/restoration, Cancel, Back, and Continue all work with unchanged typed output.
- Nutrition quick/full buttons and grid never contain untrusted food estimates; \`evidenceOwnerKey\` is required for owner-approved labels. Values for 80g/100g and unknown sodium/iron/sugar must be correct and clearly unavailable. Do not mix \`piece\` and \`ml\` into gram values without actual basis.
- Snapshot 4 actual Flutter PNGs + photo fixture/light/dark/RTL/320/430/2x samples; inspect per frame, compare against reference composition (not fake pixel-identical claim). Test overflow/wrapping/focus with VoiceOver/TalkBack on actual devices later.

## 3. Economic stage ladder; do not waste budget
Run source + Vision tests first. If any red, repair the **specific test/tool fixture** and rerun just the red case. When product bug is real, report precise file/line, reproduction, and proposed correction to main development conversation: **Codex is not authorized to edit lib/ product source**.

Then use existing \`tools/qa/bil_codex_test_ladder.py\` with same SHA/fingerprint:
\`--through-stage p0 --parallel 1\`
\`--through-stage focused --parallel 1\`
\`--through-stage broad --parallel 1\`
Only if all previous gates are green on the *same final source*, run \`--through-stage full --parallel 3\` exactly once.
On previous SHA c3acb5c7: Source/Arabic, P0 11/11 and Focused 5/5 were green; **Broad 2/6 green, 4 red with 33 test failures**, full 8 shards intentionally skipped. Those old greens DO NOT certify new Vision code. Previously identified real protected Home 1px overflow and 29 unapproved Goldens remain outside Codex's product modification authority. No mass Golden acceptance, threshold relaxing, assertion removal, false skipped->passed, hiding invalid states or cherry-picking old blobs.

## 4. Absolute protection rules
No \`main\`, no force push/merge PR11, no Supabase Production, no app-store builds/submissions, payment, Trial/Boost/quota, AI Coach/Community, protected Home, Log Food styling, 5 bottom tabs or data schema changes. Keep previous atomic SQLite commits, replay idempotence, owner isolation, verified-food gate, consent and exact portion units. Codex can only format/fix test fixtures/harness/expected UI test contracts that correctly reflect *actual owner-approved behavior*. A red test exposing real product fault must stay red and be reported rather than silenced.

## 5. Final return
Write a thorough PR11 QA handoff comment with:
- Tested exact SHA/worktree fingerprint and \`git diff --name-status\`.
- Flutter/Dart version, format/analyze, new screen tests, P0, Focused, Broad, Full results with exact executed/failed/skipped counts and local log paths.
- PNG artifacts links and **real image fixture** vs no-image cases, RTL clock and screen heights, quick/full details, approval status.
- Separate columns for fixture problems, wrong test expectations, genuine product bugs, reference differences awaiting owner's visual approval.
- List of any *unexecuted* native iOS/Android checks and any required app-source changes for main development conversation.

After test-only fixes are committed to PR11 and the handoff is posted, **STOP**. Do not claim release ready without native validation.
