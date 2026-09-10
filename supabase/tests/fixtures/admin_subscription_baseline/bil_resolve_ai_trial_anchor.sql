-- Read-only production definition snapshot, 2026-09-10. Local test fixture only.
CREATE OR REPLACE FUNCTION public.bil_resolve_ai_trial_anchor(p_owner uuid)
 RETURNS date
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(s.started_at, s.verified_at)::date
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
    and coalesce(s.started_at, s.verified_at) is not null
    and coalesce(s.started_at, s.verified_at) <= now()
  limit 1
$function$;
