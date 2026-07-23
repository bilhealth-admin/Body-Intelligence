# BIL Next Packages

## First next package

### BIL-COM-002 — Paid plan catalog foundation

**Goal:** Define immutable metadata and entitlement composition for Plus, Pro, Elite, Coach, Clinic, and Enterprise without enabling purchase or granting unverified paid access.

**Expected boundaries:**

- Domain-only catalog models.
- Explicit inheritance/composition rules with no duplicate entitlement logic.
- Focused tests for catalog completeness, uniqueness, and Free-plan non-regression.
- No prices, regional products, store SDKs, receipts, account state, paywall UI, or remote activation.

## Later packages

- BIL-COM-003: subscription lifecycle state model.
- BIL-COM-004: verified entitlement persistence boundary.
- BIL-COM-005: store-product and regional-pricing abstractions.
- BIL-COM-006: restore, grace, expiration, refund, and revocation rules.
- BIL-COM-007+: promotions, coupons, referrals, affiliates, paywall surfaces, and revenue operations.

Each package must be re-frozen against the newest Product Owner baseline before implementation.
