# BIL v1 Epic 13 — Store Billing and Server Entitlements

## Release truth

Free is always available locally. Plus and Pro are the only consumer store
subscriptions. Coach, Clinic, and Enterprise remain contract-only and hidden
from consumer purchase flows; Elite remains a reserved hidden identifier.

The device store is the sole source for displayed price, currency, billing
period, tax treatment, offers, and trials. BIL contains no fallback price, VAT
percentage, invented discount, or invented trial. Missing products make the
paywall unavailable without changing user data.

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

- `BIL_PAYMENTS_ENABLED=true` only after both stores are ready.
- Google package: `BIL_GOOGLE_PACKAGE_NAME` / server
  `GOOGLE_PLAY_PACKAGE_NAME`.
- Apple bundle: `BIL_APPLE_BUNDLE_ID` / server `APPLE_BUNDLE_ID`.
- Plus/Pro monthly and annual product IDs:
  `BIL_STORE_PLUS_MONTHLY`, `BIL_STORE_PLUS_ANNUAL`,
  `BIL_STORE_PRO_MONTHLY`, `BIL_STORE_PRO_ANNUAL`.
- Google base plans/offers in Play Console; service-account JSON only in
  `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`.
- Pub/Sub push audience and identity:
  `GOOGLE_PUBSUB_AUDIENCE`, `GOOGLE_PUBSUB_SERVICE_ACCOUNT`; notification URL
  points to the deployed verification function.
- Apple subscription group, App Store Connect issuer/key IDs, ES256 private
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
