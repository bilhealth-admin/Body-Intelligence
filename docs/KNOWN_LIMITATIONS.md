# BIL Known Limitations

## Commerce limitations after BIL-COM-002

- Paid-plan catalog entries are descriptive metadata only and do not grant access.
- No product identifiers, prices, currencies, regions, billing periods, trials, discounts, or tax models exist.
- No subscription lifecycle state or transition model exists yet.
- No store SDK, purchase flow, receipt validation, restore flow, server verification, entitlement synchronization, or persistence exists.
- No paywall, account subscription screen, or revenue dashboard exists.
- Commerce remains unavailable through the external-capability policy.

## Product-definition limitation

Elite currently inherits the Pro catalog capabilities without an Elite-only entitlement. Introducing one requires an explicit product decision and coordination with the owning product team; this package does not invent capability semantics.

## Safety limitation

`PaidPlanCatalog.composedEntitlementsFor` is not an authorization API. Runtime access must continue to come from a trusted `SubscriptionState` supplied through `EntitlementRepository`.

## Operational limitation

Verification commands are provided but results are not claimed in advance. The Product Owner must run all supplied gates after application.
