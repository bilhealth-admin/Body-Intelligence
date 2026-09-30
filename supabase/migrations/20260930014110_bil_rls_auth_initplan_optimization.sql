-- Mirrors production migration 20260930014110.
-- Performance-only RLS hardening: evaluate auth.uid() once per statement.

alter policy bil_consent_receipts_own_read on public.bil_consent_receipts
  using (user_id = (select auth.uid()));

alter policy bil_ai_weekly_usage_read_own on public.bil_ai_weekly_usage
  using (owner_id = (select auth.uid()));

alter policy bil_ai_paid_balances_read_own on public.bil_ai_paid_balances
  using (owner_id = (select auth.uid()));

alter policy bil_ai_boost_purchases_read_own on public.bil_ai_boost_purchases
  using (owner_id = (select auth.uid()));

alter policy bil_ai_coach_subscriptions_read_own on public.bil_ai_coach_subscriptions
  using (owner_id = (select auth.uid()));

alter policy bil_ai_usage_events_read_own on public.bil_ai_usage_events
  using (owner_id = (select auth.uid()));

alter policy bil_messages_read_parties on public.bil_messages
  using (
    ((sender_id = (select auth.uid())) and deleted_by_sender_at is null)
    or ((recipient_id = (select auth.uid())) and deleted_by_recipient_at is null)
  );

alter policy bil_policy_acceptance_own on public.bil_content_policy_acceptances
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

alter policy bil_cloud_operations_owner_select on public.bil_cloud_operations
  using (owner_id = (select auth.uid()));

alter policy bil_cloud_operations_owner_insert on public.bil_cloud_operations
  with check (owner_id = (select auth.uid()));

alter policy bil_cloud_records_owner_select on public.bil_cloud_records
  using (owner_id = (select auth.uid()));

alter policy bil_cloud_records_owner_insert on public.bil_cloud_records
  with check (owner_id = (select auth.uid()));

alter policy bil_cloud_records_owner_update on public.bil_cloud_records
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

alter policy bil_follows_read on public.bil_follows
  using (
    follower_id = (select auth.uid())
    or followed_id = (select auth.uid())
  );

alter policy bil_follows_own_write on public.bil_follows
  using (follower_id = (select auth.uid()))
  with check (follower_id = (select auth.uid()));
