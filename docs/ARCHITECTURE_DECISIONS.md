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

## ADR-COM-006 — Attribution before networking
Referral attribution and commission calculation are pure deterministic domain operations behind repositories. Cloud verification is represented only by an interface so offline behavior remains testable and payment/network concerns cannot leak into the domain.

## ADR-COM-007 — Billing-country authority
Store country is authoritative when present, account country is the offline fallback, and device country never grants pricing eligibility by itself. Country mismatches produce a review signal rather than silently changing eligibility. Monetary values use integer minor units and explicit fraction digits.

### ADR-COM-008 — Server authority with bounded offline continuity
Store receipts are opaque provider evidence and never directly grant entitlements. A server validation contract is the future authority. Offline access may rely only on a previously accepted validation result within a bounded freshness window. Store SDKs remain behind provider contracts so Apple, Google, and Web integrations cannot leak into domain or UI logic.

### ADR-COM-009 — Paywall presentation is non-authoritative
**Status:** Accepted in `BIL-COM-009`.

The paywall renders immutable offer metadata supplied by a trusted commerce coordinator and emits purchase/restore intent only through explicit callbacks. It never changes subscription state or grants entitlements. Transaction buttons are disabled unless corresponding provider capability is explicitly available. Localized copy remains inside the Commerce feature until Global Product owns an approved shared localization integration.


## BIL-QUALITY-001 — Global analyzer cleanup
- Classified and corrected the 40 analyzer findings blocking BIL-COM-009 verification.
- No lint was disabled; no analyzer ignore comments were introduced.
- Changes are behavior-preserving mechanical cleanup, deprecated API migration, constructor/formal cleanup, dead-code removal after reference inspection, and test cleanup.
- Acceptance requires `flutter analyze` to report `No issues found`.

## ADR — Complete removal of unused private optional widget state
Because `_SetupTile.unit` and `_PrimaryButton.busy` were private implementation details with no baseline call sites, R1 completes their removal rather than restoring unused fields solely to compile. This preserves observed behavior and avoids retaining dead API surface.


## BIL-QUALITY-001-R2 — Commerce Paywall UTF-8 Repair

- Classification: Safe Mechanical Cleanup / encoding repair.
- Finding: the full-project mojibake regression test detected a forbidden `â€` sequence in `lib/features/commerce/presentation/commerce_paywall.dart`.
- Resolution: convert malformed Windows-1252/UTF-8 punctuation sequences to intended Unicode punctuation without behavioral changes.
- Required gates: focused mojibake regression, Commerce tests, global analyzer, full project tests, and diff hygiene.
