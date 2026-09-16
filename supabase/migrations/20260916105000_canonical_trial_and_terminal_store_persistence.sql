begin;

-- Forward-only patches preserve the established atomic persistence contract.
-- Abort on unexpected live definitions rather than silently overriding drift.
do $migration$
declare
  v_oid oid := to_regprocedure('public.bil_persist_verified_store_purchase(uuid,text,text,text,text,text,text,text,text,timestamptz,timestamptz,timestamptz,boolean,timestamptz,text)');
  v_ordered_helper oid := to_regprocedure('private.bil_persist_verified_store_purchase_unordered(uuid,text,text,text,text,text,text,text,text,timestamptz,timestamptz,timestamptz,boolean,timestamptz,text)');
  v_definition text;
  v_old text;
  v_new text;
begin
  if v_oid is null then raise exception 'required_store_persistence_missing'; end if;
  v_definition := pg_get_functiondef(v_oid);
  if v_ordered_helper is not null and position('v_access_boundary' in v_definition)=0 then
    v_definition := pg_get_functiondef(v_ordered_helper);
  end if;
  if position('v_terminal_existing' in v_definition)>0 then return; end if;
  if position('v_access_boundary >= now()' in v_definition)=0
     or position('v_access_boundary timestamptz;' in v_definition)=0 then
    raise exception 'unexpected_store_persistence_definition';
  end if;
  v_definition := replace(v_definition,'v_access_boundary >= now()','v_access_boundary > now()');
  v_definition := replace(v_definition,'v_access_boundary timestamptz;',
    'v_access_boundary timestamptz; v_terminal_existing boolean := false;');
  v_old := $old$  if p_environment = 'production' and v_country !~ '^[A-Z]{2,3}$' then$old$;
  v_new := $new$  select exists (
    select 1 from public.bil_subscriptions s
    join public.bil_store_product_registry r
      on r.provider=s.provider and r.product_id=s.product_id
    where s.owner_id=p_owner_id and s.provider=p_provider
      and s.original_transaction_id=p_original_transaction_id
      and s.environment=p_environment and s.product_id=p_product_id
      and r.package_or_bundle_id=p_package_or_bundle_id
      and p_lifecycle in ('expired','refunded','revoked')
  ) into v_terminal_existing;
  if not v_terminal_existing and p_environment = 'production' and v_country !~ '^[A-Z]{2,3}$' then$new$;
  if position(v_old in v_definition)=0 then raise exception 'unexpected_store_country_guard'; end if;
  v_definition := replace(v_definition,v_old,v_new);
  v_old := '    and enabled = true;';
  if position(v_old in v_definition)=0 then raise exception 'unexpected_store_product_guard'; end if;
  v_definition := replace(v_definition,v_old,'    and (enabled = true or v_terminal_existing);');
  v_old := $old$  if v_country ~ '^[A-Z]{2,3}$'$old$;
  if position(v_old in v_definition)=0 then raise exception 'unexpected_store_market_guard'; end if;
  v_definition := replace(v_definition,v_old,$new$  if not v_terminal_existing and v_country ~ '^[A-Z]{2,3}$'$new$);
  execute v_definition;
end
$migration$;

create or replace function public.bil_valid_ai_trial_window(
  p_environment text,p_started_at timestamptz,p_expires_at timestamptz
) returns boolean language sql immutable set search_path=public
as $$
  select coalesce(p_started_at is not null and p_expires_at is not null
    and p_expires_at>p_started_at and (
      (p_environment='production' and p_expires_at-p_started_at=interval '7 days')
      or (p_environment='sandbox' and p_expires_at-p_started_at<=interval '7 days')
    ),false)
$$;
revoke all on function public.bil_valid_ai_trial_window(text,timestamptz,timestamptz)
  from public,anon,authenticated;
grant execute on function public.bil_valid_ai_trial_window(text,timestamptz,timestamptz) to service_role;

create or replace function public.bil_is_current_ai_trial(p_owner uuid)
returns boolean language sql stable security definer set search_path=public
as $$
  select exists(select 1 from public.bil_subscriptions s
    where s.owner_id=p_owner and s.plan_id='premium_ai_coach'
      and s.product_id in ('bil_premium_ai_coach','bil_premium_ai_coach_annual')
      and s.started_at<=now() and s.expires_at>now()
      and public.bil_valid_ai_trial_window(s.environment,s.started_at,s.expires_at)
      and (s.lifecycle='trial' or (s.lifecycle='cancelled' and (
        s.environment='production' or exists(select 1 from public.bil_ai_coach_subscriptions m
          where m.owner_id=s.owner_id and m.provider=s.provider
            and m.product_id=s.product_id and m.original_transaction_id=s.original_transaction_id
            and m.expires_at=s.expires_at and m.lifecycle='trial')
      ))))
$$;
revoke all on function public.bil_is_current_ai_trial(uuid) from public,anon,authenticated;
grant execute on function public.bil_is_current_ai_trial(uuid) to service_role;

-- The canonical verified row, not a stale mirror, owns the quota decision.
-- A cancelled short trial is still a trial, not a promotion to paid allowance.
create or replace function public.bil_resolve_ai_allowance_plan(p_owner uuid)
returns text language sql stable security definer set search_path=public
as $$
  select case
    when bil_admin_private.active_plan(p_owner)='premium_ai_coach' then 'ai_coach'
    when exists(select 1 from public.bil_ai_closed_test_grants g
      where g.owner_id=p_owner and g.active and g.expires_at>now()) then 'ai_coach'
    when public.bil_is_current_ai_trial(p_owner) then 'trial'
    when exists(select 1 from public.bil_subscriptions s
      where s.owner_id=p_owner and s.plan_id='premium_ai_coach'
        and s.product_id in ('bil_premium_ai_coach','bil_premium_ai_coach_annual')
        and s.lifecycle in ('active','grace_period','cancelled')
        and (case when s.lifecycle='grace_period' then s.grace_period_ends_at else s.expires_at end)>now()
        and not public.bil_is_current_ai_trial(p_owner)) then 'ai_coach'
    else 'free'
  end
$$;

create or replace function public.bil_resolve_ai_trial_anchor(p_owner uuid)
returns date language sql stable security definer set search_path=public
as $$
  select (s.started_at at time zone 'UTC')::date from public.bil_subscriptions s
  where s.owner_id=p_owner and s.plan_id='premium_ai_coach'
    and s.product_id in ('bil_premium_ai_coach','bil_premium_ai_coach_annual')
    and public.bil_is_current_ai_trial(p_owner)
  limit 1
$$;
revoke all on function public.bil_resolve_ai_allowance_plan(uuid),public.bil_resolve_ai_trial_anchor(uuid)
  from public,anon,authenticated;
grant execute on function public.bil_resolve_ai_allowance_plan(uuid),public.bil_resolve_ai_trial_anchor(uuid) to service_role;

-- Preserve the original mirror implementation, changing only cancellation's
-- classification. Other downgrade/revocation cleanup and QA overlays remain.
do $migration$
declare
  v_oid oid := to_regprocedure('public.bil_sync_ai_coach_store_subscription()');
  v_definition text;
  v_old text := $old$    when new.lifecycle = 'cancelled' then 'active'$old$;
  v_new text := $new$    when new.lifecycle = 'cancelled' and public.bil_valid_ai_trial_window(
      new.environment,new.started_at,new.expires_at) and (
        new.environment='production'
        or (tg_op='UPDATE' and old.lifecycle='trial' and old.provider=new.provider
          and old.original_transaction_id=new.original_transaction_id and old.expires_at=new.expires_at)
        or exists(select 1 from public.bil_ai_coach_subscriptions m
          where m.owner_id=new.owner_id and m.provider=new.provider and m.product_id=new.product_id
            and m.original_transaction_id=new.original_transaction_id and m.expires_at=new.expires_at
            and m.lifecycle='trial')
      ) then 'trial'
    when new.lifecycle = 'cancelled' then 'active'$new$;
begin
  if v_oid is null then raise exception 'required_store_mirror_missing'; end if;
  v_definition := pg_get_functiondef(v_oid);
  if position('bil_valid_ai_trial_window' in v_definition)>0 then return; end if;
  if position(v_old in v_definition)=0 then raise exception 'unexpected_store_mirror_definition'; end if;
  execute replace(v_definition,v_old,v_new);
end
$migration$;

commit;
