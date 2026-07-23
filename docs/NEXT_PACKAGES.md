# BIL Next Packages

## First next package

### BIL-COM-003 — Subscription lifecycle state model

**Goal:** Define immutable lifecycle vocabulary and transition rules for inactive, trial, active, grace, paused, expired, revoked, and refunded states without enabling purchases or claiming remote verification.

**Expected boundaries:**

- Domain-only lifecycle models and transition validation.
- No store SDK, price, receipt, network, persistence, account UI, or entitlement activation.
- Focused lifecycle tests and Free/catalog regression tests.

## Later packages

- BIL-COM-004: verified entitlement persistence boundary.
- BIL-COM-005: store-product and regional-pricing abstractions.
- BIL-COM-006: restore, grace, expiration, refund, and revocation orchestration.
- BIL-COM-007+: promotions, coupons, referrals, affiliates, paywalls, and revenue operations.
