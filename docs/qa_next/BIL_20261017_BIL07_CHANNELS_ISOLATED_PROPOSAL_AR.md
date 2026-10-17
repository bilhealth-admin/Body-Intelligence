# BIL-07 Community Channels — Isolated backend proposal

**NOT PRODUCTION APPROVED.** iOS36 / Android33 call seven bil07_channel_* RPCs absent in the reviewed production schema.

New migration defines five RLS-enabled, no-direct-client-access tables for rooms, membership, messages, exact receipts and expiring presence; seven SECURITY DEFINER RPCs with authenticated owner identity derived only from auth.uid(). Public membership is implicit unless banned; member-only rooms require explicit membership.

Idempotency is per owner, room and client-message UUID; channel row locks serialize sequence counters. Read receipts are separately committed then read back, capped 100. Bilateral blocked authors are hidden; consent required before sending; presence 90s, freshness 30s; no realtime publication or automatic fake room seed.

CI test uses PGlite synthetic auth, 3 owners, RLS, missing consent, ban, privacy, duplicate sends, readback, blocks, and presence. It does not touch a real account or Supabase project.

**Release blockers:** owner-reviewed initial rooms, channel-specific reporting/removal/moderation, rate limiting, cross-device and multi-owner full client tests, Apple/Google UGC reviews. Never deploy this proposal automatically.

## Moderator/report contract staged for isolated testing
A separate **private** report table and three additional authenticated-only RPCs support user reporting, restricted moderator queue and idempotent hide/keep decisions. Moderator authority comes from the existing `bil_community_moderators` table, not a mobile backdoor. Reports are rate-limited per authenticated reporter (20/24 h) with advisory transaction lock, and can never report oneself or already hidden content. Reviewer decisions are final and conflict-safe, while read APIs immediately exclude hidden content. Synthetic PGlite tests assert reviewer denial, no direct table access, idempotency and content removal.

This backend proposal is still NOT READY for production until a user-visible channel report action, moderator web access, abuse workflows, retention/privacy review and Apple/Google moderation evidence are implemented and approved.

## Client report and block controls — proposal
The channel's message bubble now exposes a safety button only on messages authored by another member. The pearl confirmation flows offer a deliberate report category (spam, harassment, hate, other), or confirm a block using the existing community block-member authority. Reporter/owner validation is repeated after every awaited sheet and before/after network dispatch; no report is sent by just opening the dialog. The repository implements an optional safety interface so older injected test fakes remain valid. All such flows require staging QA and moderator reporting/retention review before any production activation.

## QA update — source-level proof
- Initial isolated migration, report/moderator extension, and new mobile report/block menu passed **both** PGlite and Flutter focused tests on `00d1cd0b5fd499adf4b6fbe39429670cae5b65e1` (Actions run `39065891567`).
- Applied the exact seven Dart formatter deltas from that run into Git source and changed CI to enforce zero-diff source formatting. A subsequent run on the formatted HEAD is required before declaring this worktree final.
- This is staging evidence only. No approved channel seeds, no production data writes, and no published moderation web UI.
