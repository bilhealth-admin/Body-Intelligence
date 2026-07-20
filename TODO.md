# Phase 3 — Epic 2 Execution TODO

## Current target
- [ ] P3-E2-002 — Reusable premium surface primitives (cards/sections) replace duplicated layout chrome patterns.

## P3-E2-001 closure
- [x] Canonical token layer implemented and consumed by core screens/theme.
- [x] Focused Epic 2 + hierarchy/responsive tests passed.
- [x] Full test suite passed.
- [x] Debug APK build passed.
- [x] Ledger updated for P3-E2-001 completion and P3-E2-002 in-progress state.
- [x] Coherent commit created: `e2b147d`.

## Plan breakdown (P3-E2-002)
- [ ] Inspect reusable surface candidates in shared widgets and duplicated card/section patterns in:
  - `lib/features/dashboard/dashboard_page.dart`
  - `lib/features/daily_log/daily_log_page.dart`
  - `lib/features/analytics/analytics_page.dart`
  - `lib/shared/widgets/`
- [ ] Introduce/elevate one reusable premium surface primitive that consumes `PremiumDesignTokens` (no duplicate styling systems).
- [ ] Refactor major repeated surface wrappers in Dashboard/Daily Log/Analytics to use the reusable primitive.
- [ ] Keep business logic, localization, semantics, and responsive behavior unchanged.
- [ ] Add focused P3-E2-002 tests at stable reusable-surface boundary.
- [ ] Run milestone verification:
  - `dart format .`
  - `flutter analyze --no-pub`
  - focused P3-E2-002 tests
  - `flutter test`
  - `flutter build apk --debug`
  - `git diff --check`
- [ ] Update `docs/phase_3_execution_ledger.md` with P3-E2-002 evidence and status.
- [ ] Create one coherent local commit for P3-E2-002 and verify clean status.
