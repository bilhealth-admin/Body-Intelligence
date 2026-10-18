begin;
set local lock_timeout='5s';
set local statement_timeout='40s';
-- Preserve initial reservation debits separately from actual funded settlement.
alter table public.bil_ai_usage_events
  add column credit_included_actual bigint check(credit_included_actual>=0),
  add column credit_paid_actual bigint check(credit_paid_actual>=0);
CREATE OR REPLACE FUNCTION public.bil_sync_ai_monthly_usage_from_event()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_month date := coalesce(
    new.credit_period_start,
    private.bil_current_ai_month_start(new.owner_id,new.created_at)
  );
  v_plan text := coalesce(
    new.credit_plan_id,
    public.bil_resolve_ai_allowance_plan(new.owner_id)
  );
  v_old_used bigint := 0; v_old_reserved bigint := 0;
  v_new_used bigint := 0; v_new_reserved bigint := 0;
  v_used_delta bigint; v_reserved_delta bigint;
  v_limit bigint; v_total bigint;
begin
  if tg_op='UPDATE' and (
    old.created_at is distinct from new.created_at
    or old.credit_plan_id is distinct from new.credit_plan_id
    or old.credit_period_start is distinct from new.credit_period_start
  ) then raise exception 'ai_usage_event_period_immutable'; end if;
  if tg_op='UPDATE' then
    v_old_reserved := case when old.state='reserved'
      then coalesce(old.credit_weekly_debit,0) else 0 end;
    v_old_used := case when old.state='succeeded' then coalesce(old.credit_included_actual,greatest(
      coalesce(old.credit_actual,0)-least(greatest(
        coalesce(old.credit_actual,0)-coalesce(old.credit_weekly_debit,0),0
      ),coalesce(old.credit_paid_debit,0)),0
    )) else 0 end;
  end if;
  v_new_reserved := case when new.state='reserved'
    then coalesce(new.credit_weekly_debit,0) else 0 end;
  v_new_used := case when new.state='succeeded' then coalesce(new.credit_included_actual,greatest(
    coalesce(new.credit_actual,0)-least(greatest(
      coalesce(new.credit_actual,0)-coalesce(new.credit_weekly_debit,0),0
    ),coalesce(new.credit_paid_debit,0)),0
  )) else 0 end;
  v_used_delta:=v_new_used-v_old_used;
  v_reserved_delta:=v_new_reserved-v_old_reserved;
  insert into public.bil_ai_credit_monthly_usage(owner_id,month_start)
    values(new.owner_id,v_month) on conflict do nothing;
  select monthly_limit into v_limit from public.bil_ai_credit_config
    where plan_id=v_plan;
  update public.bil_ai_credit_monthly_usage set
    used=greatest(used+v_used_delta,0),
    reserved=greatest(reserved+v_reserved_delta,0),updated_at=now()
    where owner_id=new.owner_id and month_start=v_month
    returning used+reserved into v_total;
  if v_used_delta+v_reserved_delta>0 and v_limit is not null
     and v_total>v_limit then raise exception 'ai_monthly_usage_exhausted';
  end if;
  return new;
end
$function$;
CREATE OR REPLACE FUNCTION public.bil_settle_ai_usage_unserialized(p_owner_id uuid, p_request_id text, p_capability text, p_succeeded boolean, p_provider text DEFAULT NULL::text, p_model text DEFAULT NULL::text, p_input_tokens integer DEFAULT NULL::integer, p_output_tokens integer DEFAULT NULL::integer, p_latency_ms integer DEFAULT NULL::integer, p_cost_usd numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_owner uuid := p_owner_id;
  v_event public.bil_ai_usage_events%rowtype;
  v_actual bigint;
  v_week_actual bigint;
  v_paid_actual bigint;
  v_week_limit bigint; v_month_limit bigint;
  v_week_used bigint; v_week_reserved bigint;
  v_month_used bigint; v_month_reserved bigint;
  v_paid_granted bigint; v_paid_used bigint; v_paid_reserved bigint;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    raise exception 'service_role_required';
  end if;
  if v_owner is null then raise exception 'owner_required'; end if;
  if p_capability not in ('vision','text','voice')
     or p_input_tokens < 0 or p_output_tokens < 0
     or p_latency_ms < 0 or p_cost_usd < 0 then
    raise exception 'invalid_ai_usage_telemetry';
  end if;

  select * into v_event from public.bil_ai_usage_events
    where owner_id = v_owner and request_id = trim(p_request_id)
      and capability = p_capability for update;
  if not found then raise exception 'unknown_ai_usage_reservation'; end if;
  if v_event.state <> 'reserved' then
    return jsonb_build_object('duplicate',true,'state',v_event.state,
      'bil_ai_tokens_actual',coalesce(v_event.credit_actual,0));
  end if;

  if v_event.reservation_expires_at <= now() then
    update public.bil_ai_credit_weekly_usage set
      reserved = greatest(reserved - coalesce(v_event.credit_weekly_debit,0),0),
      updated_at = now()
      where owner_id = v_owner and week_start = v_event.week_start;
    update public.bil_ai_credit_balances set
      reserved = greatest(reserved - coalesce(v_event.credit_paid_debit,0),0),
      updated_at = now() where owner_id = v_owner;
    update public.bil_ai_usage_events set state = 'refunded',
      credit_actual = 0, completed_at = now()
      where owner_id = v_owner and request_id = trim(p_request_id)
        and capability = p_capability;
    return jsonb_build_object('duplicate',false,'state','refunded',
      'reason','reservation_expired','bil_ai_tokens_actual',0);
  end if;

  v_actual := case
    when not p_succeeded then 0
    when p_cost_usd is null then coalesce(v_event.credit_reserved,0)
    else ceil(p_cost_usd * 10000)::bigint
  end;

  v_week_actual := 0;
  v_paid_actual := 0;
  if v_actual > 0 then
    select weekly_limit,monthly_limit into v_week_limit,v_month_limit
      from public.bil_ai_credit_config
      where plan_id=coalesce(v_event.credit_plan_id,public.bil_resolve_ai_allowance_plan(v_owner));
    if v_week_limit is null or v_month_limit is null then
      raise exception 'ai_usage_not_configured';
    end if;
    select used,reserved into v_week_used,v_week_reserved
      from public.bil_ai_credit_weekly_usage
      where owner_id=v_owner and week_start=v_event.week_start for update;
    select used,reserved into v_month_used,v_month_reserved
      from public.bil_ai_credit_monthly_usage
      where owner_id=v_owner and month_start=coalesce(v_event.credit_period_start,
        private.bil_current_ai_month_start(v_owner,v_event.created_at)) for update;
    v_week_actual := least(v_actual,
      greatest(v_week_limit-coalesce(v_week_used,0)-coalesce(v_week_reserved,0)+coalesce(v_event.credit_weekly_debit,0),0),
      greatest(v_month_limit-coalesce(v_month_used,0)-coalesce(v_month_reserved,0)+coalesce(v_event.credit_weekly_debit,0),0));
    v_paid_actual := v_actual-v_week_actual;
    select granted,used,reserved into v_paid_granted,v_paid_used,v_paid_reserved
      from public.bil_ai_credit_balances where owner_id=v_owner for update;
    if v_paid_actual > greatest(coalesce(v_paid_granted,0)-coalesce(v_paid_used,0)-
      coalesce(v_paid_reserved,0)+coalesce(v_event.credit_paid_debit,0),0) then
      raise exception 'ai_usage_exhausted';
    end if;
  end if;

  update public.bil_ai_credit_weekly_usage set
    reserved = greatest(reserved - coalesce(v_event.credit_weekly_debit,0),0),
    used = used + v_week_actual,
    updated_at = now()
    where owner_id = v_owner and week_start = v_event.week_start;
  update public.bil_ai_credit_balances set
    reserved = greatest(reserved - coalesce(v_event.credit_paid_debit,0),0),
    used = used + v_paid_actual,
    updated_at = now()
    where owner_id = v_owner;

  update public.bil_ai_usage_events set
    state = case when p_succeeded then 'succeeded' else 'refunded' end,
    provider = nullif(trim(p_provider),''),
    model = nullif(trim(p_model),''),
    input_tokens = p_input_tokens,
    output_tokens = p_output_tokens,
    latency_ms = p_latency_ms,
    cost_usd = p_cost_usd,
    credit_actual = v_actual,
    credit_included_actual = v_week_actual,
    credit_paid_actual = v_paid_actual,
    completed_at = now()
    where owner_id = v_owner and request_id = trim(p_request_id)
      and capability = p_capability;

  return jsonb_build_object(
    'duplicate',false,
    'state',case when p_succeeded then 'succeeded' else 'refunded' end,
    'unit','BIL AI Token','bil_ai_tokens_actual',v_actual,
    'weekly_tokens_debited',v_week_actual,
    'paid_tokens_debited',v_paid_actual
  );
end
$function$;
commit;
