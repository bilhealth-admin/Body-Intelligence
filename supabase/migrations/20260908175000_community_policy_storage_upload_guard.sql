-- Close the direct Storage upload path for Community post images.
--
-- The application preflights policy acceptance before sending bytes and the
-- post INSERT repeats that assertion. Storage is nevertheless a public API of
-- its own, so a modified client must not be able to create an image object
-- without accepting the currently effective Community policy. Keep the
-- existing owner/path/suspension policy intact and add a restrictive policy so
-- every permissive INSERT path is subject to the policy-receipt assertion.
begin;

do $community_policy_storage_guard_preflight$
declare
  v_permissive boolean;
  v_roles oid[];
  v_check text;
begin
  if pg_catalog.to_regclass('storage.objects') is null
     or pg_catalog.to_regprocedure(
       'public.bil_assert_community_publish_ready()'
     ) is null then
    raise exception 'community_policy_storage_guard_precondition_failed'
      using errcode = '55000',
            detail = 'Storage objects or the policy assertion RPC is missing.';
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_policy policy
    join pg_catalog.pg_class relation on relation.oid = policy.polrelid
    join pg_catalog.pg_namespace namespace
      on namespace.oid = relation.relnamespace
    where namespace.nspname = 'storage'
      and relation.relname = 'objects'
      and policy.polname = 'community_post_image_insert_own'
      and policy.polcmd = 'a'
  ) then
    raise exception 'community_policy_storage_guard_precondition_failed'
      using errcode = '55000',
            detail = 'The reviewed Community image owner policy is missing.';
  end if;

  select
    policy.polpermissive,
    policy.polroles,
    pg_catalog.pg_get_expr(policy.polwithcheck, policy.polrelid)
  into v_permissive, v_roles, v_check
  from pg_catalog.pg_policy policy
  join pg_catalog.pg_class relation on relation.oid = policy.polrelid
  join pg_catalog.pg_namespace namespace
    on namespace.oid = relation.relnamespace
  where namespace.nspname = 'storage'
    and relation.relname = 'objects'
    and policy.polname = 'community_post_image_insert_own';

  if v_permissive is not true
     or v_roles <> array[
       (select role.oid from pg_catalog.pg_roles role
        where role.rolname = 'authenticated')
     ]::oid[]
     or pg_catalog.strpos(
       case when v_check is null then '' else v_check end,
       'bil_can_use_community'
     ) = 0
     or pg_catalog.strpos(
       case when v_check is null then '' else v_check end,
       'owner_id'
     ) = 0
     or pg_catalog.strpos(
       case when v_check is null then '' else v_check end,
       'foldername'
     ) = 0 then
    raise exception 'community_policy_storage_guard_precondition_failed'
      using errcode = '55000',
            detail = 'The existing Community image owner policy has drifted.';
  end if;

  if not pg_catalog.has_function_privilege(
       'authenticated',
       'public.bil_assert_community_publish_ready()',
       'EXECUTE'
     ) then
    raise exception 'community_policy_storage_guard_precondition_failed'
      using errcode = '55000',
            detail = 'Authenticated callers cannot execute the policy assertion.';
  end if;
end
$community_policy_storage_guard_preflight$;

drop policy if exists community_post_image_policy_acceptance_guard
on storage.objects;
create policy community_post_image_policy_acceptance_guard
on storage.objects
as restrictive
for insert
to authenticated
with check (
  case
    when bucket_id = 'community-post-images'
      then public.bil_assert_community_publish_ready() is not null
    else true
  end
);

do $community_policy_storage_guard_postconditions$
declare
  v_policy_count bigint;
  v_permissive boolean;
  v_command text;
  v_roles oid[];
  v_check text;
begin
  select pg_catalog.count(*)
  into v_policy_count
  from pg_catalog.pg_policy policy
  join pg_catalog.pg_class relation on relation.oid = policy.polrelid
  join pg_catalog.pg_namespace namespace
    on namespace.oid = relation.relnamespace
  where namespace.nspname = 'storage'
    and relation.relname = 'objects'
    and policy.polname = 'community_post_image_policy_acceptance_guard';

  if v_policy_count <> 1 then
    raise exception 'community_policy_storage_guard_postcondition_failed'
      using errcode = '55000',
            detail = 'The restrictive Storage policy count is not one.';
  end if;

  select
    policy.polpermissive,
    policy.polcmd::text,
    policy.polroles,
    pg_catalog.pg_get_expr(policy.polwithcheck, policy.polrelid)
  into v_permissive, v_command, v_roles, v_check
  from pg_catalog.pg_policy policy
  join pg_catalog.pg_class relation on relation.oid = policy.polrelid
  join pg_catalog.pg_namespace namespace
    on namespace.oid = relation.relnamespace
  where namespace.nspname = 'storage'
    and relation.relname = 'objects'
    and policy.polname = 'community_post_image_policy_acceptance_guard';

  if v_permissive is not false
     or v_command <> 'a'
     or v_roles <> array[
       (select role.oid from pg_catalog.pg_roles role
        where role.rolname = 'authenticated')
     ]::oid[]
     or pg_catalog.strpos(
       case when v_check is null then '' else v_check end,
       'community-post-images'
     ) = 0
     or pg_catalog.strpos(
       case when v_check is null then '' else v_check end,
       'bil_assert_community_publish_ready'
     ) = 0 then
    raise exception 'community_policy_storage_guard_postcondition_failed'
      using errcode = '55000',
            detail = 'The restrictive Storage policy is not the reviewed definition.';
  end if;
end
$community_policy_storage_guard_postconditions$;

commit;
