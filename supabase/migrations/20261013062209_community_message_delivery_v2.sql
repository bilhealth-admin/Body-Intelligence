-- Additive contract. Clients 32/35 keep their existing INSERT and response.
-- New clients fail honestly if these local-only RPCs have not been deployed.
begin;
do $preflight$
begin
  if pg_catalog.to_regclass('public.bil_messages') is null
     or pg_catalog.to_regclass('public.bil_friendships') is null
     or pg_catalog.to_regprocedure('public.bil_recipient_allows_community_message(uuid)') is null
     or pg_catalog.to_regprocedure('private.bil_assert_current_community_policy()') is null then
    raise exception 'community_message_delivery_v2_precondition_failed';
  end if;
end
$preflight$;
create table private.bil_community_message_deliveries_v2 (
  owner_id uuid not null references auth.users(id) on delete cascade,
  request_id uuid not null,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  body_sha256 bytea not null check(pg_catalog.octet_length(body_sha256)=32),
  message_id uuid references public.bil_messages(id) on delete set null,
  delivered_at timestamptz not null,
  primary key(owner_id,request_id),check(owner_id<>recipient_id)
);
alter table private.bil_community_message_deliveries_v2 enable row level security;
revoke all on private.bil_community_message_deliveries_v2
  from public,anon,authenticated,service_role;

-- The authenticated owner can reconcile only their own request. No actor input.
create function public.bil_get_community_message_delivery_v2(p_request_id uuid)
returns jsonb language plpgsql volatile security definer set search_path=''
as $function$
declare
  v_uid uuid := (select auth.uid());
  v_delivery private.bil_community_message_deliveries_v2%rowtype;
  v_message public.bil_messages%rowtype;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_request_id is null then
    raise exception 'invalid_message_request' using errcode='22023';
  end if;
  select * into v_delivery from private.bil_community_message_deliveries_v2
    where owner_id=v_uid and request_id=p_request_id;
  if not found then return null; end if;
  select * into v_message from public.bil_messages where id=v_delivery.message_id;
  if v_message.id is not null and (v_message.sender_id<>v_uid
      or v_message.recipient_id<>v_delivery.recipient_id) then
    raise exception 'message_delivery_integrity_error' using errcode='55000';
  end if;
  return pg_catalog.jsonb_build_object(
    'request_id',v_delivery.request_id,'owner_id',v_uid,
    'recipient_id',v_delivery.recipient_id,'message_id',v_delivery.message_id,
    'delivered_at',v_delivery.delivered_at,
    'status',case when v_message.id is null or v_message.deleted_by_sender_at is not null
      then 'removed' else 'delivered' end,
    'body',case when v_message.id is null or v_message.deleted_by_sender_at is not null
      then null else v_message.body end);
end
$function$;
create function public.bil_send_community_message_v2(
  p_recipient_id uuid,p_body text,p_request_id uuid
) returns jsonb language plpgsql security definer set search_path=''
as $function$
declare
  v_uid uuid := (select auth.uid());
  v_body text := pg_catalog.btrim(coalesce(p_body,''));
  v_hash bytea;
  v_delivery private.bil_community_message_deliveries_v2%rowtype;
  v_message public.bil_messages%rowtype;
  v_friend uuid;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_request_id is null or p_recipient_id is null or p_recipient_id=v_uid
     or pg_catalog.char_length(v_body) not between 1 and 2000
     or v_body ~ '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]' then
    raise exception 'invalid_message_request' using errcode='22023';
  end if;
  v_hash := pg_catalog.sha256(pg_catalog.convert_to(v_body,'UTF8'));
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'community_message_delivery_v2:'||v_uid::text||':'||p_request_id::text,0));
  select * into v_delivery from private.bil_community_message_deliveries_v2
    where owner_id=v_uid and request_id=p_request_id;
  if found then
    if v_delivery.recipient_id<>p_recipient_id or v_delivery.body_sha256<>v_hash then
      raise exception 'message_request_conflict' using errcode='22023';
    end if;
    -- Reconcile committed delivery without repeating INSERT/notifications.
    -- Hidden/deleted deliveries remain tombstoned and are never resurrected.
    return public.bil_get_community_message_delivery_v2(p_request_id);
  end if;
  -- Match the legacy INSERT trigger order: bilateral pair, then member state.
  -- Taking member state first would deadlock with an old client INSERT that
  -- already owns this pair and is waiting for the same member state.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'community_block_pair:' || least(v_uid::text,p_recipient_id::text)
      || ':' || greatest(v_uid::text,p_recipient_id::text),0));
  if not public.bil_can_use_community() then
    raise exception 'community_access_suspended' using errcode='42501';
  end if;
  perform private.bil_assert_current_community_policy();
  if not public.bil_recipient_allows_community_message(p_recipient_id) then
    raise exception 'community_message_recipient_unavailable' using errcode='42501';
  end if;
  select id into v_friend from public.bil_friendships
    where status='accepted' and (
      (requester_id=v_uid and addressee_id=p_recipient_id)
      or (requester_id=p_recipient_id and addressee_id=v_uid)) for share;
  if not found then
    raise exception 'community_message_friendship_required' using errcode='42501';
  end if;
  -- All original membership, bilateral-block, text, policy, rate-limit and
  -- notification triggers still execute for the one actual INSERT.
  insert into public.bil_messages(sender_id,recipient_id,body)
    values(v_uid,p_recipient_id,v_body) returning * into v_message;
  insert into private.bil_community_message_deliveries_v2(
    owner_id,request_id,recipient_id,body_sha256,message_id,delivered_at)
    values(v_uid,p_request_id,p_recipient_id,v_hash,v_message.id,v_message.created_at);
  return public.bil_get_community_message_delivery_v2(p_request_id);
end
$function$;
revoke all on function public.bil_send_community_message_v2(uuid,text,uuid)
  from public,anon,service_role;
revoke all on function public.bil_get_community_message_delivery_v2(uuid)
  from public,anon,service_role;
grant execute on function public.bil_send_community_message_v2(uuid,text,uuid)
  to authenticated;
grant execute on function public.bil_get_community_message_delivery_v2(uuid)
  to authenticated;
commit;
