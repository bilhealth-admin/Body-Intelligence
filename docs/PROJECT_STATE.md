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

## Commerce state after BIL-COM-008
Store purchase orchestration and receipt verification now have provider-neutral contracts. Locally cached validation may grant access only when it represents a fresh, valid server result. Unknown, malformed, stale, expired, refunded, or revoked receipts cannot silently grant paid access.

## BIL-COM-009 current state
The Commerce platform now includes a presentation foundation under `lib/features/commerce/presentation/`. Trusted coordinators can supply regional offers and explicit purchase/restore callbacks. The paywall remains non-authoritative: it cannot mutate `SubscriptionState`, validate receipts, or grant capabilities. English and Arabic copy are commerce-local to preserve team isolation, and the layout adapts between stacked and multi-column plan cards.

Remaining Commerce work: `BIL-COM-010`, the epic-wide quality gate, consistency audit, and living-ledger reconciliation.


## BIL-COM-009-R1B engineering disposition

BIL-COM-009 is engineering-complete within Commerce scope after the `CommercePlan.id` compatibility repair and the correction of all nine Commerce-local analyzer Info findings. Focused Paywall tests passed (6), and the complete Commerce suite passed (64). No analyzer Error or Warning remains attributed to Commerce in the captured run.

The global package gate remains blocked by 40 findings outside Commerce ownership (30 Info and 10 Warning). The gate is not weakened, suppressed, or bypassed. Full ownership classification is recorded in `docs/GLOBAL_ANALYZE_FINDINGS.md`.


## BIL-QUALITY-001 — Global analyzer cleanup
- Classified and corrected the 40 analyzer findings blocking BIL-COM-009 verification.
- No lint was disabled; no analyzer ignore comments were introduced.
- Changes are behavior-preserving mechanical cleanup, deprecated API migration, constructor/formal cleanup, dead-code removal after reference inspection, and test cleanup.
- Acceptance requires `flutter analyze` to report `No issues found`.

## BIL-QUALITY-001-R1
The initial quality cleanup exposed three compile-time analyzer errors because references to two deliberately removed, never-supplied optional parameters remained in widget build methods. R1 completes the dead-code removal without restoring unused API surface. Validation remains pending Product Owner execution.


## BIL-QUALITY-001-R2 — Commerce Paywall UTF-8 Repair

- Classification: Safe Mechanical Cleanup / encoding repair.
- Finding: the full-project mojibake regression test detected a forbidden `â€` sequence in `lib/features/commerce/presentation/commerce_paywall.dart`.
- Resolution: convert malformed Windows-1252/UTF-8 punctuation sequences to intended Unicode punctuation without behavioral changes.
- Required gates: focused mojibake regression, Commerce tests, global analyzer, full project tests, and diff hygiene.
