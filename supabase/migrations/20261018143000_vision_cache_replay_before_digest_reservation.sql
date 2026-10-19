begin;
set local lock_timeout = '5s';
set local statement_timeout = '40s';

-- Preserve shared-meter Vision admission and the unique live-payload constraint.
-- A cache replay is refunded before binding its digest, so it cannot collide
-- with the original successful provider receipt or reserve credits twice.
create or replace function public.bil_reserve_ai_vision(
  p_owner_id uuid, p_request_id text, p_image_digest text
) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public
as $$
declare
  v_existing public.bil_ai_usage_events%rowtype;
  v_cached public.bil_ai_usage_events%rowtype;
  v_result jsonb;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_owner_id is null or length(trim(p_request_id)) not between 16 and 128
      or p_request_id is null then
    raise exception 'invalid_ai_usage_request';
  end if;
  if p_image_digest is null or p_image_digest !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid_image_digest';
  end if;

  -- Serialize only this owner's short database admission transaction. The
  -- provider call occurs after the transaction and is never under this lock.
  perform pg_advisory_xact_lock(hashtextextended('bil.ai.' || p_owner_id::text, 0));
  select * into v_existing from public.bil_ai_usage_events
    where owner_id = p_owner_id and request_id = trim(p_request_id)
      and capability = 'vision' for update;
  if found then
    if v_existing.payload_digest is distinct from p_image_digest then
      raise exception 'idempotency_payload_mismatch';
    end if;
    if v_existing.state = 'refunded' and v_existing.result_kind = 'food'
        and v_existing.response_body is not null then
      return jsonb_build_object('duplicate',true,'state','succeeded',
        'response_body',v_existing.response_body,'cache_hit',true);
    end if;
    return jsonb_build_object('duplicate',true,'state',v_existing.state,
      'response_body',v_existing.response_body,'cache_hit',false);
  end if;

  if exists(select 1 from public.bil_ai_usage_events
      where owner_id = p_owner_id and capability = 'vision'
        and payload_digest = p_image_digest and state = 'reserved') then
    raise exception 'duplicate_image';
  end if;

  -- Keep canonical server funding admission before cache access. This
  -- historical RPC name delegates to the current shared Coach/Boost meter.
  v_result := public.bil_reserve_paid_ai_vision_usage(p_owner_id, p_request_id);
  select * into v_cached from public.bil_ai_usage_events
    where owner_id = p_owner_id and capability = 'vision'
      and request_id <> trim(p_request_id)
      and payload_digest = p_image_digest and state = 'succeeded'
      and result_kind = 'food' and response_body is not null
    order by completed_at desc nulls last limit 1;
  if found then
    perform public.bil_settle_ai_usage(p_owner_id, p_request_id, 'vision', false);
    update public.bil_ai_usage_events set payload_digest = p_image_digest,
        response_body = v_cached.response_body, result_kind = 'food'
      where owner_id = p_owner_id and request_id = trim(p_request_id)
        and capability = 'vision' and state = 'refunded';
    if not found then raise exception 'vision_cache_refund_failed'; end if;
    return jsonb_build_object('duplicate',true,'state','succeeded',
      'response_body',v_cached.response_body,'cache_hit',true);
  end if;

  update public.bil_ai_usage_events set payload_digest = p_image_digest
    where owner_id = p_owner_id and request_id = trim(p_request_id)
      and capability = 'vision';
  return v_result || jsonb_build_object('cache_hit',false);
end
$$;

revoke all on function public.bil_reserve_ai_vision(uuid,text,text) from public, anon, authenticated;
grant execute on function public.bil_reserve_ai_vision(uuid,text,text) to service_role;
commit;
