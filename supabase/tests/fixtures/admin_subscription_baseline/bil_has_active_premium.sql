-- Read-only production definition snapshot, 2026-09-10. Local test fixture only.
CREATE OR REPLACE FUNCTION public.bil_has_active_premium(p_owner_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select p_owner_id is not null and (
    exists (
      select 1
      from public.bil_entitlements e
      where e.owner_id = p_owner_id
        and e.entitlement_id in (
          'plan:premium',
          'plan:premium_ai_coach',
          'plan:legacy_plus'
        )
        and e.active = true
        and (e.expires_at is null or e.expires_at > now())
    )
    or exists (
      select 1
      from public.bil_subscriptions s
      where s.owner_id = p_owner_id
        and s.plan_id in ('premium', 'premium_ai_coach', 'legacy_plus')
        and s.lifecycle in ('trial', 'active', 'grace_period')
        and (
          coalesce(s.grace_period_ends_at, s.expires_at) is null
          or coalesce(s.grace_period_ends_at, s.expires_at) > now()
        )
    )
  );
$function$;
