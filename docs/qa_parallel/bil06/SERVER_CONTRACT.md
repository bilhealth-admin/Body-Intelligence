# BIL-06 server contract and local verification

Status: **LOCAL_SQL_VERIFIED / DEFERRED_PRODUCTION**. This is a forward-only proposal, not an applied Supabase migration. `production_deployed=false`.

BASE: `1744788e6bfbdffc3a168bbaf36b3abf3e2c698a`, tree `8f140791e1c2adcb21122ce64a65cb168bbe90d7`.

## Existing authority retained

The proposal reuses `bil_community_circles`, `bil_community_circle_memberships`, `bil_community_post_circles`, `bil_assert_community_publish_ready`, the current Community policy ledger, actual public profiles, current opaque BIL Codes, profile visibility, blocks and suspension authority. A saved name plus an existing BIL Code is required for management writes. Neither a biography nor a manually chosen handle is required. Reading never creates a profile/code, accepts policy, follows a person, accepts an invitation, or creates a membership.

The creator becomes one real `active`/`moderator` membership. Existing roles remain `member` and `moderator`; no new `owner` role is serialized into the BASE model. `created_by` is provenance and does not independently grant management after a moderator membership is revoked.

The five original functions `bil_list_community_circles_v1`, `bil_join_community_circle_v1`, `bil_leave_community_circle_v1`, `bil_set_my_community_post_circle_v1` and `bil_community_circle_post_refs_v1` are unchanged. The SQL suite compares their complete `pg_get_functiondef` hashes before and after the proposal. Existing moderator-cannot-leave, invite-only join, pending request, banned membership, post ownership and private-post membership guards are preserved.

The legacy list returns a PostgreSQL **TABLE**, not JSONB. Appending native metadata to that return type would require a signature replacement. This proposal leaves it intact. The new search endpoint with an empty query and the direct read endpoint return native circle names, descriptions and media. The client should use these endpoints when capabilities are available, retaining the BASE list as a compatibility path when the new contract is unavailable.

## New data and least privilege

| Table | Purpose | Mobile access |
| --- | --- | --- |
| `public.bil_circle_metadata_v1` | Real display name, description, rules and attachment IDs | RPC only |
| `public.bil_circle_invites_v1` | Recipient, issuer, expiry and authoritative invitation state | RPC only |
| `public.bil_circle_media_v1` | Exact upload reservation, owner, circle, slot and media metadata | RPC only |
| `public.bil_circle_operations_v1` | Immutable request identity, payload and committed receipt | Own receipt RPC only |

Every new table enables RLS and explicitly revokes direct privileges from PUBLIC, `anon`, `authenticated` and `service_role`. No mobile table policy grants a write shortcut. All private helpers revoke executable access from these roles. All public endpoints below explicitly grant `authenticated` only; each uses `SECURITY DEFINER`, `search_path=''` and caller checks. None accepts a caller-supplied user ID as authentication authority.

## RPC catalog

All values below use PostgreSQL JSONB. RPC names and parameter names are exact. UUIDs are lowercase canonical strings in JSON. Optional SQL defaults are shown.

| Endpoint | Parameters | Response |
| --- | --- | --- |
| `bil_circle_capabilities_v1` | `p_slug text = null` | Owner-bound capability object |
| `bil_circle_search_v1` | `p_query text = ''`, `p_mine boolean = false`, `p_after_slug text = null`, `p_limit integer = 30` | `{owner_id, query, mine, circles, next_after_slug}` |
| `bil_circle_read_v1` | `p_slug text` | `{owner_id, circle: object or null}` |
| `bil_circle_membership_v1` | `p_slug text` | Owner-bound membership/permission read for later BIL-07 use |
| `bil_circle_invites_v1` | `p_slug text = null`, `p_after_id uuid = null`, `p_limit integer = 30` | `{owner_id, invites, next_after_id}` |
| `bil_circle_invite_v1` | `p_invite_id uuid` | `{owner_id, invite: object or null}` |
| `bil_circle_operation_v1` | `p_request_id uuid` | Own committed receipt or `null` |
| `bil_circle_create_v1` | `p_request_id uuid`, `p_display_name text`, `p_description text`, `p_rules text`, `p_access text`, `p_join_policy text` | `create` receipt |
| `bil_circle_invite_send_v1` | `p_request_id uuid`, `p_slug text`, `p_invitee_code text` | `invite_send` receipt |
| `bil_circle_invite_action_v1` | `p_request_id uuid`, `p_invite_id uuid`, `p_action text` | `invite_accept`, `invite_decline` or `invite_cancel` receipt |
| `bil_circle_media_prepare_v1` | `p_request_id uuid`, `p_slug text`, `p_slot text`, `p_mime_type text`, `p_bytes integer`, `p_width integer`, `p_height integer` | `media_prepare` receipt |
| `bil_circle_media_finish_v1` | `p_request_id uuid`, `p_media_id uuid` | `media_finish` receipt |
| `bil_circle_media_cancel_v1` | `p_request_id uuid`, `p_media_id uuid` | `media_cancel` receipt |

`bil_circle_media_access_v1(p_object_path text, p_mode text, p_owner_id text = null, p_metadata jsonb = null)` is the narrowly scoped Storage RLS helper. It returns a boolean and does not upload, publish, delete or reserve an asset. The client does not use it as an action endpoint.

### Capability and membership reads

Capabilities contain `owner_id`, `circle_slug`, `available`, `can_create`, `can_search`, `can_read_invites`, `can_invite`, `can_manage_media`, `is_member`, nullable `role` and nullable machine-readable `reason`. Missing RPC means unavailable, not granted permission. A policy/configuration read error must fail closed in the client. The existing 100 active/pending memberships cap disables creation; it does not disable an existing manager's invitations/media.

`bil_circle_membership_v1` contains `owner_id`, `circle_slug`, `visible`, `is_member`, `role`, `status`, `can_read_posts`, `can_post` and `can_manage`. `can_post` also checks current publish readiness; membership alone is insufficient. A private circle visible only through a pending invitation returns `is_member=false` and `can_read_posts=false`. An unavailable or unshared private slug returns no role/status and false permissions. This read performs no BIL-07 chat work and does not authorize future writes without rechecking the receiving feature's permissions.

### Circle rows

Each row includes all BASE keys: `slug`, `title_copy_key`, `description_copy_key`, `rules_copy_key`, `access`, `join_policy`, `featured`, `member_count`, `post_count`, nullable `membership_status` and `membership_role`.

Native additions are nullable `display_name`, `description`, `rules`, `avatar`, `cover`. Seeded rows retain their existing copy keys and have null native metadata. New circles use `community_circle_custom_title`, `community_circle_custom_description`, `community_circle_custom_rules`, alongside the actual submitted text. Counts are database queries; no sample people, avatars, member totals or images are inserted by a read.

Names are 2–80 Unicode code points. Description/rules are at most 1,000/2,000. Names reject control characters; description/rules permit LF, CR and TAB but reject other controls. `access` is `public|private`; `join_policy` is `open|request|invite`. Private+open is rejected because it would permit immediate joins through the unchanged BASE join endpoint.

### Search/privacy/pagination

Search runs over all accessible rows, applying privacy **before** the limit. A public circle is discoverable to eligible signed-in members. A private circle is visible only to an active member or the recipient of a usable pending invitation. That preview requires an active moderator issuer, unexpired pending state, no suspended participant, no block in either direction and no banned recipient. Preview grants metadata/media access, not private-post access or membership. Unrelated third parties and `anon` receive no private results.

Query matching is literal substring matching over slug, native name and native description; `%` and `_` are ordinary characters. The server trims surrounding spaces, rejects control characters and limits query length to 120 Unicode code points. The current client input limit is a stricter 100. Accent folding, typo matching and localized seed-label search are not implemented: seeded circle search matches its slug.

Pagination is slug ascending with `COLLATE "C"`, after-exclusive cursor and 1–60 rows. One extra eligible row determines whether `next_after_slug` is present. Invites use ascending UUID ID, after-exclusive cursor and the same page bound. There is no global snapshot token: concurrent additions before an already-consumed cursor require a fresh search, as with ordinary keyset pagination. The client owns debounce, request generation, stale response rejection, owner/session ABA and repository/visit identity.

### Invitations

An invitation row contains `id`, `circle_slug`, nullable real `circle_name`, `inviter_id`, `invitee_id`, nullable privacy-filtered `inviter_name`/`invitee_name`, nullable `recipient_code`, `status`, timestamps and `can_accept`, `can_decline`, `can_cancel`. `recipient_code` is deliberately redacted (`null`); the UI keeps the user's entered code only in its local review. Resolving a code does not create a social relationship.

`p_invitee_code` is the current 32-hex BIL Code, trimmed and lowercased. Resolution calls the existing canonical public-code RPC, including its existing quota and privacy rules. No new invitee UUID guessing or public profile enumeration endpoint is introduced.

Only an active moderator sends/cancels invitations. Only the named recipient accepts/declines. A partial unique index permits one pending invitation per circle/recipient. Repeated sends to an existing usable pending invitation return that same invitation ID; no extra pending row is created even if distinct explicit request IDs arrive. An expired/unusable pending invitation is retired only by a new explicit authorized send. Reads never change its state. The rendered `expired` state is computed from a stored pending invitation's expiry time.

Accept changes a pending invitation and the actual BASE membership within one transaction. The recipient must pass current publish readiness and cannot be banned. Opposing terminal actions are rejected. Repeating the same terminal action is idempotent. Replaying an accepted invitation after BASE leave does **not** recreate the membership. The client must render current membership and invitation state independently.

### Mutation receipts and retries

The immutable key is `(auth.uid(), p_request_id)`. A repeated key with the same normalized operation payload returns its existing receipt; a changed operation or payload raises `circle_request_payload_conflict` (`22023`). Successful receipts contain:

```json
{
  "owner_id": "UUID",
  "request_id": "UUID",
  "operation": "create",
  "committed": true,
  "committed_at": "UTC timestamp",
  "circle_slug": "c-...",
  "invite_id": null,
  "media_id": null,
  "circle": {},
  "invite": null,
  "media": null
}
```

This example is a shape illustration; executable, synthetic, actual PostgreSQL responses are in `tool/qa_parallel/bil06/sql/evidence/sql_protocol_samples.json`.

The receipt proves the operation committed. `invite_id` and `media_id` are immutable historical identities stored directly on the operation row and are deliberately not foreign-keyed with `ON DELETE SET NULL`; deleting or superseding the current invite/media projection cannot erase which object a committed idempotent operation targeted. Nested circle/invitation/media fields are current authorized projections, so they may change or become null after revocation, deletion or a later action. A client must not treat a historic receipt as current permission. `operation_v1` reads only the requesting owner's receipt and does not execute the original mutation. After acknowledged mutation plus failed readback, retry this read only. If dispatch failed and an authoritative read finds no committed receipt, an explicitly requested mutation retry keeps the same request ID.

### Media and Storage

The bucket is `community-circle-media`, **private for both public and private circles**. Paths are server-reserved:

```text
ownerUUID/circleSlug/avatar|cover/mediaUUID.jpg|png|webp
```

Media JSON contains `id`, `owner_id`, `circle_slug`, `slot`, `object_path`, `mime_type`, `bytes`, `width`, `height`, `dimensions_verified:false`, `status`. MIME types are JPEG/PNG/WebP; max bytes 5,242,880, each dimension 1–8,192, product at most 40,000,000 pixels. Width/height are client-reported bounded values. SQL does not decode image bytes and explicitly does not claim server-verified dimensions. The client uses the existing actual image decoder before reserve/upload.

The lifecycle is reserve → upload with `upsert:false` → finish → read receipt. Reservation alone never populates avatar/cover. Finish checks an existing exact Storage object, uploader identity, byte count and MIME metadata before attaching it. Missing/mismatched upload raises `circle_media_upload_unconfirmed`; no finish receipt is written. Projection hides a missing Storage object instead of returning a fictitious image.

Storage RLS authorizes exact reserved paths and rejects wrong owner/circle/slot, MIME, size, replacement and update. Published attached objects cannot be deleted directly. Replacing an attachment marks the previous immutable object `superseded`. Explicit cancel detaches an attachment or retires a reservation; only then is cleanup permitted. The uploader may cancel/remove their unfinished upload after manager-role revocation. Members and eligible invite preview recipients can read the current private attachment; unrelated users cannot. The client signs authorized references for **60 seconds**, and keeps unavailable images absent. Already-issued signed URLs retain their service-defined expiry; immediate URL revocation is not claimed.

Locks follow the existing actor member-state lock, request lock, circle lock, then grant/asset rows. Current moderator membership rows are locked through commit. Media upload policies use the same circle/asset order as finish/cancel. Unique keys are an additional duplicate barrier. Native independent-session lock scheduling remains unverified; the single-backend test result is not a concurrent transaction proof.

## Account-deletion integration proposal

The new bucket must join the existing account cleanup list before enabling this feature. `tool/qa_parallel/bil06/sql_account_deletion.patch` is an exact separate one-line hunk for:

`supabase/functions/_shared/account_deletion_storage.ts`

BASE Git blob: `f971edd92360a1cc3d450ea57a4d092948de54a9`.

BASE SHA256: `505fe46b057f9f8ad12b18e5fa89316d32d402dae34edd4752e9876230ee9d84`.

Patched SHA256: `8e19043cfbb6340ec62271f9b56e2ae418e1f9f088311077d41ca38ac634037b`.

The original function traverses each owner prefix recursively, removes objects, and verifies emptiness before returning. The proposal adds `community-circle-media` to its default bucket list. No shared file was edited. The exact hunk was applied and tested in a private overlay using the real BASE TypeScript implementation and a synthetic Storage API. The baseline omission was reproduced; patched cleanup preserves other owners, reports Storage failures and fails on nonempty readback. This is four separate local integration test groups, not actual Auth account deletion/Storage HTTP E2E. The SQL attachment foreign keys clear the affected attachment column when media rows are deleted and do not block the circle's identity or owner deletion.

## Reproducible execution and evidence

Public runtime packages are pinned in `sql/runtime-package.json` and `sql/runtime-package-lock.json`: PGlite 0.5.8, PGlite Socket 0.2.11, pg 8.16.3. The executed runtime reports PostgreSQL **18.3**, compiled to WASM, with Node **24.19.0**. No binaries/cache are part of this deliverable. This is real PostgreSQL SQL/RLS execution through TCP `127.0.0.1`, with one backend, in a newly created empty database.

From the BASE source plus the owned patch:

```bash
mkdir -p /dev/shm/bil06-sql-local/runtime
cp tool/qa_parallel/bil06/sql/runtime-package.json /dev/shm/bil06-sql-local/runtime/package.json
cp tool/qa_parallel/bil06/sql/runtime-package-lock.json /dev/shm/bil06-sql-local/runtime/package-lock.json
npm --prefix /dev/shm/bil06-sql-local/runtime --cache /dev/shm/bil06-sql-local/npm-cache ci --ignore-scripts --no-audit --no-fund
BIL06_SQL_NODE_MODULES=/dev/shm/bil06-sql-local/runtime/node_modules node tool/qa_parallel/bil06/sql_run.mjs
BIL06_SQL_WORK=/dev/shm/bil06-sql-local node tool/qa_parallel/bil06/sql_deletion_test.mjs
```

The database runner creates its own in-memory engine, binds only loopback and refuses a nonempty database. It accepts no connection URL and reads no Supabase configuration. The test fixture uses the BASE `tool/release/community_atomic_publish_live_baseline.sql` schema/function snapshot, exact circles functions, exact profile visibility and canonical public-code resolver reconstructed from its verified BASE source plus its documented QR visibility patch. `auth.users` and request JWT GUCs are synthetic fixture identities. Storage objects are SQL metadata rows, not uploaded image bytes. The reconstructed public-code resolver fixture normalizes its trailing blank line to one final newline; its SQL statements are unchanged.

Final SQL result: **40 test groups PASS, exit 0**. Deletion overlay: **4 test groups PASS, exit 0**. These counts are separate groups and do not add prior runs. The final evidence files are:

- `sql/evidence/sql_results.json`: environment, executed source SHA256 values, group results and explicit NOT_RUN items.
- `sql/evidence/sql_run.log`: exact final SQL runtime and group outcome log.
- `sql/evidence/sql_protocol_samples.json`: actual RPC request/response samples and actors from that execution.
- `sql/evidence/sql_deletion_results.json` and `sql_deletion_run.log`: exact BASE/proposal/runner hashes and separate cleanup results.
- `sql/evidence/sql_commands.json`: exact session commands and local runtime restrictions.

**NOT_RUN:** Native PostgreSQL17 concurrent sessions/lock races; hosted Supabase Auth/PostgREST/Storage HTTP; actual image-byte upload and server image decoding; device UI and the combined BIL-00 application. The environment has no native PostgreSQL and maps only UID0, so native non-root server startup is unavailable. PGlite avoids inventing a SQL mock, but its one backend cannot substitute for independent transaction tests. No production project was contacted.

## Documentation consulted

- [Supabase Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security): grants and policies are distinct; client table privileges are explicitly limited.
- [Supabase Storage access control](https://supabase.com/docs/guides/storage/security/access-control): object access through Storage RLS; private bucket signing.
- [Supabase changelog](https://supabase.com/changelog.md) and [PostgreSQL15.19/17.11 changes](https://supabase.com/changelog/postgres-15-19-17-11-breaking-changes): checked before implementation; no live migration/advisor calls.
- [PGlite API](https://pglite.dev/docs/api) and [PGlite Socket](https://pglite.dev/docs/pglite-socket): actual local PostgreSQL/WASM runtime, private loopback server and the single-backend limitation.

All source and instructions for this proposal are local. Future production enablement requires BIL-00's separate review, the shared cleanup hunk and the outstanding runtime/integration gates.
