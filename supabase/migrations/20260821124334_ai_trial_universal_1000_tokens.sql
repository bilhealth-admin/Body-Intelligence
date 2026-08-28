begin;

insert into public.bil_ai_credit_config(plan_id, weekly_limit, monthly_limit)
values ('trial', 1000, 1000)
on conflict (plan_id) do update set
  weekly_limit = excluded.weekly_limit,
  monthly_limit = excluded.monthly_limit,
  updated_at = now();

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
        and s.lifecycle = 'trial'
        and s.expires_at is not null
        and s.expires_at > now()
    ) then 'trial'
    when exists (
      select 1
      from public.bil_ai_coach_subscriptions s
      where s.owner_id = p_owner
        and s.lifecycle in ('trial', 'active', 'grace_period')
        and (s.expires_at is null or s.expires_at > now())
    ) then 'ai_coach'
    else 'free'
  end
$$;

revoke all on function public.bil_resolve_ai_allowance_plan(uuid)
  from public, anon, authenticated;
grant execute on function public.bil_resolve_ai_allowance_plan(uuid)
  to service_role;

do $migration$
declare
  v_oid oid;
  v_definition text;
  v_old text := $old$
  select case when exists(
    select 1 from public.bil_ai_coach_subscriptions s
    where s.owner_id = v_owner
      and s.lifecycle in ('trial','active','grace_period')
      and (s.expires_at is null or s.expires_at > now())
  ) then 'ai_coach' else 'free' end into v_plan;$old$;
  v_new text := $new$
  select public.bil_resolve_ai_allowance_plan(v_owner) into v_plan;$new$;
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
      raise exception 'allowance resolver block not found in %', v_name;
    end if;
    execute replace(v_definition, v_old, v_new);
  end loop;
end
$migration$;

commit;;
