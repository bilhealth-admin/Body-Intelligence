-- Read-only production definition snapshot, 2026-09-10. Local test fixture only.
CREATE OR REPLACE FUNCTION public.bil_resolve_ai_allowance_plan(p_owner uuid)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;
