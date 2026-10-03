set local lock_timeout='5s';
set local statement_timeout='30s';

do $$
begin
  if to_regclass('public.bil_community_posts') is null
     or to_regprocedure('public.bil_social_post_visible_v2(uuid)') is null
     or to_regprocedure('private.bil_resolve_community_moderation_authority(uuid)') is null then
    raise exception 'community_multi_image_dependencies_missing';
  end if;
  if to_regclass('public.bil_community_post_media_v1') is not null then
    raise exception 'community_multi_image_v1_already_exists';
  end if;
end
$$;

create table public.bil_community_post_media_v1 (
  post_id uuid not null references public.bil_community_posts(id) on delete cascade,
  position smallint not null check (position between 0 and 3),
  object_path text not null unique,
  mime_type text not null
    check (mime_type in ('image/jpeg','image/png','image/webp')),
  bytes integer not null check (bytes between 1 and 5242880),
  width integer not null check (width between 1 and 8192),
  height integer not null check (height between 1 and 8192),
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  primary key(post_id,position),
  check ((width::bigint * height::bigint) <= 40000000)
);

create index bil_community_post_media_post_created_idx
  on public.bil_community_post_media_v1(post_id,created_at,position);

alter table public.bil_community_post_media_v1 enable row level security;
revoke all on table public.bil_community_post_media_v1
  from public,anon,authenticated,service_role;

insert into public.bil_community_post_media_v1(
  post_id,position,object_path,mime_type,bytes,width,height,created_at
)
select
  p.id,0,p.media_object_path,p.media_mime_type,
  p.media_bytes,p.media_width,p.media_height,p.created_at
from public.bil_community_posts p
where p.media_object_path is not null
  and p.media_mime_type is not null
  and p.media_bytes is not null
  and p.media_width is not null
  and p.media_height is not null
on conflict do nothing;

create or replace function public.bil_set_my_community_post_media_v1(
  p_post_id uuid,
  p_items jsonb
)
returns integer
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_count integer;
  v_first jsonb;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;

  perform public.bil_assert_community_publish_ready();

  if p_post_id is null
     or p_items is null
     or pg_catalog.jsonb_typeof(p_items)<>'array'
     or pg_catalog.jsonb_array_length(p_items)<1
     or pg_catalog.jsonb_array_length(p_items)>4 then
    raise exception 'invalid_community_post_media' using errcode='22023';
  end if;

  if not exists(
    select 1
    from public.bil_community_posts p
    where p.id=p_post_id
      and p.author_id=v_uid
      and p.deleted_at is null
      and p.moderation_status='pending'
  ) then
    raise exception 'community_post_media_not_editable' using errcode='42501';
  end if;

  if exists(
    select 1
    from pg_catalog.jsonb_array_elements(p_items) with ordinality e(item,ord)
    where pg_catalog.jsonb_typeof(e.item)<>'object'
       or not (e.item ?& array['object_path','mime_type','bytes','width','height'])
       or pg_catalog.jsonb_typeof(e.item->'object_path')<>'string'
       or pg_catalog.jsonb_typeof(e.item->'mime_type')<>'string'
       or pg_catalog.jsonb_typeof(e.item->'bytes')<>'number'
       or pg_catalog.jsonb_typeof(e.item->'width')<>'number'
       or pg_catalog.jsonb_typeof(e.item->'height')<>'number'
       or (e.item->>'object_path') not like
          (v_uid::text||'/'||p_post_id::text||'/%')
       or (e.item->>'object_path') !~
          '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpg|png|webp)$'
       or (e.item->>'mime_type') not in ('image/jpeg','image/png','image/webp')
       or ((e.item->>'bytes')::bigint not between 1 and 5242880)
       or ((e.item->>'width')::bigint not between 1 and 8192)
       or ((e.item->>'height')::bigint not between 1 and 8192)
       or (
         (e.item->>'width')::bigint * (e.item->>'height')::bigint
       ) > 40000000
       or (
         (e.item->>'mime_type')='image/jpeg'
         and right(e.item->>'object_path',4)<>'.jpg'
       )
       or (
         (e.item->>'mime_type')='image/png'
         and right(e.item->>'object_path',4)<>'.png'
       )
       or (
         (e.item->>'mime_type')='image/webp'
         and right(e.item->>'object_path',5)<>'.webp'
       )
  ) then
    raise exception 'invalid_community_post_media_item' using errcode='22023';
  end if;

  if (
    select count(distinct e.item->>'object_path')
    from pg_catalog.jsonb_array_elements(p_items) e(item)
  ) <> pg_catalog.jsonb_array_length(p_items) then
    raise exception 'duplicate_community_post_media_path' using errcode='22023';
  end if;

  delete from public.bil_community_post_media_v1
  where post_id=p_post_id;

  insert into public.bil_community_post_media_v1(
    post_id,position,object_path,mime_type,bytes,width,height
  )
  select
    p_post_id,
    (e.ord-1)::smallint,
    e.item->>'object_path',
    e.item->>'mime_type',
    (e.item->>'bytes')::integer,
    (e.item->>'width')::integer,
    (e.item->>'height')::integer
  from pg_catalog.jsonb_array_elements(p_items) with ordinality e(item,ord)
  order by e.ord;

  v_first:=p_items->0;

  update public.bil_community_posts
  set media_url=null,
      media_object_path=v_first->>'object_path',
      media_mime_type=v_first->>'mime_type',
      media_bytes=(v_first->>'bytes')::integer,
      media_width=(v_first->>'width')::integer,
      media_height=(v_first->>'height')::integer
  where id=p_post_id and author_id=v_uid;

  get diagnostics v_count=row_count;
  if v_count<>1 then
    raise exception 'community_post_media_write_failed';
  end if;

  return pg_catalog.jsonb_array_length(p_items);
end
$$;

create or replace function public.bil_community_post_media_v1(
  p_post_ids uuid[]
)
returns table(
  post_id uuid,
  media_position integer,
  object_path text,
  mime_type text,
  bytes integer,
  width integer,
  height integer
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
    raise exception 'invalid_community_post_media_batch' using errcode='22023';
  end if;

  v_moderator:=
    private.bil_resolve_community_moderation_authority(v_uid) is not null;

  return query
  select
    m.post_id,m.position::integer,m.object_path,m.mime_type,
    m.bytes,m.width,m.height
  from public.bil_community_post_media_v1 m
  join public.bil_community_posts p on p.id=m.post_id
  where m.post_id=any(p_post_ids)
    and p.deleted_at is null
    and (
      p.author_id=v_uid
      or v_moderator
      or public.bil_social_post_visible_v2(p.id)
    )
  order by m.post_id,m.position;
end
$$;

create or replace function public.bil_my_community_post_media_paths_v1(
  p_post_id uuid
)
returns text[]
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_paths text[];
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_post_id is null or not exists(
    select 1
    from public.bil_community_posts p
    where p.id=p_post_id and p.author_id=v_uid
  ) then
    raise exception 'community_post_not_owned' using errcode='42501';
  end if;

  select coalesce(
    pg_catalog.array_agg(m.object_path order by m.position),
    array[]::text[]
  )
  into v_paths
  from public.bil_community_post_media_v1 m
  where m.post_id=p_post_id;

  return v_paths;
end
$$;

create or replace function public.bil_can_read_community_post_image_v2(
  p_object_path text
)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select (select auth.uid()) is not null
    and exists(
      select 1
      from public.bil_community_post_media_v1 m
      join public.bil_community_posts p on p.id=m.post_id
      where m.object_path=p_object_path
        and p.deleted_at is null
        and (
          p.author_id=(select auth.uid())
          or public.bil_social_post_visible_v2(p.id)
          or private.bil_resolve_community_moderation_authority(
               (select auth.uid())
             ) is not null
        )
    );
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
  end if;

  return v_rows > 0;
end
$$;

revoke all on function public.bil_set_my_community_post_media_v1(uuid,jsonb)
  from public,anon,service_role;
grant execute on function public.bil_set_my_community_post_media_v1(uuid,jsonb)
  to authenticated;

revoke all on function public.bil_community_post_media_v1(uuid[])
  from public,anon,service_role;
grant execute on function public.bil_community_post_media_v1(uuid[])
  to authenticated;

revoke all on function public.bil_my_community_post_media_paths_v1(uuid)
  from public,anon,service_role;
grant execute on function public.bil_my_community_post_media_paths_v1(uuid)
  to authenticated;

revoke all on function public.bil_can_read_community_post_image_v2(text)
  from public,anon,service_role;
grant execute on function public.bil_can_read_community_post_image_v2(text)
  to authenticated;

drop policy if exists community_post_image_read_visible on storage.objects;
create policy community_post_image_read_visible
on storage.objects
for select
to authenticated
using (
  bucket_id='community-post-images'
  and storage.allow_any_operation(array[
    'storage.object.sign',
    'storage.object.sign_many',
    'storage.object.get_authenticated',
    'object.get_authenticated_info',
    'storage.render.image_authenticated'
  ])
  and (
    owner_id=(select auth.uid())::text
    or public.bil_can_read_community_post_image_v2(name)
  )
);

do $$
begin
  if to_regprocedure(
      'public.bil_set_my_community_post_media_v1(uuid,jsonb)'
    ) is null
     or to_regprocedure(
       'public.bil_community_post_media_v1(uuid[])'
     ) is null
     or to_regprocedure(
       'public.bil_my_community_post_media_paths_v1(uuid)'
     ) is null
     or to_regprocedure(
       'public.bil_can_read_community_post_image_v2(text)'
     ) is null then
    raise exception 'community_multi_image_v1_postcondition_failed';
  end if;
end
$$;
