set local lock_timeout='5s';
set local statement_timeout='30s';

do $preflight$
begin
  if to_regclass('public.bil_public_profiles') is null
     or to_regprocedure('public.bil_social_profile_visible_v2(uuid)') is null then
    raise exception 'community_profile_cover_dependencies_missing';
  end if;
  if exists(
    select 1 from information_schema.columns
    where table_schema='public'
      and table_name='bil_public_profiles'
      and column_name='cover_object_path'
  )
  or to_regprocedure(
    'public.bil_set_my_community_profile_cover_v1(text)'
  ) is not null
  or to_regprocedure(
    'public.bil_community_profile_cover_v1(uuid)'
  ) is not null then
    raise exception 'community_profile_cover_v1_already_exists';
  end if;
end
$preflight$;

alter table public.bil_public_profiles
  add column cover_object_path text;

alter table public.bil_public_profiles
  add constraint bil_public_profiles_cover_object_path_check check(
    cover_object_path is null or (
      cover_object_path like user_id::text||'/community-cover/%'
      and cover_object_path ~
        '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/community-cover/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpg|png|webp)$'
    )
  );

create or replace function public.bil_set_my_community_profile_cover_v1(
  p_object_path text
)
returns text
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_path text:=nullif(btrim(coalesce(p_object_path,'')),'');
  v_previous text;
  v_rows integer;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;

  if v_path is not null and (
    v_path not like v_uid::text||'/community-cover/%'
    or v_path !~
      '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/community-cover/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpg|png|webp)$'
    or not exists(
      select 1
      from storage.objects o
      where o.bucket_id='profile-avatars'
        and o.name=v_path
        and o.owner_id=v_uid::text
    )
  ) then
    raise exception 'invalid_community_profile_cover'
      using errcode='22023';
  end if;

  select p.cover_object_path into v_previous
  from public.bil_public_profiles p
  where p.user_id=v_uid
  for update;

  if not found then
    raise exception 'community_profile_not_found' using errcode='P0002';
  end if;

  update public.bil_public_profiles
  set cover_object_path=v_path,
      updated_at=pg_catalog.clock_timestamp()
  where user_id=v_uid;
  get diagnostics v_rows=row_count;

  if v_rows<>1 then
    raise exception 'community_profile_cover_write_failed';
  end if;

  return v_previous;
end
$$;

create or replace function public.bil_community_profile_cover_v1(
  p_user_id uuid
)
returns text
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_path text;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_user_id is null then
    raise exception 'invalid_profile_user' using errcode='22023';
  end if;

  if p_user_id<>v_uid
     and not public.bil_social_profile_visible_v2(p_user_id) then
    raise exception 'community_profile_unavailable' using errcode='42501';
  end if;

  select p.cover_object_path into v_path
  from public.bil_public_profiles p
  where p.user_id=p_user_id;

  if not found then
    raise exception 'community_profile_not_found' using errcode='P0002';
  end if;

  return v_path;
end
$$;

revoke all on function public.bil_set_my_community_profile_cover_v1(text)
  from public,anon,service_role;
grant execute on function public.bil_set_my_community_profile_cover_v1(text)
  to authenticated;

revoke all on function public.bil_community_profile_cover_v1(uuid)
  from public,anon,service_role;
grant execute on function public.bil_community_profile_cover_v1(uuid)
  to authenticated;

do $postconditions$
begin
  if to_regprocedure(
      'public.bil_set_my_community_profile_cover_v1(text)'
    ) is null
     or to_regprocedure(
       'public.bil_community_profile_cover_v1(uuid)'
     ) is null then
    raise exception 'community_profile_cover_postcondition_failed';
  end if;
end
$postconditions$;
