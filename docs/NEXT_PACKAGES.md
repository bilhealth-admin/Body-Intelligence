# BIL Next Packages

## Authoritative baseline

- Branch: `phase-3-product-excellence`
- HEAD: `9fe26c3ceddf6e1d1de6bcb04344da043f3bb338`

## Current authorization state

The Product Owner has authorized the post-program phase
`BIL V1 Global Launch Readiness`. Its accepted parent is
`9fe26c3ceddf6e1d1de6bcb04344da043f3bb338`. Architecture, Dashboard,
Trusted Truth, Premium UI, and cross-program closure gates remain closed and
must not be listed as future work.

## Authorized package sequence

1. `BIL-V1-LAUNCH-001` — phase boundary and repository audit.
2. `BIL-V1-LAUNCH-002` — Android release identity, permissions, and signing
   boundary.
3. `BIL-V1-LAUNCH-003` — Apple repository preparation and privacy-manifest
   boundary.
4. `BIL-V1-LAUNCH-004` — privacy, Data Safety, health declarations, and store
   evidence consistency.
5. `BIL-V1-LAUNCH-005` — release-candidate build and non-regression gate.
6. `BIL-V1-LAUNCH-006` — repository closure with external launch gates.

Every package must declare its accepted parent HEAD, bounded repository scope,
external exclusions, deterministic APPLY and VERIFY scripts, selective commit
targets, and approval checkpoint.

Historical package candidates are records only. They are not authorization and
must not be replayed against the current baseline.
