begin;

-- Meal-photo analysis is a universal AI Boost feature. It must never consume
-- the recurring AI Coach allowance, even when the owner has an active Coach
-- subscription. Reserve the conservative 100-token Vision ceiling from the
-- verified, non-expiring paid balance only.
create or replace function public.bil_reserve_paid_ai_vision_usage(
  p_owner_id uuid,
  p_request_id text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid := p_owner_id;
  v_week date := date_trunc('week', now() at time zone 'utc')::date;
  v_credit_reserve constant bigint := 100;
  v_paid_granted bigint;
  v_paid_used bigint;
  v_paid_reserved bigint;
  v_existing public.bil_ai_usage_events%rowtype;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    raise exception 'service_role_required';
  end if;
  if v_owner is null
     or length(trim(p_request_id)) not between 16 and 128 then
    raise exception 'invalid_ai_usage_request';
  end if;

  -- Release abandoned reservations before deciding that purchased credit is
  -- unavailable. Keep the same lock/recovery order as the shared meter.
  for v_existing in
    select * from public.bil_ai_usage_events
    where owner_id = v_owner and state = 'reserved'
      and reservation_expires_at <= now()
    for update
  loop
    update public.bil_ai_credit_weekly_usage set
      reserved = greatest(
        reserved - coalesce(v_existing.credit_weekly_debit,0), 0
      ),
      updated_at = now()
      where owner_id = v_owner and week_start = v_existing.week_start;
    update public.bil_ai_credit_balances set
      reserved = greatest(
        reserved - coalesce(v_existing.credit_paid_debit,0), 0
      ),
      updated_at = now()
      where owner_id = v_owner;
    update public.bil_ai_weekly_usage set
      reserved = greatest(reserved - v_existing.weekly_debit, 0),
      updated_at = now()
      where owner_id = v_owner and week_start = v_existing.week_start
        and capability = v_existing.capability;
    update public.bil_ai_paid_balances set
      reserved = greatest(reserved - v_existing.paid_debit, 0),
      updated_at = now()
      where owner_id = v_owner and capability = v_existing.capability;
    update public.bil_ai_usage_events set
      state = 'refunded', credit_actual = 0, completed_at = now()
      where owner_id = v_owner and request_id = v_existing.request_id
        and capability = v_existing.capability;
  end loop;

  select * into v_existing from public.bil_ai_usage_events
    where owner_id = v_owner and request_id = trim(p_request_id)
      and capability = 'vision';
  if found then
    return jsonb_build_object(
      'duplicate',true,'state',v_existing.state,
      'bil_ai_tokens_reserved',coalesce(v_existing.credit_reserved,0)
    );
  end if;

  insert into public.bil_ai_credit_balances(owner_id)
    values(v_owner) on conflict do nothing;
  select granted, used, reserved
    into v_paid_granted, v_paid_used, v_paid_reserved
    from public.bil_ai_credit_balances
    where owner_id = v_owner for update;

  if v_credit_reserve > greatest(
    v_paid_granted - v_paid_used - v_paid_reserved, 0
  ) then
    raise exception 'ai_boost_required';
  end if;

  update public.bil_ai_credit_balances set
    reserved = reserved + v_credit_reserve,
    updated_at = now()
    where owner_id = v_owner;

  insert into public.bil_ai_usage_events(
    owner_id, request_id, capability, state, weekly_debit, paid_debit,
    week_start, reservation_expires_at, credit_reserved,
    credit_weekly_debit, credit_paid_debit, credit_rate_version
  ) values (
    v_owner, trim(p_request_id), 'vision', 'reserved', 0, 0,
    v_week, now() + interval '15 minutes', v_credit_reserve,
    0, v_credit_reserve, 'usd-1e-4-v1'
  );

  return jsonb_build_object(
    'duplicate',false,'state','reserved','unit','BIL AI Token',
    'billing_source','paid_boost',
    'bil_ai_tokens_reserved',v_credit_reserve,
    'weekly_tokens_reserved',0,
    'paid_tokens_reserved',v_credit_reserve
  );
end
$$;

revoke all on function public.bil_reserve_paid_ai_vision_usage(uuid,text)
  from public, anon, authenticated;
grant execute on function public.bil_reserve_paid_ai_vision_usage(uuid,text)
  to service_role;

-- Preserve request idempotency and exact-food cache replay, but require and
-- reserve verified Boost credit before a new image can reach the provider.
-- A cache hit refunds that temporary reservation immediately.
create or replace function public.bil_reserve_ai_vision(
  p_owner_id uuid,
  p_request_id text,
  p_image_digest text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_existing public.bil_ai_usage_events%rowtype;
  v_cached public.bil_ai_usage_events%rowtype;
  v_result jsonb;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_image_digest !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid_image_digest';
  end if;

  select * into v_existing from public.bil_ai_usage_events
    where owner_id = p_owner_id and request_id = trim(p_request_id)
      and capability = 'vision';
  if found then
    if v_existing.payload_digest is distinct from p_image_digest then
      raise exception 'idempotency_payload_mismatch';
    end if;
    return jsonb_build_object(
      'duplicate',true,'state',v_existing.state,
      'response_body',v_existing.response_body,'cache_hit',false
    );
  end if;

  if exists(
    select 1 from public.bil_ai_usage_events
    where owner_id = p_owner_id and capability = 'vision'
      and payload_digest = p_image_digest and state = 'reserved'
  ) then
    raise exception 'duplicate_image';
  end if;

  v_result := public.bil_reserve_paid_ai_vision_usage(
    p_owner_id, p_request_id
  );
  update public.bil_ai_usage_events set payload_digest = p_image_digest
    where owner_id = p_owner_id and request_id = trim(p_request_id)
      and capability = 'vision';

  select * into v_cached from public.bil_ai_usage_events
    where owner_id = p_owner_id and capability = 'vision'
      and request_id <> trim(p_request_id)
      and payload_digest = p_image_digest and state = 'succeeded'
      and result_kind = 'food' and response_body is not null
    order by completed_at desc nulls last limit 1;
  if found then
    perform public.bil_settle_ai_usage(
      p_owner_id, p_request_id, 'vision', false
    );
    return jsonb_build_object(
      'duplicate',true,'state','succeeded',
      'response_body',v_cached.response_body,'cache_hit',true
    );
  end if;

  return v_result || jsonb_build_object('cache_hit',false);
end
$$;

revoke all on function public.bil_reserve_ai_vision(uuid,text,text)
  from public, anon, authenticated;
grant execute on function public.bil_reserve_ai_vision(uuid,text,text)
  to service_role;

commit;
