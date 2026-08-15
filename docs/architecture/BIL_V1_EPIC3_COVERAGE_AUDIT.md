# BIL v1 Epic 3 — Coverage audit

## Closure rule

Epic 3 is not closed by a green full-suite gate alone. Closure requires the
route registry, state evidence, complete phone matrix, visual baselines, and
comparison-reference traceability below to pass together.

## Route matrix

All 43 active paths in `app_router.dart` are classified by
`epic3_scope_coverage_audit_test.dart`. Each family has an existing executable
behavior/contract test where one exists; content-only families retain explicit
source evidence and inherit the globally tested `MaterialApp` theme. This is
intentionally not misrepresented as a per-route golden.

| Family | Routes | Direct evidence |
|---|---|---|
| Startup/splash | `/startup` | startup state + phone/tablet splash goldens |
| Account/auth | `/login`, `/register`, `/verify-email`, `/account-gateway` | auth boundary, gateway, shared account surface |
| Onboarding | `/onboarding` | EN/AR welcome goldens, responsive and recovery tests |
| Capture | `/daily-check-in`, `/daily-log` | check-in contract, diary layout/recovery |
| Dashboard/intelligence | `/dashboard`, decision/context/plan/experiments/intelligence routes | dashboard phone/tablet/desktop goldens and decision tests |
| Nutrition | `/nutrition`, `/food-libraries`, `/nutrition-plans` | search, catalog, pathway contracts |
| Progress/reports | `/history`, `/analytics`, `/weekly-report` | analytics/weight/report contracts |
| Wellness | library, sleep, workouts, fasting, recipes, packs, challenges | routed source surfaces plus global matrix |
| Community | hub, people, connections, food review, chat | routed source surfaces plus global matrix |
| Health devices | `/connected-health` | connected-health contract; BIL watch/device preserved |
| Profile | profile, measurements, share studio | premium profile and profile experience contracts |
| Settings/support | settings, location, notifications, trust support, settings analytics | settings/location contracts plus routed source surfaces |
| Commerce | `/plans` | paywall widget and commerce boundary contracts |

## State matrix

| State | Real evidence |
|---|---|
| Loading | dashboard loading skeleton test + system goldens |
| Empty | actionable empty-state test + system goldens |
| Error/retry | daily-log recovery test + system goldens |
| Disabled | disabled control in all eight system goldens |
| Offline | offline-first cloud test + offline row in all eight system goldens |

## Phone, direction, and theme matrix

The executable `epic3_visual_matrix_golden_test.dart` renders the canonical
system at both 390×844 and 430×932 for every cross-product of English/Arabic and
Light/Dark: eight goldens total. It asserts direction, brightness, 48-pixel
minimum action height, absence of render exceptions, and captures app bar,
cards, metrics, input, chips, state rows, enabled/disabled actions, and bottom
navigation.

The same executable suite separately verifies a compact 390×844 phone at 200%
text scale and with iPhone-class top/bottom safe padding plus a 300-pixel
keyboard inset. The primary action must remain reachable with no render
exception. These are behavior checks rather than extra golden variants.

Existing actual-product goldens supplement the system matrix:

- Splash: compact phone and tablet.
- Welcome/onboarding: English and Arabic compact phone.
- Dashboard: phone, tablet, desktop, corrected light, Arabic/large-text behavior.
- Personal health AI panel: phone.

Text scaling, keyboard/safe-area behavior, responsive navigation, semantics,
and RTL interaction therefore have executable behavior contracts. Goldens do
not replace those assertions.

## Comparison traceability

`docs/visual-references/BIL_V1_EPIC3_MYFITNESSPAL_REFERENCE.md` records the
owner-supplied screenshot sets, the design traits extracted from them, the
corresponding BIL evidence, and the explicit no-copy boundary.

## Required audit gate

1. Generate then verify all eight system goldens.
2. Run route/state evidence audit.
3. Run existing Epic 3 theme, responsive, splash, welcome, dashboard, profile,
   settings, auth, and commerce visual/behavior contracts.
4. Require clean format and focused analysis.
5. Only after this audit passes, rerun the full Epic 3 gate because the suite
   and golden inventory changed.

## Final result

- Original-scope coverage audit: `PASS` on 2026-08-03.
- Matrix goldens: `8/8` generated and verified.
- Final full gate after the audit: `PASS` on 2026-08-03.
- Final full-suite result: `955` passed, `18` explicitly skipped, zero analyzer
  issues, and no formatting changes across `1,001` files.
