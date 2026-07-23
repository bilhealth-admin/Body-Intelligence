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
