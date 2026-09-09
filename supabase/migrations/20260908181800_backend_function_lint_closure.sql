-- Close the two PL/pgSQL diagnostics found by the post-deployment database
-- linter. This changes function definitions only: push rows, Social rows,
-- grants, RLS, policies, tables, and business data remain untouched.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $backend_function_lint_preflight$
declare
  v_push_function regprocedure :=
    'public.bil_claim_push_deliveries(uuid,integer)'::regprocedure;
  v_code_helper regprocedure :=
    'private.bil_social_public_code_payload_v2(boolean)'::regprocedure;
begin
  if v_push_function is null
     or v_code_helper is null
     or not exists (
       select 1
       from pg_catalog.pg_constraint constraint_row
       where constraint_row.conrelid =
         'public.bil_push_delivery_attempts'::regclass
         and constraint_row.conname =
           'bil_push_delivery_attempts_pkey'
         and constraint_row.contype = 'p'
     ) then
    raise exception 'backend_function_lint_precondition_failed'
      using errcode = '55000';
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_proc procedure
    where procedure.oid = v_push_function
      and procedure.prosecdef
      and procedure.prosrc ilike
        '%on conflict (outbox_id, device_token_id) do nothing%'
  ) then
    raise exception 'backend_function_lint_precondition_failed'
      using errcode = '55000',
            detail = 'The push claim function no longer matches the reviewed ambiguous-conflict definition.';
  end if;
end
$backend_function_lint_preflight$;

create or replace function private.bil_social_public_code_payload_v2(
  p_rotate boolean
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = ''
as $function$
declare
  v_actor_id uuid := (select auth.uid());
  v_code text;
  v_has_code boolean;
begin
  if v_actor_id is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if not public.bil_can_use_community() then
    raise exception 'community_unavailable' using errcode = '42501';
  end if;
  if not exists (
    select 1
    from public.bil_public_profiles profile
    where profile.user_id = v_actor_id
  ) then
    raise exception 'community_profile_required' using errcode = 'P0001';
  end if;

  perform public.bil_social_identity_v2();
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'bil_public_code:' || v_actor_id::text,
      0
    )
  );

  select public_code.code
  into v_code
  from public.bil_social_public_codes_v2 public_code
  where public_code.user_id = v_actor_id
  for update;
  v_has_code := found;

  if not coalesce(p_rotate, false) and v_has_code then
    return pg_catalog.jsonb_build_object(
      'code', v_code,
      'uri', 'bil://community/member/' || v_code,
      'handle', (
        select handle.handle
        from public.bil_social_handles_v2 handle
        where handle.user_id = v_actor_id
      )
    );
  end if;

  if coalesce(p_rotate, false) then
    perform public.bil_consume_rate_limit(
      'community_public_code_rotate_v2',
      5,
      86400
    );
  end if;

  for v_attempt in 1..3 loop
    v_code := pg_catalog.replace(pg_catalog.gen_random_uuid()::text, '-', '');
    begin
      if v_has_code then
        update public.bil_social_public_codes_v2
        set code = v_code,
            rotated_at = pg_catalog.now()
        where user_id = v_actor_id;
      else
        insert into public.bil_social_public_codes_v2 (user_id, code)
        values (v_actor_id, v_code);
      end if;
      exit;
    exception
      when unique_violation then
        if v_attempt = 3 then
          raise;
        end if;
    end;
  end loop;

  return pg_catalog.jsonb_build_object(
    'code', v_code,
    'uri', 'bil://community/member/' || v_code,
    'handle', (
      select handle.handle
      from public.bil_social_handles_v2 handle
      where handle.user_id = v_actor_id
    )
  );
end
$function$;

create or replace function public.bil_claim_push_deliveries(
  p_outbox_id uuid,
  p_lease_seconds integer default 60
)
returns table (
  device_token_id uuid,
  provider_token text,
  platform text,
  sensitive_preview_allowed boolean,
  delivery_key text
)
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  v_recipient_id uuid;
  v_max_attempts integer;
  v_lease_seconds integer := least(
    greatest(coalesce(p_lease_seconds, 60), 15),
    300
  );
begin
  select policy.max_attempts
  into v_max_attempts
  from public.bil_push_delivery_policy policy
  where policy.singleton;

  if v_max_attempts is null then
    raise exception 'push_delivery_policy_unavailable';
  end if;

  select outbox.recipient_id
  into v_recipient_id
  from public.bil_push_outbox outbox
  where outbox.id = p_outbox_id
    and outbox.dispatched_at is null
  for update;

  if v_recipient_id is null then
    return;
  end if;

  insert into public.bil_push_delivery_attempts(outbox_id, device_token_id)
  select p_outbox_id, token.id
  from public.bil_push_device_tokens token
  where token.user_id = v_recipient_id
    and token.enabled
  on conflict on constraint bil_push_delivery_attempts_pkey do nothing;

  return query
  with eligible as (
    select attempt.outbox_id, attempt.device_token_id
    from public.bil_push_delivery_attempts attempt
    join public.bil_push_device_tokens token
      on token.id = attempt.device_token_id
    where attempt.outbox_id = p_outbox_id
      and token.user_id = v_recipient_id
      and token.enabled
      and attempt.delivered_at is null
      and attempt.terminal_at is null
      and attempt.attempt_count < v_max_attempts
      and attempt.next_attempt_at <= pg_catalog.clock_timestamp()
      and (
        attempt.leased_until is null or
        attempt.leased_until <= pg_catalog.clock_timestamp()
      )
    order by attempt.device_token_id
    limit 100
    for update of attempt skip locked
  ), claimed as (
    update public.bil_push_delivery_attempts attempt
    set leased_until = pg_catalog.clock_timestamp() +
          pg_catalog.make_interval(secs => v_lease_seconds),
        last_attempt_at = pg_catalog.clock_timestamp(),
        attempt_count = attempt.attempt_count + 1
    from eligible
    where attempt.outbox_id = eligible.outbox_id
      and attempt.device_token_id = eligible.device_token_id
    returning attempt.device_token_id
  )
  select
    token.id,
    token.token_ciphertext as provider_token,
    token.platform,
    token.sensitive_preview_allowed,
    p_outbox_id::text || ':' || token.id::text
  from claimed
  join public.bil_push_device_tokens token
    on token.id = claimed.device_token_id;
end
$function$;

revoke all on function
  private.bil_social_public_code_payload_v2(boolean)
from public, anon, authenticated, service_role;

revoke all on function
  public.bil_claim_push_deliveries(uuid, integer)
from public, anon, authenticated, service_role;

grant execute on function
  public.bil_claim_push_deliveries(uuid, integer)
to service_role;

do $backend_function_lint_postconditions$
declare
  v_push_function regprocedure :=
    'public.bil_claim_push_deliveries(uuid,integer)'::regprocedure;
  v_code_helper regprocedure :=
    'private.bil_social_public_code_payload_v2(boolean)'::regprocedure;
begin
  if not exists (
    select 1
    from pg_catalog.pg_proc procedure
    where procedure.oid = v_push_function
      and procedure.prosecdef
      and procedure.provolatile = 'v'
      and procedure.prosrc ilike
        '%on conflict on constraint bil_push_delivery_attempts_pkey do nothing%'
      and procedure.prosrc not ilike
        '%on conflict (outbox_id, device_token_id) do nothing%'
      and exists (
        select 1
        from pg_catalog.unnest(procedure.proconfig) configuration(setting)
        where configuration.setting in ('search_path=', 'search_path=""')
      )
  )
     or not pg_catalog.has_function_privilege(
       'service_role', v_push_function, 'EXECUTE'
     )
     or pg_catalog.has_function_privilege(
       'authenticated', v_push_function, 'EXECUTE'
     )
     or pg_catalog.has_function_privilege(
       'anon', v_push_function, 'EXECUTE'
     )
     or exists (
       select 1
       from pg_catalog.pg_proc procedure
       cross join lateral pg_catalog.aclexplode(
         coalesce(
           procedure.proacl,
           pg_catalog.acldefault('f', procedure.proowner)
         )
       ) privilege
       where procedure.oid = v_push_function
         and privilege.grantee = 0
         and privilege.privilege_type = 'EXECUTE'
     ) then
    raise exception 'backend_push_function_lint_postcondition_failed'
      using errcode = '55000';
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_proc procedure
    where procedure.oid = v_code_helper
      and not procedure.prosecdef
      and procedure.provolatile = 'v'
      and procedure.prosrc not ilike '%v_attempt integer%'
      and exists (
        select 1
        from pg_catalog.unnest(procedure.proconfig) configuration(setting)
        where configuration.setting in ('search_path=', 'search_path=""')
      )
  )
     or pg_catalog.has_function_privilege(
       'service_role', v_code_helper, 'EXECUTE'
     )
     or pg_catalog.has_function_privilege(
       'authenticated', v_code_helper, 'EXECUTE'
     )
     or pg_catalog.has_function_privilege(
       'anon', v_code_helper, 'EXECUTE'
     )
     or exists (
       select 1
       from pg_catalog.pg_proc procedure
       cross join lateral pg_catalog.aclexplode(
         coalesce(
           procedure.proacl,
           pg_catalog.acldefault('f', procedure.proowner)
         )
       ) privilege
       where procedure.oid = v_code_helper
         and privilege.grantee = 0
         and privilege.privilege_type = 'EXECUTE'
     ) then
    raise exception 'backend_code_helper_lint_postcondition_failed'
      using errcode = '55000';
  end if;
end
$backend_function_lint_postconditions$;

notify pgrst, 'reload schema';

commit;
