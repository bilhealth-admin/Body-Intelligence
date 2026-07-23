# BIL Architecture Decisions

## ADR-COM-001 — Separate plans, entitlements, and authority

**Status:** Accepted in `BIL-COM-001-R1`.

Plan identity, capability entitlement, and trust authority remain separate. Runtime surfaces authorize through entitlements, never plan labels.

## ADR-COM-002 — Preserve a deterministic offline Free plan

**Status:** Accepted in `BIL-COM-001-R1`.

Core local tracking remains available without account, network, store, or restoration.

## ADR-COM-003 — Use replaceable repository and Riverpod boundaries

**Status:** Accepted in `BIL-COM-001-R1`.

Commerce authority remains replaceable without changing consumers.

## ADR-COM-004 — Keep the paid catalog non-authoritative

**Status:** Accepted in `BIL-COM-002`.

Catalog composition describes product structure and never proves access.

## ADR-COM-005 — Compose paid capabilities through inheritance

**Status:** Accepted in `BIL-COM-002`.

Paid plans inherit lower-tier capabilities without copied entitlement lists.

## ADR-COM-006 — Resolve runtime access from lifecycle plus verified facts

**Status:** Accepted in `BIL-COM-003`.

**Decision:** Runtime access is resolved from an immutable `SubscriptionRecord`, explicit lifecycle, verified authority, and UTC date boundaries.

**Why:** A paid plan name, cached store value, or lifecycle label is insufficient proof. Date-aware resolution creates one deterministic authorization path that works offline from previously verified facts.

**Consequences:**

- Trial access requires a non-expired trial boundary.
- Active and cancelled access require a non-expired current-period boundary.
- Grace access requires a non-expired grace boundary.
- Inactive, paused, expired, refunded, revoked, unverified, and invalid-window records fall back to Free.

## ADR-COM-007 — Keep provider contracts SDK-neutral

**Status:** Accepted in `BIL-COM-003`.

**Decision:** Apple, Google, and Web are represented by a provider enum and abstract contract only.

**Why:** Domain and entitlement logic must not depend on store SDKs, networking, credentials, or platform-specific receipt formats.

**Consequences:**

- Real adapters and receipt validation remain deferred.
- Provider implementations must return verified neutral records.
- No secret or store dependency is introduced by this package.


## ADR: Restore capability requires verified commerce authority
A provider identifier alone is not sufficient to expose restore behavior. `canRestorePurchases` is true only when commerce authority is verified and a provider is present. This preserves the local-default invariant and prevents unverified records from advertising transactional capability.

## ADR-COM-008 — Cache verified facts, never inferred authority

**Status:** Accepted in `BIL-COM-004`.

Only provider-verified `SubscriptionRecord` values may be wrapped in a persisted `SubscriptionSnapshot`. Corrupt and unverified cache is discarded. Persistence does not create or upgrade authority.

## ADR-COM-009 — Make offline freshness an injected policy

**Status:** Accepted in `BIL-COM-004`.

The maximum age of offline subscription authority is supplied through `SubscriptionRecoveryPolicy`. The recovery engine contains no hidden commercial duration. Stale data fails closed to Free and requests provider refresh.

## ADR-COM-010 — Separate access resolution from recovery orchestration

**Status:** Accepted in `BIL-COM-004`.

`EntitlementResolver` remains the single access decision path. `SubscriptionRecoveryEngine` only validates cache freshness, invokes that resolver, and returns explicit refresh/restore/discard actions.


## ADR-COM-011 — Promotions influence offers, never entitlement authority

**Status:** Accepted in `BIL-COM-005`.

Coupon evaluation returns discount/free-duration metadata and a candidate redemption. It cannot create a subscription, perform payment, or grant runtime entitlements. Subscription authority remains exclusively behind verified subscription records and `EntitlementResolver`.

## ADR-COM-012 — Use integer commercial units

**Status:** Accepted in `BIL-COM-005`.

Percentage discounts and commissions use basis points, fixed discounts use minor currency units, and free duration uses whole days. This avoids floating-point drift and keeps local/server reconciliation deterministic.

## ADR-COM-013 — Separate evaluation from redemption recording

**Status:** Accepted in `BIL-COM-005`.

The engine is side-effect free. A successful decision contains a candidate `CouponRedemption`; the caller records it only after a future authoritative purchase flow succeeds. This prevents failed or abandoned checkouts from consuming usage limits.
