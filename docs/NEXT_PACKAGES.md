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
