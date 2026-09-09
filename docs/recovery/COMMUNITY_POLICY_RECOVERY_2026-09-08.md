# BIL Community policy recovery — 2026-09-08

Supabase project: `tgmanzhqulksykhslrzb`
Status: **POLICY LIVE AND HARDENED; NO USER ACCEPTANCE FABRICATED**

## What the mandatory current read-only preflight found

- The live project was healthy and already contained migration
  `20260908013800_bil_community_social_v2`, the `bil_social_*_v2` tables and 17
  Social v2 functions.
- RLS was enabled on the core Community tables.
- Authenticated read access for `bil_content_policies` and
  `bil_content_policy_acceptances`, plus the Community classifier execution
  path, remained present.
- Previously removed dangerous `anon`/`authenticated` table privileges
  (`TRUNCATE`, `TRIGGER`, `REFERENCES`) remained at **zero**.
- The handoff recorded an earlier pre-activation snapshot of **0 rows / 0
  active rows**. The mandatory first live re-audit in this continuation instead
  found exactly one already-active/effective `community-policy-v1` row with the
  real BIL URL and its migration-history record. The row was therefore not
  reinserted, replaced or edited.
- `public.bil_content_policy_acceptances` contained **0 rows**.
- No live Social v2 table, function family, RLS policy or prior privilege
  hardening was missing, so none was rebuilt or replaced.
- This live-schema finding did not initially establish repository completeness.
  The Social v2 source has since been recovered from the deployment migration
  history without rebuilding or replacing live Social v2 objects; the recovery
  evidence, including the terminal-LF text-file representation, is recorded in
  `SERVER_RECONCILIATION.md`.

## Schema and dependency audit

The original schema comes from
`202608040002_bil_community_cloud_completion.sql`:

- `bil_content_policies`
  - `version text primary key`
  - `locale_code text not null default 'en'`
  - `document_url text not null`
  - `effective_at timestamptz not null`
  - `active boolean not null default false`
- `bil_content_policy_acceptances`
  - `user_id uuid` referencing `auth.users(id)` with account-deletion cascade
  - `policy_version text` referencing the real policy version
  - server timestamp and composite primary key
    `(user_id, policy_version)`
- Both tables have RLS enabled. Authenticated users can read an active policy
  and operate only on their own acceptance row under the existing policies.
- The original `bil_require_community_policy` trigger function guarded legacy
  post and message inserts, but behaved permissively when the policy table was
  empty. That was misleading because the client could appear to have a policy
  gate while the database allowed interaction with no effective policy.
- Social v2 comment inserts had authorization/moderation/rate protections but
  did not independently require an accepted policy version.
- Flutter reads the active policy and current user's acceptance through
  `CommunityRepository`; Community safety/composer/chat surfaces depend on
  those results.

## Historical pre-activation canonical-content search

Before `20260908032057` was authored and applied, the pre-existing repository,
migrations, documentation and Git history were searched for a versioned policy
seed, published canonical text and a `bil_content_policies` insert. No earlier
historical, versioned production policy row or complete canonical document was
found. There was generic, unversioned Community-guidelines website copy, but it
did not supply a policy version, effective acceptance contract or the complete
required product rules.

Accordingly, recovery did not invent a database URL or silently seed acceptance.
The earlier activation work authored a complete first production version,
published it at the existing real BIL domain, verified the English and Arabic
render in a browser, and only then activated the row. This continuation verified
and hardened that state instead of replaying activation. Browser evidence covers
the canonical public web document only; it is not evidence of the in-app
acceptance or publishing flow on iOS or Android.

## Published policy

- URL: `https://www.bilhealth.com/community-guidelines`
- Version: `community-policy-v1`
- Locale authority: `en`, with a complete Arabic view at `?lang=ar`
- Effective: `2026-09-08T00:00:00Z`
- Active rows after deployment: exactly **1**
- Cloudflare Worker version:
  `f8023569-4367-4a8a-9f4a-3ce8efbf77e0`

The document covers profiles; posts; comments; replies; likes/reactions;
friends/follows; messages; reports; Community food; prohibited content;
off-platform contact exchange; blocking; privacy; human moderation and
appeals; enforcement; and the non-medical health/fitness boundary. It states
that a new policy version requires a new acceptance and that declining does
not remove available account/privacy/report/block controls.

## Production migrations

### `20260908032057_community_policy_v1_activation`

File: `supabase/migrations/20260908032057_community_policy_v1_activation.sql`

- Fails if required policy/Social v2 tables are missing.
- Fails rather than overwriting an existing active/canonical version.
- Adds a partial unique index enforcing at most one active policy.
- Adds a private, fixed-search-path helper that fails closed unless exactly one
  already-effective policy exists and the signed-in user accepted that exact
  version at or after its effective time.
- Adds a private acceptance trigger that requires the actual user JWT,
  requires the current active/effective version, and sets the server timestamp.
  A service-role write without that user's JWT cannot accept on the user's
  behalf.
- Preserves the existing post/message rate limits while making their policy
  guard fail closed.
- Adds an acceptance-only guard to Social v2 comments without double-charging
  the Social v2 abuse/rate bucket.
- Inserts exactly the one canonical active row after the real document is live.
- Does not change RLS policies, grants, moderator membership, subscriptions,
  App Attest, AI Coach or purchases.

### `20260908032453_community_message_block_visibility_hardening`

File:
`supabase/migrations/20260908032453_community_message_block_visibility_hardening.sql`

The transactional policy test uncovered a separate real defect: when recipient
B had blocked sender A, A's RLS-visible slice of `bil_blocks` could hide B's
row from the legacy message path. The test transaction rolled back completely.

This forward migration adds a private `SECURITY DEFINER`, `row_security=off`
bilateral message guard and an unordered-pair advisory transaction lock shared
by block changes and message inserts. It does not widen any table visibility or
grant direct execution on the helper.

### `20260908032558_community_block_pair_uuid_lock_fix`

File: `supabase/migrations/20260908032558_community_block_pair_uuid_lock_fix.sql`

The first runtime execution then exposed that PostgreSQL implements
`LEAST`/`GREATEST` as expressions, so `pg_catalog.least(uuid, uuid)` was not a
callable function. The applied migration was not edited. This second forward
migration replaces only the two new helper bodies with deterministic UUID-text
ordering. Trigger bindings, RLS and ACLs remain unchanged.

### `20260908132433_community_policy_client_status_rpc`

This migration was applied successfully by the Supabase CLI after a dry-run
that listed it alone. Its preflight requires both policy tables, the
single-active index, `public.bil_can_use_community()`, and
`private.bil_assert_current_community_policy()`; it refuses to overwrite either
new RPC if it already exists.

It adds:

- `public.bil_current_community_policy_status()`: a fixed-search-path,
  `SECURITY INVOKER`, server-clock status RPC. It reads the active/effective
  policy and the signed-in caller's own receipt through existing RLS and fails
  closed when effective-policy cardinality is not exactly one.
- `public.bil_assert_community_publish_ready()`: a no-argument,
  fixed-search-path `SECURITY DEFINER` assertion. It requires the JWT-bound
  actor, the existing Community membership/suspension guard, and the private
  exact-policy receipt guard before returning the current version. It has no
  DML and no caller-supplied identity.

Both RPCs revoke execute from `PUBLIC`, `anon`, and `service_role`, then grant
only `authenticated`. The postcondition checks require the expected security
mode, volatility, empty search path and ACL. No table RLS or table grant was
changed.

### `20260908175000_community_policy_storage_upload_guard`

This migration closes a bypass where a modified client could upload a private,
orphaned object to `community-post-images` without accepting the current policy.
It adds one `AS RESTRICTIVE FOR INSERT TO authenticated` Storage policy that
calls the authoritative publish-readiness assertion for that bucket. The
existing owner/path permissive policy remains unchanged. No object, receipt,
grant or table-RLS state is changed.

### `20260908180500_community_policy_version_immutability`

This migration makes every policy-version row an append-only ledger entry. It
rejects changes to `version`, `locale_code`, `document_url` or `effective_at`,
rejects deletes and rejects false-to-true reactivation. The only material update
allowed is active-to-inactive; a replacement must be inserted under a new
version and requires a new user receipt. The private trigger function uses a
fixed empty search path and has no client execute privilege.

### `20260908181500_community_policy_ledger_postconditions`

This migration rechecks the complete canonical identity—one active row,
`community-policy-v1`, `en`, the real URL and exact effective timestamp—after
the append-only guard is installed. It also adds a private statement trigger
that rejects privileged `TRUNCATE` with
`community_policy_history_immutable`. It performs no policy/acceptance DML and
does not change RLS or client grants.

The cross-cutting migration
`20260908141133_harden_public_default_table_privileges` separately removes only
dangerous future-table defaults for `anon`/`authenticated` in `public`, while
preserving four intended `service_role` defaults. It does not alter Community
business data or existing-table ACLs.

## Flutter behavior

- The client consumes the server-clock policy-status RPC and fails closed when
  no single effective policy is available.
- Unaccepted and newly versioned policies block write entry points and present
  an explicit acceptance surface. Decline never creates a receipt.
- The real user's authenticated acceptance is the only code path that inserts
  a receipt; no service or migration accepts on the user's behalf.
- Community image upload errors are reconciled against the authoritative
  readiness assertion, so policy/suspension failures remain clear while
  unrelated Storage errors retain their original diagnostics.
- English opens the canonical URL unchanged; Arabic opens the same real route
  with `?lang=ar`. No placeholder URL is used.

## Tests and results

- `supabase/tests/community_policy_v1_test.sql`
  - transactional `BEGIN`/`ROLLBACK` production-schema test;
  - no active policy fails closed;
  - active/unaccepted user cannot post/message/comment;
  - real user acceptance permits the bounded action;
  - activating a new version requires a new acceptance;
  - service-role/no-JWT and inactive-version preaccept are rejected;
  - suspended user and bilateral block paths reject writes;
  - direct table publish cannot bypass acceptance;
  - Storage cases cover no policy, unaccepted, accepted, new version,
    suspension, wrong owner and invalid path;
  - immutable-ledger cases cover every identity field, active/inactive delete,
    reactivation, versioned rotation and privileged `TRUNCATE`;
  - post-rollback residue readback covers all 11 synthetic fixture categories;
  - **final live runtime result: PASS inside `BEGIN`/`ROLLBACK`; residue 0.**
- Post-apply readback: all **114/114** migrations aligned; one active/effective
  v1 row, zero acceptances, five RLS-enabled Social v2 tables, 17 Social v2
  functions, zero dangerous current/default client grants and four preserved
  `service_role` defaults.
- Final focused Flutter policy batch: **36 PASS / 0 FAIL / 0 SKIP**.
- Final portable runner: **4,071 PASS / 0 FAIL / 1 opt-in live-stream SKIP**
  across 875/875 executed files. `flutter analyze --no-pub`: **PASS, no issues**.
- `test/launch_readiness/community_policy_v1_sql_contract_test.dart`
  validates forward-only migration boundaries, exact URL/version, no fabricated
  acceptance, private helper ACLs, Storage/version/TRUNCATE guards, required
  cases and the block forward fix. **Result: 9/9 PASS.**
- `test/features/community/community_publish_validation_regression_test.dart`
  exposed and fixed the async `setState` misuse in the composer.
  **Result after fix: 4/4 PASS.**
- Public website checks:
  - `node --check public_site/app.js`: **PASS**
  - `node tool/release/bilhealth_site_worker.test.mjs`: **6/6 PASS**
  - production HTTP and English/Arabic browser review: **PASS**
- Current Google Play read-only evidence shows one unpublished `en-GB`
  description change; it was not published and no build/track/release mutation
  occurred. Current App Store Connect state could not be authenticated because
  the retained session is at `authResult=FAILED`; historical Apple metadata is
  not treated as current proof and no login or mutation was attempted.

The required iOS/Android UI matrix—no policy, unaccepted, accepted, new
version, explicit decline, suspension, and publish rejection—remains a signed
device release gate. Automated/server success is not reported as device proof.

## Production data changes

No production business-data change was committed by this continuation. The live
verification transaction exercised synthetic rows and updates only inside
`BEGIN`/`ROLLBACK`; post-rollback residue was zero. The existing canonical row
found by the initial current audit is:

```text
public.bil_content_policies
version       = community-policy-v1
locale_code   = en
document_url  = https://www.bilhealth.com/community-guidelines
effective_at  = 2026-09-08T00:00:00Z
active        = true
```

No row was added to `bil_content_policy_acceptances`. No test user, post,
comment, message, entitlement or moderator grant remained after the rollback
test. Durable changes were the reviewed RPCs, Storage policy, private trigger
functions/triggers, future default ACL and migration-history records described
above—not Community/user/purchase/entitlement business data.

The later `20260908132433` application did not change this policy row or add
any acceptance. Its only production effects were the two RPC definitions,
their function ACLs, and the migration-history record; it did not alter
business data, table RLS, table grants, triggers, policies, entitlements, or
moderator membership.

The separate later hardening migration
`20260908141133_harden_public_default_table_privileges` also made no Community
business-data, RLS, existing-table ACL, table, or role change. Its
transactional pre-probe and post-apply rollback test passed; it affects only
future `postgres`-owned relation defaults in `public`.

The later `20260908175000`, `20260908180500`, and `20260908181500` applications
also performed no Community policy/acceptance business-data DML. Final live
readback remained one canonical active row and zero acceptance rows.

## Intentional advisor result after the RPC deployment

The Supabase security advisor reports
`authenticated_security_definer_function_executable` for
`public.bil_assert_community_publish_ready()`. This is intentional and
reviewed: authenticated application clients need a self-only, server-side
publish-readiness assertion. The endpoint has no parameters, takes identity
only from `auth.uid()`, uses a fixed empty search path, checks the existing
membership/suspension guard and private policy-receipt guard, and exposes no
`anon`, `service_role`, or `PUBLIC` execution. Do not change it merely to
silence the generic advisor warning.

## Safe rollback / supersession

Do not delete this row or user acceptance history and do not edit an applied
migration. If the document must be withdrawn, ship a reviewed forward migration
that marks it inactive; the server will then fail closed with
`community_policy_unavailable`. A replacement policy must use a new version,
publish its real document first, atomically switch the single active row, and
require each user to accept that new version from the app.
