# Supabase advisor triage — 2026-09-08

## Scope, evidence, and production state

This is a live, relation-by-relation and function-by-function triage of project
`tgmanzhqulksykhslrzb` (`body-intelligence-log`). The initial full snapshot was
at `2026-09-08 17:55:22+00`; the post-remediation live readback was at
`2026-09-08 18:08:01+00`, PostgreSQL `17.6`, using Supabase CLI `2.116.0`.
The CLI reported that `2.117.0` is available; that version notice does not
change the database-side advisor results below.

The live inspection began read-only. After it proved two unsafe, unused direct
settlement interfaces, the owner explicitly authorized the ACL-only migration.
It was first exercised with its SQL test inside an explicit final-`ROLLBACK`
transaction, then deployed, and the standalone test was rerun with its own
final `ROLLBACK`. The only production changes are the two function ACLs and the
new `supabase_migrations` history entry. No function body and no application
table row was changed.

Evidence inspected for every security finding:

- live advisor metadata;
- `pg_proc`, function bodies, owners, volatility, `proconfig`, and effective
  function ACLs;
- table RLS state, policies, table ACLs, constraints, triggers, and referenced
  functions;
- local callers in `lib/` and `supabase/functions/`, excluding tests and
  migrations;
- live migration history and local migrations `20260908181600` through
  `20260908182100`;
- live relation/index statistics for performance findings. Database statistics
  were last reset at `2026-07-24 08:28:18+00`.

No App Attest enforcement, entitlement, purchase, or user-acceptance data was
changed. App Attest/store relations appear only where the advisor itself lists
their catalog metadata.

## Executive result

| Advisor | Level | Finding | Count | Triage |
| --- | --- | --- | ---: | --- |
| Security | INFO | `rls_enabled_no_policy` | 42 | All 42 are intentional internal/fail-closed relations; zero have `anon` or `authenticated` DML privileges. |
| Security | WARN | `authenticated_security_definer_function_executable` | 67 | 51 intentional client RPCs, 15 internal/fail-closed helpers or dormant owner-bound endpoints, and 1 unsafe/BLOCKED interface. Two additional unsafe interfaces found in the initial 69 were closed by `182200`. |
| Security | WARN | `auth_leaked_password_protection` | 1 | Real configuration warning, but unavailable on the current Free plan; requires Pro+ and an owner configuration decision. |
| Performance | WARN | `auth_rls_initplan` | 16 | Existing; 15 are actionable in a tested policy-equivalence migration, one purchase-policy item is deferred to that lane. |
| Performance | WARN | `multiple_permissive_policies` | 4 | Existing and actionable after equivalence tests; no authorization failure proven. |
| Performance | INFO | `unindexed_foreign_keys` | 29 | Existing; prioritize 10 growth/cascade paths, 15 before scale, and defer 4 store/purchase items to their owner lane. |
| Performance | INFO | `unused_index` | 15 | Existing/monitor only. All are tiny or support planned/maintenance paths; zero-scan evidence alone is insufficient to drop them. |

Current remediation links:

- [RLS enabled with no policy — lint 0008](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)
- [Authenticated SECURITY DEFINER — lint 0029](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable)
- [Leaked-password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)
- [RLS initplan — lint 0003](https://supabase.com/docs/guides/database/database-linter?lint=0003_auth_rls_initplan)
- [Multiple permissive policies — lint 0006](https://supabase.com/docs/guides/database/database-linter?lint=0006_multiple_permissive_policies)
- [Unindexed foreign keys — lint 0001](https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys)
- [Unused indexes — lint 0005](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index)

## Security: 42 RLS relations with no policy

Common verified boundary: all 42 have RLS enabled and no policy, are owned by
`postgres`, and have **no** `SELECT`, `INSERT`, `UPDATE`, or `DELETE` privilege
for either `anon` or `authenticated`. Therefore adding a permissive policy to
silence the INFO finding would weaken the current design. Only four integrity
relations have explicit `service_role` DML (`bil_app_attest_keys`,
`bil_mobile_integrity_challenges`, `bil_mobile_integrity_grants`, and
`bil_play_integrity_events`); the remaining relations are reached through
reviewed owner functions/administrative paths.

| # | Relation | Classification | Body/caller evidence and purpose |
| ---: | --- | --- | --- |
| 1 | `private.bil_admin_ai_boost_grants` | Internal/fail-closed | Admin grant ledger; referenced by private admin-notice grant logic only. |
| 2 | `private.bil_admin_notification_audit` | Internal/fail-closed | Append-only notification audit used by admin enqueue functions. |
| 3 | `private.bil_admin_notification_message_overrides` | Internal/fail-closed | Server-side message overrides used by the bounded admin enqueue function. |
| 4 | `private.bil_ai_coach_admins` | Internal/fail-closed | Administrative authority source used by capability/admin functions; never client-table readable. |
| 5 | `private.bil_ai_coach_reset_token_grants` | Internal/fail-closed | Reset-token grant ledger written through a private function. |
| 6 | `private.bil_apple_sign_in_credentials` | Internal/fail-closed | Encrypted Apple credential custody; its catalog comment explicitly limits access to service-only RPCs. |
| 7 | `private.bil_community_member_access` | Internal/fail-closed | Suspension authority read by community guards and Social v2 visibility functions. |
| 8 | `private.bil_community_member_access_audit` | Internal/fail-closed | Suspension/reinstatement audit trail. |
| 9 | `private.bil_community_moderator_admin_audit` | Internal/fail-closed | Moderator add/remove audit trail. |
| 10 | `public.bil_ai_credit_config` | Internal/fail-closed | Server-owned AI allowance configuration read by usage reservation/status functions. |
| 11 | `public.bil_ai_qa_grants` | Internal/fail-closed | QA-only credit-grant ledger; no client table ACL. |
| 12 | `public.bil_ai_usage_config` | Internal/fail-closed | Server configuration relation; no current direct function reference and no client ACL. |
| 13 | `public.bil_app_attest_keys` | Internal/fail-closed | Server key/receipt registry; catalog/ACL inspected only, enforcement not changed. |
| 14 | `public.bil_barcode_shared_cache` | Internal/fail-closed | Barcode cache reachable through get/put RPCs, not through table access. |
| 15 | `public.bil_cloud_key_refs` | Internal/fail-closed | Owner-to-Vault reference map reached by cloud-key RPCs. |
| 16 | `public.bil_community_audit_events` | Internal/fail-closed | Moderation/action audit sink. |
| 17 | `public.bil_community_moderators` | Internal/fail-closed | Moderator authority relation; read through capability/moderation functions and guarded by a member-access trigger. |
| 18 | `public.bil_community_post_approval_grants` | Internal/fail-closed | Immutable per-post reward receipt written during human moderation. |
| 19 | `public.bil_community_post_reward_policy` | Internal/fail-closed | Singleton reward policy read during moderation. |
| 20 | `public.bil_community_post_reward_usage` | Internal/fail-closed | Daily reward-cap ledger locked and updated during moderation. |
| 21 | `public.bil_mobile_integrity_challenges` | Internal/fail-closed | Server verification challenge state; catalog/ACL inspected only. |
| 22 | `public.bil_mobile_integrity_grants` | Internal/fail-closed | Short-lived one-use server verification grants consumed through a bounded RPC. |
| 23 | `public.bil_play_integrity_events` | Internal/fail-closed | Server-written verdict audit; raw tokens are not stored. |
| 24 | `public.bil_push_delivery_attempts` | Internal/fail-closed | Push delivery lease/result state used by service-only dispatch functions. |
| 25 | `public.bil_push_delivery_policy` | Internal/fail-closed | Server push retry/delivery policy. |
| 26 | `public.bil_push_device_tokens` | Internal/fail-closed | Token registry reached by owner-bound registration/preference RPCs and service dispatch. |
| 27 | `public.bil_push_outbox` | Internal/fail-closed | Server notification queue reached by enqueue/claim/finalize functions. |
| 28 | `public.bil_rate_limit_buckets` | Internal/fail-closed | Per-user fixed-window counters, exclusively mutated by the hardened rate-limit function. |
| 29 | `public.bil_sensitive_request_receipts` | Internal/fail-closed | Idempotency receipts written by the authenticated, owner-bound claim function. |
| 30 | `public.bil_social_comment_likes_v2` | Internal/fail-closed | Social v2 RPC backing table; reads/writes stay inside actor/visibility-checked functions. |
| 31 | `public.bil_social_comment_reports_v2` | Internal/fail-closed | Social v2 report ledger; user creation and moderator resolution are RPC-only. |
| 32 | `public.bil_social_comments_v2` | Internal/fail-closed | Social v2 comment store protected by RPCs plus policy-acceptance trigger. |
| 33 | `public.bil_social_handles_v2` | Internal/fail-closed | Social identity map exposed only through bounded search/identity RPCs. |
| 34 | `public.bil_social_post_likes_v2` | Internal/fail-closed | Social v2 post-like backing table. |
| 35 | `public.bil_social_post_saves_v2` | Internal/fail-closed | New in `181700`; owner-only save backing table, intentionally RPC-only. |
| 36 | `public.bil_social_public_codes_v2` | Internal/fail-closed | New in `181700`; random-code map, exact-lookup/rate-limited RPC-only. |
| 37 | `public.bil_store_entitlement_audit` | Internal/fail-closed | Store entitlement audit; catalog/ACL inspected only, purchase behavior untouched. |
| 38 | `public.bil_store_notification_inbox` | Internal/fail-closed | Idempotent server notification inbox; purchase behavior untouched. |
| 39 | `public.bil_store_product_registry` | Internal/fail-closed | Server product registry; purchase behavior untouched. |
| 40 | `public.bil_vision_model_pricing` | Internal/fail-closed | Server pricing table read by the bounded cost estimator. |
| 41 | `public.bil_vision_quota_config` | Internal/fail-closed | Server quota configuration read by owner-bound vision functions. |
| 42 | `public.bil_vision_runtime_config` | Internal/fail-closed | Reservation TTL configuration read by reclaim logic. |

Result: **42 internal/fail-closed, 0 intentional direct-table client
interfaces, 0 unsafe relations.** No policy or GRANT should be added merely to
clear this INFO class.

## Security: 67 current authenticated SECURITY DEFINER functions

The table below preserves the complete 69-function initial inspection. Rows 45
and 46 are marked remediated and no longer appear in the final advisor; the
other 67 are the current set.

### Shared ACL/body observations

- All 67 current findings are owned by `postgres`, explicitly set
  `search_path`, and grant
  `EXECUTE` to `authenticated`.
- `PUBLIC` execute count is 0 and `anon` execute count is 0.
- 34 use an empty search path. The other 33 use a fixed non-empty path; live
  checks confirm `anon`, `authenticated`, and `service_role` cannot `CREATE` in
  `public`, `extensions`, `vault`, or `private`, preventing search-path object
  shadowing by those API roles.
- No reviewed body contains dynamic SQL or `SET ROLE`.
- 63 bodies call `auth.uid()` directly. The other four are two deliberately
  narrow boolean helpers (`bil_has_community_moderators`,
  `bil_recipient_allows_community_message`) and two one-line public-code
  wrappers whose private invoker helper performs the JWT/community checks.

Classification legend:

- **Client RPC**: a deliberate user/administrator Data API contract with a
  reviewed actor, visibility, input, or idempotency boundary.
- **Internal/fail-closed**: policy/nested/Edge helper or currently dormant
  owner-bound endpoint. Keeping it callable may be architectural debt, but the
  reviewed body does not establish a cross-user privilege escalation.
- **Unsafe/action required**: authenticated execution exposes a proven
  integrity/privacy boundary that should be closed or redesigned.

| # | Function | Classification | Local caller(s) and reviewed controls |
| ---: | --- | --- | --- |
| 1 | `bil_assert_community_publish_ready()` | Client RPC | Flutter preflight plus Storage policy; requires JWT, unsuspended membership, and current policy acceptance. |
| 2 | `bil_block_community_member(uuid)` | Client RPC | Community repository; actor-bound insert, rejects self, removes only relationships involving the actor. |
| 3 | `bil_can_manage_ai_coach()` | Client RPC | Admin UI and reset Edge Function; returns true only for the active JWT-bound private admin row. |
| 4 | `bil_can_moderate_community_post_image(text)` | Internal/fail-closed | Storage read-policy predicate; requires JWT moderator and exact pending post media path. |
| 5 | `bil_can_use_community()` | Internal/fail-closed | Called by Storage/Social guards; JWT-bound and serialized against suspension/reinstatement with an advisory transaction lock. |
| 6 | `bil_claim_sensitive_request(text,text,text)` | Internal/fail-closed | No runtime caller found; JWT-bound, three-action allowlist, fixed rate limit, and actor-owned receipt. Candidate revoke/archive after compatibility evidence. |
| 7 | `bil_consume_rate_limit(text,integer,integer)` | Internal/fail-closed | Four Edge callers and many database callers; `181600` now permits only 32 reviewed action/limit/window tuples and rejects arbitrary bucket keys. |
| 8 | `bil_create_support_request(text,text,text,jsonb)` | Client RPC | Settings repository; JWT-bound with category, subject, message, and 32 KiB context bounds. Operational rate limiting remains a follow-up. |
| 9 | `bil_delete_message(uuid)` | Client RPC | Community repository; updates deletion timestamps only where JWT is sender or recipient. |
| 10 | `bil_disable_push_tokens()` | Client RPC | Push service; disables only rows whose `user_id=auth.uid()`. |
| 11 | `bil_dismiss_admin_notice(uuid,uuid)` | Client RPC | Notice service; supplied owner must equal JWT and notification must be unseen. |
| 12 | `bil_dismiss_ai_coach_reset_notice(uuid,uuid)` | Client RPC | Notice/settings UI; supplied owner must equal JWT and reset notice must be unseen. |
| 13 | `bil_estimate_vision_cost(text,text,integer,integer)` | Internal/fail-closed | Analyze-meal Edge Function; authenticated read-only pricing lookup with nonnegative token checks. |
| 14 | `bil_finalize_food_submission(uuid,text)` | Client RPC | Moderator UI; moderator membership and decision allowlist precede the update. |
| 15 | `bil_follow_member(uuid)` | Client RPC | Community repository; exact rate contract, target opt-in, database self-follow constraint, and community member-access trigger. |
| 16 | `bil_get_ai_usage_status()` | Client RPC | Multiple Flutter consumers; JWT owner filters every ledger mutation/read and stale reservations are locked before refund. |
| 17 | `bil_get_existing_cloud_key()` | Client RPC | Cloud-key repository; JWT owner, latest cloud-sync consent, owner key reference, then exact Vault secret. |
| 18 | `bil_get_or_create_cloud_key()` | Client RPC | Cloud-key repository; JWT owner and per-owner advisory lock; creates/returns only that owner's random key. Consent is enforced by the calling flow, not this body. |
| 19 | `bil_get_push_preferences()` | Client RPC | Push service; aggregates only JWT owner's token rows. |
| 20 | `bil_get_vision_usage()` | Internal/fail-closed | No runtime caller found; read-only JWT-owner quota/usage response. Candidate revoke/archive after compatibility evidence. |
| 21 | `bil_has_community_moderators(uuid)` | Internal/fail-closed | Only database moderation guards call it; exposes only a boolean and has authenticated-only ACL, but should move to `private` in a future dependency migration. |
| 22 | `bil_is_community_moderator()` | Client RPC | Community repository and nested Social moderator RPCs; exact JWT membership boolean. |
| 23 | `bil_list_community_connections()` | Client RPC | Community repository; only friendships involving JWT, excludes bilateral blocks, and limits states to pending/accepted. |
| 24 | `bil_list_open_community_reports()` | Client RPC | Moderator UI; moderator check and 200-row bound. |
| 25 | `bil_list_pending_community_posts(integer)` | Client RPC | Moderator feed; JWT/moderator checks and clamped 1–200 limit. |
| 26 | `bil_list_reviewable_products()` | Client RPC | Moderator UI; moderator check, allowed review states, 40-row bound. |
| 27 | `bil_mark_conversation_read(uuid)` | Client RPC | Community repository; updates only messages received by JWT from the requested sender. |
| 28 | `bil_mark_message_read(uuid)` | Internal/fail-closed | No runtime caller found; updates only a message whose recipient is JWT. Candidate revoke/archive after compatibility evidence. |
| 29 | `bil_moderate_community_post(uuid,text)` | Client RPC | Moderator UI; JWT/moderator checks, row lock, rejects own post/redecision, immutable reward receipt and daily cap. |
| 30 | `bil_moderate_community_report(uuid,text,text)` | Client RPC | Moderator UI; moderator check, action/status allowlists, report row lock, and audit write. |
| 31 | `bil_publish_diary_snapshot(date,jsonb,integer)` | Client RPC | Sharing repository; JWT owner, date/revision validation, 256 KiB payload cap, owner/day upsert. |
| 32 | `bil_read_shared_diary(uuid,date,text)` | **Unsafe/action required — BLOCKED** | Sharing repository. It accepts a reusable SHA-256 bearer value for a UI key whose minimum is only six characters and has no attempt rate limit. A direct patch could break existing links/keys; requires compatible KDF/salt/high-entropy and throttling design. |
| 33 | `bil_recipient_allows_community_message(uuid)` | Internal/fail-closed | Message RLS helper; boolean-only lookup with authenticated-only ACL. Move to `private` in a dependency migration to remove direct RPC exposure. |
| 34 | `bil_reclaim_stale_vision_reservations()` | Internal/fail-closed | Called by reserve RPC; JWT-owner-only stale state correction using server TTL. |
| 35 | `bil_record_ai_coach_feedback(text,boolean,text,text,text)` | Client RPC | Feedback service; JWT owner, enum/length checks, and cloud responses must match a succeeded owner usage event. |
| 36 | `bil_record_consent(text,text,boolean)` | Client RPC | Multiple consent flows; JWT owner, purpose allowlist, version length bound, owner/purpose/version upsert. |
| 37 | `bil_register_push_token(text,text,text,boolean)` | Client RPC | Push service; JWT required, token/platform validation, fingerprint uniqueness, and ownership becomes current caller's device registration. |
| 38 | `bil_request_account_deletion(text)` | Client RPC | Account UI/community repository; JWT owner, per-owner lock, idempotent pending request, daily exact rate tuple, disables only owner tokens. |
| 39 | `bil_request_friendship(uuid)` | Internal/fail-closed | Called by Social v2 wrapper; exact rate tuple, rejects self, bilateral block check, and target opt-in. |
| 40 | `bil_reserve_vision_request(text,text)` | Internal/fail-closed | No runtime caller found; JWT-owner quota, input/digest validation, idempotency, duplicate-image check, and row locking. Candidate revoke/archive after compatibility evidence. |
| 41 | `bil_search_community_foods(text,integer)` | Client RPC | Community food client; JWT, two-character minimum, 1–20 clamp, live food-kind/state filters. |
| 42 | `bil_search_community_profiles(text,integer)` | Internal/fail-closed | No runtime caller found; read-only discoverability/opt-in/block filters and 30-row clamp. Candidate revoke/archive after compatibility evidence. |
| 43 | `bil_set_diary_share_settings(text,text)` | Client RPC | Sharing repository; JWT owner, visibility allowlist, exact 64-hex digest required for locked mode. |
| 44 | `bil_set_sensitive_push_previews(boolean)` | Client RPC | Push service; updates only JWT owner's tokens and coerces null to false. |
| 45 | `bil_settle_vision_request(text,boolean,text,text,integer,integer,integer,numeric,jsonb)` | **Remediated; no longer current advisor** | No runtime caller found. Any signed-in user could mark an owner reservation succeeded/refunded and write caller-supplied provider/model/metrics/response JSON. `182200` now makes it service-only. |
| 46 | `bil_settle_vision_request_v2(text,boolean,text,text,integer,integer,integer,numeric,jsonb,integer,text)` | **Remediated; no longer current advisor** | Same former direct settlement surface as v1, plus caller-supplied attempts/cost source. `182200` now makes it service-only. |
| 47 | `bil_social_add_comment_v2(uuid,text,uuid,uuid)` | Client RPC | Social repository; membership/policy acceptance, post/reply visibility, contact-exchange rejection, bounds, idempotency lock. |
| 48 | `bil_social_claim_handle_v2(text)` | Client RPC | Social repository; membership/profile checks, strict handle validation, one-time chosen identity semantics, serialization. |
| 49 | `bil_social_comment_reports_v2(integer)` | Internal/fail-closed | No Flutter caller yet; planned moderator list, requires moderator and unsuspended state, clamps to 100, excludes own authored comments. |
| 50 | `bil_social_comments_v2(uuid,timestamptz,uuid,integer)` | Client RPC | Social repository; visible post requirement, paired cursor validation, and bounded pagination. |
| 51 | `bil_social_delete_comment_v2(uuid)` | Client RPC | Social repository; unsuspended membership and author-only soft removal. |
| 52 | `bil_social_identity_v2()` | Client RPC | Social repository/private code helper; membership/profile checks and serialized generated identity creation. |
| 53 | `bil_social_like_comment_v2(uuid,boolean)` | Client RPC | Social repository; membership, visible comment/reply chain, boolean validation, actor-keyed insert/delete. |
| 54 | `bil_social_like_v2(uuid,boolean)` | Client RPC | Social repository; membership, visible post, boolean validation, actor-keyed insert/delete. |
| 55 | `bil_social_post_authors_v2(uuid[])` | Client RPC | Social repository; JWT/membership, 200-member cap, block/privacy/friendship-aware projection. |
| 56 | `bil_social_public_code_v2()` | Client RPC | Social repository; one-line wrapper to a non-executable private invoker helper that performs JWT/membership/profile/locking checks. |
| 57 | `bil_social_report_comment_v2(uuid,text)` | Client RPC | Social repository; membership, visible non-own comment, reason bounds/allowlist, reporter/comment idempotency. |
| 58 | `bil_social_request_friend_v2(uuid)` | Client RPC | Social repository; Social membership/visibility checks followed by the block/rate/opt-in legacy friendship helper. |
| 59 | `bil_social_resolve_comment_report_v2(uuid,boolean)` | Internal/fail-closed | No Flutter caller yet; moderator + unsuspended checks, locked open report, rejects own-comment review, actor-bound resolution. |
| 60 | `bil_social_resolve_public_code_v2(text)` | Client RPC | Social repository; JWT/membership, exact 32-hex shape, 60/minute rate tuple, uniform null for invalid/rotated/private/blocked/suspended targets. |
| 61 | `bil_social_rotate_public_code_v2()` | Client RPC | Social repository; private helper uses JWT/profile lock and 5/day rotation rate. |
| 62 | `bil_social_save_v2(uuid,boolean)` | Client RPC | Social repository; JWT/membership, boolean validation, visible post, actor/post keyed insert/delete. |
| 63 | `bil_social_saved_posts_v2(timestamptz,uuid,integer)` | Client RPC | Social repository; JWT/membership, paired cursor validation, owner-only saved rows and bounded page. |
| 64 | `bil_social_saved_state_v2(uuid[])` | Client RPC | Social repository; JWT/membership, 200-post cap, owner-only saved-state projection. |
| 65 | `bil_social_search_handles_v2(text,integer)` | Client RPC | Social repository; membership, fixed rate tuple, bounded query/results and profile visibility filters. |
| 66 | `bil_social_stats_v2(uuid[])` | Client RPC | Social repository; JWT, 200-post cap, visible-post filtering, aggregate-only result. |
| 67 | `bil_unfollow_member(uuid)` | Client RPC | Community repository; deletes only the JWT actor's exact follow row. |
| 68 | `bil_upsert_community_food_contribution(jsonb)` | Client RPC | Community food client; JWT owner, UUID/name/serving validation, table numeric/barcode constraints, owner/client-id upsert to pending. Abuse-rate and JSON-shape limits remain follow-ups. |
| 69 | `bil_withdraw_community_food_contribution(text)` | Client RPC | Community food client; updates only JWT owner's matching live contribution. |

Current totals: **51 client RPCs, 15 internal/fail-closed, 1 unsafe/BLOCKED**.
The initial audit found two additional unsafe functions, both now remediated.
The internal class should be reduced gradually after API-usage/compatibility
evidence; it is not safe to mass-revoke the remaining 67 warnings.

### Deployed closure for the two settlement RPCs

Applied forward migration:
`supabase/migrations/20260908182200_harden_vision_settlement_execution.sql`.

It changes ACLs only:

- preflights exact signatures, `SECURITY DEFINER`, `postgres` ownership, and
  the currently reviewed ACL state;
- revokes `PUBLIC`, `anon`, and `authenticated` execute;
- retains only `service_role` execute;
- does not replace either function body and does not read/write application
  data;
- has explicit postconditions and a PostgREST schema reload notification.

Companion test:
`supabase/tests/vision_settlement_execution_hardening_test.sql`.

The migration and test first passed a live transactional rollback probe. The
migration was then applied, the test passed again inside its own rollback, and
the final ACL readback is `PUBLIC=false`, `anon=false`,
`authenticated=false`, `service_role=true` for both signatures. The final
advisor confirms the expected reduction from 69 to 67 SECURITY DEFINER warnings
and from 112 to 110 total security findings.

### BLOCKED: compatible diary-share redesign

`bil_read_shared_diary` cannot be safely fixed by merely adding its current
arguments to `bil_consume_rate_limit`: that limiter keys only by caller/action/
window, while compatibility needs careful limits per caller and target without
creating a target-enumeration oracle. Existing clients also send the raw
SHA-256 of a user-selected key (minimum six characters), so changing the digest
contract in place would invalidate existing shares.

A safe forward design needs an owner/product compatibility decision:

1. introduce a versioned verifier (for example `locked_v2`) using a salted,
   slow password KDF or a generated high-entropy share secret;
2. add a non-enumerating attempt ledger keyed by caller plus a blinded target
   identifier, with bounded retention;
3. keep legacy shares readable during an explicit migration window, while
   strongly prompting owners to rotate;
4. never expose which of owner/day/key failed;
5. add SQL tests for success, wrong key, blocked relationship, rate exhaustion,
   cross-target abuse, legacy compatibility, and final retirement.

No diary secret or existing share setting was changed in this task.

## Effect of migrations 181600–182200

All six migrations are present in live `supabase_migrations.schema_migrations`:

| Version | Name | Advisor impact |
| --- | --- | --- |
| `20260908181600` | `harden_rate_limit_contract` | No count change. It materially reduces risk of the existing rate-limit warning by adding the exact action/limit/window allowlist and empty search path. |
| `20260908181700` | `community_social_saves_and_public_codes` | Adds two intentional RLS/no-policy RPC-only tables and six intentional authenticated Social RPCs: net `+2` INFO and `+6` WARN. |
| `20260908181800` | `backend_function_lint_closure` | No net count change. Public-code shared logic moved to a non-executable private invoker helper; the service-only push claim remains outside this authenticated warning class. |
| `20260908181900` | `community_social_post_authors_v2` | Adds one intentional authenticated, visibility-bounded Social RPC: net `+1` WARN. |
| `20260908182000` | `community_social_post_authors_volatility` | Volatility correction only; no count change. |
| `20260908182100` | `community_social_handle_backfill_and_reply_visibility` | Tightens existing Social bodies and adds a private trigger helper; no count change. |
| `20260908182200` | `harden_vision_settlement_execution` | ACL-only: removes `authenticated` from two unused settlement functions, retains `service_role`; net `-2` WARN. No body/application-data change. |

The same-day pre-181600 baseline in `docs/recovery/SERVER_RECONCILIATION.md`
was 40 RLS/no-policy + 62 authenticated SECURITY DEFINER + 1 leaked-password
warning = 103. Migrations 181600–182100 produced 42 + 69 + 1 = 112 exactly
through the two new backing tables and seven new reviewed Social RPCs above;
`182200` then reduced the current state to 42 + 67 + 1 = **110** without
reversing the earlier hardening.

Performance was 65 at that baseline (29/16/4/16). It is now 64
(29/16/4/15): no new performance finding was introduced by 181600–182200, and
one formerly zero-scan index no longer appears. The historical report did not
record the old 16 names, so this report does not invent which index left the
list.

## Performance triage

### 16 `auth_rls_initplan`

All 16 existed before 181600. The safe mechanical form is to replace per-row
`auth.uid()`/`current_setting()` evaluation with the equivalent scalar
`(select auth.uid())`, preserving policy command, roles, `USING`, and
`WITH CHECK`. This requires policy-equivalence and cross-user tests before a
forward migration.

| Relation / policy | Status |
| --- | --- |
| `bil_public_profiles.bil_profiles_privacy_read` | Existing/actionable |
| `bil_consent_receipts.bil_consent_receipts_own_read` | Existing/actionable |
| `bil_ai_weekly_usage.bil_ai_weekly_usage_read_own` | Existing/actionable |
| `bil_ai_paid_balances.bil_ai_paid_balances_read_own` | Existing/actionable |
| `bil_messages.bil_messages_read_parties` | Existing/actionable |
| `bil_follows.bil_follows_read` | Existing/actionable; coordinate with policy consolidation below |
| `bil_follows.bil_follows_own_write` | Existing/actionable; coordinate with policy consolidation below |
| `bil_content_policy_acceptances.bil_policy_acceptance_own` | Existing/actionable; preserve version-bound acceptance semantics |
| `bil_cloud_records.bil_cloud_records_owner_select` | Existing/actionable; coordinate with policy consolidation below |
| `bil_cloud_records.bil_cloud_records_owner_insert` | Existing/actionable; coordinate with policy consolidation below |
| `bil_cloud_records.bil_cloud_records_owner_update` | Existing/actionable; coordinate with policy consolidation below |
| `bil_cloud_operations.bil_cloud_operations_owner_select` | Existing/actionable |
| `bil_cloud_operations.bil_cloud_operations_owner_insert` | Existing/actionable |
| `bil_ai_boost_purchases.bil_ai_boost_purchases_read_own` | Existing/deferred to purchase lane |
| `bil_ai_coach_subscriptions.bil_ai_coach_subscriptions_read_own` | Existing/actionable |
| `bil_ai_usage_events.bil_ai_usage_events_read_own` | Existing/actionable |

### 4 `multiple_permissive_policies`

All four existed before 181600 and are actionable only after proving the pairs
are semantically redundant. Because permissive policies OR together, deleting
the wrong member can narrow legitimate access or leave a broader path.

| Relation/action | Policies | Status |
| --- | --- | --- |
| `bil_cloud_records` INSERT | `bil_cloud_records_owner_insert`, `bil_records_insert_own` | Existing/actionable with equivalence tests |
| `bil_cloud_records` SELECT | `bil_cloud_records_owner_select`, `bil_records_select_own` | Existing/actionable with equivalence tests |
| `bil_cloud_records` UPDATE | `bil_cloud_records_owner_update`, `bil_records_update_own` | Existing/actionable with equivalence tests |
| `bil_follows` SELECT | `bil_follows_own_write`, `bil_follows_read` | Existing/actionable; first separate read from write semantics |

### 29 `unindexed_foreign_keys`

All 29 existed before 181600. Current tables are small (0–78 estimated rows in
this set), so these are scale/cascade maintenance items rather than current
authorization failures. Proposed priority preserves the no-purchase scope.

| Foreign key | Rows now | Priority/classification |
| --- | ---: | --- |
| `private.bil_admin_ai_boost_grants_owner_id_fkey` | 0 | Existing; before scale |
| `private.bil_ai_coach_admins_granted_by_fkey` | 2 | Existing; before scale |
| `private.bil_ai_coach_global_reset_audit_actor_id_fkey` | 0 | Existing; before scale |
| `private.bil_ai_coach_individual_reset_audit_actor_id_fkey` | 3 | Existing; before scale |
| `private.bil_ai_coach_individual_reset_audit_target_id_fkey` | 3 | Existing; before scale |
| `private.bil_ai_coach_reset_token_grants_owner_id_fkey` | 0 | Existing; before scale |
| `private.bil_community_member_access_reinstated_by_fkey` | 0 | Existing; before scale |
| `private.bil_community_member_access_suspended_by_fkey` | 0 | Existing; before scale |
| `private.bil_community_member_access_audit_actor_id_fkey` | 5 | Existing; before scale |
| `private.bil_community_member_access_audit_target_id_fkey` | 5 | Existing; before scale |
| `private.bil_community_moderator_admin_audit_actor_id_fkey` | 0 | Existing; before scale |
| `private.bil_community_moderator_admin_audit_target_id_fkey` | 0 | Existing; before scale |
| `public.bil_ai_boost_purchases_owner_id_fkey` | 0 | Existing; deferred to purchase lane |
| `public.bil_ai_qa_grants_owner_id_fkey` | 1 | Existing; before scale |
| `public.bil_community_audit_events_actor_id_fkey` | 78 | Existing/actionable priority |
| `public.bil_community_post_approval_grants_approved_by_fkey` | 1 | Existing; before scale |
| `public.bil_community_posts_author_id_fkey` | 4 | Existing/actionable before feed growth and user cascade |
| `public.bil_community_reports_reporter_id_fkey` | 1 | Existing/actionable before moderation growth |
| `public.bil_content_policy_acceptances_policy_version_fkey` | 0 | Existing/actionable before acceptance growth; preserve version ledger |
| `public.bil_follows_followed_id_fkey` | 0 | Existing/actionable before graph growth/user cascade |
| `public.bil_food_peer_reviews_reviewer_id_fkey` | 0 | Existing; before scale |
| `public.bil_friendships_addressee_id_fkey` | 1 | Existing/actionable before graph growth/user cascade |
| `public.bil_messages_recipient_id_fkey` | 5 | Existing/actionable before message growth/user cascade |
| `public.bil_push_delivery_attempts_device_token_id_fkey` | 0 | Existing/actionable before delivery growth/token cascade |
| `public.bil_push_device_tokens_user_id_fkey` | 0 | Existing/actionable before user cascade |
| `public.bil_store_entitlement_audit_owner_id_fkey` | 9 | Existing; deferred to purchase lane |
| `public.bil_store_receipts_owner_id_fkey` | 0 | Existing; deferred to purchase lane |
| `public.bil_subscriptions_provider_product_fkey` | 4 | Existing; deferred to purchase lane |
| `public.bil_support_requests_owner_id_fkey` | 0 | Existing/actionable before support growth/user cascade |

### 15 `unused_index`

All 15 are existing, zero-scan indexes. The tables are currently tiny and many
indexes support maintenance, partial, future-growth, or recently introduced
Social/integrity paths. PostgreSQL may correctly choose sequential scans at
these sizes. **Do not drop any solely to clear this advisor.** Re-evaluate after
a representative production window with query plans and write-amplification
measurements.

| Index | Estimated rows / size | Classification |
| --- | --- | --- |
| `bil_public_profiles_discoverable_name_idx` | 1 / 16 kB | Existing/monitor; supports discoverable-name ordering/search |
| `bil_cloud_records_pull_idx` | 194 / 40 kB | Existing/monitor; pull cursor index, table still too small for reliable usage inference |
| `bil_coach_memories_owner_kind_idx` | 0 / 8 kB | Existing/monitor; partial active-memory path |
| `bil_coach_experiments_owner_history_idx` | 0 / 8 kB | Existing/monitor; partial owner-history path |
| `bil_food_status_idx` | 1 / 16 kB | Existing/monitor; moderation/status ordering |
| `bil_food_live_search_trgm_idx` | 1 / 24 kB | Existing/monitor; GIN live-search path |
| `bil_food_submission_barcode_status_idx` | 1 / 16 kB | Existing/monitor; partial barcode lookup |
| `bil_play_integrity_events_decision_created_idx` | 92 / 16 kB | Existing/monitor; audit investigation path; enforcement untouched |
| `bil_community_posts_media_path_idx` | 4 / 16 kB | Existing/monitor; pending media moderation lookup |
| `bil_app_attest_keys_receipt_purge_idx` | 1 / 16 kB | Existing/monitor; maintenance/purge path; App Attest untouched |
| `bil_mobile_integrity_grants_owner_expiry_idx` | 16 / 16 kB | Existing/monitor; unconsumed-grant cleanup/lookup |
| `bil_social_comments_author_v2` | 0 / 16 kB | Existing/monitor; author cascade/moderation path |
| `bil_social_comments_removed_by_v2` | 0 / 16 kB | Existing/monitor; partial moderator audit path |
| `bil_social_reports_reviewer_v2` | 0 / 16 kB | Existing/monitor; partial reviewed-report path |
| `bil_social_reports_reporter_v2` | 0 / 16 kB | Existing/monitor; reporter relationship/cascade path |

## Leaked-password protection and current plan

The advisor still correctly reports `auth_leaked_password_protection`: the
control is disabled. The same-day read-only Supabase console evidence recorded
in `docs/recovery/SERVER_RECONCILIATION.md` identifies organization `BIL Health`
as being on the **Free** plan. The current CLI readback confirms the same
organization/project is `ACTIVE_HEALTHY`, although the CLI project JSON does
not expose the billing tier.

Supabase's current official documentation states that leaked-password
protection is available on **Pro and above**, and the pricing matrix lists it
as not included on Free:

- [Password security documentation](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)
- [Supabase pricing matrix](https://supabase.com/pricing)

Therefore this warning cannot be remediated with database DDL on the current
plan. The safe next action is an owner decision to upgrade and enable the Auth
setting; do not build a custom password-hash workaround in Postgres.

## Verification record and next actions

Completed:

1. final live security advisors rerun: `110 = 42 INFO + 67 WARN + 1 WARN`
   (the intended two-warning reduction is live);
2. live performance advisors rerun: `64 = 16 WARN + 4 WARN + 29 INFO + 15 INFO`;
3. every RLS/no-policy table ACL and every authenticated SECURITY DEFINER body,
   owner, path, ACL, dependency, and local caller triaged above;
4. migration list readback is **121/121 aligned**, with zero local-only and
   zero remote-only versions; 181600–182200 are all present live;
5. `20260908182200_harden_vision_settlement_execution.sql` plus
   `vision_settlement_execution_hardening_test.sql` passed a live final-rollback
   probe; `182200` was then deployed and the test passed again in rollback;
6. final ACL readback proves both settlement signatures are
   `PUBLIC=false`, `anon=false`, `authenticated=false`, `service_role=true`;
7. linked `db lint` completed with no error finding and two unrelated
   `warning extra` results: unused `p_sensitive_preview_allowed` in
   `bil_register_push_token`, and unused `p_batch_size` in
   `private.bil_process_account_deletions`; `182200` modified neither body;
8. production application data is unchanged. The only live mutations were the
   two ACLs and the migration-history row.

Required next actions, in order:

1. make the product/security compatibility decision for versioned diary-share
   credentials and throttling; do not patch legacy hashes in place;
2. prepare a separate policy-equivalence migration for 15 in-scope initplan
   warnings and four permissive-policy overlaps;
3. add the ten priority foreign-key indexes with concurrent/lock-aware rollout
   appropriate to hosted Supabase, then address the fifteen low-volume entries
   before scale;
4. monitor, but do not drop, the 15 zero-scan indexes until representative
   traffic and `EXPLAIN` evidence exist;
5. upgrade to Pro+ and enable leaked-password protection if the owner accepts
   that operational cost/configuration change.
