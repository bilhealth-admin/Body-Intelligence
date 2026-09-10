-- Read-only production definition snapshot, 2026-09-10. Local test fixture only.
CREATE OR REPLACE FUNCTION public.bil_sync_ai_monthly_usage()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_plan text := public.bil_resolve_ai_allowance_plan(new.owner_id);
  v_month date := date_trunc('month', now() at time zone 'utc')::date;
  v_used_delta bigint;
  v_reserved_delta bigint;
  v_limit bigint;
  v_total bigint;
begin
  if v_plan = 'trial' then
    select public.bil_resolve_ai_trial_anchor(new.owner_id) into v_month;
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

  if v_used_delta + v_reserved_delta > 0
     and v_limit is not null
     and v_total > v_limit then
    raise exception 'ai_monthly_usage_exhausted';
  end if;
  return new;
end
$function$;
