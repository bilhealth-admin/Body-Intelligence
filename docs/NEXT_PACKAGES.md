# BIL Next Packages

## First next package

### BIL-COM-004 — Trials, Grace Periods and Subscription Recovery

**Goal:** Add persistence and deterministic recovery orchestration around verified subscription records, including trial/grace restoration and stale-record handling.

**Boundaries:**

- No live Apple/Google/Stripe integration.
- No coupon, referral, affiliate, pricing, or paywall UI.
- Preserve `EntitlementResolver` as the single runtime authorization path.

## Planned sequence

- `BIL-COM-005` — Coupon and Promotion Engine.
- `BIL-COM-006` — Referral and Affiliate Attribution.
- `BIL-COM-007` — Regional Pricing and Country Eligibility.
- `BIL-COM-008` — Store Provider Boundaries and Receipt Validation Contracts.
- `BIL-COM-009` — Commerce UI and Paywall Foundation.
- `BIL-COM-010` — Commerce Epic Quality Gate and Reconciliation.


## Gate before BIL-COM-004
BIL-COM-003-R3 must pass focused tests, commerce regression, analyzer, full regression, and debug build before trials and recovery work begins.

## Next commerce package
BIL-COM-007 — Regional Pricing and Country Eligibility.

## Next commerce package
BIL-COM-008 — Store Provider Boundaries and Receipt Validation Contracts.

## Next commerce package
BIL-COM-009 — Commerce UI and Paywall Foundation.

Then: BIL-COM-010 — Commerce Epic Quality Gate and Reconciliation.

## First next Commerce package after BIL-COM-009
### BIL-COM-010 — Commerce Epic Quality Gate and Reconciliation
Audit the complete Commerce domain, repositories, services, providers, presentation surface, tests, package history, and living documentation. Resolve only proven Commerce defects, add epic-level regression coverage, reconcile stale planning text, and close the Commerce Epic without entering another platform.


## BIL-QUALITY-001 — Global analyzer cleanup
- Classified and corrected the 40 analyzer findings blocking BIL-COM-009 verification.
- No lint was disabled; no analyzer ignore comments were introduced.
- Changes are behavior-preserving mechanical cleanup, deprecated API migration, constructor/formal cleanup, dead-code removal after reference inspection, and test cleanup.
- Acceptance requires `flutter analyze` to report `No issues found`.

## Immediate next action
Apply and verify BIL-QUALITY-001-R1. After all gates pass, rerun BIL-COM-009-R1B verification. No additional package is authorized before those results.


## BIL-QUALITY-001-R2 — Commerce Paywall UTF-8 Repair

- Classification: Safe Mechanical Cleanup / encoding repair.
- Finding: the full-project mojibake regression test detected a forbidden `â€` sequence in `lib/features/commerce/presentation/commerce_paywall.dart`.
- Resolution: convert malformed Windows-1252/UTF-8 punctuation sequences to intended Unicode punctuation without behavioral changes.
- Required gates: focused mojibake regression, Commerce tests, global analyzer, full project tests, and diff hygiene.
