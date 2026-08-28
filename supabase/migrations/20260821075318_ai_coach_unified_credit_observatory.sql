begin;

create or replace function public.bil_get_ai_coach_cost_observatory()
returns jsonb
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  v_owner uuid := auth.uid();
  v_result jsonb := '{}'::jsonb;
  v_rows jsonb;
  v_days integer;
  v_label text;
  v_credits_per_usd constant numeric := 10000;
begin
  if v_owner is null then raise exception 'authentication_required'; end if;

  foreach v_days in array array[7,30,365] loop
    v_label := case v_days when 7 then 'weekly' when 30 then 'monthly' else 'annual' end;
    select coalesce(
      jsonb_agg(to_jsonb(summary) order by summary.capability, summary.model),
      '[]'::jsonb
    )
    into v_rows
    from (
      select
        capability,
        coalesce(model,'unknown') as model,
        count(*)::integer as requests,
        coalesce(sum(input_tokens),0)::bigint as input_tokens,
        coalesce(sum(output_tokens),0)::bigint as output_tokens,
        round(coalesce(avg(latency_ms),0),0)::integer as average_latency_ms,
        round(coalesce(sum(cost_usd),0),8) as cost_usd,
        coalesce(sum(ceil(coalesce(cost_usd,0) * v_credits_per_usd)),0)::bigint
          as bil_ai_tokens,
        round(
          coalesce(avg(ceil(coalesce(cost_usd,0) * v_credits_per_usd)),0),
          2
        ) as average_bil_ai_tokens_per_request
      from public.bil_ai_usage_events
      where owner_id = v_owner
        and state = 'succeeded'
        and completed_at >= now() - make_interval(days => v_days)
      group by capability, coalesce(model,'unknown')
    ) summary;
    v_result := v_result || jsonb_build_object(v_label, v_rows);
  end loop;

  return jsonb_build_object(
    'generated_at', now(),
    'credit_definition', jsonb_build_object(
      'name','BIL AI Token',
      'usd_per_token',0.0001,
      'tokens_per_usd',v_credits_per_usd,
      'rounding','ceil_per_successful_provider_request'
    ),
    'periods', v_result
  );
end
$$;

revoke all on function public.bil_get_ai_coach_cost_observatory()
  from public, anon;
grant execute on function public.bil_get_ai_coach_cost_observatory()
  to authenticated;

commit;;
