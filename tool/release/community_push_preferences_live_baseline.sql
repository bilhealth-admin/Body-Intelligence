-- Read-only Production function snapshot: tgmanzhqulksykhslrzb, 2026-10-04 UTC.
-- Genuine bodies and ACLs; NO tokens, user rows, secrets, outbound delivery or mocks.
-- Used ONLY by the loopback disposable PostgreSQL17 fixture.

CREATE OR REPLACE FUNCTION auth.uid()
 RETURNS uuid
 LANGUAGE sql
 STABLE
AS $function$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$function$
;
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

  insert into public.bil_push_delivery_attempts(outbox_id,device_token_id)
  select p_outbox_id,token.id
  from public.bil_push_device_tokens token
  where token.user_id=v_recipient_id
    and token.enabled
    and case
      when v_category='message' then token.message_enabled
      when v_category='friend_request' then token.friend_request_enabled
      when v_category='community' and v_copy_key='friend_accepted_v1'
        then token.friend_accepted_enabled
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
revoke all on function public.bil_claim_push_deliveries(uuid,integer) from public,anon,authenticated,service_role;
grant execute on function public.bil_claim_push_deliveries(uuid,integer) to service_role;

CREATE OR REPLACE FUNCTION public.bil_disable_push_tokens()
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  update bil_push_device_tokens set enabled=false where user_id=auth.uid()
$function$
;
revoke all on function public.bil_disable_push_tokens() from public,anon,authenticated,service_role;
grant execute on function public.bil_disable_push_tokens() to authenticated;
grant execute on function public.bil_disable_push_tokens() to service_role;

CREATE OR REPLACE FUNCTION public.bil_finalize_push_outbox(p_outbox_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_recipient_id uuid;
  v_category text;
  v_copy_key text;
  v_enabled_tokens integer:=0;
  v_enabled_without_attempt integer:=0;
  v_unresolved_enabled integer:=0;
  v_attempted_tokens integer:=0;
  v_delivered_tokens integer:=0;
  v_terminal_tokens integer:=0;
  v_failure_code text;
  v_reason text;
begin
  select o.recipient_id,o.category,o.copy_key
  into v_recipient_id,v_category,v_copy_key
  from public.bil_push_outbox o
  where o.id=p_outbox_id and o.dispatched_at is null
  for update;

  if v_recipient_id is null then
    return jsonb_build_object('finalized',true,'reason','already_finalized');
  end if;

  select count(*)::integer into v_enabled_tokens
  from public.bil_push_device_tokens token
  where token.user_id=v_recipient_id and token.enabled
    and case
      when v_category='message' then token.message_enabled
      when v_category='friend_request' then token.friend_request_enabled
      when v_category='community' and v_copy_key='friend_accepted_v1'
        then token.friend_accepted_enabled
      else true
    end;

  select count(*)::integer,
         count(*) filter(where attempt.delivered_at is not null)::integer,
         count(*) filter(where attempt.delivered_at is null and attempt.terminal_at is not null)::integer
  into v_attempted_tokens,v_delivered_tokens,v_terminal_tokens
  from public.bil_push_delivery_attempts attempt
  join public.bil_push_device_tokens token on token.id=attempt.device_token_id
  where attempt.outbox_id=p_outbox_id
    and token.user_id=v_recipient_id
    and case
      when v_category='message' then token.message_enabled
      when v_category='friend_request' then token.friend_request_enabled
      when v_category='community' and v_copy_key='friend_accepted_v1'
        then token.friend_accepted_enabled
      else true
    end;

  select count(*)::integer into v_enabled_without_attempt
  from public.bil_push_device_tokens token
  where token.user_id=v_recipient_id and token.enabled
    and case
      when v_category='message' then token.message_enabled
      when v_category='friend_request' then token.friend_request_enabled
      when v_category='community' and v_copy_key='friend_accepted_v1'
        then token.friend_accepted_enabled
      else true
    end
    and not exists(
      select 1 from public.bil_push_delivery_attempts attempt
      where attempt.outbox_id=p_outbox_id and attempt.device_token_id=token.id
    );

  select count(*)::integer into v_unresolved_enabled
  from public.bil_push_delivery_attempts attempt
  join public.bil_push_device_tokens token on token.id=attempt.device_token_id
  where attempt.outbox_id=p_outbox_id
    and token.user_id=v_recipient_id
    and token.enabled
    and case
      when v_category='message' then token.message_enabled
      when v_category='friend_request' then token.friend_request_enabled
      when v_category='community' and v_copy_key='friend_accepted_v1'
        then token.friend_accepted_enabled
      else true
    end
    and attempt.delivered_at is null
    and attempt.terminal_at is null;

  if v_enabled_tokens=0 and v_attempted_tokens=0 then
    update public.bil_push_outbox
    set dispatched_at=pg_catalog.clock_timestamp(),
        failure_code='no_eligible_tokens'
    where id=p_outbox_id;
    return jsonb_build_object(
      'finalized',true,'reason','no_eligible_tokens','delivered',0,'expected',0
    );
  end if;

  if v_enabled_without_attempt=0 and v_unresolved_enabled=0 then
    v_reason:=case
      when v_delivered_tokens=v_attempted_tokens then 'delivered'
      when v_delivered_tokens>0 then 'partial_delivery'
      else 'delivery_failed'
    end;
    update public.bil_push_outbox
    set dispatched_at=pg_catalog.clock_timestamp(),
        failure_code=case when v_reason='delivered' then null else v_reason end
    where id=p_outbox_id;
    return jsonb_build_object(
      'finalized',true,'reason',v_reason,'delivered',v_delivered_tokens,
      'terminal',v_terminal_tokens,'expected',v_attempted_tokens
    );
  end if;

  select attempt.failure_code into v_failure_code
  from public.bil_push_delivery_attempts attempt
  join public.bil_push_device_tokens token on token.id=attempt.device_token_id
  where attempt.outbox_id=p_outbox_id
    and token.user_id=v_recipient_id
    and token.enabled
    and attempt.delivered_at is null
    and attempt.terminal_at is null
    and attempt.failure_code is not null
  order by attempt.last_attempt_at desc nulls last
  limit 1;

  update public.bil_push_outbox
  set dispatched_at=null,failure_code=coalesce(v_failure_code,'delivery_pending')
  where id=p_outbox_id;

  return jsonb_build_object(
    'finalized',false,'reason',coalesce(v_failure_code,'delivery_pending'),
    'delivered',v_delivered_tokens,'terminal',v_terminal_tokens,
    'expected',v_attempted_tokens+v_enabled_without_attempt
  );
end
$function$
;
revoke all on function public.bil_finalize_push_outbox(uuid) from public,anon,authenticated,service_role;
grant execute on function public.bil_finalize_push_outbox(uuid) to service_role;

CREATE OR REPLACE FUNCTION public.bil_get_push_preferences()
 RETURNS TABLE(enabled boolean, timezone text, sensitive_preview_allowed boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(bool_or(t.enabled), false), coalesce(max(t.timezone), 'UTC'),
         coalesce(bool_or(t.sensitive_preview_allowed), false)
  from bil_push_device_tokens t where t.user_id=auth.uid()
$function$
;
revoke all on function public.bil_get_push_preferences() from public,anon,authenticated,service_role;
grant execute on function public.bil_get_push_preferences() to authenticated;
grant execute on function public.bil_get_push_preferences() to service_role;

CREATE OR REPLACE FUNCTION public.bil_record_push_delivery_result(p_outbox_id uuid, p_device_token_id uuid, p_delivered boolean, p_failure_code text DEFAULT NULL::text, p_permanent_token_failure boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_attempt_count integer;
  v_existing_delivered_at timestamptz;
  v_max_attempts integer;
  v_base_backoff_seconds integer;
  v_max_backoff_seconds integer;
  v_backoff_seconds integer;
  v_terminal boolean;
  v_failure_code text;
begin
  select
    policy.max_attempts,
    policy.base_backoff_seconds,
    policy.max_backoff_seconds
    into v_max_attempts, v_base_backoff_seconds, v_max_backoff_seconds
  from public.bil_push_delivery_policy policy
  where policy.singleton;

  if v_max_attempts is null then
    raise exception 'push_delivery_policy_unavailable';
  end if;

  select attempt.attempt_count, attempt.delivered_at
    into v_attempt_count, v_existing_delivered_at
  from public.bil_push_delivery_attempts attempt
  where attempt.outbox_id = p_outbox_id
    and attempt.device_token_id = p_device_token_id
  for update;

  if not found or v_existing_delivered_at is not null then
    return;
  end if;

  if coalesce(p_delivered, false) then
    update public.bil_push_delivery_attempts attempt
       set delivered_at = pg_catalog.clock_timestamp(),
           terminal_at = null,
           permanent_token_failure = false,
           failure_code = null,
           leased_until = null
     where attempt.outbox_id = p_outbox_id
       and attempt.device_token_id = p_device_token_id;
    return;
  end if;

  v_failure_code := pg_catalog.left(
    coalesce(
      nullif(pg_catalog.btrim(p_failure_code), ''),
      'provider_failure'
    ),
    120
  );
  v_terminal := coalesce(p_permanent_token_failure, false)
    or v_attempt_count >= v_max_attempts;
  v_backoff_seconds := least(
    v_max_backoff_seconds,
    (
      v_base_backoff_seconds * pg_catalog.power(
        2::numeric,
        greatest(v_attempt_count - 1, 0)
      )
    )::integer
  );

  update public.bil_push_delivery_attempts attempt
     set terminal_at = case
           when v_terminal then pg_catalog.clock_timestamp()
           else null
         end,
         permanent_token_failure =
           coalesce(p_permanent_token_failure, false),
         failure_code = v_failure_code,
         leased_until = null,
         next_attempt_at = case
           when v_terminal then attempt.next_attempt_at
           else pg_catalog.clock_timestamp() +
             pg_catalog.make_interval(secs => v_backoff_seconds)
         end
   where attempt.outbox_id = p_outbox_id
     and attempt.device_token_id = p_device_token_id;

  -- Only the trusted provider gateway can assert this flag. A plain HTTP
  -- status is deliberately insufficient, preventing a bad gateway URL from
  -- disabling every device token. Exhausting retries terminates this delivery
  -- only and does not disable the token for future outbox rows.
  if coalesce(p_permanent_token_failure, false) then
    update public.bil_push_device_tokens token
       set enabled = false
     where token.id = p_device_token_id
       and exists (
         select 1
         from public.bil_push_outbox outbox
         where outbox.id = p_outbox_id
           and outbox.recipient_id = token.user_id
       );
  end if;
end
$function$
;
revoke all on function public.bil_record_push_delivery_result(uuid,uuid,boolean,text,boolean) from public,anon,authenticated,service_role;
grant execute on function public.bil_record_push_delivery_result(uuid,uuid,boolean,text,boolean) to service_role;

CREATE OR REPLACE FUNCTION public.bil_register_push_token(p_token text, p_platform text, p_timezone text, p_sensitive_preview_allowed boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if length(p_token) < 20 or p_platform not in ('fcm','apns') then
    raise exception 'invalid push token';
  end if;
  insert into public.bil_push_device_tokens(
    user_id, token_ciphertext, token_fingerprint, platform, timezone,
    sensitive_preview_allowed
  ) values (
    auth.uid(), p_token,
    encode(extensions.digest(p_token, 'sha256'), 'hex'),
    p_platform, p_timezone, false
  )
  on conflict(token_fingerprint) do update
    set user_id = auth.uid(), enabled = true, timezone = excluded.timezone,
        last_seen_at = now(), sensitive_preview_allowed = false;
end
$function$
;
revoke all on function public.bil_register_push_token(text,text,text,boolean) from public,anon,authenticated,service_role;
grant execute on function public.bil_register_push_token(text,text,text,boolean) to authenticated;
grant execute on function public.bil_register_push_token(text,text,text,boolean) to service_role;

CREATE OR REPLACE FUNCTION public.bil_register_push_token_v2(p_token text, p_platform text, p_timezone text, p_sensitive_preview_allowed boolean DEFAULT false, p_message_enabled boolean DEFAULT true, p_friend_request_enabled boolean DEFAULT true, p_friend_accepted_enabled boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if auth.uid() is null then raise exception 'authentication required' using errcode='42501'; end if;
  if length(p_token)<20 or p_platform not in ('fcm','apns') then
    raise exception 'invalid push token';
  end if;
  if p_message_enabled is null or p_friend_request_enabled is null or p_friend_accepted_enabled is null then
    raise exception 'invalid push categories' using errcode='22023';
  end if;
  insert into public.bil_push_device_tokens(
    user_id,token_ciphertext,token_fingerprint,platform,timezone,
    sensitive_preview_allowed,message_enabled,friend_request_enabled,
    friend_accepted_enabled
  ) values(
    auth.uid(),p_token,encode(extensions.digest(p_token,'sha256'),'hex'),
    p_platform,p_timezone,false,p_message_enabled,p_friend_request_enabled,
    p_friend_accepted_enabled
  )
  on conflict(token_fingerprint) do update
    set user_id=auth.uid(),
        enabled=true,
        timezone=excluded.timezone,
        last_seen_at=now(),
        sensitive_preview_allowed=false,
        message_enabled=excluded.message_enabled,
        friend_request_enabled=excluded.friend_request_enabled,
        friend_accepted_enabled=excluded.friend_accepted_enabled;
end
$function$
;
revoke all on function public.bil_register_push_token_v2(text,text,text,boolean,boolean,boolean,boolean) from public,anon,authenticated,service_role;
grant execute on function public.bil_register_push_token_v2(text,text,text,boolean,boolean,boolean,boolean) to authenticated;

CREATE OR REPLACE FUNCTION public.bil_set_push_delivery_categories_v2(p_message_enabled boolean, p_friend_request_enabled boolean, p_friend_accepted_enabled boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if auth.uid() is null then raise exception 'authentication required' using errcode='42501'; end if;
  if p_message_enabled is null or p_friend_request_enabled is null or p_friend_accepted_enabled is null then
    raise exception 'invalid push categories' using errcode='22023';
  end if;
  update public.bil_push_device_tokens
  set message_enabled=p_message_enabled,
      friend_request_enabled=p_friend_request_enabled,
      friend_accepted_enabled=p_friend_accepted_enabled,
      last_seen_at=now()
  where user_id=auth.uid() and enabled;
end
$function$
;
revoke all on function public.bil_set_push_delivery_categories_v2(boolean,boolean,boolean) from public,anon,authenticated,service_role;
grant execute on function public.bil_set_push_delivery_categories_v2(boolean,boolean,boolean) to authenticated;

CREATE OR REPLACE FUNCTION public.bil_set_sensitive_push_previews(p_allowed boolean)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  update bil_push_device_tokens set sensitive_preview_allowed=coalesce(p_allowed,false)
  where user_id=auth.uid()
$function$
;
revoke all on function public.bil_set_sensitive_push_previews(boolean) from public,anon,authenticated,service_role;
grant execute on function public.bil_set_sensitive_push_previews(boolean) to authenticated;
grant execute on function public.bil_set_sensitive_push_previews(boolean) to service_role;

