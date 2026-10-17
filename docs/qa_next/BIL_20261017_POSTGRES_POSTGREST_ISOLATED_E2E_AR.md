# BIL07 — Real PostgreSQL / PostgREST isolated JWT and RPC acceptance

This workflow runs an ephemeral PostgreSQL 16 database and PostgREST 12.2.8 inside GitHub Actions only. It applies the unchanged candidate BIL07 migrations to a fresh synthetic schema and tests actual JSON HTTP/RPC responses under three signed non-production owner tokens. It covers anon denial, member-only rooms, owner scopes, consent, idempotency, read receipts, moderator report decisions and removal.

Files under supabase/tests/fixtures are synthetic fixtures, never migrations: the fake consent checker accepts a test-only JWT field, whereas the real server must use durable community policy acceptance. Do NOT ship this fixture or its JWT/database passwords or treat it as equivalent to Supabase Auth. Existing PGlite and widget tests remain separate.

A full local Supabase Auth/PostgREST/RLS stack and physical devices will still be needed for release approval. No customer data, production server, TestFlight, Play or Codex worktree is altered here.

## Abuse-rate protection under isolated test
One sender can initiate at most 20 distinct channel messages in a rolling 60-second window and 300 in a rolling 24-hour window across all rooms. Per-owner advisory locks prevent cross-room races; authoritative committed UUID replays are exempt so network uncertainty does not cause duplicates. This counts hidden messages as well, prevents moderation removals refunding spam budget and does not affect other owners. The API returns SQLSTATE 42501 and the typed mobile client shows a specific English/Arabic retry-later notice while keeping the original draft. Both PGlite and real HTTP gate assert the 21st new send is denied and an already committed ID retries successfully. No Production changes.

### CI traceability (17 October)
- PostgREST integration baseline `8d22378a1e985428684334c9035c4c3e286317e5` passed [39068469341](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/39068469341).
- Extended per-owner rate limiter `b2237aefcfb4e1619025c2670884929780346c7a` passed PGlite, actual PostgreSQL/PostgREST HTTP and Flutter [39068794875](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/39068794875).
- Exact Dart formatter changes from [39069003326](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/39069003326) are applied to the tracked source; CI now strictly rejects unformatted inputs rather than modifying working copy only. Re-run required for final byte-identical source proof.

### Additional real-HTTP adversarial coverage
Added direct PostgREST table-query denial using an authenticated fixture JWT; a tampered signed token must return 401. Two concurrent HTTP POSTs with the same sender and client message UUID must result in exactly one created message, the second being a confirmed idempotent replay. These tests prove server-side security and race handling in the disposable database, without disclosing real user data or accessing Production. Latest focused CI must pass on the changed HEAD before acceptance.
