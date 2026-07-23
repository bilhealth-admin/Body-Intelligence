# BIL Master Roadmap

## Authority

This living roadmap records implementation state after baseline `fa43ba8ca14c119fb4e316db74a99de648137a8d` and package `BIL-COM-002`. Repository code remains authoritative when implementation and older planning documents disagree.

## Completed foundations protected from regression

- Application architecture, local database, repositories, offline-first behavior, responsive shell, dashboard foundation, navigation, startup, profile, and settings.
- Unified food architecture, search, gram and unit engines, explainable nutrition, food quality, deduplication, barcode foundation, meal builder, meal templates, and offline barcode resolution.
- Existing deterministic intelligence foundations already present in `lib/engine`.
- Phase 3 ledger reconciliation and regression protection.

## Commerce platform progress

### Completed

- `BIL-COM-001-R1`: plan identities, entitlement vocabulary, immutable subscription state, canonical offline Free plan, repository boundary, and Riverpod providers.
- `BIL-COM-002`: immutable paid-plan catalog metadata for Plus, Pro, Elite, Coach, Clinic, and Enterprise; explicit inheritance; deterministic entitlement composition; catalog/runtime-authority separation.

### Remaining commerce roadmap

- Subscription lifecycle state model.
- Verified entitlement persistence boundary.
- Store product discovery and regional pricing.
- Server-verified purchase, restore, grace, refund, revocation, and expiration flows.
- Coupon, promotion, referral, affiliate, paywall, and revenue operations.

## Next package

`BIL-COM-003` should define the subscription lifecycle state model without adding store SDKs, remote verification, persistence, or UI.
