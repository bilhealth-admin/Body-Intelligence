begin;

-- Decision: BOTH_AI_PRODUCTS_NO_PREMIUM_TRIAL.
-- The 1,000-token allowance belongs only to a verified, unexpired trial for
-- one of the two Premium AI Coach subscription products. Regular Premium
-- remains a valid subscription tier but can never resolve to the AI trial
-- allowance, even if stale or malformed store metadata says "trial".
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
        -- A trial that failed the canonical predicate above must not fall
        -- through to the larger paid AI allowance.
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

-- A single fail-closed anchor authority keeps reservation, status, and the
-- weekly-to-monthly usage trigger on the same seven-day window. Returning NULL
-- is intentional when the canonical plan/product/lifecycle tuple is absent.
create or replace function public.bil_resolve_ai_trial_anchor(p_owner uuid)
returns date
language sql
stable
security definer
set search_path = public
as $$
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
$$;

revoke all on function public.bil_resolve_ai_trial_anchor(uuid)
  from public, anon, authenticated;
grant execute on function public.bil_resolve_ai_trial_anchor(uuid)
  to service_role;

-- Patch the two existing quota functions instead of duplicating their large,
-- independently tested implementations. The migration aborts if the expected
-- prior definition is absent, so a drifted database cannot silently retain an
-- unsafe trial-anchor query.
do $migration$
declare
  v_oid oid;
  v_definition text;
  v_signature text;
  v_old text := $old$    select coalesce(s.started_at, s.verified_at)::date
      into v_week
    from public.bil_subscriptions s
    where s.owner_id = v_owner
      and s.lifecycle = 'trial'
      and s.expires_at > now();$old$;
  v_new text := $new$    select public.bil_resolve_ai_trial_anchor(v_owner)
      into v_week;$new$;
begin
  foreach v_signature in array array[
    'public.bil_reserve_ai_usage(uuid,text,text,numeric)',
    'public.bil_get_ai_usage_status()'
  ]
  loop
    v_oid := to_regprocedure(v_signature)::oid;
    if v_oid is null then
      raise exception 'required function % is missing', v_signature;
    end if;

    v_definition := pg_get_functiondef(v_oid);
    if position(v_old in v_definition) = 0 then
      raise exception 'unsafe trial anchor block not found in %', v_signature;
    end if;

    v_definition := replace(v_definition, v_old, v_new);
    if position(v_old in v_definition) <> 0
       or position(v_new in v_definition) = 0 then
      raise exception 'trial anchor hardening failed for %', v_signature;
    end if;
    execute v_definition;
  end loop;
end
$migration$;

-- The monthly sync trigger has the same trial anchor under a different local
-- variable name and must use the same canonical helper.
do $migration$
declare
  v_oid oid := to_regprocedure(
    'public.bil_sync_ai_monthly_usage()'
  )::oid;
  v_definition text;
  v_old text := $old$    select coalesce(s.started_at, s.verified_at)::date
      into v_month
    from public.bil_subscriptions s
    where s.owner_id = new.owner_id
      and s.lifecycle = 'trial'
      and s.expires_at > now();$old$;
  v_new text := $new$    select public.bil_resolve_ai_trial_anchor(new.owner_id)
      into v_month;$new$;
begin
  if v_oid is null then
    raise exception 'required function bil_sync_ai_monthly_usage() is missing';
  end if;

  v_definition := pg_get_functiondef(v_oid);
  if position(v_old in v_definition) = 0 then
    raise exception 'unsafe trial anchor block not found in bil_sync_ai_monthly_usage()';
  end if;

  v_definition := replace(v_definition, v_old, v_new);
  if position(v_old in v_definition) <> 0
     or position(v_new in v_definition) = 0 then
    raise exception 'trial anchor hardening failed for bil_sync_ai_monthly_usage()';
  end if;
  execute v_definition;
end
$migration$;

commit;
