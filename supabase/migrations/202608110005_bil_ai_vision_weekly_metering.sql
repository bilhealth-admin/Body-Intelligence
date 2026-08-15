begin;

alter table public.bil_ai_usage_events
  add column if not exists payload_digest text,
  add column if not exists response_body jsonb,
  add column if not exists provider_attempts integer,
  add column if not exists cost_source text;

alter table public.bil_ai_usage_events
  add constraint bil_ai_usage_payload_digest_format
  check (payload_digest is null or payload_digest ~ '^[0-9a-f]{64}$'),
  add constraint bil_ai_usage_provider_attempts_bounds
  check (provider_attempts is null or provider_attempts between 0 and 2);

create unique index bil_ai_one_live_vision_per_payload
  on public.bil_ai_usage_events(owner_id,capability,payload_digest)
  where capability='vision' and payload_digest is not null
    and state in ('reserved','succeeded');

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
      'response_body',v_existing.response_body);
  end if;
  if exists(select 1 from public.bil_ai_usage_events where owner_id=p_owner_id
    and capability='vision' and payload_digest=p_image_digest
    and state in ('reserved','succeeded')) then raise exception 'duplicate_image'; end if;
  v_result:=public.bil_reserve_ai_usage(p_owner_id,p_request_id,'vision',1);
  update public.bil_ai_usage_events set payload_digest=p_image_digest
    where owner_id=p_owner_id and request_id=trim(p_request_id) and capability='vision';
  return v_result;
end $$;

create or replace function public.bil_settle_ai_vision(
  p_owner_id uuid,p_request_id text,p_succeeded boolean,p_provider text,
  p_model text,p_latency_ms integer,p_input_tokens integer,p_output_tokens integer,
  p_cost_usd numeric,p_response_body jsonb,p_provider_attempts integer,p_cost_source text
) returns jsonb language plpgsql security definer set search_path=public as $$
declare v_result jsonb;
begin
  if auth.role()<>'service_role' then raise exception 'service_role_required'; end if;
  v_result:=public.bil_settle_ai_usage(p_owner_id,p_request_id,'vision',p_succeeded,
    p_provider,p_model,p_input_tokens,p_output_tokens,p_latency_ms,p_cost_usd);
  update public.bil_ai_usage_events set
    response_body=case when p_succeeded then p_response_body else null end,
    provider_attempts=p_provider_attempts,cost_source=nullif(trim(p_cost_source),'')
    where owner_id=p_owner_id and request_id=trim(p_request_id) and capability='vision';
  return v_result;
end $$;

revoke all on function public.bil_reserve_ai_vision(uuid,text,text),
  public.bil_settle_ai_vision(uuid,text,boolean,text,text,integer,integer,integer,numeric,jsonb,integer,text)
  from public,anon,authenticated;
grant execute on function public.bil_reserve_ai_vision(uuid,text,text),
  public.bil_settle_ai_vision(uuid,text,boolean,text,text,integer,integer,integer,numeric,jsonb,integer,text)
  to service_role;

commit;
