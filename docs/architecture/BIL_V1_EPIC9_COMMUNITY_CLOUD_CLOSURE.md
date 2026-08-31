# BIL v1 Epic 9 — Community and cloud closure

Epic 9 is fail-closed. Community requires `BIL_USE_SUPABASE`, valid Supabase
configuration, and `BIL_COMMUNITY_ENABLED=true`. Push additionally requires
`BIL_PUSH_ENABLED=true`, and `BIL_PUSH_PROVIDER_READY=true` only after the
native APNs/FCM provider is installed and device-certified. Without those
release flags the surfaces are hidden
and no token, message, or health value is uploaded.

## Closed boundaries

- Supabase RLS enforces profile visibility, relationship membership, message
  parties, blocks, reports, and user-owned deletion requests.
- Posting, messaging, following, friend requests, and account deletion are
  server rate-limited. Active content-policy acceptance is required before
  posting or messaging.
- Reports are visible only through moderator RPCs. Moderator actions and
  relationship/content lifecycle events write metadata-only audit records;
  bodies, health values, and push tokens are prohibited from audit metadata.
- Account deletion is queued by an authenticated RPC. A secret-protected Edge
  Function first removes and verifies the user's object prefixes in every
  BIL-owned Storage bucket through the Storage API, then uses the service role
  to delete the Auth user so database cascades remove user-owned rows. Storage
  or Auth failure returns the durable request to `pending`; the superseded
  database-only worker fails closed. Push tokens are disabled immediately.
- Push tokens are registered only after opt-in. Time zone and deep links are
  stored server-side. Lock-screen text stays generic unless the user separately
  consents to sensitive previews.
- Incoming `bil://` links are restricted to an allowlist of community and
  notification-settings routes. Community links fail closed to Settings while
  the cloud configuration and explicit release flag are unavailable.
- The community entry itself is omitted from Settings until activation.
- Feed, chat, relationships, safety, profile privacy, reporting, blocking and
  deletion expose honest unavailable/error states and never fabricate data.

## External activation

Android exposes a build-safe `BILPushProvider` seam. The default provider
returns `push_provider_not_configured`; a production flavor must bind that seam
to Firebase Messaging after `google-services.json` and the Firebase project are
approved. iOS exposes the equivalent APNs registration bridge. Neither platform
invents a token when provider credentials are absent.

The reviewed Edge Function sources are versioned in the canonical Supabase
directories `community-push-dispatch/index.ts` and
`account-data-deletion/index.ts`; the gate also checks deterministic parity
with their review-friendly flat sources. It does not deploy or enable them.

Deployment still requires the project owner to apply the migration, deploy
`community-push-dispatch` and `account-data-deletion`, configure their internal
secrets, configure FCM/APNs credentials, and enable the release flags. The
credential-gated integration test uses two dedicated accounts and is skipped
honestly when those secrets are absent.

Do not advertise community or remote push before the production deployment,
two-account integration run, moderation staffing, policy URL publication, and
provider credentials are all complete.
