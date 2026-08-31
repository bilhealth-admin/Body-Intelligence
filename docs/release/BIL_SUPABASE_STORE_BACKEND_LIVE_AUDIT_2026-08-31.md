# BIL Supabase store backend live audit — 2026-08-31

## Result

The deployed purchase verifier is active and fail-closed, and its six runtime
files match the current repository source. Apple App Store Server
Notifications V2 points to the exact production endpoint for both production
and sandbox. One critical data-config omission was fixed: the provider-scoped
store registry now contains the four canonical Apple subscription rows, so a
valid Apple subscription can reach the existing persistence RPC instead of
failing `product_not_enabled`.

The backend is not yet fully launch-proven. No Apple or Google notification has
ever reached the notification inbox, the Google Pub/Sub resources cannot be
read by either existing Android Publisher credential, and no store
reconciliation cron job exists.

## Live facts checked

- The current Supabase changelog and Edge Function authorization guidance were
  reviewed before live calls. The documented pattern for external webhooks is
  `verify_jwt=false` plus authentication inside the handler, which matches the
  deployed BIL design. No current changelog item requires a runtime migration
  for this function.
- Supabase project status: healthy.
- Edge Function `verify-store-purchase`: `ACTIVE`, version 18,
  `verify_jwt=false`. This is required because Apple and Pub/Sub cannot supply
  a Supabase user JWT; the handler performs its own authentication.
- Live deployment contents match the repository runtime files. No Edge
  Function deployment was made in this audit.
- Missing user authorization returns `401 authentication_required`; an invalid
  bearer returns `401 invalid_session`.
- A request without the reconciliation secret returns
  `reconciliation_forbidden`; a Pub/Sub-shaped request without Google OIDC
  returns `invalid_pubsub_identity`.
- The notification inbox, claim RPC, subscriptions and entitlements exist.
  Commerce RLS is enabled. `anon` and `authenticated` have no inbox table
  privileges and cannot execute the claim RPC.
- The notification inbox currently has zero rows. Therefore RTDN and Apple V2
  delivery are configured in code but not proven end to end.
- Current subscription aggregates contain prior Google verification evidence,
  but no Apple subscription row.
- The country policy resolves 172 sale markets: 4 Premium and 168 Premium + AI
  Coach. Alpha-2 and Apple alpha-3 storefront samples resolve to the same plan.
- App Store Connect live GET confirms the exact function URL for production
  and sandbox, both V2.
- Both existing Google credentials can obtain OAuth tokens, but both receive
  HTTP 403 when listing Pub/Sub topics and subscriptions. Android Publisher
  access does not prove Cloud Pub/Sub access.
- `pg_cron` is installed, but the only active job is the account-deletion job.
  There is no store reconciliation job and no matching reconciliation secret
  name in Vault.

## Safe correction applied

Migration
`supabase/migrations/20260831024716_register_apple_store_products.sql` was
applied live as `register_apple_store_products`. It inserts or reconciles only
these provider-scoped Apple rows:

- `bil_premium` — Premium monthly
- `bil_premium_annual` — Premium annual
- `bil_premium_ai_coach` — Premium + AI Coach monthly
- `bil_premium_ai_coach_annual` — Premium + AI Coach annual

All use bundle ID `com.bilhealth.bodyintelligencelog`. The four Google rows
were left unchanged. `bil_ai_boost` remains outside the subscription registry
because it uses the dedicated idempotent consumable-credit flow.

## External owner/UI blockers

1. In Google Cloud Pub/Sub, verify the RTDN topic and grant
   `google-play-developer-notifications@system.gserviceaccount.com` Publisher
   on that topic.
2. Verify the push subscription targets the exact Edge Function URL, uses an
   authenticated OIDC service account, and sets the audience to the exact same
   URL. The current Android Publisher credentials cannot inspect these Cloud
   resources (HTTP 403), so use a Cloud principal with read-only Pub/Sub/IAM
   access rather than creating another key.
3. In Google Play Console, Monetize setup / real-time developer notifications,
   select the topic for subscriptions and one-time products and send Google's
   test notification. Completion evidence is one Google inbox row with status
   `processed`.
4. In Supabase Edge Function secrets, confirm the presence of the required
   names without revealing values: `GOOGLE_PLAY_PACKAGE_NAME`, one of
   `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` or
   `BIL_PLAY_INTEGRITY_SERVICE_ACCOUNT_JSON`, `GOOGLE_PUBSUB_AUDIENCE`,
   `GOOGLE_PUBSUB_SERVICE_ACCOUNT`, `APPLE_BUNDLE_ID`, `APPLE_ISSUER_ID`,
   `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, `APPLE_ROOT_CA_SHA256`, and
   `BIL_RECONCILIATION_SECRET`. Managed Supabase URL/anon/service-role values
   are demonstrably present because the invalid-session probe reached Auth.
5. Request a real Apple Server Notifications V2 test notification. Completion
   evidence is one Apple inbox row with status `processed`. No synthetic
   transaction or purchase is required.
6. Schedule `action=reconcile` using the existing
   `BIL_RECONCILIATION_SECRET`. Store the same value in a protected scheduler
   or Vault reference; never place it inline in SQL or source. There is no live
   reconciliation job today.

## Follow-up safety decision: no secret or cron mutation

The current Supabase connector can inspect projects, functions, logs and SQL,
but it has no Edge Secrets list/set operation. Supabase CLI is not installed,
there is no Supabase management token in the process environment, and the
local Supabase config contains telemetry only. Consequently this audit cannot
prove whether the Edge secret name `BIL_RECONCILIATION_SECRET` exists; the
unauthorized endpoint response is intentionally indistinguishable for missing
and mismatched secrets.

No secret or cron was created. Edge Secrets and Postgres Vault are separate
systems, so setting the same generated value in both cannot be made atomic
with the current connector. Passing the value through the raw SQL tool would
also place it in tool arguments, violating the no-disclosure boundary. A safe
future operation requires both a Supabase Management API credential that can
list/set Edge secret names and a parameterized database connection. It must:

1. prove the Edge name, Vault name and cron job are all absent;
2. generate a cryptographically random value only in process memory;
3. set the Edge secret;
4. in one database transaction, store the same value in Vault and create the
   `pg_cron` + `pg_net` job that reads only from `vault.decrypted_secrets`;
5. verify the job and compensate by deleting only the newly created Edge
   secret if the database transaction fails.

Because no two-system transaction can guarantee that compensation succeeds,
the owner must approve the maintenance window and recovery plan before that
operation. The existing secret must never be rotated merely to make setup
easier.

## Apple test-notification key result

Apple's official `Request a Test Notification` endpoint is safe and creates no
purchase, but it requires an **In-App Purchase key** from App Store Connect
Users and Access / Integrations / In-App Purchase. The two current generic
App Store Connect keys are fully accounted for by App Manager and Developer
metadata; no In-App Purchase key metadata or unaccounted generic key file is
present. The App Manager catalogue key is not an In-App Purchase key.

Therefore no Apple test notification was sent. The Account Holder or Admin
must generate/download an In-App Purchase key, store it securely, and then use
it to call the production and sandbox test endpoints and poll each returned
test token. The test is complete only when Apple's status reports success and
the Supabase Apple inbox row is `processed`.

## Evidence and boundaries

- Redacted machine summary:
  `artifacts/release/supabase/2026-08-31-store-backend-audit/redacted-summary.json`
- Live Apple GET artifact:
  `artifacts/release/supabase/2026-08-31-store-backend-audit/apple-v1-live.json`
- Pub/Sub audit utility:
  `tool/google_play/google_pubsub_readiness_audit.mjs`

No secret was printed, copied, rotated or created. No fake purchase was sent.
No schema, entitlement, subscription, notification, price, release or store
submission was changed. No Flutter command or test/build workflow was run.
