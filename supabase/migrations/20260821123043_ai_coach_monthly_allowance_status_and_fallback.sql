
begin;

create or replace function public.bil_reserve_ai_usage(
  p_owner_id uuid,
  p_request_id text,
  p_capability text,
  p_units numeric default 1
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid := p_owner_id;
  v_week date := date_trunc('week', now() at time zone 'utc')::date;
  v_month date := date_trunc('month', now() at time zone 'utc')::date;
  v_plan text;
  v_week_limit bigint;
  v_month_limit bigint;
  v_week_used bigint;
  v_week_reserved bigint;
  v_month_used bigint;
  v_month_reserved bigint;
  v_paid_granted bigint;
  v_paid_used bigint;
  v_paid_reserved bigint;
  v_credit_reserve bigint;
  v_included_debit bigint;
  v_paid_debit bigint;
  v_existing public.bil_ai_usage_events%rowtype;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    raise exception 'service_role_required';
  end if;
  if v_owner is null then raise exception 'owner_required'; end if;
  if p_capability not in ('vision','text','voice')
     or p_units <= 0 or p_units > 1000
     or length(trim(p_request_id)) not between 16 and 128 then
    raise exception 'invalid_ai_usage_request';
  end if;

  v_credit_reserve := case p_capability
    when 'text' then 100
    when 'vision' then 100
    else ceil(p_units * 500)::bigint + 50
  end;

  for v_existing in
    select * from public.bil_ai_usage_events
    where owner_id = v_owner and state = 'reserved'
      and reservation_expires_at <= now()
    for update
  loop
    update public.bil_ai_credit_weekly_usage set
      reserved = greatest(reserved - coalesce(v_existing.credit_weekly_debit,0),0),
      updated_at = now()
      where owner_id = v_owner and week_start = v_existing.week_start;
    update public.bil_ai_credit_balances set
      reserved = greatest(reserved - coalesce(v_existing.credit_paid_debit,0),0),
      updated_at = now()
      where owner_id = v_owner;
    update public.bil_ai_weekly_usage set
      reserved = greatest(reserved - v_existing.weekly_debit,0), updated_at = now()
      where owner_id = v_owner and week_start = v_existing.week_start
        and capability = v_existing.capability;
    update public.bil_ai_paid_balances set
      reserved = greatest(reserved - v_existing.paid_debit,0), updated_at = now()
      where owner_id = v_owner and capability = v_existing.capability;
    update public.bil_ai_usage_events set state = 'refunded',
      credit_actual = 0, completed_at = now()
      where owner_id = v_owner and request_id = v_existing.request_id
        and capability = v_existing.capability;
  end loop;

  select * into v_existing from public.bil_ai_usage_events
    where owner_id = v_owner and request_id = trim(p_request_id)
      and capability = p_capability;
  if found then
    return jsonb_build_object('duplicate',true,'state',v_existing.state,
      'bil_ai_tokens_reserved',coalesce(v_existing.credit_reserved,0));
  end if;

  select case when exists(
    select 1 from public.bil_ai_coach_subscriptions s
    where s.owner_id = v_owner
      and s.lifecycle in ('trial','active','grace_period')
      and (s.expires_at is null or s.expires_at > now())
  ) then 'ai_coach' else 'free' end into v_plan;

  select weekly_limit, monthly_limit
    into v_week_limit, v_month_limit
  from public.bil_ai_credit_config
  where plan_id = v_plan;
  if v_week_limit is null or v_month_limit is null then
    raise exception 'ai_usage_not_configured';
  end if;

  insert into public.bil_ai_credit_monthly_usage(owner_id, month_start)
    values(v_owner, v_month) on conflict do nothing;
  select used, reserved into v_month_used, v_month_reserved
    from public.bil_ai_credit_monthly_usage
    where owner_id = v_owner and month_start = v_month for update;

  insert into public.bil_ai_credit_weekly_usage(owner_id, week_start)
    values(v_owner, v_week) on conflict do nothing;
  select used, reserved into v_week_used, v_week_reserved
    from public.bil_ai_credit_weekly_usage
    where owner_id = v_owner and week_start = v_week for update;

  insert into public.bil_ai_credit_balances(owner_id)
    values(v_owner) on conflict do nothing;
  select granted, used, reserved
    into v_paid_granted, v_paid_used, v_paid_reserved
    from public.bil_ai_credit_balances where owner_id = v_owner for update;

  v_included_debit := least(
    v_credit_reserve,
    greatest(v_week_limit - v_week_used - v_week_reserved,0),
    greatest(v_month_limit - v_month_used - v_month_reserved,0)
  );
  v_paid_debit := v_credit_reserve - v_included_debit;
  if v_paid_debit > greatest(v_paid_granted - v_paid_used - v_paid_reserved,0)
  then raise exception 'ai_usage_exhausted'; end if;

  update public.bil_ai_credit_weekly_usage set
    reserved = reserved + v_included_debit, updated_at = now()
    where owner_id = v_owner and week_start = v_week;
  update public.bil_ai_credit_balances set
    reserved = reserved + v_paid_debit, updated_at = now()
    where owner_id = v_owner;

  insert into public.bil_ai_usage_events(
    owner_id, request_id, capability, state, weekly_debit, paid_debit,
    week_start, reservation_expires_at, credit_reserved,
    credit_weekly_debit, credit_paid_debit, credit_rate_version
  ) values (
    v_owner, trim(p_request_id), p_capability, 'reserved', 0, 0,
    v_week, now() + interval '15 minutes', v_credit_reserve,
    v_included_debit, v_paid_debit, 'usd-1e-4-v1'
  );

  return jsonb_build_object(
    'duplicate',false,'state','reserved','unit','BIL AI Token',
    'bil_ai_tokens_reserved',v_credit_reserve,
    'weekly_tokens_reserved',v_included_debit,
    'monthly_tokens_reserved',v_included_debit,
    'paid_tokens_reserved',v_paid_debit,
    'week_start',v_week,'reset_at',(v_week + 7)::date,
    'month_start',v_month,
    'month_reset_at',(v_month + interval '1 month')::date
  );
end
$$;

revoke all on function public.bil_reserve_ai_usage(uuid,text,text,numeric)
  from public, anon, authenticated;
grant execute on function public.bil_reserve_ai_usage(uuid,text,text,numeric)
  to service_role;

create or replace function public.bil_get_ai_usage_status()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid := auth.uid();
  v_week date := date_trunc('week', now() at time zone 'utc')::date;
  v_month date := date_trunc('month', now() at time zone 'utc')::date;
  v_plan text;
  v_week_limit bigint;
  v_month_limit bigint;
  v_week_used bigint := 0;
  v_week_reserved bigint := 0;
  v_month_used bigint := 0;
  v_month_reserved bigint := 0;
  v_granted bigint := 0;
  v_paid_used bigint := 0;
  v_paid_reserved bigint := 0;
  v_week_remaining bigint;
  v_month_remaining bigint;
  v_included_remaining bigint;
  v_paid_remaining bigint;
  v_shared jsonb;
  v_event public.bil_ai_usage_events%rowtype;
begin
  if v_owner is null then raise exception 'authentication_required'; end if;

  for v_event in
    select * from public.bil_ai_usage_events
    where owner_id = v_owner and state = 'reserved'
      and reservation_expires_at <= now()
    for update
  loop
    update public.bil_ai_credit_weekly_usage set
      reserved = greatest(reserved - coalesce(v_event.credit_weekly_debit,0),0),
      updated_at = now()
      where owner_id = v_owner and week_start = v_event.week_start;
    update public.bil_ai_credit_balances set
      reserved = greatest(reserved - coalesce(v_event.credit_paid_debit,0),0),
      updated_at = now() where owner_id = v_owner;
    update public.bil_ai_weekly_usage set
      reserved = greatest(reserved - v_event.weekly_debit,0), updated_at = now()
      where owner_id = v_owner and week_start = v_event.week_start
        and capability = v_event.capability;
    update public.bil_ai_paid_balances set
      reserved = greatest(reserved - v_event.paid_debit,0), updated_at = now()
      where owner_id = v_owner and capability = v_event.capability;
    update public.bil_ai_usage_events set state = 'refunded',
      credit_actual = 0, completed_at = now()
      where owner_id = v_owner and request_id = v_event.request_id
        and capability = v_event.capability;
  end loop;

  select case when exists(
    select 1 from public.bil_ai_coach_subscriptions s
    where s.owner_id = v_owner
      and s.lifecycle in ('trial','active','grace_period')
      and (s.expires_at is null or s.expires_at > now())
  ) then 'ai_coach' else 'free' end into v_plan;

  select weekly_limit, monthly_limit
    into v_week_limit, v_month_limit
  from public.bil_ai_credit_config
  where plan_id = v_plan;
  if v_week_limit is null or v_month_limit is null then
    raise exception 'ai_usage_not_configured';
  end if;

  select used, reserved into v_week_used, v_week_reserved
    from public.bil_ai_credit_weekly_usage
    where owner_id = v_owner and week_start = v_week;
  if not found then v_week_used := 0; v_week_reserved := 0; end if;

  select used, reserved into v_month_used, v_month_reserved
    from public.bil_ai_credit_monthly_usage
    where owner_id = v_owner and month_start = v_month;
  if not found then v_month_used := 0; v_month_reserved := 0; end if;

  select granted, used, reserved into v_granted, v_paid_used, v_paid_reserved
    from public.bil_ai_credit_balances where owner_id = v_owner;
  if not found then
    v_granted := 0; v_paid_used := 0; v_paid_reserved := 0;
  end if;

  v_week_remaining := greatest(
    v_week_limit - v_week_used - v_week_reserved,0
  );
  v_month_remaining := greatest(
    v_month_limit - v_month_used - v_month_reserved,0
  );
  v_included_remaining := least(v_week_remaining, v_month_remaining);
  v_paid_remaining := greatest(v_granted - v_paid_used - v_paid_reserved,0);
  v_shared := jsonb_build_object(
    'unit','BIL AI Token','billing_scope','shared',
    'weekly_limit',v_week_limit,'weekly_used',v_week_used,
    'weekly_reserved',v_week_reserved,
    'weekly_remaining',v_week_remaining,
    'monthly_limit',v_month_limit,'monthly_used',v_month_used,
    'monthly_reserved',v_month_reserved,
    'monthly_remaining',v_month_remaining,
    'included_remaining',v_included_remaining,
    'paid_granted',v_granted,'paid_used',v_paid_used,
    'paid_reserved',v_paid_reserved,'paid_remaining',v_paid_remaining,
    'total_remaining',v_included_remaining + v_paid_remaining
  );

  return jsonb_build_object(
    'plan',v_plan,
    'week_start',v_week,'reset_at',(v_week + 7)::date,
    'month_start',v_month,
    'month_reset_at',(v_month + interval '1 month')::date,
    'credits',v_shared,
    'capabilities',jsonb_build_object(
      'text',v_shared,'vision',v_shared,'voice',v_shared
    )
  );
end
$$;

revoke all on function public.bil_get_ai_usage_status()
  from public, anon;
grant execute on function public.bil_get_ai_usage_status()
  to authenticated;

commit;
;
