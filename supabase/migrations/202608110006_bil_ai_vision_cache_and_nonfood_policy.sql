begin;

alter table public.bil_ai_usage_events
  add column if not exists result_kind text,
  add column if not exists courtesy_refund boolean not null default false;

alter table public.bil_ai_usage_events
  drop constraint if exists bil_ai_usage_result_kind_check;
alter table public.bil_ai_usage_events
  add constraint bil_ai_usage_result_kind_check
  check (result_kind is null or result_kind in ('food','unknown_nonfood'));

create or replace function public.bil_reserve_ai_vision(
  p_owner_id uuid,p_request_id text,p_image_digest text
) returns jsonb language plpgsql security definer set search_path=public as $$
declare v_existing public.bil_ai_usage_events%rowtype; v_result jsonb;
begin
  if auth.role()<>'service_role' then raise exception 'service_role_required'; end if;
  if p_image_digest !~ '^[0-9a-f]{64}$' then raise exception 'invalid_image_digest'; end if;
  select * into v_existing from public.bil_ai_usage_events
    where owner_id=p_owner_id and request_id=trim(p_request_id) and capability='vision';
  if found then
    if v_existing.payload_digest is distinct from p_image_digest then
      raise exception 'idempotency_payload_mismatch';
    end if;
    return jsonb_build_object('duplicate',true,'state',v_existing.state,
      'response_body',v_existing.response_body,'cache_hit',false);
  end if;

  -- Exact known-food payloads are replayed without a new reservation, provider
  -- call, or debit. Unknown/non-food outcomes are deliberately not cached as a
  -- successful meal result.
  select * into v_existing from public.bil_ai_usage_events
    where owner_id=p_owner_id and capability='vision'
      and payload_digest=p_image_digest and state='succeeded'
      and result_kind='food' and response_body is not null
    order by completed_at desc nulls last limit 1;
  if found then
    return jsonb_build_object('duplicate',true,'state','succeeded',
      'response_body',v_existing.response_body,'cache_hit',true);
  end if;
  if exists(select 1 from public.bil_ai_usage_events where owner_id=p_owner_id
    and capability='vision' and payload_digest=p_image_digest and state='reserved') then
    raise exception 'duplicate_image';
  end if;
  v_result:=public.bil_reserve_ai_usage(p_owner_id,p_request_id,'vision',1);
  update public.bil_ai_usage_events set payload_digest=p_image_digest
    where owner_id=p_owner_id and request_id=trim(p_request_id) and capability='vision';
  return v_result||jsonb_build_object('cache_hit',false);
end $$;

create or replace function public.bil_decide_unknown_nonfood_settlement(
  p_owner_id uuid,p_request_id text
) returns jsonb language plpgsql security definer set search_path=public as $$
declare v_prior integer; v_event public.bil_ai_usage_events%rowtype; v_courtesy boolean;
begin
  if auth.role()<>'service_role' then raise exception 'service_role_required'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_owner_id::text||':vision-nonfood',0));
  select * into v_event from public.bil_ai_usage_events
    where owner_id=p_owner_id and request_id=trim(p_request_id)
      and capability='vision' for update;
  if not found or v_event.state<>'reserved' then
    raise exception 'unknown_or_settled_vision_reservation';
  end if;
  select count(*) into v_prior from public.bil_ai_usage_events
    where owner_id=p_owner_id and capability='vision'
      and result_kind='unknown_nonfood'
      and created_at>=now()-interval '24 hours'
      and request_id<>trim(p_request_id);
  v_courtesy:=v_prior=0;
  update public.bil_ai_usage_events set result_kind='unknown_nonfood',
    courtesy_refund=v_courtesy
    where owner_id=p_owner_id and request_id=trim(p_request_id)
      and capability='vision';
  return jsonb_build_object('courtesy_refund',v_courtesy,
    'charge',not v_courtesy,'prior_unknown_nonfood_24h',v_prior);
end $$;

create or replace function public.bil_mark_ai_vision_food(
  p_owner_id uuid,p_request_id text
) returns void language plpgsql security definer set search_path=public as $$
begin
  if auth.role()<>'service_role' then raise exception 'service_role_required'; end if;
  update public.bil_ai_usage_events set result_kind='food',courtesy_refund=false
    where owner_id=p_owner_id and request_id=trim(p_request_id)
      and capability='vision' and state='reserved';
  if not found then raise exception 'unknown_or_settled_vision_reservation'; end if;
end $$;

revoke all on function public.bil_decide_unknown_nonfood_settlement(uuid,text),
  public.bil_mark_ai_vision_food(uuid,text) from public,anon,authenticated;
grant execute on function public.bil_decide_unknown_nonfood_settlement(uuid,text),
  public.bil_mark_ai_vision_food(uuid,text) to service_role;

commit;
