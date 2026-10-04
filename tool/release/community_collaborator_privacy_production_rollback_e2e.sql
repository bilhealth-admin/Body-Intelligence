-- DRAFT / NOT EXECUTED. Prepared from current Production metadata 2026-10-04.
-- Project tgmanzhqulksykhslrzb. ROOT REVIEW REQUIRED; NOT a migration/build.
-- Execute ONLY after exact new staging Targeted + Candidate SUCCESS, permanent
-- community_collaborator_projection_privacy_v1 apply, and full source/body/ACL
-- readback. Source version170806 is NOT assumed to equal MCP's actual version.
--
-- Three INDEPENDENT calls: PRECHECK then TRANSACTION then RESIDUE.
-- Retain both68-table JSON inventories externally; require every synthetic_rows
-- zero, count68. Real concurrent traffic may change unrelated global counts.
-- TRANSACTION must return explicit PASS and all assertions; a tool/transport
-- error or last successful ROLLBACK is NOT PASS. Independently check RESIDUE
-- even after error; never retry until exact error and residue reviewed.
-- No function swapping, helper/temp DDL, GRANT, permanent config, external
-- Auth/API/provider/native call, Storage upload, or existing identity edit.
-- Four NEVER-existing SQL auth identities have no usable password/session.
-- Ordinary owner profile/policy/handle, atomic publish, metadata setter,
-- moderator review, collaboration acceptance and block RPCs are real calls.
-- One synthetic moderator roster row and synthetic suspension flag are
-- explicit backend fixture setup inside this rollback, not proof of admin UI/
-- suspension service workflow. ONLY these synthetic setup rows may be reset.
-- All identity reads use ordinary authenticated role. No app CRUD privileges
-- are manufactured. Accepted collaboration persists when identity is hidden.
-- Post approval may grant configured real credits ONLY to synthetic owner,
-- uncommitted and rolled back. No reward policy is changed or fake value shown.
-- No provider token is registered. Uncommitted Activity/outbox rows are invisible
-- to external workers. Refuse any new Auth/notification/outbox trigger hook.
-- This is SQL boundary proof, NOT real Auth/device/StoreKit/push/visual evidence.
-- Sequence values can advance despite rollback; gaps are not surviving rows.

-- BEGIN SEGMENT PRECHECK
-- PRECHECK: READ-ONLY; execute separately and retain the returned JSON externally.
-- Counts may change because of genuine concurrent traffic. Never require global equality.
-- synthetic_rows must be zero for EVERY row; missing tables/errors are NOT a pass.
with marker as (
  select 'bil_collab_privacy_rollback_20261004_cdfbafad|cdfbafad-a72e-4996-84c2-21524aa659c4|281f5a9b-15ea-4bf0-abbe-a8dae0de7034|9a1009bb-9093-4585-9f9d-6c92ed17071b|98785458-b0d2-4ce8-a013-36cb04900847|7cf938ee-ddc7-4687-abd4-3b518f784596'::text as pattern,
    array['cdfbafad-a72e-4996-84c2-21524aa659c4','281f5a9b-15ea-4bf0-abbe-a8dae0de7034','9a1009bb-9093-4585-9f9d-6c92ed17071b','98785458-b0d2-4ce8-a013-36cb04900847','7cf938ee-ddc7-4687-abd4-3b518f784596']::uuid[] as identifiers,
    array['cdfbafad-a72e-4996-84c2-21524aa659c4','281f5a9b-15ea-4bf0-abbe-a8dae0de7034','9a1009bb-9093-4585-9f9d-6c92ed17071b','98785458-b0d2-4ce8-a013-36cb04900847']::uuid[] as owners,
    array['cdfbafad-a72e-4996-84c2-21524aa659c4','281f5a9b-15ea-4bf0-abbe-a8dae0de7034','9a1009bb-9093-4585-9f9d-6c92ed17071b','98785458-b0d2-4ce8-a013-36cb04900847']::text[] as owner_strings,
    array['bil_collab_privacy_rollback_20261004_cdfbafad-author@example.invalid','bil_collab_privacy_rollback_20261004_cdfbafad-collab@example.invalid','bil_collab_privacy_rollback_20261004_cdfbafad-viewer@example.invalid','bil_collab_privacy_rollback_20261004_cdfbafad-moderator@example.invalid']::text[] as emails,
    'bil_collab_privacy_rollback_20261004_cdfbafad'::text as audit_marker,
    array['cdfbafad-a72e-4996-84c2-21524aa659c4/%','281f5a9b-15ea-4bf0-abbe-a8dae0de7034/%','9a1009bb-9093-4585-9f9d-6c92ed17071b/%','98785458-b0d2-4ce8-a013-36cb04900847/%']::text[] as owner_path_prefixes
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
 v_a constant uuid:='cdfbafad-a72e-4996-84c2-21524aa659c4';
 v_c constant uuid:='281f5a9b-15ea-4bf0-abbe-a8dae0de7034';
 v_v constant uuid:='9a1009bb-9093-4585-9f9d-6c92ed17071b';
 v_m constant uuid:='98785458-b0d2-4ce8-a013-36cb04900847';
 v_post constant uuid:='7cf938ee-ddc7-4687-abd4-3b518f784596';
 v_marker constant text:='bil_collab_privacy_rollback_20261004_cdfbafad';
 v_owners constant uuid[]:=array[v_a,v_c,v_v,v_m];
 v_ids constant uuid[]:=array[v_a,v_c,v_v,v_m,v_post];
 v_emails constant text[]:=array[
  v_marker||'-author@example.invalid',v_marker||'-collab@example.invalid',
  v_marker||'-viewer@example.invalid',v_marker||'-moderator@example.invalid'];
 v_handles constant text[]:=array['qacdfbafad','qa281f5a9b','qa9a1009bb','qa98785458'];
 v_pattern constant text:='bil_collab_privacy_rollback_20261004_cdfbafad|cdfbafad-a72e-4996-84c2-21524aa659c4|281f5a9b-15ea-4bf0-abbe-a8dae0de7034|9a1009bb-9093-4585-9f9d-6c92ed17071b|98785458-b0d2-4ce8-a013-36cb04900847|7cf938ee-ddc7-4687-abd4-3b518f784596';
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
 v_uid uuid; v_table text; v_predicate text; v_policy text; v_state text;
 v_message text; v_context text; v_count bigint; v_i integer; v_tokens integer;
 v_payload jsonb; v_result jsonb; v_meta jsonb; v_checks jsonb:='{}';
begin
 if exists(select 1 from pg_roles where rolname in('anon','authenticated') and(rolsuper or rolbypassrls)) then
  raise exception 'AUDIT ordinary roles unexpectedly bypass RLS';
 end if;
 if(select count(*) from supabase_migrations.schema_migrations
    where name='community_collaborator_projection_privacy_v1')<>1
  or(select count(*) from supabase_migrations.schema_migrations
    where name='community_atomic_publish_operation_v1')<>1
  or md5(replace(pg_get_functiondef('public.bil_community_post_reference_metadata_v1(uuid[])'::regprocedure),chr(13),''))
    is distinct from '6527ab896dce29d2481b4f09aa8c331b' then
  raise exception 'AUDIT exact candidate collaborator function not permanently applied';
 end if;
 if has_function_privilege('anon','public.bil_community_post_reference_metadata_v1(uuid[])','EXECUTE')
  or not has_function_privilege('authenticated','public.bil_community_post_reference_metadata_v1(uuid[])','EXECUTE')
  or has_table_privilege('authenticated','public.bil_community_post_collaborators_v1','SELECT,INSERT,UPDATE,DELETE')
  or has_table_privilege('anon','public.bil_community_post_collaborators_v1','SELECT,INSERT,UPDATE,DELETE') then
  raise exception 'AUDIT collaborator RPC-only privileges changed';
 end if;
 -- Full exact68-table absence rechecked inside the transaction, not only in
 -- PRECHECK's earlier connector call. Credential tables use narrow predicates.
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
   into v_count using v_pattern,v_ids,v_owners,
    array[v_a::text,v_c::text,v_v::text,v_m::text],v_emails,
    array[v_a::text||'/%',v_c::text||'/%',v_v::text||'/%',v_m::text||'/%'],v_marker;
  if v_count<>0 then raise exception 'AUDIT preexisting synthetic residue in %',v_table; end if;
 end loop;
 if exists(select 1 from public.bil_social_handles_v2 where handle=any(v_handles)) then
  raise exception 'AUDIT synthetic handle already exists';
 end if;
 if exists(select 1 from pg_trigger where not tgisinternal and tgrelid in(
  'auth.users'::regclass,'public.bil_community_notifications'::regclass,'public.bil_push_outbox'::regclass)) then
  raise exception 'AUDIT external-boundary trigger inventory changed';
 end if;
 if(select count(*) from public.bil_content_policies where active and effective_at<=statement_timestamp())<>1 then
  raise exception 'AUDIT active policy unavailable';
 end if;
 select version into strict v_policy from public.bil_content_policies where active and effective_at<=statement_timestamp();
 select tokens_per_approval into strict v_tokens from public.bil_community_post_reward_policy where singleton;
 v_checks:=v_checks||jsonb_build_object('exact_candidate_body_acl_rpc_only',true,'all68_synthetic_absent',true);

 for v_i in 1..4 loop
  v_uid:=v_owners[v_i];
  insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,
   raw_app_meta_data,raw_user_meta_data,is_anonymous) values(v_uid,
   'authenticated','authenticated',v_emails[v_i],now(),now(),now(),
   '{"provider":"email","providers":["email"]}',jsonb_build_object('audit_marker',v_marker),false);
  perform set_config('request.jwt.claim.sub',v_uid::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_uid,'role','authenticated')::text,true);
  execute 'set local role authenticated';
  if current_user<>'authenticated' or auth.uid() is distinct from v_uid then raise exception 'AUDIT principal mismatch'; end if;
  insert into public.bil_public_profiles(user_id,display_name,bio,profile_visibility,discoverable,allow_follows)
   values(v_uid,case v_i when 1 then 'Audit Author' when 2 then 'Audit Collaborator'
    when 3 then 'Audit Viewer' else 'Audit Moderator' end,'Nutrition collaboration audit','public',true,true);
  insert into public.bil_content_policy_acceptances(user_id,policy_version)
   values(v_uid,v_policy) on conflict(user_id,policy_version) do update
   set user_id=excluded.user_id,policy_version=excluded.policy_version;
  if public.bil_current_community_policy_status()->>'status' is distinct from 'accepted' then
   raise exception 'AUDIT genuine policy owner readback failed';
  end if;
  perform public.bil_social_claim_handle_v2(v_handles[v_i]);
  execute 'reset role';
 end loop;
 insert into public.bil_community_moderators(user_id) values(v_m);
 v_checks:=v_checks||jsonb_build_object('four_new_ordinary_owner_profile_policy_handles',true,'distinct_synthetic_moderator_setup',true);

 perform set_config('request.jwt.claim.sub',v_a::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',v_a,'role','authenticated')::text,true);
 execute 'set local role authenticated';
 v_payload:=jsonb_build_object('body','Authoritative collaboration privacy audit','media','[]'::jsonb,
  'topic_slugs','[]'::jsonb,'circle_slug',null,'location_label',null,'mentioned_user_ids','[]'::jsonb,
  'title','Collaboration privacy audit','hashtags',jsonb_build_array('habits'),
  'collaborator_user_ids',jsonb_build_array(v_c::text),'poll',null,'persistent_draft_id',null);
 v_result:=public.bil_begin_my_community_publish_operation_v1(v_post,v_payload);
 if v_result->>'owner_id' is distinct from v_a::text or v_result->>'status' is distinct from 'prepared' then
  raise exception 'AUDIT owner preparation failed';
 end if;
 v_result:=public.bil_publish_community_post_operation_v1(v_post,v_payload);
 if (v_result @> jsonb_build_object('committed',true,'post_id',v_post,'owner_id',v_a)) is distinct from true then
  raise exception 'AUDIT canonical atomic publish did not commit';
 end if;
 v_result:=public.bil_set_my_community_post_reference_metadata_v1(v_post,'Collaboration privacy audit',array['habits'],array[v_c]);
 if (v_result @> jsonb_build_object('post_id',v_post,'collaborator_count',1,'hashtag_count',1)) is distinct from true then
  raise exception 'AUDIT real owner metadata setter failed';
 end if;
 select to_jsonb(t) into strict v_meta from public.bil_community_post_reference_metadata_v1(array[v_post])t;
 if jsonb_array_length(v_meta->'collaborators') is distinct from 1 then raise exception 'AUDIT author pending invitation absent'; end if;
 v_checks:=v_checks||jsonb_build_object('real_atomic_publish_owner_receipt',true,'real_pending_metadata_setter',true,'author_pending_status',true);
 perform set_config('request.jwt.claim.sub',v_c::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',v_c,'role','authenticated')::text,true);
 v_state:=null;
 begin perform public.bil_respond_community_collaboration_v1(v_post,true);
 exception when others then get stacked diagnostics v_state=returned_sqlstate; end;
 if v_state is distinct from '42501' then raise exception 'AUDIT preapproval acceptance not denied %',v_state; end if;
 perform set_config('request.jwt.claim.sub',v_v::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',v_v,'role','authenticated')::text,true);
 if exists(select 1 from public.bil_community_post_reference_metadata_v1(array[v_post])) then
  raise exception 'AUDIT unrelated viewer read pending post';
 end if;
 execute 'reset role';
 if exists(select 1 from public.bil_community_notifications where entity_id=v_post::text and kind='collaboration_invite') then
  raise exception 'AUDIT invitation emitted before human approval';
 end if;
 perform set_config('request.jwt.claim.sub',v_m::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',v_m,'role','authenticated')::text,true);
 execute 'set local role authenticated';
 v_result:=public.bil_moderate_community_post(v_post,'approved');
 if (v_result @> jsonb_build_object('post_id',v_post,'decision','approved','duplicate',false,'tokens_granted',v_tokens)) is distinct from true then
  raise exception 'AUDIT real distinct moderator approval failed';
 end if;
 perform set_config('request.jwt.claim.sub',v_v::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',v_v,'role','authenticated')::text,true);
 select to_jsonb(t) into strict v_meta from public.bil_community_post_reference_metadata_v1(array[v_post])t;
 if v_meta->'collaborators' is distinct from '[]'::jsonb then raise exception 'AUDIT pending identity public'; end if;
 perform set_config('request.jwt.claim.sub',v_c::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',v_c,'role','authenticated')::text,true);
 v_result:=public.bil_respond_community_collaboration_v1(v_post,true);
 if (v_result @> '{"status":"accepted","duplicate":false}'::jsonb) is distinct from true then raise exception 'AUDIT real acceptance failed'; end if;
 v_result:=public.bil_respond_community_collaboration_v1(v_post,true);
 if (v_result @> '{"status":"accepted","duplicate":true}'::jsonb) is distinct from true then raise exception 'AUDIT duplicate acceptance not idempotent'; end if;
 v_checks:=v_checks||jsonb_build_object('preapproval_acceptance_denied',true,'pending_post_private',true,'no_early_activity',
  true,'real_human_moderation_rpc',true,'unaccepted_identity_not_public',true,'real_acceptance',true,'duplicate_accept_idempotent',true);

 perform set_config('request.jwt.claim.sub',v_v::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',v_v,'role','authenticated')::text,true);
 select to_jsonb(t) into strict v_meta from public.bil_community_post_reference_metadata_v1(array[v_post])t;
 if jsonb_array_length(v_meta->'collaborators') is distinct from 1 or (v_meta->'collaborators' @>
  jsonb_build_array(jsonb_build_object('user_id',v_c,'handle',v_handles[2],'display_name','Audit Collaborator','status','accepted'))) is distinct from true
  or(select count(*) from jsonb_object_keys(v_meta))<>6 then
  raise exception 'AUDIT public accepted identity/bounded metadata shape mismatch';
 end if;
 v_checks:=v_checks||jsonb_build_object('public_accepted_identity_authoritative',true,'no_extra_collaborator_total_projection',true);
 -- Privacy writes are real owner-scoped profile UPDATEs, exactly the live
 -- client table contract. Readback and affected-row count are not assumed.
 for v_i in 1..3 loop
  perform set_config('request.jwt.claim.sub',v_c::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_c,'role','authenticated')::text,true);
  update public.bil_public_profiles set profile_visibility=case v_i when 1 then 'private' when 2 then 'public' else 'friends' end,
   discoverable=(v_i<>2) where user_id=v_c;
  get diagnostics v_count=row_count;
  if v_count<>1 then raise exception 'AUDIT owner privacy write affected %',v_count; end if;
  perform set_config('request.jwt.claim.sub',v_v::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_v,'role','authenticated')::text,true);
  select to_jsonb(t) into strict v_meta from public.bil_community_post_reference_metadata_v1(array[v_post])t;
  if v_meta->'collaborators' is distinct from '[]'::jsonb or position(v_c::text in v_meta::text)>0
   or(select count(*) from jsonb_object_keys(v_meta))<>6 then
   raise exception 'AUDIT third-actor identity/count leakage after privacy state %',v_i;
  end if;
  v_checks:=v_checks||jsonb_build_object(case v_i when 1 then 'private_third_actor_hidden'
   when 2 then 'undiscoverable_third_actor_hidden' else 'friends_only_stranger_hidden' end,true);
  if v_i=1 then
   perform set_config('request.jwt.claim.sub',v_a::text,true);
   perform set_config('request.jwt.claims',jsonb_build_object('sub',v_a,'role','authenticated')::text,true);
   select collaborators into strict v_result from public.bil_community_post_reference_metadata_v1(array[v_post]);
   if v_result is distinct from '[]'::jsonb then raise exception 'AUDIT author bypasses current private collaborator'; end if;
   perform set_config('request.jwt.claim.sub',v_c::text,true);
   perform set_config('request.jwt.claims',jsonb_build_object('sub',v_c,'role','authenticated')::text,true);
   select collaborators into strict v_result from public.bil_community_post_reference_metadata_v1(array[v_post]);
   if jsonb_array_length(v_result) is distinct from 1 then raise exception 'AUDIT private self identity unreachable'; end if;
   perform set_config('request.jwt.claim.sub',v_m::text,true);
   perform set_config('request.jwt.claims',jsonb_build_object('sub',v_m,'role','authenticated')::text,true);
   select collaborators into strict v_result from public.bil_community_post_reference_metadata_v1(array[v_post]);
   if jsonb_array_length(v_result) is distinct from 1 then raise exception 'AUDIT trusted moderator private review lost'; end if;
   perform set_config('request.jwt.claim.sub',v_v::text,true);
   perform set_config('request.jwt.claims',jsonb_build_object('sub',v_v,'role','authenticated',
    'user_metadata',jsonb_build_object('role','admin','is_moderator',true))::text,true);
   select collaborators into strict v_result from public.bil_community_post_reference_metadata_v1(array[v_post]);
   if v_result is distinct from '[]'::jsonb then raise exception 'AUDIT user metadata forged review access'; end if;
   v_checks:=v_checks||jsonb_build_object('author_not_privacy_bypass',true,'private_self_still_visible',true,
    'trusted_moderator_review_preserved',true,'user_metadata_not_authority',true);
  end if;
 end loop;
 perform set_config('request.jwt.claim.sub',v_c::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',v_c,'role','authenticated')::text,true);
 update public.bil_public_profiles set profile_visibility='public',discoverable=true where user_id=v_c;
 get diagnostics v_count=row_count;
 if v_count<>1 then raise exception 'AUDIT privacy restore not owner-scoped'; end if;
 -- Actual owner block RPCs. Reset only this pair's newly created fixture row
 -- as backend setup between independent cases; NOT an unblock UI test.
 for v_i in 1..3 loop
  v_uid:=case v_i when 1 then v_c when 2 then v_v else v_c end;
  perform set_config('request.jwt.claim.sub',v_uid::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_uid,'role','authenticated')::text,true);
  perform public.bil_block_community_member(case when v_i=1 then v_v when v_i=2 then v_c else v_a end);
  v_uid:=case when v_i=3 then v_a else v_v end;
  perform set_config('request.jwt.claim.sub',v_uid::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_uid,'role','authenticated')::text,true);
  select to_jsonb(t) into strict v_meta from public.bil_community_post_reference_metadata_v1(array[v_post])t;
  if v_meta->'collaborators' is distinct from '[]'::jsonb or position(v_c::text in v_meta::text)>0 then
   raise exception 'AUDIT blocked collaborator identity/count leakage case %',v_i;
  end if;
  v_checks:=v_checks||jsonb_build_object(case v_i when 1 then 'collaborator_blocks_viewer_hidden'
   when 2 then 'viewer_blocks_collaborator_hidden' else 'blocked_author_cannot_bypass' end,true);
  execute 'reset role';
  delete from public.bil_blocks where blocker_id=v_uid and blocked_id=v_c
   or blocker_id=v_c and blocked_id=v_uid;
  get diagnostics v_count=row_count;
  if v_count<>1 then raise exception 'AUDIT fixture block reset not exact'; end if;
  execute 'set local role authenticated';
 end loop;
 execute 'reset role';
 insert into private.bil_community_member_access(user_id,suspended,reason)
  values(v_c,true,'Rollback collaborator privacy fixture');
 perform set_config('request.jwt.claim.sub',v_v::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',v_v,'role','authenticated')::text,true);
 execute 'set local role authenticated';
 select to_jsonb(t) into strict v_meta from public.bil_community_post_reference_metadata_v1(array[v_post])t;
 if v_meta->'collaborators' is distinct from '[]'::jsonb or position(v_c::text in v_meta::text)>0 then
  raise exception 'AUDIT suspended third-party collaborator exposed';
 end if;
 perform set_config('request.jwt.claim.sub',v_m::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',v_m,'role','authenticated')::text,true);
 select collaborators into strict v_result from public.bil_community_post_reference_metadata_v1(array[v_post]);
 if jsonb_array_length(v_result) is distinct from 1 then raise exception 'AUDIT suspended identity review evidence unavailable'; end if;
 execute 'reset role';
 delete from private.bil_community_member_access where user_id=v_c and reason='Rollback collaborator privacy fixture';
 get diagnostics v_count=row_count;
 if v_count<>1 then raise exception 'AUDIT synthetic suspension reset not exact'; end if;
 if(select count(*) from public.bil_community_post_collaborators_v1 where post_id=v_post
  and collaborator_id=v_c and status='accepted' and responded_at is not null)<>1 then
  raise exception 'AUDIT privacy/block/suspension destroyed authoritative acceptance';
 end if;
 v_checks:=v_checks||jsonb_build_object('suspended_identity_hidden',true,'suspended_moderator_review_preserved',true,
  'accepted_record_immutable_after_all_filters',true);

 perform set_config('request.jwt.claim.sub',v_v::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',v_v,'role','authenticated')::text,true);
 execute 'set local role authenticated';
 select to_jsonb(t) into strict v_meta from public.bil_community_post_reference_metadata_v1(array[v_post])t;
 if jsonb_array_length(v_meta->'collaborators') is distinct from 1 or v_meta->>'title' is distinct from 'Collaboration privacy audit'
  or v_meta->'hashtags' is distinct from '["habits"]'::jsonb then
  raise exception 'AUDIT final public identity or unrelated metadata corrupted';
 end if;
 v_state:=null;
 begin perform 1 from public.bil_community_post_collaborators_v1 where post_id=v_post;
 exception when others then get stacked diagnostics v_state=returned_sqlstate; end;
 if v_state is distinct from '42501' then raise exception 'AUDIT direct table read not denied %',v_state; end if;
 execute 'reset role';
 if exists(select 1 from public.bil_push_device_tokens where user_id=any(v_owners))
  or exists(select 1 from storage.objects where owner=any(v_owners) or owner_id=any(
   array[v_a::text,v_c::text,v_v::text,v_m::text])) then
  raise exception 'AUDIT unrequested provider/storage artifacts created';
 end if;
 v_checks:=v_checks||jsonb_build_object('restored_identity_real_not_fake',true,'unrelated_metadata_preserved',true,
  'direct_table_read_denied',true,'no_provider_tokens_or_storage_objects',true);
 if(select count(*) from jsonb_object_keys(v_checks))<30 then raise exception 'AUDIT assertion inventory incomplete'; end if;
 perform set_config('bil.collab_privacy_e2e_assertions',v_checks::text,true);
 perform set_config('bil.collab_privacy_e2e_failure','',true);
 perform set_config('bil.collab_privacy_e2e_result','PASS',true);
 perform set_config('request.jwt.claim.sub','',true);
 perform set_config('request.jwt.claims','{}',true);
exception when others or query_canceled or assert_failure then
 get stacked diagnostics v_state=returned_sqlstate,v_message=message_text,v_context=pg_exception_context;
 perform set_config('bil.collab_privacy_e2e_result','FAIL',true);
 perform set_config('bil.collab_privacy_e2e_assertions','{}',true);
 perform set_config('bil.collab_privacy_e2e_failure',jsonb_build_object('sqlstate',v_state,
  'error',v_message,'stack_context',v_context,'checks_reached_before_failure',v_checks)::text,true);
end;
$audit$;
select statement_timestamp() as assertions_completed_at,
 coalesce(nullif(current_setting('bil.collab_privacy_e2e_result',true),''),'UNKNOWN') as transaction_result,
 nullif(current_setting('bil.collab_privacy_e2e_failure',true),'')::jsonb as exact_failure,
 coalesce(nullif(current_setting('bil.collab_privacy_e2e_assertions',true),'')::jsonb,'{}'::jsonb) as completed_assertions,
 (select count(*) from jsonb_object_keys(coalesce(nullif(current_setting('bil.collab_privacy_e2e_assertions',true),'')::jsonb,'{}'::jsonb))) as completed_assertion_count;
rollback;
-- END SEGMENT TRANSACTION

-- BEGIN SEGMENT RESIDUE
-- RESIDUE: READ-ONLY; execute separately and retain the returned JSON externally.
-- Counts may change because of genuine concurrent traffic. Never require global equality.
-- synthetic_rows must be zero for EVERY row; missing tables/errors are NOT a pass.
with marker as (
  select 'bil_collab_privacy_rollback_20261004_cdfbafad|cdfbafad-a72e-4996-84c2-21524aa659c4|281f5a9b-15ea-4bf0-abbe-a8dae0de7034|9a1009bb-9093-4585-9f9d-6c92ed17071b|98785458-b0d2-4ce8-a013-36cb04900847|7cf938ee-ddc7-4687-abd4-3b518f784596'::text as pattern,
    array['cdfbafad-a72e-4996-84c2-21524aa659c4','281f5a9b-15ea-4bf0-abbe-a8dae0de7034','9a1009bb-9093-4585-9f9d-6c92ed17071b','98785458-b0d2-4ce8-a013-36cb04900847','7cf938ee-ddc7-4687-abd4-3b518f784596']::uuid[] as identifiers,
    array['cdfbafad-a72e-4996-84c2-21524aa659c4','281f5a9b-15ea-4bf0-abbe-a8dae0de7034','9a1009bb-9093-4585-9f9d-6c92ed17071b','98785458-b0d2-4ce8-a013-36cb04900847']::uuid[] as owners,
    array['cdfbafad-a72e-4996-84c2-21524aa659c4','281f5a9b-15ea-4bf0-abbe-a8dae0de7034','9a1009bb-9093-4585-9f9d-6c92ed17071b','98785458-b0d2-4ce8-a013-36cb04900847']::text[] as owner_strings,
    array['bil_collab_privacy_rollback_20261004_cdfbafad-author@example.invalid','bil_collab_privacy_rollback_20261004_cdfbafad-collab@example.invalid','bil_collab_privacy_rollback_20261004_cdfbafad-viewer@example.invalid','bil_collab_privacy_rollback_20261004_cdfbafad-moderator@example.invalid']::text[] as emails,
    'bil_collab_privacy_rollback_20261004_cdfbafad'::text as audit_marker,
    array['cdfbafad-a72e-4996-84c2-21524aa659c4/%','281f5a9b-15ea-4bf0-abbe-a8dae0de7034/%','9a1009bb-9093-4585-9f9d-6c92ed17071b/%','98785458-b0d2-4ce8-a013-36cb04900847/%']::text[] as owner_path_prefixes
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
