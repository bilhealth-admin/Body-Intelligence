begin;

set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $migration_preflight$
begin
  if to_regclass('public.bil_public_profiles') is null
     or to_regclass('public.bil_friendships') is null
     or to_regclass('public.bil_social_handles_v2') is null
     or to_regprocedure('public.bil_can_use_community()') is null
     or to_regprocedure('public.bil_social_profile_visible_v2(uuid)') is null then
    raise exception 'community_social_v2_dependencies_missing';
  end if;

  if to_regprocedure('public.bil_social_post_authors_v2(uuid[])') is not null then
    raise exception 'bil_social_post_authors_v2_already_exists';
  end if;
end;
$migration_preflight$;

-- The underlying profile, handle, friendship, block, and suspension records are
-- intentionally RPC-only. This narrowly scoped reader binds every result to the
-- authenticated caller and reuses the canonical Social v2 visibility predicate.
create function public.bil_social_post_authors_v2(p_user_ids uuid[])
returns table (
  user_id uuid,
  handle text,
  relationship text,
  can_request boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
begin
  if v_actor is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;

  if not public.bil_can_use_community() then
    raise exception 'community_unavailable' using errcode = '42501';
  end if;

  if coalesce(cardinality(p_user_ids), 0) > 100 then
    raise exception 'too_many_members' using errcode = '22023';
  end if;

  return query
  with requested as (
    select
      input.member_id,
      min(input.position)::bigint as first_position
    from unnest(coalesce(p_user_ids, array[]::uuid[]))
      with ordinality as input(member_id, position)
    where input.member_id is not null
    group by input.member_id
  )
  select
    requested.member_id as user_id,
    social_handle.handle,
    case
      when requested.member_id = v_actor then 'self'
      when friendship.status = 'accepted' then 'accepted'
      when friendship.status = 'pending' and friendship.requester_id = v_actor
        then 'pending'
      when friendship.status = 'pending' and friendship.addressee_id = v_actor
        then 'incoming'
      else 'none'
    end::text as relationship,
    (
      requested.member_id <> v_actor
      and friendship.id is null
      and profile.discoverable
      and profile.allow_friend_requests
      and profile.profile_visibility <> 'private'
    ) as can_request
  from requested
  join public.bil_public_profiles as profile
    on profile.user_id = requested.member_id
  left join public.bil_social_handles_v2 as social_handle
    on social_handle.user_id = requested.member_id
  left join lateral (
    select
      candidate.id,
      candidate.requester_id,
      candidate.addressee_id,
      candidate.status
    from public.bil_friendships as candidate
    where least(candidate.requester_id::text, candidate.addressee_id::text)
          = least(v_actor::text, requested.member_id::text)
      and greatest(candidate.requester_id::text, candidate.addressee_id::text)
          = greatest(v_actor::text, requested.member_id::text)
    limit 1
  ) as friendship on true
  where public.bil_social_profile_visible_v2(requested.member_id)
  order by requested.first_position;
end;
$function$;

revoke all on function public.bil_social_post_authors_v2(uuid[])
  from public, anon, authenticated, service_role;
grant execute on function public.bil_social_post_authors_v2(uuid[])
  to authenticated;

comment on function public.bil_social_post_authors_v2(uuid[]) is
  'Returns caller-scoped, visibility-filtered Social v2 author handles and relationship state for at most 100 users.';

do $migration_postconditions$
declare
  v_signature regprocedure :=
    to_regprocedure('public.bil_social_post_authors_v2(uuid[])');
begin
  if v_signature is null then
    raise exception 'bil_social_post_authors_v2_missing';
  end if;

  if pg_catalog.has_function_privilege('anon', v_signature, 'EXECUTE')
     or pg_catalog.has_function_privilege(
       'service_role', v_signature, 'EXECUTE'
     )
     or exists (
       select 1
       from pg_catalog.pg_proc as procedure
       cross join lateral pg_catalog.aclexplode(
         coalesce(
           procedure.proacl,
           pg_catalog.acldefault('f', procedure.proowner)
         )
       ) as privilege
       where procedure.oid = v_signature::oid
         and privilege.grantee = 0
         and privilege.privilege_type = 'EXECUTE'
     ) then
    raise exception 'bil_social_post_authors_v2_excess_execute_privilege';
  end if;

  if not pg_catalog.has_function_privilege(
    'authenticated', v_signature, 'EXECUTE'
  ) then
    raise exception 'bil_social_post_authors_v2_authenticated_execute_missing';
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_proc as procedure
    cross join lateral pg_catalog.unnest(procedure.proconfig)
      as configuration(setting)
    where procedure.oid = v_signature::oid
      and procedure.prosecdef
      and configuration.setting in ('search_path=', 'search_path=""')
  ) then
    raise exception 'bil_social_post_authors_v2_security_contract_invalid';
  end if;
end;
$migration_postconditions$;

commit;
