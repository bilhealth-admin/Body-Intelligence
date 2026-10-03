set local lock_timeout='5s';
set local statement_timeout='30s';

do $$
begin
  if to_regclass('public.bil_community_posts') is null
     or to_regclass('public.bil_community_post_media_v1') is null
     or to_regprocedure('public.bil_social_post_visible_v2(uuid)') is null
     or to_regprocedure('private.bil_resolve_community_moderation_authority(uuid)') is null then
    raise exception 'community_location_dependencies_missing';
  end if;
  if to_regclass('public.bil_community_post_locations_v1') is not null then
    raise exception 'community_location_v1_already_exists';
  end if;
end
$$;

create table public.bil_community_post_locations_v1 (
  post_id uuid primary key references public.bil_community_posts(id) on delete cascade,
  label text not null
    check (
      char_length(label) between 2 and 80
      and label=btrim(label)
      and label !~ '[[:cntrl:]]'
    ),
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp()
);

alter table public.bil_community_post_locations_v1 enable row level security;
revoke all on table public.bil_community_post_locations_v1
  from public,anon,authenticated,service_role;

create or replace function public.bil_set_my_community_post_location_v1(
  p_post_id uuid,
  p_label text
)
returns text
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_label text;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;

  perform public.bil_assert_community_publish_ready();

  if p_post_id is null then
    raise exception 'invalid_community_location' using errcode='22023';
  end if;

  if not exists(
    select 1
    from public.bil_community_posts p
    where p.id=p_post_id
      and p.author_id=v_uid
      and p.deleted_at is null
      and p.moderation_status='pending'
  ) then
    raise exception 'community_location_post_not_editable' using errcode='42501';
  end if;

  v_label:=nullif(btrim(coalesce(p_label,'')),'');
  if v_label is null then
    delete from public.bil_community_post_locations_v1
    where post_id=p_post_id;
    return null;
  end if;

  if char_length(v_label) not between 2 and 80
     or v_label ~ '[[:cntrl:]]' then
    raise exception 'invalid_community_location' using errcode='22023';
  end if;

  insert into public.bil_community_post_locations_v1(
    post_id,label
  )
  values(p_post_id,v_label)
  on conflict(post_id) do update
  set label=excluded.label,
      updated_at=pg_catalog.clock_timestamp();

  return v_label;
end
$$;

create or replace function public.bil_community_post_locations_v1(
  p_post_ids uuid[]
)
returns table(
  post_id uuid,
  location_label text
)
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_moderator boolean:=false;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_post_ids is null
     or cardinality(p_post_ids)<1
     or cardinality(p_post_ids)>100
     or cardinality(p_post_ids)<>(
       select count(distinct value) from unnest(p_post_ids) value
     ) then
    raise exception 'invalid_community_location_batch' using errcode='22023';
  end if;

  v_moderator:=
    private.bil_resolve_community_moderation_authority(v_uid) is not null;

  return query
  select l.post_id,l.label
  from public.bil_community_post_locations_v1 l
  join public.bil_community_posts p on p.id=l.post_id
  where l.post_id=any(p_post_ids)
    and p.deleted_at is null
    and (
      p.author_id=v_uid
      or v_moderator
      or public.bil_social_post_visible_v2(p.id)
    )
  order by l.post_id;
end
$$;

create or replace function public.bil_delete_community_post(p_post_id uuid)
returns boolean
language plpgsql
security definer
set search_path='public','pg_catalog'
as $$
declare
  v_rows integer;
begin
  if auth.uid() is null then
    raise exception 'community_authentication_required' using errcode='42501';
  end if;

  update public.bil_community_posts
  set deleted_at = pg_catalog.now(),
      media_url = null,
      media_object_path = null,
      media_mime_type = null,
      media_bytes = null,
      media_width = null,
      media_height = null
  where id = p_post_id
    and author_id = auth.uid()
    and deleted_at is null;

  get diagnostics v_rows = row_count;

  if v_rows>0 then
    delete from public.bil_community_post_media_v1
    where post_id=p_post_id;
    delete from public.bil_community_post_locations_v1
    where post_id=p_post_id;
  end if;

  return v_rows > 0;
end
$$;

revoke all on function public.bil_set_my_community_post_location_v1(uuid,text)
  from public,anon,service_role;
grant execute on function public.bil_set_my_community_post_location_v1(uuid,text)
  to authenticated;

revoke all on function public.bil_community_post_locations_v1(uuid[])
  from public,anon,service_role;
grant execute on function public.bil_community_post_locations_v1(uuid[])
  to authenticated;

do $$
begin
  if to_regprocedure(
       'public.bil_set_my_community_post_location_v1(uuid,text)'
     ) is null
     or to_regprocedure(
       'public.bil_community_post_locations_v1(uuid[])'
     ) is null then
    raise exception 'community_location_v1_postcondition_failed';
  end if;
end
$$;
