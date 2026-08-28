begin;

do $migration$
declare
  v_oid oid;
  v_definition text;
  v_old text := $old$  select public.bil_resolve_ai_allowance_plan(v_owner) into v_plan;

  select weekly_limit, monthly_limit$old$;
  v_new text := $new$  select public.bil_resolve_ai_allowance_plan(v_owner) into v_plan;

  if v_plan = 'trial' then
    select coalesce(s.started_at, s.verified_at)::date
      into v_week
    from public.bil_subscriptions s
    where s.owner_id = v_owner
      and s.lifecycle = 'trial'
      and s.expires_at > now();
    if v_week is null then raise exception 'trial_period_missing'; end if;
    v_month := v_week;
  end if;

  select weekly_limit, monthly_limit$new$;
  v_name text;
begin
  foreach v_name in array array[
    'bil_reserve_ai_usage',
    'bil_get_ai_usage_status'
  ]
  loop
    select p.oid into v_oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = v_name;

    if v_oid is null then
      raise exception 'required function % is missing', v_name;
    end if;
    v_definition := pg_get_functiondef(v_oid);
    if position(v_old in v_definition) = 0 then
      raise exception 'trial anchor point not found in %', v_name;
    end if;
    v_definition := replace(v_definition, v_old, v_new);
    v_definition := replace(
      v_definition,
      $old$(v_month + interval '1 month')::date$old$,
      $new$case when v_plan = 'trial'
        then (v_week + 7)::date
        else (v_month + interval '1 month')::date
      end$new$
    );
    execute v_definition;
  end loop;
end
$migration$;

create or replace function public.bil_sync_ai_monthly_usage()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_plan text := public.bil_resolve_ai_allowance_plan(new.owner_id);
  v_month date := date_trunc('month', now() at time zone 'utc')::date;
  v_used_delta bigint;
  v_reserved_delta bigint;
  v_limit bigint;
  v_total bigint;
begin
  if v_plan = 'trial' then
    select coalesce(s.started_at, s.verified_at)::date
      into v_month
    from public.bil_subscriptions s
    where s.owner_id = new.owner_id
      and s.lifecycle = 'trial'
      and s.expires_at > now();
    if v_month is null then raise exception 'trial_period_missing'; end if;
  end if;

  if tg_op = 'INSERT' then
    v_used_delta := new.used;
    v_reserved_delta := new.reserved;
  else
    v_used_delta := new.used - old.used;
    v_reserved_delta := new.reserved - old.reserved;
  end if;

  insert into public.bil_ai_credit_monthly_usage(owner_id, month_start)
    values(new.owner_id, v_month) on conflict do nothing;
  select monthly_limit into v_limit
  from public.bil_ai_credit_config
  where plan_id = v_plan;

  update public.bil_ai_credit_monthly_usage set
    used = greatest(used + v_used_delta, 0),
    reserved = greatest(reserved + v_reserved_delta, 0),
    updated_at = now()
  where owner_id = new.owner_id and month_start = v_month
  returning used + reserved into v_total;

  if v_limit is not null and v_total > v_limit then
    raise exception 'ai_monthly_usage_exhausted';
  end if;
  return new;
end
$$;

commit;;
