# BIL Package Constitution

Package: `BDAR-003B-R1 — Test Compatibility`
Baseline: BDAR-003B working tree over commit `cf4aa3e`
Branch: `phase-3-product-excellence`

This revision is subordinate to BDAR-003B and all higher BIL governance.

## Frozen scope

- Fix only the three stale or invalid tests created by BDAR-003B.
- Replace the invalid constant double-key map with record-based test cases.
- Make the source contract resilient to formatter line wrapping.
- Align the legacy composition test with the approved 1500px two-region rule.
- Change no production Dart code, layout metrics, routing, data, engines,
  calculations, persistence, localization, or scientific behavior.

## Completion gate

- `flutter analyze --no-pub` has no BDAR-003B errors.
- All three corrected tests pass.
- All BDAR-003A and critical BDAR-002 regression tests remain passing.
- Manual Windows review passes before commit.
