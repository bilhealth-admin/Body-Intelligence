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

## BIL-COM-006 state
Completed: referral programs, unique normalized codes, attribution, duplicate/self-attribution prevention, expiry windows, dual-sided rewards, affiliate commission ledger/statuses, refund/cancellation revocation support, audit records, local repository, and future sync contract.

## Commerce state after BIL-COM-007
Regional pricing and country eligibility are implemented locally. Billing country resolves from store country first, then account country; device country is contextual only. No network pricing, tax, payment, or receipt validation is implemented.
