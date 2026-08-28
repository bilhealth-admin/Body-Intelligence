# BIL v1 Epic 13 — Store Billing and Server Entitlements

## Release truth

Free is always available locally. Premium and Premium AI Coach are the only
consumer subscriptions, each offered monthly and annually. Premium AI Coach
inherits Premium. Historical Pro maps to Premium; historical Plus remains a
hidden compatibility identifier and never acquires AI Coach access. Coach,
Clinic, and Enterprise remain contract-only; Elite remains reserved and hidden.

The device store is the sole source for displayed price, currency, billing
period, tax treatment, offers, discounts, savings, and trials. BIL contains no
fallback price, fixed saving, VAT percentage, or invented trial. The requested
seven-day Premium AI Coach trial is displayed only when the store returns that
offer and the current account is eligible. Missing products make the paywall
unavailable without changing user data.

## End-to-end authority

1. The client loads fresh `ProductDetails` and sends the selected transaction
   token/JWS to the authenticated `verify-store-purchase` Edge Function.
2. Google transactions are read from Android Publisher
   `subscriptionsv2`; Apple transactions and Notifications V2 are ES256 JWS
   verified against an owner-supplied Apple root fingerprint.
3. Package/bundle, environment, enabled product registry, lifecycle, and BIL
   owner are checked before `bil_subscriptions` is written.
4. `provider + original_transaction_id` is unique, preventing silent reuse by
   multiple BIL accounts. Notification IDs are idempotent.
5. The client acknowledges/completes only after server verification and then
   re-reads the RLS-protected subscription row. Pending, hold, paused,
   suspended, deferred, expired, refunded, and revoked states do not grant.
6. Reinstall/device changes recover from the server snapshot. Android queries
   completed purchases at startup; Apple sync is invoked only by the explicit
   Restore action. Scheduled reconciliation rechecks both store APIs.
7. Offline or stale authority fails to Free without deleting user data. No
   preference, debug flag, paywall selection, receipt cache, or client response
   can create permanent Premium access.

## OWNER_REQUIRED configuration

No passwords, OTPs, private keys, receipts, or purchase tokens belong in source
control or chat. Supply secrets through Supabase, GitHub, or CI secret stores.

- `BIL_PAYMENTS_ENABLED=true` per platform only after that platform is ready.
- Google package: `BIL_GOOGLE_PACKAGE_NAME` / server
  `GOOGLE_PLAY_PACKAGE_NAME`.
- Apple bundle: `BIL_APPLE_BUNDLE_ID` / server `APPLE_BUNDLE_ID`.
- Premium monthly and annual use the immutable cross-store IDs
  `bil_premium` and `bil_premium_annual`.
- Premium AI Coach monthly and annual use the immutable cross-store IDs
  `bil_premium_ai_coach` and `bil_premium_ai_coach_annual`.
- AI Boost uses the price-neutral immutable ID `bil_ai_boost`. It is available
  to every authenticated tier, does not change tier, and does not unlock
  Barcode for Free.
- The client never manufactures a price, discount, saving, currency, or trial;
  Google Play and App Store metadata remain authoritative.
- Google base plans/offers in Play Console; service-account JSON only in
  `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`.
- Pub/Sub push audience and identity:
  `GOOGLE_PUBSUB_AUDIENCE`, `GOOGLE_PUBSUB_SERVICE_ACCOUNT`; notification URL
  points to the deployed verification function.
- Apple may remain disabled while its external account issue is unresolved.
  Its client path and bundle configuration are retained. When enabled, supply
  the Apple subscription group, App Store Connect issuer/key IDs, ES256 private
  key in `APPLE_PRIVATE_KEY`, and Apple root CA SHA-256 pin in
  `APPLE_ROOT_CA_SHA256`.
- `BIL_STORE_ENVIRONMENT` is explicitly `sandbox` or `production`; never mix.
- Scheduled job calls action `reconcile` with `BIL_RECONCILIATION_SECRET`.
- Publish HTTPS `BIL_TERMS_URL` and `BIL_PRIVACY_URL`; links remain hidden
  until both are valid.
- Populate `bil_store_product_registry` with the exact enabled store products,
  provider, package/bundle, plan, and term. There are no seeded placeholder
  products.

## External gates

- Google Play closed-track purchase, pending payment, grace/hold/pause,
  upgrade/downgrade, refund/revocation, restore, RTDN, acknowledgement.
- Apple Sandbox/TestFlight purchase, Ask to Buy pending, billing retry/grace,
  upgrade/downgrade, refund/revocation, restore, Notifications V2, Server API.
- Two independent BIL accounts prove purchase ownership and RLS isolation.
- Store listing, tax, banking, contracts, Terms, Privacy, age policy, and local
  legal review are owner/external facts and are not claimed by mocks.

## Local coverage

- Plan policy: behavioral domain tests.
- Lifecycle fail-closed matrix: behavioral resolver tests.
- Unconfigured and localized paywall: widget test.
- Client/server acknowledgement, idempotency, RLS, RTDN, Notifications V2,
  reconciliation, and no-local-entitlement boundaries: targeted contracts plus
  the full suite and Android build in the Epic 13 gate.
