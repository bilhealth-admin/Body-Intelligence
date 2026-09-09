# Server reconciliation — read-only snapshot (2026-09-08)

## Scope and method

The initial reconciliation and independent catalog/advisor readbacks in this
document are **read-only** inspections of live Supabase project
`tgmanzhqulksykhslrzb` against the checked-out `supabase/` tree. Runtime
fixtures used temporary DML only inside explicit `BEGIN`/final `ROLLBACK` and
left zero residue; they made no durable business-data change. The separately controlled,
CLI-only applications of `20260908132433`, `20260908141133`, `20260908175000`,
`20260908180500`, and `20260908181500` are documented below. Community policy
and Social v2 runtime behavior were deliberately out of scope for the initial
reconciliation; migration-history drift, including Social v2, was in scope.

Evidence source: Supabase Management API migration/function/advisor endpoints and local source inspection, on 2026-09-08.

## Confirmed live baseline

The production project is available and includes the applied Community-policy
chain through `20260908032558_community_block_pair_uuid_lock_fix`, including
`20260908032057_community_policy_v1_activation` and
`20260908032453_community_message_block_visibility_hardening`. Those three
policy/block forward files are present in the checkout. The applied Social v2
base migration `20260908013800_bil_community_social_v2` has since been
recovered locally from deployment migration history as documented below, so the
historical local migration chain is complete through the live baseline.

| Area | Confirmed live migration set |
| --- | --- |
| Android integrity | `20260818163257`, `20260818165223`, `20260818165240`, `20260818165259`, `20260818182103`, `20260818182144`, `20260905010000` |
| AI Coach | `20260820115847`, `20260820172843`, `20260820215019`, `20260820231631`, `20260820232033`, `20260820235144`, `20260821074908`, `20260821075318`, `20260821080542`, `20260821123043`, `20260821123129`, `20260821124334`, `20260821124632`, `202608220001`, `202608220002`, `20260822005720`, `20260822010050`, `20260830175811`, `20260831074550`, `20260831151527`, `20260901010000`, `20260904010000` |
| Purchase / entitlement | `202608020003`, `202608040004`, `202608090001`, `202608100001`, `20260821102504`, `20260828220000`, `20260830120109`, `20260830180011`, `20260831024716`, `20260904020000`, `20260905170000` |
| Push | `20260904040000` |
| Account deletion / Apple identity | `202608140001`, `20260822103316`, `20260822134000`, `20260830034302`, `20260830053817`, `20260830053941`, `20260830054600`, `20260830054752`, `20260905143000` |

## Migration-history reconciliation

All five migration sources that were initially absent from the checkout have now
been recovered locally. This was source reconciliation only: no migration SQL
was pushed and no production data, schema, grant, policy, function, or
migration-history row was mutated.

Four files came byte-for-byte from documented release-candidate commit
`de3f17e56853698f40726291a46733c095e07c5e` (`Prepare Android 9 and iOS 10
clean release candidates`, 2026-09-07T05:15:30+03:00). SHA-256, Git blob IDs,
and `git diff --no-index` all matched the candidate source:

| Version | Local file | SHA-256 | Git blob |
| --- | --- | --- | --- |
| `20260906100000` | `community_moderation_reviewer_and_message_privacy` | `0622057ac2edf50dd424c83af4ed36ca6dc57115411838913fd0394bee6b8bae` | `2f62acb363df5bab6d06241e472d6cefd9783e44` |
| `20260906110000` | `admin_community_friendship_access` | `ea0431148b059c03bfee3b775d3db4fb9df9e2f257906f813c5af9d34206c49a` | `29eb10a56b8007e67b9366ffef5e2f914e4a95f8` |
| `20260906120000` | `owner_approved_second_administrator` | `bba5e0ee71446c68c7179ecd2983d0e67b91c0869bfbbd45e5d63cba4d4ba2f8` | `9552a193d27cce4cfc3b2c2b44b0dfbd6c8b6c09` |
| `20260907010000` | `bil_backfill_community_food_live_search` | `92c4423566e9dc8a634b3a28ff091a61af577ed847c8a0239b36785cb32f3145` | `f4e6cfea4aeb81c2d2545ca7f43b7bdff77dadc3` |

`20260908013800_bil_community_social_v2` was recovered from the live
deployment-authoritative `supabase_migrations.schema_migrations` row, not by
reconstructing live objects. That row has one `statements` element, 23,548
UTF-8 bytes, and SHA-256
`e36139da4a97becd840325080e57dbb9fc6a6f0d99481bdbba6bcef08ac46812`.
The local text file is 23,549 UTF-8 bytes with the one terminal LF that
`apply_patch` requires, SHA-256
`a44a3e659fbed85e13f1a24518c2035808c9ec26963275f2c4ee004877e91293`.
Removing that final LF in memory only yields 23,548 bytes and the exact live
statement SHA-256 above; no formatter or other content transformation was
used. This is an EOF representation difference only, and not substitute SQL.

Before the controlled deployment, read-only `supabase migration list` showed
`20260908132433_community_policy_client_status_rpc` as the only
local-pending migration and `supabase db push --dry-run --skip-vault` listed
it alone. It was then applied successfully by the Supabase CLI only. The
final post-deploy `migration list` reports **114/114** local and remote versions
aligned through `20260908181500`; there is no local-pending or remote-only
version.

Do **not** use MCP `apply_migration` for timestamp-preserving reconciliation:
its interface has no local migration-version argument, and the published MCP
implementation issue documents server-generated history timestamps that can
create local/remote drift. It was not used here. Do not delete schema,
reconstruct Social v2 from live objects, or invent substitute migration
contents.

## Post-deploy Community policy client-status RPC

Controlled CLI deployment applied
`20260908132433_community_policy_client_status_rpc` only. It adds no table,
RLS, table-grant, trigger, policy, or business-data mutation. Its durable
effects are the migration-history record plus two function definitions and
their function ACLs:

- `public.bil_current_community_policy_status()` is owned by `postgres`,
  `SECURITY INVOKER`, `STABLE`, and fixed to an empty `search_path`. It is
  executable only by `authenticated`, uses `statement_timestamp()` as the
  server clock, returns the current active/effective policy and only the
  caller's own receipt under existing RLS, and returns `unavailable` unless
  cardinality is exactly one.
- `public.bil_assert_community_publish_ready()` is owned by `postgres`,
  no-argument, `SECURITY DEFINER`, `VOLATILE`, and fixed to an empty
  `search_path`. It is executable only by `authenticated`, first requires a
  JWT-bound actor, then `public.bil_can_use_community()`, then the private
  exact-policy receipt assertion. `anon`, `service_role`, and `PUBLIC` have
  no execute privilege. It has no caller-supplied identity and performs no
  DML.

The migration's preflight and postcondition checks completed successfully.
The post-deploy transactional SQL runtime scenarios passed, with zero test
residue. Independent readback found exactly one total/active/effective policy,
zero acceptance rows, RLS still enabled on both policy tables, all five Social
v2 tables present with RLS enabled, all 17 expected Social v2 functions
present, and zero `TRUNCATE`, `TRIGGER`, or `REFERENCES` privileges for either
`anon` or `authenticated` across public relations.

The security advisor now reports
`authenticated_security_definer_function_executable` for
`bil_assert_community_publish_ready()`. This is an intentional, reviewed
warning—not a reason to revoke its authenticated execution or switch it to
invoker mode. The narrow endpoint is the published self-only assertion
boundary described above; the function's fixed search path, no-argument
signature, JWT-bound identity, membership guard, private receipt guard, and
explicit ACL prevent it from becoming a general privileged interface. No
advisor-driven permission change was made.

## Post-deploy policy ledger and Storage hardening

Three additional forward migrations were applied individually after dry-runs
listed only the intended pending file:

- `20260908175000_community_policy_storage_upload_guard` adds a restrictive
  authenticated INSERT policy on `storage.objects` for
  `community-post-images`. It calls the no-argument publish-readiness assertion,
  closing pre-acceptance and suspended-user orphan uploads while retaining the
  existing permissive owner/path policy.
- `20260908180500_community_policy_version_immutability` binds a private row
  trigger that rejects identity edits, deletes and inactive-to-active
  reactivation. Active-to-inactive remains available for a reviewed versioned
  supersession.
- `20260908181500_community_policy_ledger_postconditions` requires exactly one
  canonical active v1 row with the reviewed locale, URL and effective time, then
  binds a private `BEFORE TRUNCATE FOR EACH STATEMENT` guard. The trigger
  function is `SECURITY DEFINER`, fixed to an empty search path and executable
  only by `postgres`.

None of the three migrations performs policy, receipt, Storage-object or other
business-data DML; none changes Community table RLS or grants. The final current
SQL fixture executed every scenario inside `BEGIN`/`ROLLBACK` and passed. The
post-test residue count was zero for all 11 tracked categories. Independent
readback remained one active/effective `community-policy-v1`, zero production
acceptances, five RLS-enabled Social v2 tables, 17 Social v2 functions, zero
dangerous current/default client privileges and four preserved future
`service_role` defaults. Each of the three migration versions has exactly one
live history row.

## Live Edge Functions

All required functions are `ACTIVE` at the time of inspection:

| Function | Version | Platform JWT setting | Reconciliation note |
| --- | ---: | --- | --- |
| `ai-coach` | 49 | disabled | Must authenticate internally; inspect source and live behavior before any release claim. |
| `verify-store-purchase` | 27 | disabled | Must authenticate internally; keep store server verification fail-closed. |
| `play-integrity` | 23 | enabled | Local source verifies session, Google token, exact request binding, licensing, app recognition, device integrity, replay, and issues a bounded grant only on allow. |
| `app-attest` | 12 | enabled | Local source validates authentication, challenge/nonce, certificate chain/signature, counter replay, environment/version/category binding, then issues a bounded grant. |
| `account-data-deletion` | 18 | enabled | Present; local migrations establish idempotent worker/timeout/cleanup path. Device and live queue execution evidence remains required. |
| `community-push-dispatch` | 12 | disabled | Must authenticate or verify a trusted server invocation internally. Its dispatch idempotency migration is present. |
| `ai-coach-global-reset` | 18 | enabled | Present. No entitlement/admin grant was created or modified in this review. |
| `barcode-lookup` | 27 | disabled | Out of scope beyond presence/status. |
| `food-search` | 15 | disabled | Out of scope beyond presence/status. |
| `apple-sign-in-token` | 7 | enabled | Present. |
| `apple-sign-in-notifications` | 7 | disabled | Expected webhook-style endpoint; verify signed notification handling separately. |

Disabled platform JWT is not inherently a defect for webhook/custom-auth functions, but it is a release gate: each listed function needs source-level authentication coverage plus a real endpoint test before it can be called release-ready.

### Source parity check (2026-09-08)

The active deployment sources for the six in-scope functions were read through
the Management API and compared with both the checked-out source and the
matching `.codex_server_reconciliation` snapshot. No secret value or runtime
configuration value was read or recorded. The exact and normalized SHA-256
manifest covered all 19 deployed files. Normalization removes an optional UTF-8
BOM, normalizes line endings to LF, and removes terminal LF bytes solely for
this serialization comparison.

| Function | Active version / live bundle | Files | Exact local-to-live result | Normalized result |
| --- | --- | ---: | --- | --- |
| `app-attest` | 12 / `f0f8aa…70482` | 1 | One terminal LF only: local/snapshot `17dbab…04c6d`; live `d9c3b9…cfaba` has no final LF. | 1/1 equal |
| `play-integrity` | 23 / `a0c5f4…99c42` | 1 | 1/1 equal (`853c14…afc2`). Snapshot has one extra terminal LF. | 1/1 equal |
| `ai-coach` | 49 / `24c0a8…35066` | 5 | 5/5 equal. Each snapshot file has one extra terminal LF. | 5/5 equal |
| `verify-store-purchase` | 27 / `d152eaf…230f9` | 7 | 7/7 equal. Each snapshot file has one extra terminal LF. | 7/7 equal |
| `community-push-dispatch` | 12 / `0863f4…3e05` | 1 | 1/1 equal (`896a2d…915cf`). Snapshot has one extra terminal LF. | 1/1 equal |
| `account-data-deletion` | 18 / `bbf6b1…349d5` | 4 | 4/4 equal. Each snapshot file has one extra terminal LF. | 4/4 equal |

Thus there is no semantic source drift or deployment candidate to deploy from
this comparison. The terminal-LF differences are snapshot/API text
serialization artifacts, not code differences. This result does not certify
runtime configuration or endpoint behavior.

The configuration identifiers observed without reading their values include
`BIL_MOBILE_INTEGRITY_ENFORCEMENT`, `BIL_APP_ATTEST_ALLOW_LEGACY`,
`BIL_APP_ATTEST_APP_ID`, `BIL_APP_ATTEST_BUNDLE_VERSIONS`,
`BIL_APP_ATTEST_ENVIRONMENTS`, `BIL_PLAY_INTEGRITY_PACKAGE_NAME`, and
`BIL_PLAY_INTEGRITY_SERVICE_ACCOUNT_JSON`. Their presence in source and source
parity were verified; their production values/presence were not disclosed or
changed. The necessary follow-up is signed-device evidence: real App Attest
and Play Integrity allow/deny/replay paths, custom-auth AI Coach and purchase
canaries, a trusted Community push event, and an end-to-end disposable-account
deletion/worker/storage cleanup flow.

## RLS, grants, and default-privilege results

The live security advisor reports 40 `rls_enabled_no_policy` findings. Many are intentionally service-only/private tables (for example private admin and credential tables); the public findings include service-owned tables such as `bil_app_attest_keys`, `bil_ai_qa_grants`, `bil_ai_usage_config`, `bil_barcode_shared_cache`, and `bil_cloud_key_refs`. An RLS-no-policy finding is not permission to add a broad policy: doing so could expose security data.

The subsequent bounded catalog audit established that all 40 RLS-no-policy
relations have zero `anon`/`authenticated` `SELECT`, `INSERT`, `UPDATE`,
`DELETE`, `TRUNCATE`, `REFERENCES`, `TRIGGER`, and `MAINTAIN` privileges. They
remain intentionally locked service/RPC-only relations at the time of audit;
this is not a reason to create permissive policies.

The same audit found a future-object gap: `postgres`-owned relations created in
schema `public` would inherit `TRUNCATE`, `REFERENCES`, `TRIGGER`, and
`MAINTAIN` for `anon` and `authenticated`. Global dangerous defaults were
already zero; the public-schema default ACL had the eight role/privilege
combinations. After a transactional pre-apply probe passed, CLI-only forward
migration `20260908141133_harden_public_default_table_privileges` was applied.
Its rollback test `supabase/tests/default_privileges_hardening_test.sql` passed.
Postconditions are: client/PUBLIC dangerous global and `public` defaults zero,
the four `service_role` defaults preserved, no synthetic probe relation left,
and one migration-history row. It changes future default ACLs for
`postgres`-owned `public` relations only; it made no business-data, RLS,
existing-table ACL, role, or table mutation.

The advisor's 62 `authenticated_security_definer_function_executable` findings
are not a single class of defect. The reviewed
`bil_assert_community_publish_ready()` finding is intentional: it is a narrow,
no-argument, JWT-bound, fixed-search-path assertion with only
`authenticated` execute. The remaining 61 functions require individual
interface/ACL/search-path review; do not apply a blanket revoke or grant to
silence the advisor. The `auth_leaked_password_protection` finding is also not
a migration defect: read-only console evidence shows `BIL Health` is on the
Free plan and the control is unavailable below Pro. The Email provider and
secure-email-change controls are enabled. Enabling leaked-password protection
therefore needs an owner plan/configuration decision, not database DDL.

The performance advisor separately reports:

- 29 `unindexed_foreign_keys` suggestions, including the policy-acceptance
  version foreign key.
- 16 `auth_rls_initplan` suggestions (replace repeated `auth.*` calls in RLS predicates with scalar subselects).
- 4 `multiple_permissive_policies` suggestions for `bil_cloud_records` and `bil_follows`.
- 16 `unused_index` suggestions across existing application tables.

The restrictive Community Storage guard created no new multiple-permissive-
policy finding.

These are performance/maintenance candidates, not validated authorization failures. Each needs an explain-plan, policy-equivalence test, and a forward migration before production change.

## Local integrity implementation review

`supabase/functions/play-integrity/index.ts` is deliberately fail-closed: it requires a valid user session, rate-limits before remote decoding, binds request hash/action/payload digest, requires `PLAY_RECOGNIZED`, `LICENSED`, a recognized package/certificate/version, `MEETS_DEVICE_INTEGRITY`, and writes a one-time bounded grant only after the verdict passes. Replay only returns an already outstanding exact grant.

`supabase/functions/app-attest/index.ts` performs certificate-chain, certificate-signature, nonce, application identifier, environment/version, validation-category, sign-counter and replay checks. Its legacy attestation path is explicit opt-in (`BIL_APP_ATTEST_ALLOW_LEGACY=true`) and records `legacy-unreported`; this must remain disabled in production unless a documented compatibility decision and device evidence justify it.

## Store-console read-only audit (2026-09-08)

The current Google Play Console for `com.bilhealth.bodyintelligencelog` was
available for a read-only UI audit. Its dashboard says `Ready to publish`, but
Production is `Inactive`: the production-access application is under review
(`Applied Sunday, 10:22`; the console says the decision normally takes seven
days or less). The active artifact is Android App Bundle version code `8`,
version name `1.0.0`, uploaded 2026-09-06 15:07. It is available only in
Closed testing - Alpha as a full rollout (177 of 177 testers, install base
0.00%, release updated 2026-09-06 19:16). No production release was shown.

Managed publishing is on. The Publishing overview shows exactly one change
ready to publish: an `en-GB` default-store-listing full-description change;
the `Publish 1 change` control was deliberately not used. This confirms an
unpublished listing change, not a release approval or a production rollout.
The production-access review and the required signed-device/store canaries
remain blockers.

App Store Connect could not be audited beyond its current sign-in boundary:
the retained browser tab showed the Apple Account sign-in screen at the Apps
target URL with `authResult=FAILED`. Authentication was not attempted or
automated. Consequently, current Apple app/build/review/subscription state and
the exact `MISSING_METADATA` field are **not verified** by this audit; do not
infer or edit them from the prior generic API status.

## Release conclusion

The read-only audits and rollback fixtures made no persistent test-data change.
The controlled CLI applications added the two Community RPCs/function ACLs,
scoped future default-ACL hardening, the restrictive Storage guard and the two
append-only ledger triggers, plus their migration-history records. None changed
production business data. The server is **not certified release-ready** from
this snapshot alone. The concrete blockers are (1) bounded live tests for
custom-auth Edge Functions and device integrity, (2) signed iOS/Android device
evidence, and (3) an owner plan/configuration decision for leaked-password
protection. The remaining individually unreviewed `SECURITY DEFINER`
interfaces must not be changed in bulk. Existing security hardening, RLS,
grants, Store/AI Coach entitlements, and Community policy data must not be
rebuilt or widened while resolving them.
