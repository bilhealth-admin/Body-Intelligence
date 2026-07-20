# Phase 3 — Epic 2 Execution TODO

## Current target
- [ ] P3-E2-001 — Design tokens and semantic theme foundations are centralized and consumed by primary surfaces.

## Plan breakdown (implementation-first)
- [x] Inspect existing theme and screen styling usage in:
  - `lib/features/dashboard/dashboard_page.dart`
  - `lib/features/daily_log/daily_log_page.dart`
  - `lib/features/analytics/analytics_page.dart`
  - relevant shared theme/style files under `lib/app/` and `lib/shared/`
- [ ] Introduce/extend canonical token layer (color, spacing, radius, elevation, type scale) in shared theme location.
- [ ] Refactor Dashboard primary surfaces/headings to consume semantic tokens.
- [ ] Refactor Daily Log primary surfaces/headings to consume semantic tokens.
- [ ] Refactor Analytics primary surfaces/headings to consume semantic tokens.
- [ ] Add/extend focused tests for tokenized surfaces/hierarchy.
- [ ] Run verification:
  - `dart format .`
  - `flutter analyze --no-pub`
  - focused tests
  - full `flutter test`
  - `flutter build apk --debug`
  - `git diff --check`
- [ ] Update `docs/phase_3_execution_ledger.md` P3-E2-001 with concrete evidence/results.
- [ ] Prepare coherent commit for P3-E2-001 with clean worktree.
