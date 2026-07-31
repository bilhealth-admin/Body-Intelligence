# GLOBAL ANALYZE FINDINGS

## BIL-QUALITY-001

Baseline: `a4f602ebcd3415212033b71056327365528fa481`

The 40 non-Commerce findings reported after BIL-COM-009-R1B are addressed without changing analyzer policy.

| Area | Findings | Classification | Owner | Resolution |
|---|---:|---|---|---|
| App theme | 1 | Safe Mechanical Cleanup | App Platform | Removed redundant animation import. |
| Data repositories | 9 | Constructor/Formal Cleanup | Data Platform | Replaced initializer assignments with initializing formals. |
| Daily Log | 3 | Safe Mechanical Cleanup | Daily Log | Replaced multiple unused underscore parameters with `_`. |
| Nutrition | 4 | Constructor/Formal Cleanup | Nutrition | Replaced initializer assignments with initializing formals. |
| Onboarding body canvas/plan | 6 | Safe Mechanical Cleanup / Dead Code Removal | Onboarding | Removed redundant const nesting and an unused optional parameter. |
| Onboarding shared calibration | 7 | Dead Code Removal / Safe Mechanical Cleanup | Onboarding | Removed unreferenced private widgets/field/parameters and used null-aware collection element. |
| Onboarding profile | 8 | Deprecated API Migration / Dead Code Removal | Onboarding | Removed unreferenced private state/helpers/import and migrated deprecated APIs. |
| Shared wheel field | 1 | Safe Mechanical Cleanup | Shared UI | Added braces around guarded return. |
| Product excellence test | 1 | Test Cleanup | Product Excellence | Removed unused import. |

Behavioral-risk assessment: none of the reported findings required functional redesign. Private dead code was removed only after repository reference inspection.

## R1 correction record
Three errors were introduced during BIL-QUALITY-001 application:

| File | Analyzer result | Classification | Resolution |
|---|---|---|---|
| `lib/features/onboarding/body_canvas/body_setup_canvas.dart` | 2 × `undefined_getter` for `unit` | Dead Code Removal | Removed the remaining private `widget.unit` rendering branch because the optional parameter had no callers. |
| `lib/features/onboarding/shared/calibration_components.dart` | `undefined_identifier` for `busy` | Dead Code Removal | Removed the remaining private busy-state branch because the optional parameter had no callers. |

These are R1 corrections to the quality package, not baseline findings.


## BIL-QUALITY-001-R2 — Commerce Paywall UTF-8 Repair

- Classification: Safe Mechanical Cleanup / encoding repair.
- Finding: the full-project mojibake regression test detected a forbidden `â€` sequence in `lib/features/commerce/presentation/commerce_paywall.dart`.
- Resolution: convert malformed Windows-1252/UTF-8 punctuation sequences to intended Unicode punctuation without behavioral changes.
- Required gates: focused mojibake regression, Commerce tests, global analyzer, full project tests, and diff hygiene.
