begin;

alter table public.bil_ai_usage_config
  add column if not exists monthly_limit numeric(12,3),
  add column if not exists annual_limit numeric(12,3);

update public.bil_ai_usage_config
set monthly_limit = case
      when plan_id = 'ai_coach' and capability = 'text' then 500
      when plan_id = 'ai_coach' and capability = 'vision' then 100
      when plan_id = 'ai_coach' and capability = 'voice' then 60
      else 0
    end,
    annual_limit = case
      when plan_id = 'ai_coach' and capability = 'text' then 5000
      when plan_id = 'ai_coach' and capability = 'vision' then 1000
      when plan_id = 'ai_coach' and capability = 'voice' then 600
      else 0
    end,
    updated_at = now();

alter table public.bil_ai_usage_config
  alter column monthly_limit set not null,
  alter column annual_limit set not null;

alter table public.bil_ai_usage_config
  drop constraint if exists bil_ai_usage_config_period_limits_check;
alter table public.bil_ai_usage_config
  add constraint bil_ai_usage_config_period_limits_check check (
    monthly_limit >= weekly_limit
    and annual_limit >= monthly_limit
  );

create index if not exists bil_ai_usage_events_period_lookup_idx
  on public.bil_ai_usage_events(owner_id, capability, created_at)
  where state in ('reserved','succeeded');

create or replace function public.bil_reserve_ai_usage(
  p_owner_id uuid,p_request_id text,p_capability text,p_units numeric default 1
) returns jsonb language plpgsql security definer set search_path=public as $$
declare
  v_owner uuid:=p_owner_id;
  v_week date:=date_trunc('week',now() at time zone 'utc')::date;
  v_month date:=date_trunc('month',now() at time zone 'utc')::date;
  v_year date:=date_trunc('year',now() at time zone 'utc')::date;
  v_plan text;
  v_week_limit numeric;
  v_month_limit numeric;
  v_annual_limit numeric;
  v_week_used numeric;
  v_week_reserved numeric;
  v_month_used numeric;
  v_month_reserved numeric;
  v_annual_used numeric;
  v_annual_reserved numeric;
  v_paid_granted numeric;
  v_paid_used numeric;
  v_paid_reserved numeric;
  v_week_debit numeric;
  v_paid_debit numeric;
  v_existing public.bil_ai_usage_events%rowtype;
begin
  if v_owner is null then raise exception 'owner_required'; end if;
  if p_capability not in ('vision','text','voice') or p_units<=0 or p_units>1000
     or length(trim(p_request_id)) not between 16 and 128 then
    raise exception 'invalid_ai_usage_request';
  end if;

  for v_existing in select * from public.bil_ai_usage_events
    where owner_id=v_owner and state='reserved' and reservation_expires_at<=now()
    for update
  loop
    update public.bil_ai_weekly_usage set
      reserved=greatest(reserved-v_existing.weekly_debit,0),updated_at=now()
      where owner_id=v_owner and week_start=v_existing.week_start
        and capability=v_existing.capability;
    update public.bil_ai_paid_balances set
      reserved=greatest(reserved-v_existing.paid_debit,0),updated_at=now()
      where owner_id=v_owner and capability=v_existing.capability;
    update public.bil_ai_usage_events set state='refunded',completed_at=now()
      where owner_id=v_owner and request_id=v_existing.request_id
        and capability=v_existing.capability;
  end loop;

  select * into v_existing from public.bil_ai_usage_events
    where owner_id=v_owner and request_id=trim(p_request_id)
      and capability=p_capability;
  if found then
    return jsonb_build_object('duplicate',true,'state',v_existing.state);
  end if;

  select case when exists(
    select 1 from public.bil_ai_coach_subscriptions s
    where s.owner_id=v_owner
      and s.lifecycle in ('trial','active','grace_period')
      and (s.expires_at is null or s.expires_at>now())
  ) then 'ai_coach' else 'free' end into v_plan;

  select weekly_limit,monthly_limit,annual_limit
    into v_week_limit,v_month_limit,v_annual_limit
    from public.bil_ai_usage_config
    where plan_id=v_plan and capability=p_capability;
  if v_week_limit is null or v_month_limit is null or v_annual_limit is null then
    raise exception 'ai_usage_not_configured';
  end if;

  insert into public.bil_ai_weekly_usage(owner_id,week_start,capability)
    values(v_owner,v_week,p_capability) on conflict do nothing;
  select used,reserved into v_week_used,v_week_reserved
    from public.bil_ai_weekly_usage
    where owner_id=v_owner and week_start=v_week and capability=p_capability
    for update;

  select
    coalesce(sum(weekly_debit) filter (where state='succeeded'),0),
    coalesce(sum(weekly_debit) filter (where state='reserved'),0)
  into v_month_used,v_month_reserved
  from public.bil_ai_usage_events
  where owner_id=v_owner and capability=p_capability
    and created_at>=v_month::timestamptz
    and created_at<(v_month+interval '1 month');

  select
    coalesce(sum(weekly_debit) filter (where state='succeeded'),0),
    coalesce(sum(weekly_debit) filter (where state='reserved'),0)
  into v_annual_used,v_annual_reserved
  from public.bil_ai_usage_events
  where owner_id=v_owner and capability=p_capability
    and created_at>=v_year::timestamptz
    and created_at<(v_year+interval '1 year');

  insert into public.bil_ai_paid_balances(owner_id,capability)
    values(v_owner,p_capability) on conflict do nothing;
  select granted,used,reserved into v_paid_granted,v_paid_used,v_paid_reserved
    from public.bil_ai_paid_balances
    where owner_id=v_owner and capability=p_capability
    for update;

  v_week_debit:=least(
    p_units,
    greatest(v_week_limit-v_week_used-v_week_reserved,0),
    greatest(v_month_limit-v_month_used-v_month_reserved,0),
    greatest(v_annual_limit-v_annual_used-v_annual_reserved,0)
  );
  v_paid_debit:=p_units-v_week_debit;
  if v_paid_debit>greatest(v_paid_granted-v_paid_used-v_paid_reserved,0) then
    raise exception 'ai_usage_exhausted';
  end if;

  update public.bil_ai_weekly_usage
    set reserved=reserved+v_week_debit,updated_at=now()
    where owner_id=v_owner and week_start=v_week and capability=p_capability;
  update public.bil_ai_paid_balances
    set reserved=reserved+v_paid_debit,updated_at=now()
    where owner_id=v_owner and capability=p_capability;
  insert into public.bil_ai_usage_events(
    owner_id,request_id,capability,state,weekly_debit,paid_debit,
    week_start,reservation_expires_at
  ) values(
    v_owner,trim(p_request_id),p_capability,'reserved',v_week_debit,
    v_paid_debit,v_week,now()+interval '15 minutes'
  );

  return jsonb_build_object(
    'duplicate',false,
    'state','reserved',
    'weekly_debit',v_week_debit,
    'paid_debit',v_paid_debit,
    'week_start',v_week,
    'reset_at',(v_week+7)::date,
    'month_start',v_month,
    'monthly_reset_at',(v_month+interval '1 month')::date,
    'annual_start',v_year,
    'annual_reset_at',(v_year+interval '1 year')::date
  );
end $$;

revoke all on function public.bil_reserve_ai_usage(uuid,text,text,numeric)
  from public,anon,authenticated;
grant execute on function public.bil_reserve_ai_usage(uuid,text,text,numeric)
  to service_role;

create or replace function public.bil_get_ai_usage_status()
returns jsonb language plpgsql security definer set search_path=public as $$
declare
  v_owner uuid:=auth.uid();
  v_week date:=date_trunc('week',now() at time zone 'utc')::date;
  v_month date:=date_trunc('month',now() at time zone 'utc')::date;
  v_year date:=date_trunc('year',now() at time zone 'utc')::date;
  v_plan text;
  v_capability text;
  v_week_limit numeric;
  v_month_limit numeric;
  v_annual_limit numeric;
  v_week_used numeric;
  v_week_reserved numeric;
  v_month_used numeric;
  v_month_reserved numeric;
  v_annual_used numeric;
  v_annual_reserved numeric;
  v_granted numeric;
  v_paid_used numeric;
  v_paid_reserved numeric;
  v_event public.bil_ai_usage_events%rowtype;
  v_rows jsonb:='{}'::jsonb;
begin
  if v_owner is null then raise exception 'authentication_required'; end if;

  for v_event in select * from public.bil_ai_usage_events
    where owner_id=v_owner and state='reserved' and reservation_expires_at<=now()
    for update
  loop
    update public.bil_ai_weekly_usage set
      reserved=greatest(reserved-v_event.weekly_debit,0),updated_at=now()
      where owner_id=v_owner and week_start=v_event.week_start
        and capability=v_event.capability;
    update public.bil_ai_paid_balances set
      reserved=greatest(reserved-v_event.paid_debit,0),updated_at=now()
      where owner_id=v_owner and capability=v_event.capability;
    update public.bil_ai_usage_events set state='refunded',completed_at=now()
      where owner_id=v_owner and request_id=v_event.request_id
        and capability=v_event.capability;
  end loop;

  select case when exists(
    select 1 from public.bil_ai_coach_subscriptions s
    where s.owner_id=v_owner
      and s.lifecycle in ('trial','active','grace_period')
      and (s.expires_at is null or s.expires_at>now())
  ) then 'ai_coach' else 'free' end into v_plan;

  foreach v_capability in array array['vision','text','voice'] loop
    select weekly_limit,monthly_limit,annual_limit
      into v_week_limit,v_month_limit,v_annual_limit
      from public.bil_ai_usage_config
      where plan_id=v_plan and capability=v_capability;

    select coalesce(used,0),coalesce(reserved,0)
      into v_week_used,v_week_reserved
      from public.bil_ai_weekly_usage
      where owner_id=v_owner and week_start=v_week
        and capability=v_capability;
    if not found then v_week_used:=0; v_week_reserved:=0; end if;

    select
      coalesce(sum(weekly_debit) filter (where state='succeeded'),0),
      coalesce(sum(weekly_debit) filter (where state='reserved'),0)
    into v_month_used,v_month_reserved
    from public.bil_ai_usage_events
    where owner_id=v_owner and capability=v_capability
      and created_at>=v_month::timestamptz
      and created_at<(v_month+interval '1 month');

    select
      coalesce(sum(weekly_debit) filter (where state='succeeded'),0),
      coalesce(sum(weekly_debit) filter (where state='reserved'),0)
    into v_annual_used,v_annual_reserved
    from public.bil_ai_usage_events
    where owner_id=v_owner and capability=v_capability
      and created_at>=v_year::timestamptz
      and created_at<(v_year+interval '1 year');

    select coalesce(granted,0),coalesce(used,0),coalesce(reserved,0)
      into v_granted,v_paid_used,v_paid_reserved
      from public.bil_ai_paid_balances
      where owner_id=v_owner and capability=v_capability;
    if not found then
      v_granted:=0; v_paid_used:=0; v_paid_reserved:=0;
    end if;

    v_rows:=v_rows||jsonb_build_object(
      v_capability,
      jsonb_build_object(
        'unit',case when v_capability='voice' then 'minutes' else 'requests' end,
        'weekly_limit',v_week_limit,
        'weekly_used',v_week_used,
        'weekly_reserved',v_week_reserved,
        'weekly_remaining',greatest(v_week_limit-v_week_used-v_week_reserved,0),
        'monthly_limit',v_month_limit,
        'monthly_used',v_month_used,
        'monthly_reserved',v_month_reserved,
        'monthly_remaining',greatest(v_month_limit-v_month_used-v_month_reserved,0),
        'annual_limit',v_annual_limit,
        'annual_used',v_annual_used,
        'annual_reserved',v_annual_reserved,
        'annual_remaining',greatest(v_annual_limit-v_annual_used-v_annual_reserved,0),
        'paid_granted',v_granted,
        'paid_used',v_paid_used,
        'paid_reserved',v_paid_reserved,
        'paid_remaining',greatest(v_granted-v_paid_used-v_paid_reserved,0)
      )
    );
  end loop;

  return jsonb_build_object(
    'plan',v_plan,
    'week_start',v_week,
    'reset_at',(v_week+7)::date,
    'month_start',v_month,
    'monthly_reset_at',(v_month+interval '1 month')::date,
    'annual_start',v_year,
    'annual_reset_at',(v_year+interval '1 year')::date,
    'capabilities',v_rows
  );
end $$;

revoke all on function public.bil_get_ai_usage_status()
  from public,anon,service_role;
grant execute on function public.bil_get_ai_usage_status()
  to authenticated;

commit;;
