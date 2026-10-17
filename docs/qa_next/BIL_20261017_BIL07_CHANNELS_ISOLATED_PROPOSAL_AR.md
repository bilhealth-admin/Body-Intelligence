# BIL-07 Community Channels — Isolated backend proposal

**NOT PRODUCTION APPROVED.** iOS36 / Android33 call seven bil07_channel_* RPCs absent in the reviewed production schema.

New migration defines five RLS-enabled, no-direct-client-access tables for rooms, membership, messages, exact receipts and expiring presence; seven SECURITY DEFINER RPCs with authenticated owner identity derived only from auth.uid(). Public membership is implicit unless banned; member-only rooms require explicit membership.

Idempotency is per owner, room and client-message UUID; channel row locks serialize sequence counters. Read receipts are separately committed then read back, capped 100. Bilateral blocked authors are hidden; consent required before sending; presence 90s, freshness 30s; no realtime publication or automatic fake room seed.

CI test uses PGlite synthetic auth, 3 owners, RLS, missing consent, ban, privacy, duplicate sends, readback, blocks, and presence. It does not touch a real account or Supabase project.

**Release blockers:** owner-reviewed initial rooms, channel-specific reporting/removal/moderation, rate limiting, cross-device and multi-owner full client tests, Apple/Google UGC reviews. Never deploy this proposal automatically.

## Moderator/report contract staged for isolated testing
A separate **private** report table and three additional authenticated-only RPCs support user reporting, restricted moderator queue and idempotent hide/keep decisions. Moderator authority comes from the existing `bil_community_moderators` table, not a mobile backdoor. Reports are rate-limited per authenticated reporter (20/24 h) with advisory transaction lock, and can never report oneself or already hidden content. Reviewer decisions are final and conflict-safe, while read APIs immediately exclude hidden content. Synthetic PGlite tests assert reviewer denial, no direct table access, idempotency and content removal.

This backend proposal is still NOT READY for production until a user-visible channel report action, moderator web access, abuse workflows, retention/privacy review and Apple/Google moderation evidence are implemented and approved.
