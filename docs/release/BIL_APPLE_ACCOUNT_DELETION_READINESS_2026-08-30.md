# BIL Apple account-deletion readiness — 2026-08-30

## Implemented in source

- The primary in-app deletion screen warns that deleting BIL does not cancel
  Apple or Google billing and links iOS users directly to
  `https://apps.apple.com/account/subscriptions` before submission.
- An authenticated request is stored first. The app then asks the
  `account-data-deletion` Edge Function to process it immediately; an
  unavailable immediate call leaves the durable request pending for the
  scheduled retry worker.
- The worker recursively lists the signed-in user's UUID prefix in
  `profile-avatars` and `community-post-images`, deletes those objects through
  the Supabase Storage API, then verifies every prefix is empty. It cannot call
  `auth.admin.deleteUser` unless that verification succeeds.
- Storage or Auth failure returns the request to `pending` with a sanitized
  failure code. Interrupted `processing` claims become retryable after 15
  minutes. The superseded database-only deletion worker raises an exception.

## Required production configuration

Production safety state on 30 August 2026: the unsafe SQL-only cron worker was
unscheduled and its function was replaced by a fail-closed guard through remote
migration `20260830034302_disable_unsafe_account_deletion_cron`. New requests
remain `pending`; no path can delete `auth.users` before Storage cleanup. This
is a safety closure, not completion of the deletion service.

Deploy migration `20260830093000_account_deletion_storage_cleanup.sql`, deploy
the canonical `account-data-deletion` Edge Function, and configure these secret
values without committing them:

1. Edge Function secret `BIL_INTERNAL_DELETION_SECRET`.
2. Vault `bil_account_deletion_worker_url` pointing to the canonical function.
3. Vault `bil_internal_deletion_secret` with the same secret value.
4. Vault `bil_supabase_anon_key` for the platform JWT gate.

Then exercise a non-production account that owns nested objects in both
buckets and prove: objects disappear, Auth sign-in fails, user-owned database
rows cascade, the app clears its local session, and a forced Storage failure
leaves Auth intact with the deletion request pending.

## Sign in with Apple revocation lifecycle added for +8

The +8 source now follows the server-token sequence in Apple TN3194:

1. Native sign-in sends the short-lived authorization code, identity token,
   raw nonce, and Apple subject over the authenticated Supabase Function
   channel immediately after Supabase accepts the ID token.
2. `apple-sign-in-token` independently verifies the Apple JWT issuer,
   audience, signature, nonce, subject, and current Supabase Apple identity.
   It validates the single-use authorization code at Apple's `/auth/token`
   endpoint.
3. Only the returned refresh token is retained, encrypted using AES-256-GCM
   with owner and Apple client ID as authenticated additional data. The
   provider token and raw Apple subject are unavailable to app clients; only a
   SHA-256 subject index is stored for signed server notifications.
4. `account-data-deletion` calls Apple's `/auth/revoke` with the refresh token
   before Storage and Auth deletion. Provider failure returns the durable
   deletion request to `pending` without deleting the encrypted token, so the
   worker can retry safely.
5. `apple-sign-in-notifications` verifies Apple's signed server-to-server JWS.
   `consent-revoked` and `account-deleted` events idempotently queue account
   deletion and remove the now-invalid token; email-relay events are
   acknowledged because BIL does not use the relay address for messaging.

Accounts created before this lifecycle was deployed may have no stored Apple
refresh token. Those legacy rows continue through BIL deletion and receive the
manual confirmation route required by TN3194:
`Settings > [your name] > Sign in with Apple > BIL > Delete or Stop Using`.
The screen links to Apple's instructions at `https://support.apple.com/102571`.
The fallback does not block or undo a completed BIL deletion.

### +8 production gates

- Apply `20260905143000_apple_sign_in_token_lifecycle.sql`.
- Set `BIL_APPLE_SIGN_IN_TEAM_ID`, `BIL_APPLE_SIGN_IN_KEY_ID`,
  `BIL_APPLE_SIGN_IN_CLIENT_ID`,
  `BIL_APPLE_SIGN_IN_PRIVATE_KEY_BASE64`, and a separately generated random
  32-byte `BIL_APPLE_TOKEN_ENCRYPTION_KEY_BASE64`. The Sign in with Apple key
  is distinct from the App Store Connect API key; neither key belongs in
  source.
- Deploy `apple-sign-in-token`, `apple-sign-in-notifications`, and the updated
  `account-data-deletion`. The notification endpoint must be deployed without
  gateway JWT verification because Apple supplies its own signed JWS; the
  handler verifies that JWS before any database work.
- Register the absolute `apple-sign-in-notifications` HTTPS URL as the Sign in
  with Apple server-to-server notification endpoint in Certificates,
  Identifiers & Profiles.
- Exercise a new signed-device Apple account through sign-in, explicit BIL
  deletion, `/auth/revoke`, Storage cleanup, Auth deletion, and both Apple
  notification event types. Source tests do not replace this provider E2E.
