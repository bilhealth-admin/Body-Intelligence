# BIL Next Packages

## First next package

### BIL-COM-005 — Coupon and Promotion Engine

**Goal:** Add deterministic, non-authoritative coupon and promotion eligibility, validation, stacking, and expiration rules without store or payment integration.

**Boundaries:**

- No live Apple, Google, Web, or Stripe purchase integration.
- No referral, affiliate, regional pricing, or paywall UI.
- Promotions may influence offer metadata but never directly grant runtime entitlements.

## Planned sequence

- `BIL-COM-006` — Referral and Affiliate Attribution.
- `BIL-COM-007` — Regional Pricing and Country Eligibility.
- `BIL-COM-008` — Store Provider Boundaries and Receipt Validation Contracts.
- `BIL-COM-009` — Commerce UI and Paywall Foundation.
- `BIL-COM-010` — Commerce Epic Quality Gate and Reconciliation.

## Gate before BIL-COM-005

BIL-COM-004 must pass package formatting, focused recovery tests, all commerce tests, package-scoped analyzer, full regression, Android debug build, and diff integrity.
