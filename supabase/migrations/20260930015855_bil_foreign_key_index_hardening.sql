-- Mirrors production migration 20260930015855.
-- Adds covering indexes for foreign-key columns identified by Supabase advisor.

create index if not exists bil_idx_admin_boost_grants_owner
  on private.bil_admin_ai_boost_grants(owner_id);
create index if not exists bil_idx_ai_coach_admins_granted_by
  on private.bil_ai_coach_admins(granted_by);
create index if not exists bil_idx_ai_coach_global_reset_actor
  on private.bil_ai_coach_global_reset_audit(actor_id);
create index if not exists bil_idx_ai_coach_ind_reset_actor
  on private.bil_ai_coach_individual_reset_audit(actor_id);
create index if not exists bil_idx_ai_coach_ind_reset_target
  on private.bil_ai_coach_individual_reset_audit(target_id);
create index if not exists bil_idx_ai_coach_reset_grants_owner
  on private.bil_ai_coach_reset_token_grants(owner_id);
create index if not exists bil_idx_comm_access_reinstated_by
  on private.bil_community_member_access(reinstated_by);
create index if not exists bil_idx_comm_access_suspended_by
  on private.bil_community_member_access(suspended_by);
create index if not exists bil_idx_comm_access_audit_actor
  on private.bil_community_member_access_audit(actor_id);
create index if not exists bil_idx_comm_access_audit_target
  on private.bil_community_member_access_audit(target_id);
create index if not exists bil_idx_comm_mod_audit_actor
  on private.bil_community_moderator_admin_audit(actor_id);
create index if not exists bil_idx_comm_mod_audit_target
  on private.bil_community_moderator_admin_audit(target_id);
create index if not exists bil_idx_google_lineage_owner
  on private.bil_google_purchase_token_lineage(owner_id);

create index if not exists bil_idx_ai_boost_purchases_owner
  on public.bil_ai_boost_purchases(owner_id);
create index if not exists bil_idx_ai_boost_store_owner
  on public.bil_ai_boost_store_state(owner_id);
create index if not exists bil_idx_ai_qa_grants_owner
  on public.bil_ai_qa_grants(owner_id);
create index if not exists bil_idx_comm_audit_actor
  on public.bil_community_audit_events(actor_id);
create index if not exists bil_idx_comm_post_approval_by
  on public.bil_community_post_approval_grants(approved_by);
create index if not exists bil_idx_comm_posts_author
  on public.bil_community_posts(author_id);
create index if not exists bil_idx_policy_accept_version
  on public.bil_content_policy_acceptances(policy_version);
create index if not exists bil_idx_follows_followed
  on public.bil_follows(followed_id);
create index if not exists bil_idx_food_peer_reviewer
  on public.bil_food_peer_reviews(reviewer_id);
create index if not exists bil_idx_push_attempt_device
  on public.bil_push_delivery_attempts(device_token_id);
create index if not exists bil_idx_push_tokens_user
  on public.bil_push_device_tokens(user_id);
create index if not exists bil_idx_store_entitlement_owner
  on public.bil_store_entitlement_audit(owner_id);
create index if not exists bil_idx_store_receipts_owner
  on public.bil_store_receipts(owner_id);
create index if not exists bil_idx_subscriptions_provider_product
  on public.bil_subscriptions(provider, product_id);
create index if not exists bil_idx_support_requests_owner
  on public.bil_support_requests(owner_id);
