# BIL Known Limitations

## Commerce limitations after BIL-COM-003

- No Apple Billing, Google Play Billing, Stripe, or Web checkout integration exists.
- No receipt validation, server verification, purchase execution, restore orchestration, or subscription persistence exists.
- Provider contracts expose future boundaries only and have no concrete implementation.
- `authorityVerified` is an input contract; this package does not produce or validate verification evidence.
- No coupon, promotion, referral, affiliate, regional pricing, country eligibility, paywall, or revenue dashboard exists.
- Commerce activation remains unavailable through the external-capability policy.

## Lifecycle limitations

- Missing required date boundaries produce Free fallback rather than optimistic access.
- Cancelled subscriptions retain paid access only through a valid current-period end.
- Paused subscriptions do not retain paid access in this package.
- Date normalization is UTC-based; future adapters own conversion from provider timestamps.

## Product-definition limitation

Elite still inherits Pro without an Elite-only entitlement. No capability semantics were invented.

## Operational limitation

Verification results are not claimed in advance. The Product Owner must run the supplied gates after applying the package.


## BIL-COM-003-R3
Real store restoration remains intentionally unimplemented. The domain only exposes restore eligibility for verified provider-backed records.

## BIL-COM-006 limitations
No financial payout, creator dashboard, payment processing, network verification, fraud scoring, tax handling, or cloud persistence is implemented. Paid commissions are intentionally immutable locally; payout correction requires future server reconciliation.

## BIL-COM-007 limitations
No live Apple, Google, or Web pricing; no taxes; no server country verification; no final paywall. The local repository contains deterministic policy data only.

## BIL-COM-008 limitations
- No Apple StoreKit integration.
- No Google Play Billing integration.
- No Web/Stripe integration.
- No remote receipt validation or server signature verification.
- No tax calculation or payment settlement.
- Cached validation storage is an in-memory boundary until the persistence/cloud teams provide an approved durable implementation.

## BIL-COM-009 limitations
- The paywall is not routed from Dashboard, Navigation, Startup, Profile, or Premium surfaces because those files are outside Commerce Team ownership.
- No live StoreKit, Google Play Billing, or Web checkout adapter is connected.
- Offer construction, tax-inclusive display, legal copy, provider product identifiers, and remote experimentation remain integration responsibilities.
- Commerce-local English and Arabic copy is intentionally isolated; shared localization integration requires the Global Product team.
- Purchase and restore callbacks express intent only and cannot grant access.


## BIL-COM-009-R1B global analyzer blocker

- The global analyzer reported 49 findings: 39 Info, 10 Warning, and 0 Error.
- Nine Commerce-local Info findings are corrected by BIL-COM-009-R1B.
- Forty findings remain outside Commerce ownership: 30 Info and 10 Warning.
- The unchanged global quality gate therefore remains externally blocked until the responsible teams resolve the inventory recorded in `docs/GLOBAL_ANALYZE_FINDINGS.md`.
- Commerce focused tests and the complete Commerce test suite passed before this documentation correction; no waiver or analyzer suppression is introduced.


## BIL-QUALITY-001 — Global analyzer cleanup
- Classified and corrected the 40 analyzer findings blocking BIL-COM-009 verification.
- No lint was disabled; no analyzer ignore comments were introduced.
- Changes are behavior-preserving mechanical cleanup, deprecated API migration, constructor/formal cleanup, dead-code removal after reference inspection, and test cleanup.
- Acceptance requires `flutter analyze` to report `No issues found`.

## BIL-QUALITY-001-R1
No known functional limitation is introduced. The removed `_SetupTile.unit` and `_PrimaryButton.busy` paths were private and had no call sites in the authoritative baseline. Full verification must still be run in the Product Owner Flutter environment.


## BIL-QUALITY-001-R2 — Commerce Paywall UTF-8 Repair

- Classification: Safe Mechanical Cleanup / encoding repair.
- Finding: the full-project mojibake regression test detected a forbidden `â€` sequence in `lib/features/commerce/presentation/commerce_paywall.dart`.
- Resolution: convert malformed Windows-1252/UTF-8 punctuation sequences to intended Unicode punctuation without behavioral changes.
- Required gates: focused mojibake regression, Commerce tests, global analyzer, full project tests, and diff hygiene.
