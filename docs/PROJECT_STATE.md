# BIL Project State

## Baseline

- Branch: `phase-3-product-excellence`
- Parent HEAD: `1867640`
- Package: `BIL-COM-001-R1`
- Package state: ready for Product Owner application and verification.

## Current implemented reality

The baseline already contains substantial product, nutrition, offline, database, dashboard, and deterministic intelligence foundations. Commerce activation is explicitly unavailable in the baseline external-capability policy.

This package establishes only the internal commerce access boundary. It does not add billing, network calls, paywalls, prices, receipts, or store SDKs.

## Added production capabilities

- `CommercePlan`: stable commercial plan identities.
- `CommerceEntitlement`: capability-level access vocabulary.
- `SubscriptionState`: immutable access snapshot with authority metadata.
- `FreePlan`: deterministic local Free-plan state.
- `EntitlementRepository`: replaceable access-source contract.
- `LocalEntitlementRepository`: safe offline default implementation.
- Riverpod providers for consumers to read current subscription state.

## Verification assets

- Focused unit tests for the Free plan and immutable entitlement snapshot.
- Regression tests for provider replacement, external commerce unavailability, and local-authority safety.
- PowerShell preflight and verification scripts.

## Technical debt

No intentional technical debt is introduced. Paid catalogs, persistence, server verification, and store integration are deliberately outside this frozen package rather than stubbed.

## Known risks

- Future teams could incorrectly treat plan identifiers as proof of entitlement. Consumers must use `SubscriptionState.grants` and respect `EntitlementAuthority`.
- A future remote adapter must never accept client-only flags as authoritative purchase verification.
- Entitlement naming changes become cross-team API changes once consumed by product surfaces.

## Cross-team dependencies

- Cloud Team: authenticated server authority and synchronized verified state.
- Global Launch Team: Apple/Google/Microsoft/Web store adapters and platform policy compliance.
- Premium Team: paywalls and entitlement-gated surfaces.
- AI, Coach, Clinic, and Enterprise teams: capability definitions only; no direct billing authority.
