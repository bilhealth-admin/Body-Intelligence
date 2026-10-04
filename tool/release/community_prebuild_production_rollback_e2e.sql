-- DRAFT / NOT EXECUTED: prepared 2026-10-04 from read-only LIVE signatures.
-- Project: tgmanzhqulksykhslrzb. This file is NOT a migration or a build.
-- ROOT REVIEW REQUIRED. Execute only after exact staging Targeted + Candidate
-- are SUCCESS and the following exact migration NAMEs exist once each:
-- community_prebuild_privacy_write_hardening_v1
-- community_atomic_publish_operation_v1
-- notification_delivery_preferences_authority_v1
-- Source filenames 20261004073453 / 20261004074954 / 20261004094021 are NOT Production version
-- requirements: MCP apply_migration generates its own timestamp. Names alone
-- do NOT attest body identity. Root must independently read back migration
-- statements plus relevant functions/grants/policies/triggers and compare them
-- to the QA-approved source bodies before executing this transaction. Retain
-- that source/hash/name/actual-version mapping as evidence outside this script.
--
-- EXECUTION PROTOCOL (three separate tool calls; no session-reuse assumption):
-- 1. Execute segment PRECHECK only, retain its 68-table JSON externally, require
--    zero_synthetic_rows=true and inventoried_table_count=68.
-- 2. Execute segment TRANSACTION only. PASS requires the explicit status and
--    every assertion. The DO block's exception subtransaction rolls back ALL
--    its writes on a database exception, records the exact FAIL/SQLSTATE/error,
--    and permits the unconditional final ROLLBACK to execute. Tool/transport
--    errors remain FAILURE, never success. Never retry before independent
--    residue/error review. There is NO COMMIT in this file.
-- 3. Execute segment RESIDUE only independently, even if step 2 fails. Require
--    zero_synthetic_rows=true and all 68 row counts. Compare global counts only
--    for reporting (real concurrent users can legitimately change them).
-- Do not run this entire file through a connector that returns only its final
-- statement: a last successful readback does not erase a failed transaction.
--
-- Explicit setup only: two never-existing auth.users UUIDs (no usable password,
-- no Auth/HTTP login), ordinary authenticated-owned profile/policy writes,
-- and one synthetic moderator roster row, ALL within this rollback transaction.
-- The real moderation RPC is called by that distinct authenticated moderator.
-- Moderator provisioning Edge Function/admin UI is NOT covered by this setup.
-- No helper/table/function/temp DDL, GRANT, policy/config changes, existing-user
-- edits, Storage HTTP, provider dispatch, network calls, or direct post seeding.
-- Notification proof here is ONLY new synthetic-owner zero-token desired-state
-- CAS/write/readback/privacy. NEVER call bil_claim_push_deliveries or register
-- provider tokens in Production; retry/race proof belongs to the local fixture.
-- Read-only LIVE configuration 2026-10-04: one current community-policy-v1;
-- actual approval policy 5 credits / max5 per UTC day; real active Topics/Circles.
--
-- Evidence boundaries: SQL identities/claims do NOT prove genuine Auth login,
-- device UI/accessibility, delayed transport/storage bytes, provider push, or
-- a human's UI review action. Negative Storage INSERT tests must fail before any
-- object row exists; no synthetic physical file/metadata success is invented.
-- Concurrency, prepared/new-ID caps and Storage delete/reinsert were proved in
-- isolated PG fixtures, not re-tested here by changing Production configuration.
-- Sequence values may advance despite rollback; sequence gaps are NOT data rows.
-- The permanent Google reviewer account is intentional and NOT in these UUIDs.
-- Inventory cost review 2026-10-04 (catalog/statistics only, NOT execution):
-- 66 currently existing tables total 786432 heap bytes / 5095424 bytes including
-- indexes, with pg_stat_user_tables estimated live rows=1409. Journal and desired
-- notification tables are not applied yet. Recheck sizes immediately before execution; estimates are not
-- exact counts or a latency proof. Exact global COUNT still scans relations.
-- Auth/Storage residue checks use known synthetic UUID/FK/email/path columns,
-- NOT whole rows (no password/token/credential JSON serialization). Separate
-- residue subqueries permit existing PK/user/email/name-prefix indexes; the
-- planner may legitimately choose a sequential scan for these tiny tables.
-- refresh_tokens.user_id and Storage owner columns have no standalone index.
-- Read-only EXPLAIN (not ANALYZE) currently selects users_pkey Index Only Scan
-- for UUID lookup, refresh_tokens_instance_id_user_id_idx Index Only Scan for
-- user_id lookup, and Seq Scan for the 10-row Storage name-prefix probe. These
-- are selected component plans, NOT execution/timing proof for the full audit.
-- Narrow predicates never serialize token/password/object metadata fields.
--
-- BEGIN SEGMENT PRECHECK
-- PRECHECK: READ-ONLY; execute separately and retain the returned JSON externally.
-- Counts may change because of genuine concurrent traffic. Never require global equality.
-- synthetic_rows must be zero for EVERY row; missing tables/errors are NOT a pass.
with marker as (
  select 'bil_prebuild_rollback_20261004_18970beb|18970beb-5e1c-4ec0-9254-dda7437b4cf6|1958c6c4-edea-4135-b04c-35f31e0f8571|be21d52a-bbdd-440b-9615-d4813f9553b8|18716ad9-a16d-47fd-bf19-6aa6e967d7b0|580d488e-ea06-43bf-9745-9d921cc7e3fd|64e7f014-1fff-47dd-b016-a280b7b6f6f1|ec5f3513-89a9-42dd-bdc1-4790b0ac37cc|05fd5bed-4c4d-4003-b27f-9e464cf6c79e|0d02f9d0-2e11-4d1a-abb4-94915c30ca80|690ae7d1-6fd1-4cf3-9dcc-9089ee50161c'::text as pattern,
    array['18970beb-5e1c-4ec0-9254-dda7437b4cf6','1958c6c4-edea-4135-b04c-35f31e0f8571','be21d52a-bbdd-440b-9615-d4813f9553b8','18716ad9-a16d-47fd-bf19-6aa6e967d7b0','580d488e-ea06-43bf-9745-9d921cc7e3fd','64e7f014-1fff-47dd-b016-a280b7b6f6f1','ec5f3513-89a9-42dd-bdc1-4790b0ac37cc','05fd5bed-4c4d-4003-b27f-9e464cf6c79e','0d02f9d0-2e11-4d1a-abb4-94915c30ca80','690ae7d1-6fd1-4cf3-9dcc-9089ee50161c']::uuid[] as identifiers,
    array['18970beb-5e1c-4ec0-9254-dda7437b4cf6','1958c6c4-edea-4135-b04c-35f31e0f8571']::uuid[] as owners,
    array['18970beb-5e1c-4ec0-9254-dda7437b4cf6','1958c6c4-edea-4135-b04c-35f31e0f8571']::text[] as owner_strings,
    array['bil_prebuild_rollback_20261004_18970beb-a@example.invalid','bil_prebuild_rollback_20261004_18970beb-b@example.invalid']::text[] as emails,
    'bil_prebuild_rollback_20261004_18970beb'::text as audit_marker,
    array['18970beb-5e1c-4ec0-9254-dda7437b4cf6/%','1958c6c4-edea-4135-b04c-35f31e0f8571/%']::text[] as owner_path_prefixes
),
inventory as (
  select 'auth.users' as table_name,
    (select count(*) from auth.users) as total_rows,
    (select count(*) from auth.users t where t.id=any(marker.identifiers) or t.email=any(marker.emails)
      or t.raw_user_meta_data->>'audit_marker'=marker.audit_marker) as synthetic_rows
  from marker
  union all
  select 'private.bil_admin_notification_audit' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from private.bil_admin_notification_audit t cross join marker
  union all
  select 'private.bil_admin_notification_message_overrides' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from private.bil_admin_notification_message_overrides t cross join marker
  union all
  select 'public.bil_account_deletion_requests' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_account_deletion_requests t cross join marker
  union all
  select 'public.bil_ai_credit_balances' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_ai_credit_balances t cross join marker
  union all
  select 'public.bil_ai_credit_monthly_usage' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_ai_credit_monthly_usage t cross join marker
  union all
  select 'public.bil_ai_credit_weekly_usage' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_ai_credit_weekly_usage t cross join marker
  union all
  select 'public.bil_community_notifications' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_notifications t cross join marker
  union all
  select 'public.bil_community_post_approval_grants' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_post_approval_grants t cross join marker
  union all
  select 'public.bil_community_post_circles' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_post_circles t cross join marker
  union all
  select 'public.bil_community_post_collaborators_v1' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_post_collaborators_v1 t cross join marker
  union all
  select 'public.bil_community_post_draft_media_v1' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_post_draft_media_v1 t cross join marker
  union all
  select 'public.bil_community_post_drafts_v1' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_post_drafts_v1 t cross join marker
  union all
  select 'public.bil_community_post_hashtags_v1' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_post_hashtags_v1 t cross join marker
  union all
  select 'public.bil_community_post_locations_v1' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_post_locations_v1 t cross join marker
  union all
  select 'public.bil_community_post_media_v1' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_post_media_v1 t cross join marker
  union all
  select 'public.bil_community_post_mentions_v1' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_post_mentions_v1 t cross join marker
  union all
  select 'public.bil_community_post_reward_usage' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_post_reward_usage t cross join marker
  union all
  select 'public.bil_community_post_topics' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_post_topics t cross join marker
  union all
  select 'public.bil_community_post_views_v1' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_post_views_v1 t cross join marker
  union all
  select 'public.bil_community_posts' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_posts t cross join marker
  union all
  select 'public.bil_community_quest_progress' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_quest_progress t cross join marker
  union all
  select 'public.bil_community_quest_progress_events' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_quest_progress_events t cross join marker
  union all
  select 'public.bil_community_reputation_accounts' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_reputation_accounts t cross join marker
  union all
  select 'public.bil_community_reward_claim_audit' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_reward_claim_audit t cross join marker
  union all
  select 'public.bil_gold_accounts' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_gold_accounts t cross join marker
  union all
  select 'public.bil_gold_ledger' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_gold_ledger t cross join marker
  union all
  select 'public.bil_public_profiles' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_public_profiles t cross join marker
  union all
  select 'public.bil_push_outbox' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_push_outbox t cross join marker
  union all
  select 'public.bil_rate_limit_buckets' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_rate_limit_buckets t cross join marker
  union all
  select 'public.bil_sensitive_request_receipts' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_sensitive_request_receipts t cross join marker
  union all
  select 'public.bil_social_handles_v2' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_social_handles_v2 t cross join marker
  union all
  select 'public.bil_store_notification_inbox' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_store_notification_inbox t cross join marker
  union all
  select 'public.bil_support_requests' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_support_requests t cross join marker
  union all
  select 'public.bil_vision_request_receipts' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_vision_request_receipts t cross join marker
  union all
  select 'storage.objects' as table_name,
    (select count(*) from storage.objects) as total_rows,
    (select count(*) from storage.objects t where t.id=any(marker.identifiers) or t.owner=any(marker.owners)
      or t.owner_id=any(marker.owner_strings) or t.name like any(marker.owner_path_prefixes)) as synthetic_rows
  from marker
  union all
  select 'public.bil_follows' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_follows t cross join marker
  union all
  select 'auth.identities' as table_name,
    (select count(*) from auth.identities) as total_rows,
    (select count(*) from auth.identities t where t.id=any(marker.identifiers) or t.user_id=any(marker.owners)
      or t.provider_id=any(marker.owner_strings) or t.email=any(marker.emails)) as synthetic_rows
  from marker
  union all
  select 'auth.sessions' as table_name,
    (select count(*) from auth.sessions) as total_rows,
    (select count(*) from auth.sessions t where t.id=any(marker.identifiers) or t.user_id=any(marker.owners)) as synthetic_rows
  from marker
  union all
  select 'auth.refresh_tokens' as table_name,
    (select count(*) from auth.refresh_tokens) as total_rows,
    (select count(*) from auth.refresh_tokens t where t.user_id=any(marker.owner_strings)) as synthetic_rows
  from marker
  union all
  select 'private.bil_community_publish_operations_v1' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from private.bil_community_publish_operations_v1 t cross join marker
  union all
  select 'private.bil_community_member_access' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from private.bil_community_member_access t cross join marker
  union all
  select 'private.bil_community_member_access_audit' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from private.bil_community_member_access_audit t cross join marker
  union all
  select 'private.bil_community_moderator_admin_audit' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from private.bil_community_moderator_admin_audit t cross join marker
  union all
  select 'public.bil_blocks' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_blocks t cross join marker
  union all
  select 'public.bil_friendships' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_friendships t cross join marker
  union all
  select 'public.bil_community_audit_events' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_audit_events t cross join marker
  union all
  select 'public.bil_community_circle_memberships' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_circle_memberships t cross join marker
  union all
  select 'public.bil_community_moderators' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_moderators t cross join marker
  union all
  select 'public.bil_content_policy_acceptances' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_content_policy_acceptances t cross join marker
  union all
  select 'public.bil_community_polls' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_polls t cross join marker
  union all
  select 'public.bil_community_poll_options' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_poll_options t cross join marker
  union all
  select 'public.bil_community_poll_votes' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_poll_votes t cross join marker
  union all
  select 'public.bil_social_comments_v2' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_social_comments_v2 t cross join marker
  union all
  select 'public.bil_social_comment_likes_v2' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_social_comment_likes_v2 t cross join marker
  union all
  select 'public.bil_social_comment_reports_v2' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_social_comment_reports_v2 t cross join marker
  union all
  select 'public.bil_social_post_likes_v2' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_social_post_likes_v2 t cross join marker
  union all
  select 'public.bil_social_post_saves_v2' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_social_post_saves_v2 t cross join marker
  union all
  select 'public.bil_social_public_codes_v2' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_social_public_codes_v2 t cross join marker
  union all
  select 'public.bil_community_xp_ledger' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_xp_ledger t cross join marker
  union all
  select 'public.bil_community_referral_attributions' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_referral_attributions t cross join marker
  union all
  select 'public.bil_community_invites' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_invites t cross join marker
  union all
  select 'public.bil_community_creator_certifications_v1' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_creator_certifications_v1 t cross join marker
  union all
  select 'public.bil_community_reports' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_reports t cross join marker
  union all
  select 'public.bil_messages' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_messages t cross join marker
  union all
  select 'public.bil_push_delivery_attempts' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_push_delivery_attempts t cross join marker
  union all
  select 'public.bil_push_device_tokens' as table_name, count(*) as total_rows,
    count(*) filter (where t.user_id=any(marker.owners)) as synthetic_rows
  from public.bil_push_device_tokens t cross join marker
  union all
  select 'private.bil_push_delivery_preferences_v1' as table_name,
    (select count(*) from private.bil_push_delivery_preferences_v1) as total_rows,
    (select count(*) from private.bil_push_delivery_preferences_v1 t
      where t.user_id=any(marker.owners)) as synthetic_rows
  from marker
)
select pg_catalog.statement_timestamp() as inspected_at,
  pg_catalog.jsonb_agg(pg_catalog.to_jsonb(inventory) order by table_name) as table_inventory,
  pg_catalog.bool_and(synthetic_rows=0) as zero_synthetic_rows,
  count(*) as inventoried_table_count
from inventory;
-- END SEGMENT PRECHECK

-- BEGIN SEGMENT TRANSACTION
begin;
set local statement_timeout='45s';
set local lock_timeout='3s';
set local idle_in_transaction_session_timeout='60s';

do $audit$
declare
  v_a constant uuid:='18970beb-5e1c-4ec0-9254-dda7437b4cf6';
  v_b constant uuid:='1958c6c4-edea-4135-b04c-35f31e0f8571';
  v_accept constant uuid:='be21d52a-bbdd-440b-9615-d4813f9553b8';
  v_decline constant uuid:='18716ad9-a16d-47fd-bf19-6aa6e967d7b0';
  v_draft constant uuid:='580d488e-ea06-43bf-9745-9d921cc7e3fd';
  v_delete_draft constant uuid:='64e7f014-1fff-47dd-b016-a280b7b6f6f1';
  v_comment constant uuid:='ec5f3513-89a9-42dd-bdc1-4790b0ac37cc';
  v_reply constant uuid:='05fd5bed-4c4d-4003-b27f-9e464cf6c79e';
  v_media_op constant uuid:='0d02f9d0-2e11-4d1a-abb4-94915c30ca80';
  v_tombstone constant uuid:='690ae7d1-6fd1-4cf3-9dcc-9089ee50161c';
  v_marker constant text:='bil_prebuild_rollback_20261004_18970beb';
  v_ids constant uuid[]:=array[v_a,v_b,v_accept,v_decline,v_draft,v_delete_draft,
    v_comment,v_reply,v_media_op,v_tombstone];
  v_pattern constant text:='bil_prebuild_rollback_20261004_18970beb|18970beb-5e1c-4ec0-9254-dda7437b4cf6|1958c6c4-edea-4135-b04c-35f31e0f8571|be21d52a-bbdd-440b-9615-d4813f9553b8|18716ad9-a16d-47fd-bf19-6aa6e967d7b0|580d488e-ea06-43bf-9745-9d921cc7e3fd|64e7f014-1fff-47dd-b016-a280b7b6f6f1|ec5f3513-89a9-42dd-bdc1-4790b0ac37cc|05fd5bed-4c4d-4003-b27f-9e464cf6c79e|0d02f9d0-2e11-4d1a-abb4-94915c30ca80|690ae7d1-6fd1-4cf3-9dcc-9089ee50161c';
  v_tables constant text[]:=array[
    'auth.users',
    'private.bil_admin_notification_audit',
    'private.bil_admin_notification_message_overrides',
    'public.bil_account_deletion_requests',
    'public.bil_ai_credit_balances',
    'public.bil_ai_credit_monthly_usage',
    'public.bil_ai_credit_weekly_usage',
    'public.bil_community_notifications',
    'public.bil_community_post_approval_grants',
    'public.bil_community_post_circles',
    'public.bil_community_post_collaborators_v1',
    'public.bil_community_post_draft_media_v1',
    'public.bil_community_post_drafts_v1',
    'public.bil_community_post_hashtags_v1',
    'public.bil_community_post_locations_v1',
    'public.bil_community_post_media_v1',
    'public.bil_community_post_mentions_v1',
    'public.bil_community_post_reward_usage',
    'public.bil_community_post_topics',
    'public.bil_community_post_views_v1',
    'public.bil_community_posts',
    'public.bil_community_quest_progress',
    'public.bil_community_quest_progress_events',
    'public.bil_community_reputation_accounts',
    'public.bil_community_reward_claim_audit',
    'public.bil_gold_accounts',
    'public.bil_gold_ledger',
    'public.bil_public_profiles',
    'public.bil_push_outbox',
    'public.bil_rate_limit_buckets',
    'public.bil_sensitive_request_receipts',
    'public.bil_social_handles_v2',
    'public.bil_store_notification_inbox',
    'public.bil_support_requests',
    'public.bil_vision_request_receipts',
    'storage.objects',
    'public.bil_follows',
    'auth.identities',
    'auth.sessions',
    'auth.refresh_tokens',
    'private.bil_community_publish_operations_v1',
    'private.bil_community_member_access',
    'private.bil_community_member_access_audit',
    'private.bil_community_moderator_admin_audit',
    'public.bil_blocks',
    'public.bil_friendships',
    'public.bil_community_audit_events',
    'public.bil_community_circle_memberships',
    'public.bil_community_moderators',
    'public.bil_content_policy_acceptances',
    'public.bil_community_polls',
    'public.bil_community_poll_options',
    'public.bil_community_poll_votes',
    'public.bil_social_comments_v2',
    'public.bil_social_comment_likes_v2',
    'public.bil_social_comment_reports_v2',
    'public.bil_social_post_likes_v2',
    'public.bil_social_post_saves_v2',
    'public.bil_social_public_codes_v2',
    'public.bil_community_xp_ledger',
    'public.bil_community_referral_attributions',
    'public.bil_community_invites',
    'public.bil_community_creator_certifications_v1',
    'public.bil_community_reports',
    'public.bil_messages',
    'public.bil_push_delivery_attempts',
    'public.bil_push_device_tokens',
    'private.bil_push_delivery_preferences_v1'
  ];
  v_table text; v_predicate text; v_uid uuid; v_count bigint; v_expected bigint;
  v_topic text; v_circle text; v_policy text; v_handle text;
  v_payload jsonb; v_payload_decline jsonb; v_media_payload jsonb;
  v_result jsonb; v_first jsonb; v_profile jsonb; v_creator jsonb;
  v_checks jsonb:='{}'; v_group jsonb; v_check record;
  v_error_state text; v_error_message text; v_error_context text; v_paths text[];
  v_cursor_time timestamptz; v_cursor_id uuid; v_first_page jsonb;
  v_path text; v_option uuid; v_tokens integer; v_cap integer;
begin
  -- No API role bypass and no direct-table permission manufactured for testing.
  if exists(select 1 from pg_roles where rolname in('anon','authenticated')
      and (rolsuper or rolbypassrls)) then
    raise exception 'AUDIT ordinary API roles unexpectedly bypass RLS';
  end if;
  if (select count(*) from supabase_migrations.schema_migrations
      where name='community_prebuild_privacy_write_hardening_v1')<>1
      or (select count(*) from supabase_migrations.schema_migrations
      where name='community_atomic_publish_operation_v1')<>1
      or (select count(*) from supabase_migrations.schema_migrations
      where name='notification_delivery_preferences_authority_v1')<>1
      or to_regprocedure('public.bil_publish_community_post_operation_v1(uuid,jsonb)') is null
      or to_regprocedure('public.bil_get_my_push_delivery_categories_v1()') is null
      or to_regprocedure('public.bil_set_my_push_delivery_categories_v1(boolean,boolean,boolean,bigint)') is null then
    raise exception 'AUDIT required permanent forward migrations are not applied';
  end if;
  if has_table_privilege('anon','private.bil_community_publish_operations_v1','SELECT,INSERT,UPDATE,DELETE')
     or has_table_privilege('authenticated','private.bil_community_publish_operations_v1','SELECT,INSERT,UPDATE,DELETE')
     or has_table_privilege('service_role','private.bil_community_publish_operations_v1','SELECT,INSERT,UPDATE,DELETE') then
    raise exception 'AUDIT journal no longer RPC-only';
  end if;
  if has_table_privilege('anon','private.bil_push_delivery_preferences_v1','SELECT,INSERT,UPDATE,DELETE')
     or has_table_privilege('authenticated','private.bil_push_delivery_preferences_v1','SELECT,INSERT,UPDATE,DELETE')
     or has_table_privilege('service_role','private.bil_push_delivery_preferences_v1','SELECT,INSERT,UPDATE,DELETE') then
    raise exception 'AUDIT notification desired state no longer RPC-only';
  end if;

  -- Re-check complete identity/resource absence immediately before mutation.
  foreach v_table in array v_tables loop
    v_predicate:=case v_table
      when 'auth.users' then 't.id=any($2) or t.email=any($5) or t.raw_user_meta_data->>''audit_marker''=$7'
      when 'auth.identities' then 't.id=any($2) or t.user_id=any($3) or t.provider_id=any($4) or t.email=any($5)'
      when 'auth.sessions' then 't.id=any($2) or t.user_id=any($3)'
      when 'auth.refresh_tokens' then 't.user_id=any($4)'
      when 'storage.objects' then 't.id=any($2) or t.owner=any($3) or t.owner_id=any($4) or t.name like any($6)'
      when 'public.bil_push_device_tokens' then 't.user_id=any($3)'
      when 'private.bil_push_delivery_preferences_v1' then 't.user_id=any($3)'
      else 'to_jsonb(t)::text ~ $1' end;
    execute format('select count(*) from %s t where %s',v_table::regclass,v_predicate)
      into v_count using v_pattern,v_ids,array[v_a,v_b],array[v_a::text,v_b::text],
        array[v_marker||'-a@example.invalid',v_marker||'-b@example.invalid'],
        array[v_a::text||'/%',v_b::text||'/%'],v_marker;
    if v_count<>0 then raise exception 'AUDIT pre-existing synthetic rows in %',v_table; end if;
  end loop;
  if exists(select 1 from public.bil_social_handles_v2
      where handle in('qa18970beb','qa1958c6c4')) then
    raise exception 'AUDIT pre-existing synthetic handle';
  end if;
  -- No uncommitted row is visible to the external outbox worker. Refuse new
  -- direct Auth/notification/outbox hooks rather than assume they are harmless.
  if exists(select 1 from pg_trigger where not tgisinternal and tgrelid in(
      'auth.users'::regclass,'public.bil_community_notifications'::regclass,
      'public.bil_push_outbox'::regclass)) then
    raise exception 'AUDIT external-boundary trigger inventory changed; review required';
  end if;
  if (select count(*) from public.bil_content_policies
      where active and effective_at<=statement_timestamp())<>1 then
    raise exception 'AUDIT current policy unavailable';
  end if;
  select version into strict v_policy from public.bil_content_policies
    where active and effective_at<=statement_timestamp();
  select tokens_per_approval,max_rewarded_posts_per_owner_per_utc_day
    into strict v_tokens,v_cap from public.bil_community_post_reward_policy where singleton;
  if v_tokens<>5 or v_cap<2 then raise exception 'AUDIT approval configuration changed'; end if;
  select slug into v_topic from public.bil_community_topics
    where active order by slug limit 1;
  select slug into v_circle from public.bil_community_circles
    where active and access='public' and join_policy='open' order by slug limit 1;
  if v_topic is null or v_circle is null then
    raise exception 'AUDIT real active topic/open circle missing; no fake configuration';
  end if;

  -- SQL-only new identities: no password and no external Auth operation.
  insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,
      raw_app_meta_data,raw_user_meta_data,is_anonymous)
    values
      (v_a,'authenticated','authenticated',v_marker||'-a@example.invalid',
       now(),now(),now(),'{"provider":"email","providers":["email"]}',
       jsonb_build_object('audit_marker',v_marker),false),
      (v_b,'authenticated','authenticated',v_marker||'-b@example.invalid',
       now(),now(),now(),'{"provider":"email","providers":["email"]}',
       jsonb_build_object('audit_marker',v_marker),false);

  foreach v_uid in array array[v_a,v_b] loop
    perform set_config('request.jwt.claim.sub',v_uid::text,true);
    perform set_config('request.jwt.claims',
      jsonb_build_object('sub',v_uid,'role','authenticated')::text,true);
    execute 'set local role authenticated';
    if current_user<>'authenticated' or auth.uid() is distinct from v_uid then
      raise exception 'AUDIT authenticated principal mismatch';
    end if;
    v_result:=public.bil_get_my_push_delivery_categories_v1();
    if v_result->>'owner_id' is distinct from v_uid::text or not (v_result @>
       '{"initialized":false,"revision":0,"message_enabled":null,"friend_request_enabled":null,
         "friend_accepted_enabled":null,"effective_message_enabled":false,
         "effective_friend_request_enabled":false,"effective_friend_accepted_enabled":false,
         "synchronized":false}'::jsonb) then
      raise exception 'AUDIT fresh owner notification state is not unknown and isolated';
    end if;
    v_first:=public.bil_set_my_push_delivery_categories_v1(false,v_uid=v_b,false,0);
    if v_first->>'owner_id' is distinct from v_uid::text or not (v_first @>
       jsonb_build_object('initialized',true,'revision',1,'message_enabled',false,
         'friend_request_enabled',v_uid=v_b,'friend_accepted_enabled',false,
         'effective_message_enabled',false,'effective_friend_request_enabled',false,
         'effective_friend_accepted_enabled',false,'synchronized',true))
       or public.bil_get_my_push_delivery_categories_v1() is distinct from v_first then
      raise exception 'AUDIT zero-token notification preference CAS/readback is not authoritative';
    end if;
    v_error_state:=null;
    begin
      perform 1 from private.bil_push_delivery_preferences_v1
      where user_id=case when v_uid=v_a then v_b else v_a end;
    exception when others then
      get stacked diagnostics v_error_state=returned_sqlstate;
    end;
    if v_error_state is distinct from '42501' then
      raise exception 'AUDIT direct foreign notification preference read was not denied';
    end if;
    insert into public.bil_public_profiles(user_id,display_name,bio,profile_visibility,
        discoverable,allow_follows,show_membership_tier)
      values(v_uid,case when v_uid=v_a then 'Audit Author' else 'Audit Reviewer' end,
        'Nutrition release audit','public',true,true,false);
    -- Exact production app boundary: owner policy upsert + canonical trigger.
    insert into public.bil_content_policy_acceptances(user_id,policy_version)
      values(v_uid,v_policy) on conflict(user_id) do update
      set policy_version=excluded.policy_version;
    v_result:=public.bil_current_community_policy_status();
    if v_result->>'status' is distinct from 'accepted' then
      raise exception 'AUDIT authoritative policy readback did not accept: %',v_result;
    end if;
    v_handle:=case when v_uid=v_a then 'qa18970beb' else 'qa1958c6c4' end;
    perform public.bil_social_claim_handle_v2(v_handle);
    if public.bil_join_community_circle_v1(v_circle) is distinct from 'active' then
      raise exception 'AUDIT genuine circle join did not activate';
    end if;
    execute 'reset role';
  end loop;
  v_checks:=v_checks||jsonb_build_object('owner_profile_policy_handle_circle_setup',true);
  if exists(select 1 from public.bil_push_device_tokens where user_id=any(array[v_a,v_b])) then
    raise exception 'AUDIT preference write created synthetic provider tokens';
  end if;
  v_checks:=v_checks||jsonb_build_object('zero_token_notification_owner_cas_readback_privacy',true);
  -- Fixture authority only; not a privileged public bypass or permanent admin.
  insert into public.bil_community_moderators(user_id) values(v_b);

  perform set_config('request.jwt.claim.sub',v_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_a,'role','authenticated')::text,true);
  execute 'set local role authenticated';
  select count(*) into v_count from public.bil_search_community_mentions_v1('qa1958c6c4',12)
    where user_id=v_b and handle='qa1958c6c4';
  if v_count<>1 then raise exception 'AUDIT real mention discovery missing'; end if;
  -- All calls occur in this one DO statement: the genuine fixed window uses
  -- statement_timestamp(), so minute-boundary timing cannot manufacture a pass.
  for i in 2..60 loop perform public.bil_search_community_mentions_v1('qa1958c6c4',12); end loop;
  v_error_state:=null; v_error_message:=null;
  begin perform public.bil_search_community_mentions_v1('qa1958c6c4',12);
  exception when others then
    get stacked diagnostics v_error_state=returned_sqlstate,v_error_message=message_text;
  end;
  if v_error_state is distinct from 'P0001' or v_error_message is distinct from 'rate limit exceeded' then
    raise exception 'AUDIT mention limit expected P0001/rate limit exceeded; got %/%',v_error_state,v_error_message;
  end if;
  v_checks:=v_checks||jsonb_build_object('mention_search',true,'mention_61st_rate_denied',true);

  perform public.bil_upsert_my_community_post_draft_v1(v_delete_draft,
    p_title=>'Draft deletion',p_body=>'Balanced nutrition draft',p_hashtags=>array['#Nutrition']);
  v_result:=public.bil_get_my_community_post_draft_v1(v_delete_draft);
  if v_result->>'title' is distinct from 'Draft deletion'
     or v_result->'hashtags' is distinct from '["nutrition"]'::jsonb then
    raise exception 'AUDIT authoritative draft title/hashtags missing';
  end if;
  v_paths:=public.bil_delete_my_community_post_draft_v1(v_delete_draft);
  if v_paths is distinct from array[]::text[] then raise exception 'AUDIT unexpected draft media paths'; end if;
  v_error_state:=null; v_error_message:=null;
  begin perform public.bil_get_my_community_post_draft_v1(v_delete_draft);
  exception when others then
    get stacked diagnostics v_error_state=returned_sqlstate,v_error_message=message_text;
  end;
  if v_error_state is distinct from 'P0002' or v_error_message is distinct from 'community_draft_not_found' then
    raise exception 'AUDIT deleted draft still available or wrong error %/%',v_error_state,v_error_message;
  end if;
  perform public.bil_upsert_my_community_post_draft_v1(v_draft,
    p_title=>'تدقيق نشر غذائي',p_body=>E'وجبة متوازنة بعد التمرين.\nBalanced meal after training.',
    p_topic_slugs=>array[v_topic],p_circle_slug=>v_circle,p_location_label=>'Audit locality',
    p_mentioned_user_ids=>array[v_b],p_collaborator_user_ids=>array[v_b],
    p_hashtags=>array['nutrition','غذاء'],p_poll_question=>'Which balanced meal?',
    p_poll_options=>array['Vegetables and protein','Whole grains and protein']);
  v_result:=public.bil_get_my_community_post_draft_v1(v_draft);
  if v_result->>'title' is distinct from 'تدقيق نشر غذائي'
     or v_result->'hashtags' is distinct from '["nutrition","غذاء"]'::jsonb
     or v_result->'mentions'->0->>'user_id' is distinct from v_b::text
     or v_result->'collaborators'->0->>'user_id' is distinct from v_b::text then
    raise exception 'AUDIT rich draft persistence/projections mismatch';
  end if;
  v_checks:=v_checks||jsonb_build_object('draft_save_get',true,'draft_delete_get_denial',true,
    'draft_title_hashtags_mentions_collaboration',true,'draft_multiline_arabic_english',true);

  -- Cross-owner draft access must fail under ordinary authenticated B.
  perform set_config('request.jwt.claim.sub',v_b::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_b,'role','authenticated')::text,true);
  v_error_state:=null; v_error_message:=null;
  begin perform public.bil_get_my_community_post_draft_v1(v_draft);
  exception when others then
    get stacked diagnostics v_error_state=returned_sqlstate,v_error_message=message_text;
  end;
  if v_error_state is distinct from 'P0002' or v_error_message is distinct from 'community_draft_not_found' then
    raise exception 'AUDIT foreign draft disclosure %/%',v_error_state,v_error_message;
  end if;
  v_checks:=v_checks||jsonb_build_object('draft_owner_read_isolation',true);
  perform set_config('request.jwt.claim.sub',v_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_a,'role','authenticated')::text,true);
  v_payload:=jsonb_build_object(
    'body',E'وجبة متوازنة بعد التمرين.\nBalanced meal after training.',
    'media','[]'::jsonb,'topic_slugs',jsonb_build_array(v_topic),'circle_slug',v_circle,
    'location_label','Audit locality','mentioned_user_ids',jsonb_build_array(v_b),
    'title','تدقيق نشر غذائي','hashtags','["nutrition","غذاء"]'::jsonb,
    'collaborator_user_ids',jsonb_build_array(v_b),
    'poll',jsonb_build_object('question','Which balanced meal?',
      'options',jsonb_build_array('Vegetables and protein','Whole grains and protein'),
      'allow_multiple',false,'closes_at',null),'persistent_draft_id',v_draft);
  v_payload_decline:=v_payload||jsonb_build_object(
    'body','A second balanced meal for collaboration review','title','Collaboration decline audit',
    'poll',null,'persistent_draft_id',null);
  v_first:=public.bil_begin_my_community_publish_operation_v1(v_accept,v_payload);
  if (v_first @> jsonb_build_object('operation_id',v_accept,'owner_id',v_a,
      'status','prepared','committed',false,'payload',v_payload)) is distinct from true then
    raise exception 'AUDIT prepared operation envelope mismatch';
  end if;
  v_result:=public.bil_begin_my_community_publish_operation_v1(v_accept,v_payload);
  if v_result is distinct from v_first then raise exception 'AUDIT begin retry changed envelope'; end if;
  v_error_state:=null; v_error_message:=null;
  begin perform public.bil_begin_my_community_publish_operation_v1(v_accept,
      v_payload||jsonb_build_object('body','Mutated immutable submission'));
  exception when others then
    get stacked diagnostics v_error_state=returned_sqlstate,v_error_message=message_text;
  end;
  if v_error_state is distinct from '22023' or v_error_message is distinct from 'community_publish_payload_conflict' then
    raise exception 'AUDIT immutable payload conflict not denied %/%',v_error_state,v_error_message;
  end if;
  v_first:=public.bil_publish_community_post_operation_v1(v_accept,v_payload);
  if (v_first @> jsonb_build_object('status','committed','committed',true,
      'post_id',v_accept,'operation_id',v_accept,'owner_id',v_a,'payload',v_payload)) is distinct from true then
    raise exception 'AUDIT committed envelope mismatch';
  end if;
  v_result:=public.bil_publish_community_post_operation_v1(v_accept,v_payload);
  if v_result is distinct from v_first then raise exception 'AUDIT commit retry changed receipt'; end if;
  if public.bil_abort_my_community_publish_operation_v1(v_accept) is distinct from v_first then
    raise exception 'AUDIT committed abort failed to return full verified receipt';
  end if;
  perform public.bil_begin_my_community_publish_operation_v1(v_decline,v_payload_decline);
  v_result:=public.bil_publish_community_post_operation_v1(v_decline,v_payload_decline);
  if v_result->>'committed' is distinct from 'true' then raise exception 'AUDIT second commit failed'; end if;
  execute 'reset role';
  v_group:=jsonb_build_object(
    'atomic_pending_post',exists(select 1 from public.bil_community_posts where id=v_accept
      and author_id=v_a and moderation_status='pending' and visibility='community'
      and title='تدقيق نشر غذائي'),
    'atomic_topic',(select count(*)=1 from public.bil_community_post_topics where post_id=v_accept),
    'atomic_circle',(select count(*)=1 from public.bil_community_post_circles where post_id=v_accept),
    'atomic_location',(select count(*)=1 from public.bil_community_post_locations_v1
      where post_id=v_accept and label='Audit locality'),
    'atomic_mention',(select count(*)=1 from public.bil_community_post_mentions_v1
      where post_id=v_accept and mentioned_user_id=v_b),
    'atomic_collaborator',(select count(*)=1 from public.bil_community_post_collaborators_v1
      where post_id=v_accept and collaborator_id=v_b and status='pending'),
    'atomic_poll_options',(select count(*)=2 from public.bil_community_poll_options where post_id=v_accept),
    'atomic_draft_consumed',not exists(select 1 from public.bil_community_post_drafts_v1 where draft_id=v_draft),
    'no_preapproval_collaboration_invite',not exists(select 1 from public.bil_community_notifications
      where entity_id in(v_accept::text,v_decline::text) and kind='collaboration_invite'),
    'no_preapproval_reward',not exists(select 1 from public.bil_community_post_approval_grants
      where post_id in(v_accept,v_decline)),
    'post_quota_not_duplicated',(select coalesce(sum(hit_count),0)=2 from public.bil_rate_limit_buckets
      where user_id=v_a and action='post'));
  for v_check in select key,value from jsonb_each(v_group) loop
    if v_check.value is distinct from 'true'::jsonb then raise exception 'AUDIT failed %',v_check.key; end if;
  end loop;
  v_checks:=v_checks||v_group||jsonb_build_object('begin_retry',true,'immutable_payload',true,
    'commit_retry',true,'committed_abort_full_receipt',true);

  perform set_config('request.jwt.claim.sub',v_b::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_b,'role','authenticated')::text,true);
  execute 'set local role authenticated';
  v_error_state:=null; v_error_message:=null;
  begin perform public.bil_record_community_post_view_v1(v_accept);
  exception when others then
    get stacked diagnostics v_error_state=returned_sqlstate,v_error_message=message_text;
  end;
  if v_error_state is distinct from '42501' or v_error_message is distinct from 'post_unavailable' then
    raise exception 'AUDIT pending post accessible through actual view API %/%',v_error_state,v_error_message;
  end if;
  v_error_state:=null; v_error_message:=null;
  begin perform public.bil_respond_community_collaboration_v1(v_accept,true);
  exception when others then
    get stacked diagnostics v_error_state=returned_sqlstate,v_error_message=message_text;
  end;
  if v_error_state is distinct from '42501'
     or v_error_message is distinct from 'community_collaboration_post_unavailable' then
    raise exception 'AUDIT preapproval collab response permitted %/%',v_error_state,v_error_message;
  end if;
  -- Distinct authenticated canonical moderator; no direct moderation UPDATE.
  v_result:=public.bil_moderate_community_post(v_accept,'approved');
  if (v_result @> jsonb_build_object('post_id',v_accept,'decision','approved',
      'duplicate',false,'tokens_granted',v_tokens)) is distinct from true then
    raise exception 'AUDIT canonical first moderation/reward mismatch %',v_result;
  end if;
  v_result:=public.bil_moderate_community_post(v_accept,'approved');
  if (v_result @> '{"duplicate":true,"tokens_granted":0}'::jsonb) is distinct from true then
    raise exception 'AUDIT moderation retry not idempotent';
  end if;
  v_result:=public.bil_moderate_community_post(v_decline,'approved');
  if (v_result @> jsonb_build_object('duplicate',false,'tokens_granted',v_tokens)) is distinct from true then
    raise exception 'AUDIT canonical second moderation/reward mismatch';
  end if;
  select count(*) into v_count from public.bil_list_community_activity_v2(
    null,null,array['collaboration_invite'],100)
    where actor_id=v_a and entity_id in(v_accept::text,v_decline::text);
  if v_count<>2 then raise exception 'AUDIT approved collab Activity source mismatch'; end if;
  select count(*) into v_count from public.bil_list_community_activity_v2(null,null,array['mention'],100)
    where actor_id=v_a and entity_id in(v_accept::text,v_decline::text);
  if v_count<>2 then raise exception 'AUDIT approval mention Activity source mismatch'; end if;
  v_result:=public.bil_respond_community_collaboration_v1(v_accept,true);
  if (v_result @> '{"status":"accepted","duplicate":false}'::jsonb) is distinct from true then
    raise exception 'AUDIT collaboration acceptance mismatch';
  end if;
  v_result:=public.bil_respond_community_collaboration_v1(v_accept,true);
  if (v_result @> '{"status":"accepted","duplicate":true}'::jsonb) is distinct from true then
    raise exception 'AUDIT collaboration acceptance replay not idempotent';
  end if;
  v_result:=public.bil_respond_community_collaboration_v1(v_decline,false);
  if (v_result @> '{"status":"declined","duplicate":false}'::jsonb) is distinct from true then
    raise exception 'AUDIT collaboration decline mismatch';
  end if;
  v_error_state:=null; v_error_message:=null;
  begin perform public.bil_respond_community_collaboration_v1(v_accept,false);
  exception when others then
    get stacked diagnostics v_error_state=returned_sqlstate,v_error_message=message_text;
  end;
  if v_error_state is distinct from '23505'
     or v_error_message is distinct from 'community_collaboration_already_responded' then
    raise exception 'AUDIT final collaboration decision rewritable %/%',v_error_state,v_error_message;
  end if;
  v_checks:=v_checks||jsonb_build_object('pending_visibility_denial',true,'preapproval_collab_denial',true,
    'canonical_distinct_moderator_approval',true,'moderation_reward_idempotency',true,
    'approval_collaboration_activity',true,'approval_mention_activity',true,
    'collaboration_accept',true,'duplicate_accept',true,'collaboration_decline',true,
    'collaboration_decision_immutable',true);

  if public.bil_record_community_post_view_v1(v_accept) is distinct from 1::bigint
     or public.bil_record_community_post_view_v1(v_accept) is distinct from 1::bigint then
    raise exception 'AUDIT authoritative view duplicate mismatch';
  end if;
  select count(*) into v_count from public.bil_community_post_view_counts_v1(array[v_accept])
    where post_id=v_accept and view_count=1;
  if v_count<>1 then raise exception 'AUDIT batch authoritative views mismatch'; end if;
  v_result:=public.bil_social_add_comment_v2(v_accept,'Balanced nutrition discussion',null,v_comment);
  if v_result->>'id' is distinct from v_comment::text then raise exception 'AUDIT root comment missing'; end if;
  v_first:=public.bil_social_add_comment_v2(v_accept,'Balanced nutrition discussion',null,v_comment);
  if v_first is distinct from v_result then raise exception 'AUDIT comment replay mismatch'; end if;
  v_result:=public.bil_social_add_comment_v2(v_accept,'Protein and vegetables together',v_comment,v_reply);
  if v_result->>'parent_id' is distinct from v_comment::text then raise exception 'AUDIT reply root mismatch'; end if;
  -- Genuine poll API, not a direct SELECT grant on RPC-only poll tables.
  v_result:=public.bil_community_poll_v1(v_accept);
  v_option:=(v_result->'options'->0->>'id')::uuid;
  if v_result->>'post_id' is distinct from v_accept::text
     or jsonb_array_length(v_result->'options') is distinct from 2 then
    raise exception 'AUDIT genuine poll read contract missing';
  end if;
  if v_option is null or public.bil_vote_community_poll_v1(v_accept,array[v_option]) is distinct from 1
     or public.bil_vote_community_poll_v1(v_accept,array[v_option]) is distinct from 1 then
    raise exception 'AUDIT genuine poll vote retry failed';
  end if;
  v_profile:=public.bil_community_profile_projection_v1(v_a);
  v_creator:=public.bil_community_creator_projection_v1(v_a);
  if v_profile->>'post_count' is distinct from '2'
     or v_profile->'gold_balance' is distinct from 'null'::jsonb
     or v_creator->>'approved_posts' is distinct from '2'
     or v_creator->>'comments_received' is distinct from '2'
     or v_profile ?| array['weight','measurements','health_data','membership_tier']
     or v_creator ?| array['weight','measurements','health_data','membership_tier'] then
    raise exception 'AUDIT public profile/creator authoritative/privacy mismatch';
  end if;
  select count(*) into v_count from public.bil_community_comment_membership_tiers_v1(array[v_a]);
  if v_count<>0 then raise exception 'AUDIT opt-out membership tier exposed'; end if;
  -- Genuine latest root preview is returned; reply count derives from DB.
  select count(*) into v_count from public.bil_community_feed_comment_previews_v1(array[v_accept,v_decline])
    where post_id=v_accept and comment->>'id'=v_comment::text
      and comment->>'parent_id' is null and comment->>'reply_count'='1';
  if v_count<>1 then raise exception 'AUDIT root comment batch preview/reply count mismatch'; end if;
  execute 'reset role';
  v_group:=jsonb_build_object(
    'view_count_database',(select count(*)=1 from public.bil_community_post_views_v1 where post_id=v_accept),
    'comment_duplicate_database',(select count(*)=2 from public.bil_social_comments_v2 where post_id=v_accept),
    'poll_vote_duplicate_database',(select count(*)=1 from public.bil_community_poll_votes
      where post_id=v_accept and voter_id=v_b),
    'approval_credit_database',(select granted=2*v_tokens from public.bil_ai_credit_balances where owner_id=v_a),
    'approval_grant_database',(select count(*)=2 from public.bil_community_post_approval_grants
      where post_id in(v_accept,v_decline) and owner_id=v_a and tokens=v_tokens),
    'accepted_activity_database',(select count(*)=1 from public.bil_community_notifications
      where recipient_id=v_a and actor_id=v_b and kind='collaboration_accepted' and entity_id=v_accept::text));
  for v_check in select key,value from jsonb_each(v_group) loop
    if v_check.value is distinct from 'true'::jsonb then raise exception 'AUDIT failed %',v_check.key; end if;
  end loop;
  v_checks:=v_checks||v_group||jsonb_build_object('views_rpc_idempotent',true,'root_comment_reply_contract',true,
    'comment_retry_idempotent',true,'poll_vote_retry',true,'profile_creator_counts',true,
    'public_projection_no_health_or_gold',true,'tier_opt_out',true,'batch_comment_preview',true);

  -- Compare published metadata and topic/circle projections to actual visible DB
  -- counts with JWT still B, not hardcoded global counters. Admin inspection only.
  select count(*) into v_expected from public.bil_community_post_topics pt
    join public.bil_community_topics t on t.id=pt.topic_id
    join public.bil_community_posts p on p.id=pt.post_id
    where t.slug=v_topic and p.deleted_at is null and p.moderation_status='approved'
      and public.bil_social_post_visible_v2(p.id);
  execute 'set local role authenticated';
  select count(*) into v_count from public.bil_list_community_topics_v1()
    where slug=v_topic and post_count=v_expected;
  if v_count<>1 then raise exception 'AUDIT topic count not server authoritative'; end if;
  execute 'reset role';
  select count(*) into v_expected from public.bil_community_post_circles pc
    join public.bil_community_circles c on c.id=pc.circle_id
    join public.bil_community_posts p on p.id=pc.post_id
    where c.slug=v_circle and p.deleted_at is null and p.moderation_status='approved'
      and public.bil_social_post_visible_v2(p.id);
  execute 'set local role authenticated';
  select count(*) into v_count from public.bil_list_community_circles_v1()
    where slug=v_circle and post_count=v_expected and membership_status='active';
  if v_count<>1 then raise exception 'AUDIT circle metadata/membership count mismatch'; end if;
  select count(*) into v_count from public.bil_community_post_reference_metadata_v1(array[v_accept,v_decline])
    where post_id=v_accept and title='تدقيق نشر غذائي'
      and hashtags @> array['nutrition','غذاء']
      and topics->0->>'slug'=v_topic and circle->>'slug'=v_circle
      and collaborators->0->>'user_id'=v_b::text and collaborators->0->>'status'='accepted';
  if v_count<>1 then raise exception 'AUDIT authoritative rich reference metadata mismatch'; end if;
  v_checks:=v_checks||jsonb_build_object('topics_count_authority',true,'circle_metadata_authority',true,
    'batch_reference_metadata',true);

  -- Actor B is moderator only for setup/review; REMOVE that fixture authority
  -- before public privacy/block assertions, preserving genuine ordinary rules.
  execute 'reset role';
  delete from public.bil_community_moderators where user_id=v_b;
  perform set_config('request.jwt.claim.sub',v_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_a,'role','authenticated')::text,true);
  execute 'set local role authenticated';
  select count(*) into v_count from public.bil_list_community_activity_v2(
    null,null,array['collaboration_accepted'],100)
    where actor_id=v_b and entity_id=v_accept::text;
  if v_count<>1 then raise exception 'AUDIT acceptance Activity replay duplicated/missing'; end if;
  -- Cursor composite ordering is genuine; equal timestamps are disambiguated IDs.
  select jsonb_agg(to_jsonb(x)) into v_first_page
    from public.bil_list_community_activity_v2(null,null,null,1) x;
  if jsonb_array_length(v_first_page) is distinct from 1 then raise exception 'AUDIT first Activity cursor page empty'; end if;
  v_cursor_time:=(v_first_page->0->>'created_at')::timestamptz;
  v_cursor_id:=(v_first_page->0->>'id')::uuid;
  if v_cursor_time is null or v_cursor_id is null then
    raise exception 'AUDIT Activity cursor incomplete';
  end if;
  if exists(select 1 from public.bil_list_community_activity_v2(v_cursor_time,v_cursor_id,null,100)
      where (created_at,id)>=(v_cursor_time,v_cursor_id)) then
    raise exception 'AUDIT Activity cursor duplicate/order error';
  end if;
  select count(*) into v_expected from public.bil_list_community_activity_v2(null,null,null,100);
  select count(*)+1 into v_count from public.bil_list_community_activity_v2(v_cursor_time,v_cursor_id,null,100);
  if v_expected<>v_count then raise exception 'AUDIT Activity cursor loses a row'; end if;
  if public.bil_begin_my_community_publish_operation_v1(v_accept,v_payload)->>'committed' is distinct from 'true'
     or public.bil_begin_my_community_publish_operation_v1(v_accept,v_payload)->'payload' is distinct from v_payload then
    raise exception 'AUDIT normal moderation/comments/vote invalidated valid receipt';
  end if;
  update public.bil_public_profiles set show_membership_tier=true where user_id=v_a;
  perform set_config('request.jwt.claim.sub',v_b::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_b,'role','authenticated')::text,true);
  select count(*) into v_count from public.bil_community_comment_membership_tiers_v1(array[v_a])
    where user_id=v_a and membership_tier='free';
  if v_count<>1 then raise exception 'AUDIT explicit tier opt-in not authoritative Free'; end if;
  perform set_config('request.jwt.claim.sub',v_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_a,'role','authenticated')::text,true);
  update public.bil_public_profiles set show_posts=false,show_followers=false where user_id=v_a;
  perform set_config('request.jwt.claim.sub',v_b::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_b,'role','authenticated')::text,true);
  v_creator:=public.bil_community_creator_projection_v1(v_a);
  if v_creator->'approved_posts' is distinct from 'null'::jsonb
     or v_creator->'followers' is distinct from 'null'::jsonb
     or exists(select 1 from jsonb_array_elements(v_creator->'badges') b
       where b->>'badge_key' in('first_moment','contributor','conversation_starter','appreciated','connector')) then
    raise exception 'AUDIT creator opt-out counts/badges exposed';
  end if;
  perform set_config('request.jwt.claim.sub',v_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_a,'role','authenticated')::text,true);
  update public.bil_public_profiles set profile_visibility='private' where user_id=v_a;
  perform set_config('request.jwt.claim.sub',v_b::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_b,'role','authenticated')::text,true);
  foreach v_table in array array['bil_community_profile_projection_v1','bil_community_creator_projection_v1'] loop
    v_error_state:=null; v_error_message:=null;
    begin execute format('select public.%I($1)',v_table) into v_result using v_a;
    exception when others then
      get stacked diagnostics v_error_state=returned_sqlstate,v_error_message=message_text;
    end;
    if v_error_state is distinct from '42501' or v_error_message is distinct from 'community_profile_unavailable' then
      raise exception 'AUDIT private profile disclosure by %: %/%',v_table,v_error_state,v_error_message;
    end if;
  end loop;
  if exists(select 1 from public.bil_search_community_mentions_v1('qa18970beb',12) where user_id=v_a) then
    raise exception 'AUDIT private profile appeared in mention search';
  end if;
  perform set_config('request.jwt.claim.sub',v_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_a,'role','authenticated')::text,true);
  update public.bil_public_profiles set profile_visibility='public',show_posts=true,show_followers=true where user_id=v_a;
  v_checks:=v_checks||jsonb_build_object('activity_acceptance_source',true,'activity_cursor_no_repeat',true,
    'moderation_and_engagement_preserve_receipt',true,'tier_opt_in_authoritative',true,
    'creator_hidden_counts_badges',true,'private_profile_projection_denial',true,
    'private_creator_projection_denial',true,'private_mention_denial',true);

  -- Missing-media commit must fail closed without any Storage-success fiction.
  v_path:=v_a::text||'/'||v_media_op::text||'/'||v_reply::text||'.png';
  v_media_payload:=v_payload_decline||jsonb_build_object('media',jsonb_build_array(
    jsonb_build_object('object_path',v_path,'mime_type','image/png','bytes',100,'width',10,'height',10)));
  perform public.bil_begin_my_community_publish_operation_v1(v_media_op,v_media_payload);
  v_error_state:=null; v_error_message:=null;
  begin perform public.bil_publish_community_post_operation_v1(v_media_op,v_media_payload);
  exception when others then
    get stacked diagnostics v_error_state=returned_sqlstate,v_error_message=message_text;
  end;
  if v_error_state is distinct from '42501' or v_error_message is distinct from 'community_publish_media_unverified' then
    raise exception 'AUDIT missing Storage media commit not denied %/%',v_error_state,v_error_message;
  end if;
  v_result:=public.bil_abort_my_community_publish_operation_v1(v_media_op);
  if (v_result @> jsonb_build_object('status','aborted','aborted',true,
      'payload',v_media_payload,'media_paths',jsonb_build_array(v_path))) is distinct from true then
    raise exception 'AUDIT prepared abort exact authoritative media envelope mismatch';
  end if;
  v_result:=public.bil_abort_my_community_publish_operation_v1(v_tombstone);
  if (v_result @> '{"status":"aborted","aborted":true,"payload":null,"media_paths":[]}'::jsonb) is distinct from true then
    raise exception 'AUDIT absent abort tombstone envelope mismatch';
  end if;
  if public.bil_begin_my_community_publish_operation_v1(v_tombstone,v_payload_decline)->>'status'
      is distinct from 'aborted' then raise exception 'AUDIT delayed begin revived tombstone'; end if;
  perform set_config('storage.operation','storage.object.get_authenticated',true);
  -- Only denial attempts: these statements must not insert metadata or bytes.
  foreach v_uid in array array[v_accept,v_tombstone] loop
    v_error_state:=null; v_error_message:=null;
    begin
      insert into storage.objects(bucket_id,name,owner_id,metadata)
        values('community-post-images',v_a::text||'/'||v_uid::text||'/'||v_reply::text||'.png',
          v_a::text,'{"size":100,"mimetype":"image/png"}');
    exception when others then
      get stacked diagnostics v_error_state=returned_sqlstate,v_error_message=message_text;
    end;
    if v_error_state is distinct from '42501' then
      raise exception 'AUDIT approved/aborted Storage path INSERT not denied: %/%',v_error_state,v_error_message;
    end if;
  end loop;
  execute 'reset role';
  if exists(select 1 from public.bil_community_posts where id=v_media_op)
     or exists(select 1 from storage.objects where name like v_a::text||'/%')
     or (select status from private.bil_community_publish_operations_v1 where operation_id=v_media_op)
       is distinct from 'aborted' then
    raise exception 'AUDIT missing-media/negative Storage attempt left partial state';
  end if;
  v_checks:=v_checks||jsonb_build_object('missing_media_fail_closed',true,
    'failed_media_commit_no_partial_post',true,'prepared_abort_exact_paths',true,
    'absent_abort_null_payload',true,'delayed_begin_tombstone',true,
    'approved_path_storage_insert_denial',true,'aborted_path_storage_insert_denial',true,
    'no_synthetic_storage_object',true);

  -- Block RPC is owner initiated, not a direct privileged block fixture.
  execute 'set local role authenticated';
  perform public.bil_block_community_member(v_b);
  select count(*) into v_count from public.bil_community_feed_comment_previews_v1(array[v_accept])
    where post_id=v_accept and comment is not null;
  if v_count<>0 then raise exception 'AUDIT blocked author comment leaked into owner feed preview'; end if;
  select count(*) into v_count from public.bil_list_community_activity_v2(null,null,null,100)
    where actor_id=v_b;
  if v_count<>0 then raise exception 'AUDIT blocked actor Activity leaked'; end if;
  perform set_config('request.jwt.claim.sub',v_b::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_b,'role','authenticated')::text,true);
  if exists(select 1 from public.bil_community_post_reference_metadata_v1(array[v_accept]))
     or exists(select 1 from public.bil_community_comment_membership_tiers_v1(array[v_a]))
     or exists(select 1 from public.bil_search_community_mentions_v1('qa18970beb',12) where user_id=v_a)
     or exists(select 1 from public.bil_community_feed_comment_previews_v1(array[v_accept])) then
    raise exception 'AUDIT blocked viewer metadata/tier/mention/comment leak';
  end if;
  v_error_state:=null; v_error_message:=null;
  begin perform public.bil_social_add_comment_v2(v_accept,'Blocked attempt',null,v_delete_draft);
  exception when others then
    get stacked diagnostics v_error_state=returned_sqlstate,v_error_message=message_text;
  end;
  if v_error_state is distinct from '42501' or v_error_message is distinct from 'post_unavailable' then
    raise exception 'AUDIT blocked viewer can comment %/%',v_error_state,v_error_message;
  end if;
  v_error_state:=null; v_error_message:=null;
  begin perform public.bil_record_community_post_view_v1(v_accept);
  exception when others then
    get stacked diagnostics v_error_state=returned_sqlstate,v_error_message=message_text;
  end;
  if v_error_state is distinct from '42501' or v_error_message is distinct from 'post_unavailable' then
    raise exception 'AUDIT blocked viewer can record view %/%',v_error_state,v_error_message;
  end if;
  v_error_state:=null; v_error_message:=null;
  begin perform public.bil_abort_my_community_publish_operation_v1(v_accept);
  exception when others then
    get stacked diagnostics v_error_state=returned_sqlstate,v_error_message=message_text;
  end;
  if v_error_state is distinct from '42501' or v_error_message is distinct from 'community_publish_operation_not_owned' then
    raise exception 'AUDIT foreign owner can abort/read publication %/%',v_error_state,v_error_message;
  end if;
  v_checks:=v_checks||jsonb_build_object('block_rpc',true,'blocked_comment_preview_hidden',true,
    'blocked_activity_hidden',true,'blocked_post_visibility_denial',true,
    'blocked_metadata_tier_mention_preview_denial',true,'blocked_comment_write_denial',true,
    'blocked_view_write_denial',true,'publish_operation_owner_isolation',true);

  perform set_config('request.jwt.claim.sub',v_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_a,'role','authenticated')::text,true);
  if public.bil_delete_community_post(v_decline) is distinct from true then
    raise exception 'AUDIT canonical owner deletion failed';
  end if;
  v_result:=public.bil_begin_my_community_publish_operation_v1(v_decline,v_payload_decline);
  if (v_result @> jsonb_build_object('operation_id',v_decline,'owner_id',v_a,
      'post_id',v_decline,'payload',v_payload_decline,'status','unavailable',
      'committed',false,'was_committed',true,'post_available',false,
      'cleanup_allowed',false,'media_paths','[]'::jsonb)) is distinct from true then
    raise exception 'AUDIT deleted historical commit got false success/cleanup %',v_result;
  end if;
  v_result:=public.bil_abort_my_community_publish_operation_v1(v_decline);
  if (v_result @> jsonb_build_object('status','unavailable','aborted',false,
      'post_id',v_decline,'payload',v_payload_decline,'was_committed',true,
      'committed',false,'post_available',false,'cleanup_allowed',false,'media_paths','[]'::jsonb)) is distinct from true then
    raise exception 'AUDIT unavailable abort envelope unsafe %',v_result;
  end if;
  execute 'reset role';
  if (select status from private.bil_community_publish_operations_v1 where operation_id=v_decline)
      is distinct from 'committed' then raise exception 'AUDIT historical journal changed after deletion'; end if;
  v_checks:=v_checks||jsonb_build_object('canonical_owner_delete',true,'deleted_receipt_no_false_success',true,
    'unavailable_abort_no_cleanup',true,'historical_commit_terminal',true);

  for v_check in select key,value from jsonb_each(v_checks) loop
    if v_check.value is distinct from 'true'::jsonb then raise exception 'AUDIT final assertion failed %',v_check.key; end if;
  end loop;
  if (select count(*) from jsonb_object_keys(v_checks))<60 then
    raise exception 'AUDIT nonvacuous assertion inventory too small';
  end if;
  -- This value is transaction-local. It is emitted BEFORE rollback only; do
  -- not rely on it persisting or returning in a separate connector call.
  perform set_config('bil.audit_transaction_assertions',v_checks::text,true);
  perform set_config('bil.audit_transaction_failure','',true);
  perform set_config('bil.audit_transaction_result','PASS',true);
  perform set_config('request.jwt.claim.sub','',true);
  perform set_config('request.jwt.claims','{}',true);
exception when others or query_canceled or assert_failure then
  -- PostgreSQL has already rolled back every write in this block, including
  -- earlier assertion settings and SET LOCAL ROLE/claims. This handler never
  -- labels an incomplete run PASS or retains partial successful assertions.
  get stacked diagnostics v_error_state=returned_sqlstate,
    v_error_message=message_text,v_error_context=pg_exception_context;
  perform set_config('bil.audit_transaction_result','FAIL',true);
  perform set_config('bil.audit_transaction_assertions','{}',true);
  perform set_config('bil.audit_transaction_failure',
    jsonb_build_object('sqlstate',v_error_state,'error',v_error_message,
      'stack_context',v_error_context,'checks_reached_before_failure',v_checks)::text,true);
end;
$audit$;

-- FAIL remains a failure even though this SELECT/ROLLBACK completes. The
-- executor MUST check explicit status, exact failure and all assertions, then
-- perform independent residue readback regardless of result. Harmless
-- configuration-only MCP probes verified PASS, P0001 and 57014 reporting and
-- block rollback on 2026-10-04; they were NOT application/Production E2E proof.
select pg_catalog.statement_timestamp() as assertions_completed_at,
  coalesce(nullif(pg_catalog.current_setting('bil.audit_transaction_result',true),''),'UNKNOWN') as transaction_result,
  nullif(pg_catalog.current_setting('bil.audit_transaction_failure',true),'')::jsonb as exact_failure,
  coalesce(nullif(pg_catalog.current_setting('bil.audit_transaction_assertions',true),'')::jsonb,'{}'::jsonb) as completed_assertions,
  (select count(*) from pg_catalog.jsonb_object_keys(
    coalesce(nullif(pg_catalog.current_setting('bil.audit_transaction_assertions',true),'')::jsonb,'{}'::jsonb))) as completed_assertion_count;
rollback;
-- END SEGMENT TRANSACTION

-- BEGIN SEGMENT RESIDUE
-- RESIDUE: READ-ONLY; execute separately and retain the returned JSON externally.
-- Counts may change because of genuine concurrent traffic. Never require global equality.
-- synthetic_rows must be zero for EVERY row; missing tables/errors are NOT a pass.
with marker as (
  select 'bil_prebuild_rollback_20261004_18970beb|18970beb-5e1c-4ec0-9254-dda7437b4cf6|1958c6c4-edea-4135-b04c-35f31e0f8571|be21d52a-bbdd-440b-9615-d4813f9553b8|18716ad9-a16d-47fd-bf19-6aa6e967d7b0|580d488e-ea06-43bf-9745-9d921cc7e3fd|64e7f014-1fff-47dd-b016-a280b7b6f6f1|ec5f3513-89a9-42dd-bdc1-4790b0ac37cc|05fd5bed-4c4d-4003-b27f-9e464cf6c79e|0d02f9d0-2e11-4d1a-abb4-94915c30ca80|690ae7d1-6fd1-4cf3-9dcc-9089ee50161c'::text as pattern,
    array['18970beb-5e1c-4ec0-9254-dda7437b4cf6','1958c6c4-edea-4135-b04c-35f31e0f8571','be21d52a-bbdd-440b-9615-d4813f9553b8','18716ad9-a16d-47fd-bf19-6aa6e967d7b0','580d488e-ea06-43bf-9745-9d921cc7e3fd','64e7f014-1fff-47dd-b016-a280b7b6f6f1','ec5f3513-89a9-42dd-bdc1-4790b0ac37cc','05fd5bed-4c4d-4003-b27f-9e464cf6c79e','0d02f9d0-2e11-4d1a-abb4-94915c30ca80','690ae7d1-6fd1-4cf3-9dcc-9089ee50161c']::uuid[] as identifiers,
    array['18970beb-5e1c-4ec0-9254-dda7437b4cf6','1958c6c4-edea-4135-b04c-35f31e0f8571']::uuid[] as owners,
    array['18970beb-5e1c-4ec0-9254-dda7437b4cf6','1958c6c4-edea-4135-b04c-35f31e0f8571']::text[] as owner_strings,
    array['bil_prebuild_rollback_20261004_18970beb-a@example.invalid','bil_prebuild_rollback_20261004_18970beb-b@example.invalid']::text[] as emails,
    'bil_prebuild_rollback_20261004_18970beb'::text as audit_marker,
    array['18970beb-5e1c-4ec0-9254-dda7437b4cf6/%','1958c6c4-edea-4135-b04c-35f31e0f8571/%']::text[] as owner_path_prefixes
),
inventory as (
  select 'auth.users' as table_name,
    (select count(*) from auth.users) as total_rows,
    (select count(*) from auth.users t where t.id=any(marker.identifiers) or t.email=any(marker.emails)
      or t.raw_user_meta_data->>'audit_marker'=marker.audit_marker) as synthetic_rows
  from marker
  union all
  select 'private.bil_admin_notification_audit' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from private.bil_admin_notification_audit t cross join marker
  union all
  select 'private.bil_admin_notification_message_overrides' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from private.bil_admin_notification_message_overrides t cross join marker
  union all
  select 'public.bil_account_deletion_requests' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_account_deletion_requests t cross join marker
  union all
  select 'public.bil_ai_credit_balances' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_ai_credit_balances t cross join marker
  union all
  select 'public.bil_ai_credit_monthly_usage' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_ai_credit_monthly_usage t cross join marker
  union all
  select 'public.bil_ai_credit_weekly_usage' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_ai_credit_weekly_usage t cross join marker
  union all
  select 'public.bil_community_notifications' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_notifications t cross join marker
  union all
  select 'public.bil_community_post_approval_grants' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_post_approval_grants t cross join marker
  union all
  select 'public.bil_community_post_circles' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_post_circles t cross join marker
  union all
  select 'public.bil_community_post_collaborators_v1' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_post_collaborators_v1 t cross join marker
  union all
  select 'public.bil_community_post_draft_media_v1' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_post_draft_media_v1 t cross join marker
  union all
  select 'public.bil_community_post_drafts_v1' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_post_drafts_v1 t cross join marker
  union all
  select 'public.bil_community_post_hashtags_v1' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_post_hashtags_v1 t cross join marker
  union all
  select 'public.bil_community_post_locations_v1' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_post_locations_v1 t cross join marker
  union all
  select 'public.bil_community_post_media_v1' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_post_media_v1 t cross join marker
  union all
  select 'public.bil_community_post_mentions_v1' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_post_mentions_v1 t cross join marker
  union all
  select 'public.bil_community_post_reward_usage' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_post_reward_usage t cross join marker
  union all
  select 'public.bil_community_post_topics' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_post_topics t cross join marker
  union all
  select 'public.bil_community_post_views_v1' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_post_views_v1 t cross join marker
  union all
  select 'public.bil_community_posts' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_posts t cross join marker
  union all
  select 'public.bil_community_quest_progress' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_quest_progress t cross join marker
  union all
  select 'public.bil_community_quest_progress_events' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_quest_progress_events t cross join marker
  union all
  select 'public.bil_community_reputation_accounts' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_reputation_accounts t cross join marker
  union all
  select 'public.bil_community_reward_claim_audit' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_reward_claim_audit t cross join marker
  union all
  select 'public.bil_gold_accounts' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_gold_accounts t cross join marker
  union all
  select 'public.bil_gold_ledger' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_gold_ledger t cross join marker
  union all
  select 'public.bil_public_profiles' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_public_profiles t cross join marker
  union all
  select 'public.bil_push_outbox' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_push_outbox t cross join marker
  union all
  select 'public.bil_rate_limit_buckets' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_rate_limit_buckets t cross join marker
  union all
  select 'public.bil_sensitive_request_receipts' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_sensitive_request_receipts t cross join marker
  union all
  select 'public.bil_social_handles_v2' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_social_handles_v2 t cross join marker
  union all
  select 'public.bil_store_notification_inbox' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_store_notification_inbox t cross join marker
  union all
  select 'public.bil_support_requests' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_support_requests t cross join marker
  union all
  select 'public.bil_vision_request_receipts' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_vision_request_receipts t cross join marker
  union all
  select 'storage.objects' as table_name,
    (select count(*) from storage.objects) as total_rows,
    (select count(*) from storage.objects t where t.id=any(marker.identifiers) or t.owner=any(marker.owners)
      or t.owner_id=any(marker.owner_strings) or t.name like any(marker.owner_path_prefixes)) as synthetic_rows
  from marker
  union all
  select 'public.bil_follows' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_follows t cross join marker
  union all
  select 'auth.identities' as table_name,
    (select count(*) from auth.identities) as total_rows,
    (select count(*) from auth.identities t where t.id=any(marker.identifiers) or t.user_id=any(marker.owners)
      or t.provider_id=any(marker.owner_strings) or t.email=any(marker.emails)) as synthetic_rows
  from marker
  union all
  select 'auth.sessions' as table_name,
    (select count(*) from auth.sessions) as total_rows,
    (select count(*) from auth.sessions t where t.id=any(marker.identifiers) or t.user_id=any(marker.owners)) as synthetic_rows
  from marker
  union all
  select 'auth.refresh_tokens' as table_name,
    (select count(*) from auth.refresh_tokens) as total_rows,
    (select count(*) from auth.refresh_tokens t where t.user_id=any(marker.owner_strings)) as synthetic_rows
  from marker
  union all
  select 'private.bil_community_publish_operations_v1' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from private.bil_community_publish_operations_v1 t cross join marker
  union all
  select 'private.bil_community_member_access' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from private.bil_community_member_access t cross join marker
  union all
  select 'private.bil_community_member_access_audit' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from private.bil_community_member_access_audit t cross join marker
  union all
  select 'private.bil_community_moderator_admin_audit' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from private.bil_community_moderator_admin_audit t cross join marker
  union all
  select 'public.bil_blocks' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_blocks t cross join marker
  union all
  select 'public.bil_friendships' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_friendships t cross join marker
  union all
  select 'public.bil_community_audit_events' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_audit_events t cross join marker
  union all
  select 'public.bil_community_circle_memberships' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_circle_memberships t cross join marker
  union all
  select 'public.bil_community_moderators' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_moderators t cross join marker
  union all
  select 'public.bil_content_policy_acceptances' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_content_policy_acceptances t cross join marker
  union all
  select 'public.bil_community_polls' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_polls t cross join marker
  union all
  select 'public.bil_community_poll_options' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_poll_options t cross join marker
  union all
  select 'public.bil_community_poll_votes' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_poll_votes t cross join marker
  union all
  select 'public.bil_social_comments_v2' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_social_comments_v2 t cross join marker
  union all
  select 'public.bil_social_comment_likes_v2' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_social_comment_likes_v2 t cross join marker
  union all
  select 'public.bil_social_comment_reports_v2' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_social_comment_reports_v2 t cross join marker
  union all
  select 'public.bil_social_post_likes_v2' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_social_post_likes_v2 t cross join marker
  union all
  select 'public.bil_social_post_saves_v2' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_social_post_saves_v2 t cross join marker
  union all
  select 'public.bil_social_public_codes_v2' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_social_public_codes_v2 t cross join marker
  union all
  select 'public.bil_community_xp_ledger' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_xp_ledger t cross join marker
  union all
  select 'public.bil_community_referral_attributions' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_referral_attributions t cross join marker
  union all
  select 'public.bil_community_invites' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_invites t cross join marker
  union all
  select 'public.bil_community_creator_certifications_v1' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_creator_certifications_v1 t cross join marker
  union all
  select 'public.bil_community_reports' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_community_reports t cross join marker
  union all
  select 'public.bil_messages' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_messages t cross join marker
  union all
  select 'public.bil_push_delivery_attempts' as table_name, count(*) as total_rows,
    count(*) filter (where pg_catalog.to_jsonb(t)::text ~ marker.pattern) as synthetic_rows
  from public.bil_push_delivery_attempts t cross join marker
  union all
  select 'public.bil_push_device_tokens' as table_name, count(*) as total_rows,
    count(*) filter (where t.user_id=any(marker.owners)) as synthetic_rows
  from public.bil_push_device_tokens t cross join marker
  union all
  select 'private.bil_push_delivery_preferences_v1' as table_name,
    (select count(*) from private.bil_push_delivery_preferences_v1) as total_rows,
    (select count(*) from private.bil_push_delivery_preferences_v1 t
      where t.user_id=any(marker.owners)) as synthetic_rows
  from marker
)
select pg_catalog.statement_timestamp() as inspected_at,
  pg_catalog.jsonb_agg(pg_catalog.to_jsonb(inventory) order by table_name) as table_inventory,
  pg_catalog.bool_and(synthetic_rows=0) as zero_synthetic_rows,
  count(*) as inventoried_table_count
from inventory;
-- END SEGMENT RESIDUE

