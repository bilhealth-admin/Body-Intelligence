# BIL Master Roadmap

## Authority

This living roadmap records the implementation state after baseline `1867640` and package `BIL-COM-001-R1`. The repository code is authoritative when implementation and older planning documents disagree.

## Completed foundations protected from regression

- Application architecture, local database, repositories, offline-first behavior, responsive shell, dashboard foundation, navigation, startup, profile, and settings.
- Unified food architecture, search, gram and unit engines, explainable nutrition, food quality, deduplication, barcode foundation, meal builder, meal templates, and offline barcode resolution.
- Existing deterministic intelligence foundations already present in `lib/engine`, including cautious Body Twin, Data Honesty, Personal Baseline, What Changed, One Best Action, Recovery, Weekly Review, and Decision Memory persistence.
- Phase 3 ledger reconciliation and existing regression protection.

## Active program sequence

1. AI & Intelligence Platform.
2. Commerce & Subscription Platform.
3. Cloud & Synchronization Platform.
4. Premium Experience Platform.
5. Coach Platform.
6. Clinic Platform.
7. Enterprise Platform.
8. Global Launch.
9. Version 1.0 release hardening.
10. Post-launch ecosystem.

## Commerce platform progress

### Completed by BIL-COM-001-R1

- Stable plan identifiers for Free, Plus, Pro, Elite, Clinic, Coach, and Enterprise.
- Stable entitlement vocabulary separated from billing and store availability.
- Immutable `SubscriptionState` with explicit entitlement authority.
- Canonical offline-first Free plan.
- Replaceable entitlement repository boundary and Riverpod providers.
- Safety rule preventing a local default state from advertising purchase or restore capability.

### Remaining commerce roadmap

- Paid-plan entitlement catalogs and product rules.
- Store product discovery and regional pricing.
- Server-verified purchases, receipts, restore, grace, refund, revocation, and expiration flows.
- Coupon, promotion, referral, and affiliate engines.
- Paywall and account-facing subscription experience.
- Revenue and operational reporting.

## Next package

`BIL-COM-002` should define paid-plan catalog metadata and entitlement composition without activating billing, store products, or unverified access.
