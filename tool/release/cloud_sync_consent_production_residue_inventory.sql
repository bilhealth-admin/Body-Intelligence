-- READ-ONLY supplemental residue inventory; NOT EXECUTED.
-- Complements (does not replace/change) the cloud rollback E2E's strict6 known
-- mutated-table guards and TRANSACTION. No evidence of another touched table
-- was found: existing auth.users noninternal-trigger absence is fail-closed.
-- Run FULL_PRECHECK independently BEFORE the cloud E2E and FULL_RESIDUE AFTER,
-- including after a failed/transport-interrupted transaction. Retain both JSON
-- outputs externally. Require68 rows and every synthetic_rows=0; errors or a
-- missing table are NOT PASS. Global row counts may change with real traffic.
-- Exact unchanged community68-table predicates; only cloud owners/marker/email
-- variants substituted. Auth/Storage use narrow identifiers rather than token,
-- password, private key, payload or object-metadata output/serialization.
-- No writes, RPC calls, grants, DDL, credential reads, provider, build or tests.
-- The original6 cloud inventory remains required: its4 cloud/consent tables
-- are not in the canonical community68 (auth.users/auth.identities overlap).
-- Both inventories cover72 distinct tables; this file alone is NOT cloud
-- residue completeness. Broader cross-feature coverage is defense in depth,
-- not extra behavior proof or an invented finding. ROOT must still freshly
-- review actual Auth-trigger metadata before the separate transaction.

-- BEGIN SEGMENT FULL_PRECHECK
-- PRECHECK: READ-ONLY; execute separately and retain the returned JSON externally.
-- Counts may change because of genuine concurrent traffic. Never require global equality.
-- synthetic_rows must be zero for EVERY row; missing tables/errors are NOT a pass.
with marker as (
  select 'bil_cloud_rollback_20261004_c56534f4|c56534f4-b96f-498c-99e4-3a60f9ac2c9c|977a0ce5-c8a2-4046-b3db-1553f92daaab'::text as pattern,
    array['c56534f4-b96f-498c-99e4-3a60f9ac2c9c','977a0ce5-c8a2-4046-b3db-1553f92daaab']::uuid[] as identifiers,
    array['c56534f4-b96f-498c-99e4-3a60f9ac2c9c','977a0ce5-c8a2-4046-b3db-1553f92daaab']::uuid[] as owners,
    array['c56534f4-b96f-498c-99e4-3a60f9ac2c9c','977a0ce5-c8a2-4046-b3db-1553f92daaab']::text[] as owner_strings,
    array['bil_cloud_rollback_20261004_c56534f4@example.invalid','bil_cloud_rollback_20261004_c56534f4-a@example.invalid','bil_cloud_rollback_20261004_c56534f4-b@example.invalid']::text[] as emails,
    'bil_cloud_rollback_20261004_c56534f4'::text as audit_marker,
    array['c56534f4-b96f-498c-99e4-3a60f9ac2c9c/%','977a0ce5-c8a2-4046-b3db-1553f92daaab/%']::text[] as owner_path_prefixes
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
-- END SEGMENT FULL_PRECHECK

-- BEGIN SEGMENT FULL_RESIDUE
-- PRECHECK: READ-ONLY; execute separately and retain the returned JSON externally.
-- Counts may change because of genuine concurrent traffic. Never require global equality.
-- synthetic_rows must be zero for EVERY row; missing tables/errors are NOT a pass.
with marker as (
  select 'bil_cloud_rollback_20261004_c56534f4|c56534f4-b96f-498c-99e4-3a60f9ac2c9c|977a0ce5-c8a2-4046-b3db-1553f92daaab'::text as pattern,
    array['c56534f4-b96f-498c-99e4-3a60f9ac2c9c','977a0ce5-c8a2-4046-b3db-1553f92daaab']::uuid[] as identifiers,
    array['c56534f4-b96f-498c-99e4-3a60f9ac2c9c','977a0ce5-c8a2-4046-b3db-1553f92daaab']::uuid[] as owners,
    array['c56534f4-b96f-498c-99e4-3a60f9ac2c9c','977a0ce5-c8a2-4046-b3db-1553f92daaab']::text[] as owner_strings,
    array['bil_cloud_rollback_20261004_c56534f4@example.invalid','bil_cloud_rollback_20261004_c56534f4-a@example.invalid','bil_cloud_rollback_20261004_c56534f4-b@example.invalid']::text[] as emails,
    'bil_cloud_rollback_20261004_c56534f4'::text as audit_marker,
    array['c56534f4-b96f-498c-99e4-3a60f9ac2c9c/%','977a0ce5-c8a2-4046-b3db-1553f92daaab/%']::text[] as owner_path_prefixes
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
-- END SEGMENT FULL_RESIDUE
