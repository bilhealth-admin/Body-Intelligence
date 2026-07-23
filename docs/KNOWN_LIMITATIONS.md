# BIL Known Limitations

## Commerce limitations after BIL-COM-001-R1

- Only the Free plan has an active entitlement definition.
- Paid plan enum values are identifiers only; they do not grant capabilities.
- No product catalog, price, currency, region, trial, discount, or billing-period model exists.
- No store SDK, purchase flow, receipt validation, restore flow, server verification, or entitlement synchronization exists.
- No subscription persistence or lifecycle events exist.
- No paywall, account subscription screen, or revenue dashboard exists.
- Commerce remains unavailable through the baseline external-capability policy.

## Safety limitation

`EntitlementAuthority.verifiedServer` is reserved vocabulary only in this package. No implementation may claim verified authority until a later package provides an authenticated and tested verification path.

## Operational limitation

The package includes executable verification commands, but their results are not claimed in advance. The Product Owner must run the supplied gates after applying the package.
