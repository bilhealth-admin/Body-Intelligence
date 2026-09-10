-- Read-only production definition snapshot, 2026-09-10. Local test fixture only.
CREATE OR REPLACE FUNCTION public.bil_settle_ai_usage(p_owner_id uuid, p_request_id text, p_capability text, p_succeeded boolean, p_provider text DEFAULT NULL::text, p_model text DEFAULT NULL::text, p_input_tokens integer DEFAULT NULL::integer, p_output_tokens integer DEFAULT NULL::integer, p_latency_ms integer DEFAULT NULL::integer, p_cost_usd numeric DEFAULT NULL::numeric)
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
  v_overage bigint;
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
  v_week_actual := least(v_actual, coalesce(v_event.credit_weekly_debit,0));
  v_paid_actual := least(
    greatest(v_actual - v_week_actual,0),
    coalesce(v_event.credit_paid_debit,0)
  );
  v_overage := greatest(v_actual - v_week_actual - v_paid_actual,0);

  update public.bil_ai_credit_weekly_usage set
    reserved = greatest(reserved - coalesce(v_event.credit_weekly_debit,0),0),
    used = used + v_week_actual + v_overage,
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
    completed_at = now()
    where owner_id = v_owner and request_id = trim(p_request_id)
      and capability = p_capability;

  return jsonb_build_object(
    'duplicate',false,
    'state',case when p_succeeded then 'succeeded' else 'refunded' end,
    'unit','BIL AI Token','bil_ai_tokens_actual',v_actual,
    'weekly_tokens_debited',v_week_actual + v_overage,
    'paid_tokens_debited',v_paid_actual
  );
end
$function$;
