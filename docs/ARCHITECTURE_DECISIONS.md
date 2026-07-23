# BIL Architecture Decisions

## ADR-COM-001 — Separate plans, entitlements, and billing authority

**Status:** Accepted in `BIL-COM-001-R1`.

**Decision:** Represent commercial identity (`CommercePlan`), product capability (`CommerceEntitlement`), and the source of trust (`EntitlementAuthority`) as separate concepts.

**Why:** A plan label is not proof of purchase, and a store product is not the same as a product capability. Separation prevents UI, local configuration, or cached plan names from becoming accidental authorization.

**Consequences:**

- Product surfaces consume entitlement checks rather than plan-name comparisons.
- Future billing adapters must produce a verified `SubscriptionState` through the repository boundary.
- Adding or removing entitlement vocabulary requires coordinated review with consuming teams.

## ADR-COM-002 — Ship a deterministic offline Free plan

**Status:** Accepted in `BIL-COM-001-R1`.

**Decision:** The application always has a locally available Free-plan snapshot granting the established offline foundation.

**Why:** BIL is privacy-first and offline-first. Core local tracking must remain usable without account creation, connectivity, store availability, or successful purchase restoration.

**Consequences:**

- Startup does not depend on commerce infrastructure.
- Local default authority cannot advertise purchase or restore capability.
- Paid capability activation remains unavailable until a verified adapter exists.

## ADR-COM-003 — Use a replaceable repository boundary

**Status:** Accepted in `BIL-COM-001-R1`.

**Decision:** Consumers obtain subscription state from `EntitlementRepository`, exposed through Riverpod providers.

**Why:** This isolates current local behavior from future verified server/store adapters and allows tests to replace the authority without changing consumers.

**Consequences:**

- No store SDK dependency enters the domain layer.
- Future persistence or streaming behavior can be introduced behind the repository contract in a later package.
