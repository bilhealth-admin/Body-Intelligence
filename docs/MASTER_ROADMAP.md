# BIL Master Roadmap

## Authority

This living roadmap reflects repository reality after applying `BIL-COM-003` to baseline `4f4f541fa66307fdcabc7ad7e38047130d795371`. Repository code is authoritative when older planning text conflicts with implementation.

## Completed and protected foundations

- Application architecture, local database, repositories, offline-first behavior, responsive framework, dashboard foundation, navigation, startup, profile, and settings.
- Unified food architecture, search, gram and unit engines, explainable nutrition, quality, deduplication, barcode foundation, meal builder/templates, and offline barcode resolver.
- Explainable intelligence foundation, regression protection, and ledger reconciliation.

## Commerce platform

### Completed

- `BIL-COM-001-R1`: plan and entitlement vocabulary, immutable subscription snapshot, canonical offline Free plan, local entitlement repository, and Riverpod boundaries.
- `BIL-COM-002`: immutable paid-plan catalog for Plus, Pro, Elite, Coach, Clinic, and Enterprise with deterministic inheritance and non-authoritative catalog composition.
- `BIL-COM-003`: subscription lifecycle vocabulary, date-aware deterministic entitlement resolution, provider-neutral Apple/Google/Web contracts, and regression protection for all prior commerce foundations.

### Remaining

- `BIL-COM-004`: trials, grace periods, recovery orchestration, and persistence boundary.
- `BIL-COM-005`: coupon and promotion engine.
- `BIL-COM-006`: referral and affiliate attribution.
- `BIL-COM-007`: regional pricing and country eligibility.
- `BIL-COM-008`: store adapter and receipt-validation contracts.
- `BIL-COM-009`: commerce UI and paywall foundation.
- `BIL-COM-010`: commerce epic quality gate and reconciliation.


## BIL-COM-003-R3 verification correction
The subscription lifecycle package remains in verification. R2 corrects local fallback restoration capability so unverified records cannot advertise restore operations.

## Commerce update — BIL-COM-006
Referral and Affiliate Attribution is implemented as a deterministic offline-first domain and repository boundary. Financial transfers, creator dashboards, payment networking, and server verification remain future work.

## BIL-COM-007 — Regional Pricing and Country Eligibility
Implemented deterministic regional pricing models, country eligibility, billing-country precedence, local currency amounts, provider boundaries, and anti-arbitrage review signals. Next: BIL-COM-008 store provider boundaries and receipt validation contracts.

## BIL-COM-008 — Store Provider Boundaries and Receipt Validation Contracts
Status: Ready for Product Owner application.

Delivered deterministic Apple, Google, and Web provider boundaries; receipt identity models; offline validation-cache policy; server-validation contracts; and regression protection. Real billing, network verification, taxes, and payment execution remain outside this package.

## BIL-COM-009 — Commerce UI and Paywall Foundation
Status: Ready for Product Owner application.

Delivered a commerce-owned, responsive and RTL-safe paywall foundation with immutable localized copy, presentation-safe offer models, deterministic available-offer selection, explicit purchase/restore capability gates, and callback-only transactional handoff. The surface does not grant entitlements, import store SDKs, or modify subscription authority.

Next: `BIL-COM-010` Commerce Epic Quality Gate and Reconciliation.


## BIL-QUALITY-001 — Global analyzer cleanup
- Classified and corrected the 40 analyzer findings blocking BIL-COM-009 verification.
- No lint was disabled; no analyzer ignore comments were introduced.
- Changes are behavior-preserving mechanical cleanup, deprecated API migration, constructor/formal cleanup, dead-code removal after reference inspection, and test cleanup.
- Acceptance requires `flutter analyze` to report `No issues found`.

- BIL-QUALITY-001-R1: analyzer compile-error correction for incomplete private dead-code cleanup — delivered, verification pending.


## BIL-QUALITY-001-R2 — Commerce Paywall UTF-8 Repair

- Classification: Safe Mechanical Cleanup / encoding repair.
- Finding: the full-project mojibake regression test detected a forbidden `â€` sequence in `lib/features/commerce/presentation/commerce_paywall.dart`.
- Resolution: convert malformed Windows-1252/UTF-8 punctuation sequences to intended Unicode punctuation without behavioral changes.
- Required gates: focused mojibake regression, Commerce tests, global analyzer, full project tests, and diff hygiene.
