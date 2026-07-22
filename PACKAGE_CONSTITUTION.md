# BIL Package Constitution

Package: `BDAR-003A-R1 — First Value Test Compatibility`
Baseline commit: `9270697`
Branch: `phase-3-product-excellence`

This revision is subordinate to BDAR-003A and all higher BIL governance
documents.

## Frozen scope

- Update only `test/first_value_handoff_test.dart`.
- Import `FirstValueHandoffCard` from its new presentation file.
- Preserve the existing Arabic honesty and single-action assertions.
- Remove trailing whitespace from the package constitution.
- Change no production code, behavior, calculations, navigation, persistence,
  localization, or dashboard layout.

## Completion gate

- `git diff --check` reports no whitespace errors from this package.
- `flutter analyze --no-pub` has no BDAR-003A errors.
- `flutter test test\first_value_handoff_test.dart` passes.
- Existing BDAR-003A and BDAR-002 regression tests remain passing.
