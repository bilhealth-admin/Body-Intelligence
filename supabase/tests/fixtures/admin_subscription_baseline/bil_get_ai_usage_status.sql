-- Read-only production definition snapshot, 2026-09-10. Local test fixture only.
CREATE OR REPLACE FUNCTION public.bil_get_ai_usage_status()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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

  select public.bil_resolve_ai_allowance_plan(v_owner) into v_plan;

  if v_plan = 'trial' then
    select public.bil_resolve_ai_trial_anchor(v_owner)
      into v_week;
    if v_week is null then raise exception 'trial_period_missing'; end if;
    v_month := v_week;
  end if;

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
    'month_reset_at',case when v_plan = 'trial'
        then (v_week + 7)::date
        else (v_month + interval '1 month')::date
      end,
    'credits',v_shared,
    'capabilities',jsonb_build_object(
      'text',v_shared,'vision',v_shared,'voice',v_shared
    )
  );
end
$function$;
