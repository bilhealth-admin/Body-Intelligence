-- Forward-only notification privacy repair; no master opt-in or provider send.
-- LIVE retry regression reproduced on isolated PostgreSQL17 before this change.
-- One RPC-only desired-state row per Auth owner, including zero-token owners.
create table private.bil_push_delivery_preferences_v1 (
  user_id uuid primary key references auth.users(id) on delete cascade,
  message_enabled boolean not null,
  friend_request_enabled boolean not null,
  friend_accepted_enabled boolean not null,
  revision bigint not null default 1 check (revision>0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table private.bil_push_delivery_preferences_v1 enable row level security;
revoke all on private.bil_push_delivery_preferences_v1 from public,anon,authenticated,service_role;
-- No policies/direct CRUD: only the narrowly owner-authenticated RPCs below.
-- Preserve actual delivery of existing ACTIVE devices: ANY, never AND/defaults.
-- Inactive-only/no-token owners stay UNKNOWN until an explicit owner write.
insert into private.bil_push_delivery_preferences_v1 (
  user_id,message_enabled,friend_request_enabled,friend_accepted_enabled
)
select user_id,bool_or(message_enabled),bool_or(friend_request_enabled),
       bool_or(friend_accepted_enabled)
from public.bil_push_device_tokens where enabled group by user_id;

create function public.bil_get_my_push_delivery_categories_v1()
returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare
  v_owner uuid:=auth.uid();
  v_result jsonb;
begin
  if v_owner is null then raise exception 'authentication required' using errcode='42501'; end if;
  -- Desired and effective projections are read in ONE SQL/MVCC snapshot.
  select jsonb_build_object(
    'owner_id',v_owner,
    'initialized',preferences.user_id is not null,
    'revision',coalesce(preferences.revision,0),
    'message_enabled',preferences.message_enabled,
    'friend_request_enabled',preferences.friend_request_enabled,
    'friend_accepted_enabled',preferences.friend_accepted_enabled,
    'effective_message_enabled',coalesce(tokens.message_enabled,false)
      and coalesce(preferences.message_enabled,true),
    'effective_friend_request_enabled',coalesce(tokens.friend_request_enabled,false)
      and coalesce(preferences.friend_request_enabled,true),
    'effective_friend_accepted_enabled',coalesce(tokens.friend_accepted_enabled,false)
      and coalesce(preferences.friend_accepted_enabled,true),
    'synchronized',preferences.user_id is not null and not exists(
      select 1 from public.bil_push_device_tokens token
      where token.user_id=v_owner and token.enabled and (
        token.message_enabled is distinct from preferences.message_enabled or
        token.friend_request_enabled is distinct from preferences.friend_request_enabled or
        token.friend_accepted_enabled is distinct from preferences.friend_accepted_enabled
      )
    )
  ) into v_result
  from (
    select bool_or(token.message_enabled) as message_enabled,
           bool_or(token.friend_request_enabled) as friend_request_enabled,
           bool_or(token.friend_accepted_enabled) as friend_accepted_enabled
    from public.bil_push_device_tokens token
    where token.user_id=v_owner and token.enabled
  ) tokens
  left join private.bil_push_delivery_preferences_v1 preferences on preferences.user_id=v_owner;
  return v_result;
end
$function$;

-- Internal helper permits NULL expected revision ONLY for the pre-existing
-- three-argument legacy RPC. Its full-snapshot last-write-wins limitation is
-- retained for compatibility; new clients MUST use strict revision CAS.
create function private.bil_write_my_push_delivery_categories_v1(
  p_message_enabled boolean,p_friend_request_enabled boolean,
  p_friend_accepted_enabled boolean,p_expected_revision bigint
)
returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare
  v_owner uuid:=auth.uid();
  v_revision bigint;
begin
  if v_owner is null then raise exception 'authentication required' using errcode='42501'; end if;
  if p_message_enabled is null or p_friend_request_enabled is null or p_friend_accepted_enabled is null
    or p_expected_revision<0 then
    raise exception 'invalid push categories' using errcode='22023';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'bil.push.delivery.owner:'||v_owner::text,0));
  select revision into v_revision from private.bil_push_delivery_preferences_v1 where user_id=v_owner;
  v_revision:=coalesce(v_revision,0);
  if p_expected_revision is not null and p_expected_revision<>v_revision then
    raise exception 'push_delivery_preferences_conflict' using errcode='40001';
  end if;
  insert into private.bil_push_delivery_preferences_v1 as preferences(
    user_id,message_enabled,friend_request_enabled,friend_accepted_enabled
  ) values(v_owner,p_message_enabled,p_friend_request_enabled,p_friend_accepted_enabled)
  on conflict(user_id) do update set
    message_enabled=excluded.message_enabled,
    friend_request_enabled=excluded.friend_request_enabled,
    friend_accepted_enabled=excluded.friend_accepted_enabled,
    revision=preferences.revision+1,updated_at=now()
  where (preferences.message_enabled,preferences.friend_request_enabled,preferences.friend_accepted_enabled)
    is distinct from
    (excluded.message_enabled,excluded.friend_request_enabled,excluded.friend_accepted_enabled);
  update public.bil_push_device_tokens set
    message_enabled=p_message_enabled,friend_request_enabled=p_friend_request_enabled,
    friend_accepted_enabled=p_friend_accepted_enabled,last_seen_at=now()
  where user_id=v_owner and enabled;
  -- Durable server readback is valid even when no active device exists.
  return public.bil_get_my_push_delivery_categories_v1();
end
$function$;

create function public.bil_set_my_push_delivery_categories_v1(
  p_message_enabled boolean,p_friend_request_enabled boolean,
  p_friend_accepted_enabled boolean,p_expected_revision bigint
)
returns jsonb
language plpgsql security definer set search_path=''
as $function$
begin
  if p_expected_revision is null then
    raise exception 'expected revision required' using errcode='22023';
  end if;
  return private.bil_write_my_push_delivery_categories_v1(
    p_message_enabled,p_friend_request_enabled,p_friend_accepted_enabled,p_expected_revision);
end
$function$;

create or replace function public.bil_set_push_delivery_categories_v2(
  p_message_enabled boolean,p_friend_request_enabled boolean,p_friend_accepted_enabled boolean
)
returns void
language plpgsql security definer set search_path=''
as $function$
begin
  perform private.bil_write_my_push_delivery_categories_v1(
    p_message_enabled,p_friend_request_enabled,p_friend_accepted_enabled,null);
end
$function$;

create or replace function public.bil_register_push_token_v2(
  p_token text,p_platform text,p_timezone text,p_sensitive_preview_allowed boolean default false,
  p_message_enabled boolean default true,p_friend_request_enabled boolean default true,
  p_friend_accepted_enabled boolean default true
)
returns void
language plpgsql security definer set search_path=''
as $function$
declare
  v_owner uuid:=auth.uid();
  v_categories private.bil_push_delivery_preferences_v1%rowtype;
begin
  if v_owner is null then raise exception 'authentication required' using errcode='42501'; end if;
  if length(p_token)<20 or p_platform not in ('fcm','apns') then raise exception 'invalid push token'; end if;
  if p_message_enabled is null or p_friend_request_enabled is null or p_friend_accepted_enabled is null then
    raise exception 'invalid push categories' using errcode='22023';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'bil.push.delivery.owner:'||v_owner::text,0));
  -- First-ever owner registration may initialize its explicit parameters.
  -- Rotation/resume/legacy defaults NEVER overwrite an established opt-out.
  insert into private.bil_push_delivery_preferences_v1(
    user_id,message_enabled,friend_request_enabled,friend_accepted_enabled
  ) values(v_owner,p_message_enabled,p_friend_request_enabled,p_friend_accepted_enabled)
  on conflict(user_id) do nothing;
  select * into strict v_categories from private.bil_push_delivery_preferences_v1 where user_id=v_owner;
  insert into public.bil_push_device_tokens(
    user_id,token_ciphertext,token_fingerprint,platform,timezone,
    sensitive_preview_allowed,message_enabled,friend_request_enabled,friend_accepted_enabled
  ) values(v_owner,p_token,encode(extensions.digest(p_token,'sha256'),'hex'),
    p_platform,p_timezone,false,v_categories.message_enabled,v_categories.friend_request_enabled,
    v_categories.friend_accepted_enabled)
  on conflict(token_fingerprint) do update set
    user_id=v_owner,enabled=true,timezone=excluded.timezone,last_seen_at=now(),
    sensitive_preview_allowed=false,message_enabled=excluded.message_enabled,
    friend_request_enabled=excluded.friend_request_enabled,friend_accepted_enabled=excluded.friend_accepted_enabled;
end
$function$;

-- Preserve the old registration signature/ACL and false sensitive previews;
-- route legacy creation through the SAME durable owner-category authority.
create or replace function public.bil_register_push_token(
  p_token text,p_platform text,p_timezone text,p_sensitive_preview_allowed boolean default false
)
returns void
language plpgsql security definer set search_path=''
as $function$
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  perform public.bil_register_push_token_v2(p_token,p_platform,p_timezone,p_sensitive_preview_allowed,true,true,true);
end
$function$;

CREATE OR REPLACE FUNCTION public.bil_claim_push_deliveries(p_outbox_id uuid, p_lease_seconds integer DEFAULT 60)
 RETURNS TABLE(device_token_id uuid, provider_token text, platform text, sensitive_preview_allowed boolean, delivery_key text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_recipient_id uuid;
  v_category text;
  v_copy_key text;
  v_max_attempts integer;
  v_categories private.bil_push_delivery_preferences_v1%rowtype;
  v_lease_seconds integer:=least(greatest(coalesce(p_lease_seconds,60),15),300);
begin
  select policy.max_attempts into v_max_attempts
  from public.bil_push_delivery_policy policy where policy.singleton;
  if v_max_attempts is null then raise exception 'push_delivery_policy_unavailable'; end if;

  select outbox.recipient_id,outbox.category,outbox.copy_key
  into v_recipient_id,v_category,v_copy_key
  from public.bil_push_outbox outbox
  where outbox.id=p_outbox_id and outbox.dispatched_at is null
  for update;
  if v_recipient_id is null then return; end if;

  -- Serialize a claim against committed owner opt-outs and token registration.
  -- Already-sent provider requests cannot be recalled by a database preference.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'bil.push.delivery.owner:'||v_recipient_id::text,0));
  select * into v_categories from private.bil_push_delivery_preferences_v1
  where user_id=v_recipient_id;

  insert into public.bil_push_delivery_attempts(outbox_id,device_token_id)
  select p_outbox_id,token.id
  from public.bil_push_device_tokens token
  where token.user_id=v_recipient_id
    and token.enabled
    and case
      when v_category='message' then token.message_enabled and coalesce(v_categories.message_enabled,true)
      when v_category='friend_request' then token.friend_request_enabled and coalesce(v_categories.friend_request_enabled,true)
      when v_category='community' and v_copy_key='friend_accepted_v1'
        then token.friend_accepted_enabled and coalesce(v_categories.friend_accepted_enabled,true)
      else true
    end
  on conflict on constraint bil_push_delivery_attempts_pkey do nothing;

  return query
  with eligible as (
    select attempt.outbox_id,attempt.device_token_id
    from public.bil_push_delivery_attempts attempt
    join public.bil_push_device_tokens token on token.id=attempt.device_token_id
    where attempt.outbox_id=p_outbox_id
      and token.user_id=v_recipient_id
      and token.enabled
      and case
        when v_category='message' then token.message_enabled and coalesce(v_categories.message_enabled,true)
        when v_category='friend_request' then token.friend_request_enabled and coalesce(v_categories.friend_request_enabled,true)
        when v_category='community' and v_copy_key='friend_accepted_v1'
          then token.friend_accepted_enabled and coalesce(v_categories.friend_accepted_enabled,true)
        else true
      end
      and attempt.delivered_at is null
      and attempt.terminal_at is null
      and attempt.attempt_count<v_max_attempts
      and attempt.next_attempt_at<=pg_catalog.clock_timestamp()
      and (attempt.leased_until is null or attempt.leased_until<=pg_catalog.clock_timestamp())
    order by attempt.device_token_id
    limit 100
    for update of attempt skip locked
  ),
  claimed as (
    update public.bil_push_delivery_attempts attempt
    set leased_until=pg_catalog.clock_timestamp()+pg_catalog.make_interval(secs=>v_lease_seconds),
        last_attempt_at=pg_catalog.clock_timestamp(),
        attempt_count=attempt.attempt_count+1
    from eligible
    where attempt.outbox_id=eligible.outbox_id
      and attempt.device_token_id=eligible.device_token_id
    returning attempt.device_token_id
  )
  select token.id,token.token_ciphertext,token.platform,
         token.sensitive_preview_allowed,
         p_outbox_id::text||':'||token.id::text
  from claimed
  join public.bil_push_device_tokens token on token.id=claimed.device_token_id;
end
$function$
;
-- No source actor exists in the current outbox contract. Do not invent
-- block/suspension enforcement from a URL/source_key. All LIVE recipient,
-- token-owner, enabled, lease, retry cap, bound and idempotency guards remain.
-- Unchanged bil_get_push_preferences()/master/sensitive/finalizer/result RPCs.

revoke all on function public.bil_get_my_push_delivery_categories_v1(),
  public.bil_set_my_push_delivery_categories_v1(boolean,boolean,boolean,bigint),
  private.bil_write_my_push_delivery_categories_v1(boolean,boolean,boolean,bigint)
  from public,anon,authenticated,service_role;
grant execute on function public.bil_get_my_push_delivery_categories_v1(),
  public.bil_set_my_push_delivery_categories_v1(boolean,boolean,boolean,bigint) to authenticated;
-- CREATE OR REPLACE preserves the existing legacy and dispatcher ACLs.
-- Explicitly retain their audited allowlists without direct table privileges.
revoke all on function public.bil_set_push_delivery_categories_v2(boolean,boolean,boolean),
  public.bil_register_push_token_v2(text,text,text,boolean,boolean,boolean,boolean)
  from public,anon,authenticated,service_role;
grant execute on function public.bil_set_push_delivery_categories_v2(boolean,boolean,boolean),
  public.bil_register_push_token_v2(text,text,text,boolean,boolean,boolean,boolean) to authenticated;
revoke all on function public.bil_register_push_token(text,text,text,boolean),
  public.bil_claim_push_deliveries(uuid,integer) from public,anon,authenticated,service_role;
grant execute on function public.bil_register_push_token(text,text,text,boolean) to authenticated,service_role;
grant execute on function public.bil_claim_push_deliveries(uuid,integer) to service_role;

