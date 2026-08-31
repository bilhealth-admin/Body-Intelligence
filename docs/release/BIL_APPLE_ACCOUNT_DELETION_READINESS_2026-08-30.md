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

## Sign in with Apple tokenless fallback

The current app delegates Apple OAuth to Supabase and does not retain the
provider access token, refresh token, or authorization code required by
Apple's token-revocation endpoint. It therefore does not fabricate or claim an
automatic Apple revocation.

Apple TN3194 explicitly permits a manual fallback when none of those
credentials is available: delete the user's data, direct the user to revoke
the client manually, and return the client to an unauthenticated state. BIL now
implements that sequence:

1. It detects an Apple-linked Supabase user from the authenticated identity
   list, with `app_metadata.provider/providers` as a defensive fallback.
2. It completes BIL's Storage-first account and cloud-data deletion first.
3. Only after completion, it explains that Apple access was not revoked
   automatically and shows the exact device route:
   `Settings > [your name] > Sign in with Apple > BIL > Delete or Stop Using`.
4. It links to Apple's official instructions at
   `https://support.apple.com/102571`.
5. The user may close the notice without completing the optional Apple step;
   that does not block or undo the completed BIL deletion. The app then clears
   the local Supabase session and returns to an unauthenticated state.

This closes the current tokenless-deletion flow under TN3194. A future
server-token revocation path may improve the experience, but it must not be
claimed until Apple tokens are retained securely and the real revoke endpoint
is exercised end to end.
