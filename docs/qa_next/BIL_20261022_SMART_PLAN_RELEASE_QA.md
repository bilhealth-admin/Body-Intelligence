# BIL Smart Plan release QA — execution matrix, not a passing certificate

## Environment & provenance

Baseline commit: 31554b3e078667a38bd3c53aa105f5f1d2a4dc96.
Independent feature branch: feature/bil-smart-plan-handoff-20261022.
No local Flutter SDK accessible in the ChatGPT session; no tests have actually run on this feature in this session.
Never overwrite locally repaired Codex work or move the protected HEAD.

## 1. Compile / static

- flutter pub get (with existing lock file; do not upgrade dependencies)
- dart format --output=none --set-exit-if-changed lib/features/smart_plan test/features/smart_plan
- flutter analyze --no-pub lib/features/smart_plan test/features/smart_plan
- flutter analyze --no-pub
- flutter test --no-pub test/features/smart_plan/bil_smart_plan_engine_test.dart
- flutter test --no-pub test/app_router_plan_navigation_guard_test.dart
- Check all original feature tests; full test suite only after focused fixes and frozen source.

## 2. Widget/Golden and interaction acceptance

- My Plan appears adjacent to Tools in Coach overview; the original five lower tabs remain unchanged.
- My Plan also appears in Coach menu, sheet closes, navigation pushes and returns to the Coach rather than Dashboard.
- 320/375/414px widths, Arabic/English, LTR/RTL, increased text scale 1.3–2.0, accessibility semantics and screenshots.
- Plan creation sheet: four horizons, nutrition/training/combined, 2–6 workouts, dietary controls, disclaimer, apply/Cancel.
- Draft is not active until explicit approval. No video or food log is falsely marked complete.
- Today page shows correct date, workout and meal references. Other periods show no false today.
- Week list moves by seven-day pages. Completed workout remains after restart; Undo restores status.
- No setState after disposal, no rapid-double-tap duplicate writes, no loading flicker after auth switch.

## 3. Calendar and time

- Day lengths across daylight-saving transitions, Egyptian time and international travel; no shifted diary dates.
- Jan 31 -> Feb 28/29 for month, leap years, December rollover, 3/6-month endpoints.
- Day changes after midnight with UI refresh; no automatic logging or fabricated exercise.
- The app's existing "day starts after sleep" diary rule (if enabled) is not silently overwritten by Smart Plan; align to canonical day resolver before release.

## 4. Privacy / authorization / persistence

- Account A saves plan; switch to B -> A's plan never rendered to B in cache, async responses, errors or widgets.
- Account B creates plan, switch back A -> each sees only own plan.
- Logout while read/write pending -> operation must cancel or fail closed.
- Manual malformed JSON, truncated JSON, oversized JSON, unknown schema, duplicate days, wrong owner, wrong revision -> no data leaked and no bad write.
- Two writers with same revision -> only one accepted; reread avoids silent overwrite.
- Deletion/export contract after cloud sync: active plan + tombstone + events included.
- Offline plan view, reconnection, upload conflicts; sync is NOT implemented yet and these tests remain blocked.
- Supabase RLS SELECT/INSERT/UPDATE/DELETE require correct owner; no cross-owner selection by forged headers.
- No log contains detailed health information, AI prompts, access tokens or request bodies.

## 5. Nutrition and training safety

- Verified Gym six-month runtime manifest and SHA match; reject revoked/absent/unapproved exercise ID.
- Cannot claim video playable if licensed media pack is missing or integrity check fails.
- Existing DietaryCompatibility blocks saved allergen, excluded ingredient, halal/kosher/gluten/lactose restrictions.
- Empty compatible recipe list or missing one meal slot -> block; don't silently substitute.
- Meal suggestion stays separate from actual MealRepository intake and micronutrients; no double counting.
- Three meals are proposals, not validated personal energy prescriptions.
- A high-risk symptom, injury, clinician-supervised context, very low energy target or unsafe rapid-loss target demands review.
- Do not provide pregnancy/minor/medical-specific individual plans before validated assessment.
- User must explicitly mark workout as completed; never mark future workout completed.
- No extra workout as punishment for a missed day, no dramatic calorie lowering when progress stalls.

## 6. AI Coach integration (not yet implemented; blocking production)

- Exact reproduction of screenshot: "goal aim or target 60kg", "please i need to plan", "أريد خطة حتى أوصل 60 خلال أسبوع".
- A goal is not an actual weight log; wrong proposed weight must be rejected by client admission.
- User asks for plan -> native plan draft/open action with correct plan ID, duration and focus.
- User asks "What is my workout today?" -> returns saved day or explains no active plan, never invents IDs.
- No tool receipts -> no claim of data change. Only verified app receipts can mark saved.
- Provider 429/500/timeout fallback diagnostics and exact request reconciliation; no double charging or hidden text.
- Third-party consent denial -> local plan remains readable.
- AI safety report flow works for suggestions and assistant reply.
- Model output injection tries to overwrite owner_id, skip consent, elevate account tier, or create HealthKit data -> rejected.

## 7. Purchase and store regressions

- Existing personalPlan PremiumRouteGlassGate and trial/free/expired states; do not bypass server entitlement via local cache.
- Existing iOS TestFlight account and Apple sign-in test; existing Android Play Billing path; tester access uses store-approved experience.
- No external checkout, no paid-only workaround through AI chat.
- Check release notes / privacy policy / listing and user declarations.

## 8. Command to Codex

Prepare a clean worktree at feature/bil-smart-plan-handoff-20261022. Freeze the protected source for comparison. Run section 1 commands. Fix format/compile errors on the feature branch only. Expand tests for all blocked sections, including screenshots and integrations. Do not claim completion or merge until tests pass and the documented blockers are implemented. Show exact SHAs, changed files, test counts and pass/fail/skip reasons; send a release-readiness table.

## Definition of done

- Zero compile errors, zero unrelated regressions and complete semantic/accessibility/device UI testing.
- Real plan persistence with tested owner isolation and synchronization; write confirmations and receipts enforced.
- Real diary/workout integration with no false records, all suggestions reversible and not auto-consumed.
- Apple/Google policy forms & AI report paths reviewed on the actual shipped binary.
- Owner signs off before changing production cloud or delivering TestFlight.
