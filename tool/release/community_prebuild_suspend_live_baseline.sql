-- Fixture-only unchanged Production function snapshot, read 2026-10-04.
-- Genuine canonical administrator suspension; never apply this baseline to Production.
CREATE OR REPLACE FUNCTION public.bil_suspend_community_member_by_email(p_actor_id uuid, p_email text, p_reason text, p_idempotency_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_email text := pg_catalog.lower(pg_catalog.btrim(p_email));
  v_reason text := pg_catalog.btrim(p_reason);
  v_target_id uuid;
  v_matches integer;
  v_changed boolean := false;
  v_moderator_removed boolean := false;
  v_digest text;
  v_existing_actor uuid;
  v_existing_action text;
  v_existing_digest text;
  v_existing_result jsonb;
  v_result jsonb;
begin
  if coalesce((select auth.jwt()->>'role'), '') <> 'service_role'
     or p_actor_id is null
     or not exists (
       select 1
       from private.bil_ai_coach_admins administrator
       where administrator.user_id = p_actor_id
         and administrator.active
     ) then
    raise exception 'administrator_required' using errcode = '42501';
  end if;
  if p_idempotency_key is null
     or pg_catalog.char_length(pg_catalog.btrim(p_idempotency_key))
       not between 16 and 128
     or pg_catalog.btrim(p_idempotency_key) !~ '^[A-Za-z0-9:_-]+$' then
    raise exception 'invalid_idempotency_key';
  end if;
  if v_email is null or v_email = '' or pg_catalog.char_length(v_email) > 254
     or v_email ~ '[[:cntrl:][:space:]]'
     or v_email !~ '^[^@]+@[^@]+[.][^@]+$' then
    raise exception 'invalid_email';
  end if;
  if v_reason is null or pg_catalog.char_length(v_reason) not between 2 and 160
     or v_reason ~ '[[:cntrl:]]' then
    raise exception 'invalid_suspension_reason';
  end if;

  v_digest := pg_catalog.encode(
    extensions.digest(v_email || E'\n' || v_reason, 'sha256'),
    'hex'
  );
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'community_member_access:' || pg_catalog.btrim(p_idempotency_key), 0
    )
  );
  select audit.actor_id, audit.action, audit.request_digest, audit.result
    into v_existing_actor, v_existing_action, v_existing_digest,
      v_existing_result
  from private.bil_community_member_access_audit audit
  where audit.idempotency_key = pg_catalog.btrim(p_idempotency_key);
  if found then
    if v_existing_actor is distinct from p_actor_id then
      raise exception 'idempotency_key_owned_by_another_admin'
        using errcode = '42501';
    end if;
    if v_existing_action <> 'suspend' or v_existing_digest <> v_digest then
      raise exception 'idempotency_key_request_mismatch';
    end if;
    return v_existing_result;
  end if;

  select pg_catalog.count(*)::integer, pg_catalog.min(account.id::text)::uuid
    into v_matches, v_target_id
  from auth.users account
  where pg_catalog.lower(account.email) = v_email;

  if v_matches <> 1 then
    v_result := pg_catalog.jsonb_build_object(
      'matched', false, 'active', false, 'changed', false,
      'moderator_removed', false
    );
    insert into private.bil_community_member_access_audit(
      idempotency_key, actor_id, action, request_digest, result
    ) values (
      pg_catalog.btrim(p_idempotency_key), p_actor_id, 'suspend', v_digest,
      v_result
    );
    return v_result;
  end if;

  if exists (
    select 1
    from private.bil_ai_coach_admins administrator
    where administrator.user_id = v_target_id
      and administrator.active
  ) then
    raise exception 'protected_administrator_member' using errcode = '42501';
  end if;

  -- Serialize with moderator add/remove. Without the shared roster lock, an
  -- add waiting on this transaction's moderator-row delete could run its
  -- eligibility trigger against the pre-suspension snapshot and recreate the
  -- moderator immediately after the delete commits.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('community_moderator_roster', 0)
  );
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'community_member_state:' || v_target_id::text, 0
    )
  );

  insert into private.bil_community_member_access(
    user_id, suspended, reason, suspended_by, suspended_at,
    reinstated_by, reinstated_at, updated_at
  ) values (
    v_target_id, true, v_reason, p_actor_id, pg_catalog.clock_timestamp(),
    null, null, pg_catalog.clock_timestamp()
  )
  on conflict (user_id) do update set
    suspended = true,
    reason = excluded.reason,
    suspended_by = excluded.suspended_by,
    suspended_at = case
      when private.bil_community_member_access.suspended
        then private.bil_community_member_access.suspended_at
      else excluded.suspended_at
    end,
    reinstated_by = null,
    reinstated_at = null,
    updated_at = pg_catalog.clock_timestamp()
  where not private.bil_community_member_access.suspended
     or private.bil_community_member_access.reason is distinct from excluded.reason;
  v_changed := found;

  delete from public.bil_community_moderators moderator
  where moderator.user_id = v_target_id;
  v_moderator_removed := found;

  v_result := pg_catalog.jsonb_build_object(
    'matched', true,
    'active', true,
    'changed', v_changed,
    'moderator_removed', v_moderator_removed
  );
  insert into private.bil_community_member_access_audit(
    idempotency_key, actor_id, target_id, action, request_digest, result
  ) values (
    pg_catalog.btrim(p_idempotency_key), p_actor_id, v_target_id, 'suspend',
    v_digest, v_result
  );
  return v_result;
end
$function$;
