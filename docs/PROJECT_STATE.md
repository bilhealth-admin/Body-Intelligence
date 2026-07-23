# BIL Project State

## Baseline and package

- Branch: `phase-3-product-excellence`
- Parent HEAD: `4f4f541fa66307fdcabc7ad7e38047130d795371`
- Package: `BIL-COM-003`
- Frozen scope: subscription lifecycle and entitlement resolution.

## Current implemented reality after application

Commerce Foundation remains intact. The project now additionally contains a provider-neutral lifecycle model for inactive, trial, active, grace period, paused, expired, cancelled, refunded, and revoked subscriptions.

`EntitlementResolver` deterministically resolves runtime access from plan, lifecycle, verified authority, provider identity, and UTC date boundaries. A paid plan label alone never grants access. Unverified, terminal, paused, missing-boundary, or out-of-window records fall back to the canonical Free plan.

Apple, Google, and Web are represented only as future provider contracts. No store SDK, network purchase, receipt validation, secret, or cloud dependency is introduced.

## Verification assets

- Focused lifecycle and boundary tests.
- Regression tests for Free Plan, Paid Plan Catalog, Local Entitlement Repository, Commerce Providers, and entitlement-based consumer authorization.
- Package verification covers formatting, focused tests, all commerce tests, analyzer, full tests, Android debug build, and changed-file integrity.

## Technical debt

No intentional technical debt is introduced. Provider verification and persistence are deliberately deferred to later packages rather than simulated locally.

## Known risks

- Provider adapters must never mark records verified before trusted validation.
- Date values must be normalized to UTC at adapter boundaries.
- UI consumers must call `grants` and must not branch on plan names or lifecycle labels.

## Cross-team dependencies

- Cloud Team: future authoritative synchronization and verification transport.
- Global Launch Team: Apple/Google store SDK adapters.
- Premium Team: paywall and subscription-management UI.
- AI, Coach, Clinic, and Enterprise teams: capability implementations consumed through entitlements.


## Current verification correction
BIL-COM-003-R3 fixes the entitlement fallback invariant discovered by focused tests: unverified records resolve to Free with restore disabled.

## BIL-COM-004 — Trials, Grace Periods and Subscription Recovery

The commerce domain now persists only previously verified subscription facts through a platform-neutral key/value boundary. `SubscriptionRecoveryEngine` restores valid cached active, trial, grace-period, and cancelled access deterministically while offline. Missing, stale, terminal, corrupt, invalid, or expired cache fails closed to the canonical Free plan and emits an explicit provider follow-up action.

The maximum offline authority age is an injected policy rather than a hidden product constant. No Apple, Google, Web, cloud, network, credential, or store SDK implementation is included.


## BIL-COM-005 — Coupon and Promotion Engine

The commerce domain now contains deterministic coupon definitions, integer-safe benefit models, subscription-term eligibility, local usage ledgers, stacking rules, and promotion evaluation. Coupon evaluation produces offer metadata and a candidate redemption only; it never performs payment, records usage automatically, or grants runtime entitlements.

Celebrity, blogger, affiliate, partner, and campaign attribution are represented as neutral metadata. Commission basis points are recorded for future settlement, but no transfer, payout, dashboard, server, cloud, or store integration is introduced.

### Verification assets

- Focused percentage, fixed-amount, free-duration, eligibility, stacking, and usage-limit tests.
- Regression tests proving promotions cannot alter Free Plan or entitlement authority.
- Package-scoped analyzer, all commerce tests, full regression, Android debug build, and diff integrity gates.

### Next stage

`BIL-COM-006 — Referral and Affiliate Attribution`.
