begin;

-- The closed-test grant is an audited, time-bounded server authority that is
-- deliberately separate from Apple and Google purchases. It unlocks the paid
-- AI allowance for approved testers without fabricating a receipt or being
-- misclassified as the public seven-day trial.
create or replace function public.bil_resolve_ai_allowance_plan(p_owner uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select case
    when exists (
      select 1
      from public.bil_ai_closed_test_grants g
      where g.owner_id = p_owner
        and g.active
        and g.expires_at > now()
    ) then 'ai_coach'
    when exists (
      select 1
      from public.bil_subscriptions s
      where s.owner_id = p_owner
        and s.plan_id = 'premium_ai_coach'
        and s.product_id in (
          'bil_premium_ai_coach',
          'bil_premium_ai_coach_annual'
        )
        and s.lifecycle = 'trial'
        and s.expires_at is not null
        and s.expires_at > now()
    ) then 'trial'
    when exists (
      select 1
      from public.bil_ai_coach_subscriptions s
      where s.owner_id = p_owner
        and s.product_id in (
          'bil_premium_ai_coach',
          'bil_premium_ai_coach_annual'
        )
        and s.lifecycle in ('active', 'grace_period')
        and s.expires_at is not null
        and s.expires_at > now()
    ) then 'ai_coach'
    else 'free'
  end
$$;

revoke all on function public.bil_resolve_ai_allowance_plan(uuid)
  from public, anon, authenticated;
grant execute on function public.bil_resolve_ai_allowance_plan(uuid)
  to service_role;

comment on function public.bil_resolve_ai_allowance_plan(uuid) is
  'Resolves server-verified AI allowance. Active closed-test grants map to the paid AI Coach allowance, never to a store trial.';

commit;
