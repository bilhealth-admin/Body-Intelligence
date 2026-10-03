set local lock_timeout='5s';
set local statement_timeout='30s';

do $preflight$
begin
  if to_regclass('public.bil_community_posts') is null
     or to_regclass('public.bil_public_profiles') is null
     or to_regclass('public.bil_social_handles_v2') is null
     or to_regprocedure('public.bil_assert_community_publish_ready()') is null
     or to_regprocedure('public.bil_social_post_visible_v2(uuid)') is null
     or to_regprocedure('public.bil_social_member_visible_v2(uuid)') is null
     or to_regprocedure(
       'private.bil_resolve_community_moderation_authority(uuid)'
     ) is null then
    raise exception 'community_reference_composer_dependencies_missing';
  end if;
  if exists(
    select 1 from information_schema.columns
    where table_schema='public'
      and table_name='bil_community_posts'
      and column_name='title'
  )
  or to_regclass('public.bil_community_post_hashtags_v1') is not null
  or to_regclass('public.bil_community_post_collaborators_v1') is not null
  or to_regclass('public.bil_community_post_drafts_v1') is not null
  or to_regclass('public.bil_community_post_draft_media_v1') is not null then
    raise exception 'community_reference_composer_v1_already_exists';
  end if;
end
$preflight$;

alter table public.bil_community_posts
  add column title text;

alter table public.bil_community_posts
  add constraint bil_community_posts_title_check check(
    title is null or (
      char_length(title) between 1 and 120
      and title !~ '[[:cntrl:]]'
      and title=btrim(title)
    )
  );

create table public.bil_community_post_hashtags_v1(
  post_id uuid not null
    references public.bil_community_posts(id) on delete cascade,
  hashtag text not null,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  primary key(post_id,hashtag),
  check (
    char_length(hashtag) between 1 and 40
    and hashtag !~ '[#[:space:][:cntrl:]]'
    and hashtag=lower(hashtag)
  )
);
create index bil_community_post_hashtags_tag_idx
  on public.bil_community_post_hashtags_v1(hashtag,created_at desc,post_id);
alter table public.bil_community_post_hashtags_v1 enable row level security;
revoke all on table public.bil_community_post_hashtags_v1
  from public,anon,authenticated,service_role;

create table public.bil_community_post_collaborators_v1(
  post_id uuid not null
    references public.bil_community_posts(id) on delete cascade,
  collaborator_id uuid not null
    references auth.users(id) on delete cascade,
  status text not null default 'pending'
    check(status in('pending','accepted','declined')),
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  responded_at timestamptz,
  primary key(post_id,collaborator_id),
  check(
    (status='pending' and responded_at is null)
    or (status in('accepted','declined') and responded_at is not null)
  )
);
create index bil_community_post_collaborators_member_idx
  on public.bil_community_post_collaborators_v1(
    collaborator_id,status,created_at desc,post_id
  );
alter table public.bil_community_post_collaborators_v1 enable row level security;
revoke all on table public.bil_community_post_collaborators_v1
  from public,anon,authenticated,service_role;

create or replace function public.bil_set_my_community_post_reference_metadata_v1(
  p_post_id uuid,
  p_title text default null,
  p_hashtags text[] default array[]::text[],
  p_collaborator_user_ids uuid[] default array[]::uuid[]
)
returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_title text:=nullif(btrim(coalesce(p_title,'')),'');
  v_hashtags text[];
  v_collaborators uuid[]:=coalesce(
    p_collaborator_user_ids,array[]::uuid[]
  );
  v_hashtag_count integer;
  v_collaborator_count integer:=cardinality(
    coalesce(p_collaborator_user_ids,array[]::uuid[])
  );
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  perform public.bil_assert_community_publish_ready();

  if p_post_id is null
     or (v_title is not null and (
       char_length(v_title) not between 1 and 120
       or v_title ~ '[[:cntrl:]]'
     )) then
    raise exception 'invalid_community_post_reference_metadata'
      using errcode='22023';
  end if;

  if not exists(
    select 1 from public.bil_community_posts p
    where p.id=p_post_id
      and p.author_id=v_uid
      and p.deleted_at is null
      and p.moderation_status='pending'
      and p.visibility='community'
  ) then
    raise exception 'community_post_reference_metadata_not_editable'
      using errcode='42501';
  end if;

  select coalesce(
    pg_catalog.array_agg(
      lower(ltrim(btrim(value),'#')) order by ord
    ),
    array[]::text[]
  )
  into v_hashtags
  from unnest(coalesce(p_hashtags,array[]::text[]))
    with ordinality item(value,ord);

  v_hashtag_count:=cardinality(v_hashtags);
  if v_hashtag_count>10
     or exists(
       select 1 from unnest(v_hashtags) value
       where value is null
          or char_length(value) not between 1 and 40
          or value ~ '[#[:space:][:cntrl:]]'
     )
     or v_hashtag_count<>(
       select count(distinct value) from unnest(v_hashtags) value
     ) then
    raise exception 'invalid_community_post_hashtags'
      using errcode='22023';
  end if;

  if v_collaborator_count>3
     or v_uid=any(v_collaborators)
     or exists(
       select 1 from unnest(v_collaborators) value where value is null
     )
     or v_collaborator_count<>(
       select count(distinct value) from unnest(v_collaborators) value
     ) then
    raise exception 'invalid_community_post_collaborators'
      using errcode='22023';
  end if;

  if v_collaborator_count>0 and (
    select count(*)::integer
    from public.bil_public_profiles p
    join public.bil_social_handles_v2 h
      on h.user_id=p.user_id and h.chosen
    where p.user_id=any(v_collaborators)
      and p.discoverable
      and p.profile_visibility<>'private'
      and public.bil_social_member_visible_v2(p.user_id)
  )<>v_collaborator_count then
    raise exception 'community_collaborator_unavailable'
      using errcode='42501';
  end if;

  update public.bil_community_posts
  set title=v_title
  where id=p_post_id and author_id=v_uid;

  delete from public.bil_community_post_hashtags_v1
  where post_id=p_post_id;
  insert into public.bil_community_post_hashtags_v1(post_id,hashtag)
  select p_post_id,value from unnest(v_hashtags) value;

  delete from public.bil_community_post_collaborators_v1
  where post_id=p_post_id;
  insert into public.bil_community_post_collaborators_v1(
    post_id,collaborator_id
  )
  select p_post_id,value from unnest(v_collaborators) value;

  return pg_catalog.jsonb_build_object(
    'post_id',p_post_id,
    'title',v_title,
    'hashtag_count',v_hashtag_count,
    'collaborator_count',v_collaborator_count
  );
end
$$;

create or replace function public.bil_community_post_reference_metadata_v1(
  p_post_ids uuid[]
)
returns table(
  post_id uuid,
  title text,
  hashtags text[],
  topics jsonb,
  circle jsonb,
  collaborators jsonb
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
    raise exception 'invalid_community_post_reference_batch'
      using errcode='22023';
  end if;

  v_moderator:=
    private.bil_resolve_community_moderation_authority(v_uid) is not null;

  return query
  select
    p.id,
    p.title,
    coalesce(
      (
        select pg_catalog.array_agg(h.hashtag order by h.hashtag)
        from public.bil_community_post_hashtags_v1 h
        where h.post_id=p.id
      ),
      array[]::text[]
    ),
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'slug',t.slug,
            'title_copy_key',t.title_copy_key,
            'post_count',(
              select count(*)::integer
              from public.bil_community_post_topics pt_all
              join public.bil_community_posts p_all
                on p_all.id=pt_all.post_id
              where pt_all.topic_id=t.id
                and p_all.deleted_at is null
                and p_all.moderation_status='approved'
                and p_all.moderation_visibility='visible'
                and public.bil_social_post_visible_v2(p_all.id)
            )
          )
          order by pt.created_at,t.slug
        )
        from public.bil_community_post_topics pt
        join public.bil_community_topics t on t.id=pt.topic_id
        where pt.post_id=p.id and t.active
      ),
      '[]'::jsonb
    ),
    (
      select pg_catalog.jsonb_build_object(
        'slug',cir.slug,
        'title_copy_key',cir.title_copy_key,
        'post_count',(
          select count(*)::integer
          from public.bil_community_post_circles pc_all
          join public.bil_community_posts p_all
            on p_all.id=pc_all.post_id
          where pc_all.circle_id=cir.id
            and p_all.deleted_at is null
            and p_all.moderation_status='approved'
            and p_all.moderation_visibility='visible'
            and public.bil_social_post_visible_v2(p_all.id)
        ),
        'member_count',(
          select count(*)::integer
          from public.bil_community_circle_memberships cm
          where cm.circle_id=cir.id and cm.status='active'
        )
      )
      from public.bil_community_post_circles pc
      join public.bil_community_circles cir on cir.id=pc.circle_id
      where pc.post_id=p.id and cir.active
      order by pc.created_at desc
      limit 1
    ),
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'user_id',coll.collaborator_id,
            'handle',sh.handle,
            'display_name',pp.display_name,
            'avatar_url',pp.avatar_url,
            'status',coll.status
          )
          order by coll.created_at,coll.collaborator_id
        )
        from public.bil_community_post_collaborators_v1 coll
        join public.bil_public_profiles pp
          on pp.user_id=coll.collaborator_id
        left join public.bil_social_handles_v2 sh
          on sh.user_id=coll.collaborator_id and sh.chosen
        where coll.post_id=p.id
          and (
            coll.status='accepted'
            or p.author_id=v_uid
            or coll.collaborator_id=v_uid
            or v_moderator
          )
      ),
      '[]'::jsonb
    )
  from public.bil_community_posts p
  where p.id=any(p_post_ids)
    and p.deleted_at is null
    and (
      p.author_id=v_uid
      or v_moderator
      or public.bil_social_post_visible_v2(p.id)
    )
  order by p.id;
end
$$;

create table public.bil_community_post_drafts_v1(
  draft_id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text,
  body text not null default '',
  topic_slugs text[] not null default array[]::text[],
  circle_slug text,
  location_label text,
  mentioned_user_ids uuid[] not null default array[]::uuid[],
  collaborator_user_ids uuid[] not null default array[]::uuid[],
  hashtags text[] not null default array[]::text[],
  poll_question text,
  poll_options text[] not null default array[]::text[],
  poll_allow_multiple boolean not null default false,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  check (
    title is null or (
      char_length(title) between 1 and 120
      and title=btrim(title)
      and title !~ '[[:cntrl:]]'
    )
  ),
  check (char_length(body)<=1200 and body !~ '[[:cntrl:]]'),
  check (
    location_label is null or (
      char_length(location_label) between 2 and 80
      and location_label !~ '[[:cntrl:]]'
    )
  ),
  check(cardinality(topic_slugs)<=3),
  check(cardinality(mentioned_user_ids)<=10),
  check(cardinality(collaborator_user_ids)<=3),
  check(cardinality(hashtags)<=10),
  check(cardinality(poll_options)<=6)
);
create index bil_community_post_drafts_owner_history_idx
  on public.bil_community_post_drafts_v1(
    owner_id,updated_at desc,draft_id desc
  );
alter table public.bil_community_post_drafts_v1 enable row level security;
revoke all on table public.bil_community_post_drafts_v1
  from public,anon,authenticated,service_role;

create table public.bil_community_post_draft_media_v1(
  draft_id uuid not null
    references public.bil_community_post_drafts_v1(draft_id)
    on delete cascade,
  position smallint not null check(position between 0 and 3),
  object_path text not null unique,
  mime_type text not null
    check(mime_type in('image/jpeg','image/png','image/webp')),
  bytes integer not null check(bytes between 1 and 5242880),
  width integer not null check(width between 1 and 8192),
  height integer not null check(height between 1 and 8192),
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  primary key(draft_id,position),
  check((width::bigint*height::bigint)<=40000000)
);
alter table public.bil_community_post_draft_media_v1 enable row level security;
revoke all on table public.bil_community_post_draft_media_v1
  from public,anon,authenticated,service_role;

create or replace function public.bil_upsert_my_community_post_draft_v1(
  p_draft_id uuid,
  p_title text default null,
  p_body text default '',
  p_topic_slugs text[] default array[]::text[],
  p_circle_slug text default null,
  p_location_label text default null,
  p_mentioned_user_ids uuid[] default array[]::uuid[],
  p_collaborator_user_ids uuid[] default array[]::uuid[],
  p_hashtags text[] default array[]::text[],
  p_poll_question text default null,
  p_poll_options text[] default array[]::text[],
  p_poll_allow_multiple boolean default false
)
returns uuid
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_title text:=nullif(btrim(coalesce(p_title,'')),'');
  v_body text:=btrim(coalesce(p_body,''));
  v_topics text[]:=coalesce(p_topic_slugs,array[]::text[]);
  v_circle text:=nullif(btrim(coalesce(p_circle_slug,'')),'');
  v_location text:=nullif(btrim(coalesce(p_location_label,'')),'');
  v_mentions uuid[]:=coalesce(p_mentioned_user_ids,array[]::uuid[]);
  v_collabs uuid[]:=coalesce(p_collaborator_user_ids,array[]::uuid[]);
  v_hashtags text[];
  v_poll_question text:=nullif(btrim(coalesce(p_poll_question,'')),'');
  v_poll_options text[]:=coalesce(p_poll_options,array[]::text[]);
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  perform public.bil_assert_community_publish_ready();

  if p_draft_id is null
     or char_length(v_body)>1200
     or v_body ~ '[[:cntrl:]]'
     or (v_title is not null and (
       char_length(v_title) not between 1 and 120
       or v_title ~ '[[:cntrl:]]'
     ))
     or (v_location is not null and (
       char_length(v_location) not between 2 and 80
       or v_location ~ '[[:cntrl:]]'
     )) then
    raise exception 'invalid_community_draft_text'
      using errcode='22023';
  end if;

  if cardinality(v_topics)>3
     or cardinality(v_topics)<>(
       select count(distinct value) from unnest(v_topics) value
     )
     or exists(
       select 1 from unnest(v_topics) value
       where value is null
          or char_length(value)>48
          or value !~ '^[a-z0-9]+(-[a-z0-9]+)*
     ) then
    raise exception 'invalid_community_draft_topics'
      using errcode='22023';
  end if;

  if v_circle is not null
     and (
       char_length(v_circle)>48
       or v_circle !~ '^[a-z0-9]+(-[a-z0-9]+)*
    raise exception 'invalid_community_draft_circle'
      using errcode='22023';
  end if;

  if cardinality(v_mentions)>10
     or cardinality(v_mentions)<>(
       select count(distinct value) from unnest(v_mentions) value
     )
     or v_uid=any(v_mentions)
     or exists(select 1 from unnest(v_mentions) value where value is null) then
    raise exception 'invalid_community_draft_mentions'
      using errcode='22023';
  end if;

  if cardinality(v_mentions)>0 and (
    select count(*)::integer
    from public.bil_public_profiles p
    join public.bil_social_handles_v2 h
      on h.user_id=p.user_id and h.chosen
    where p.user_id=any(v_mentions)
      and p.discoverable
      and p.profile_visibility<>'private'
      and public.bil_social_member_visible_v2(p.user_id)
  )<>cardinality(v_mentions) then
    raise exception 'community_draft_mention_unavailable'
      using errcode='42501';
  end if;

  if cardinality(v_collabs)>3
     or cardinality(v_collabs)<>(
       select count(distinct value) from unnest(v_collabs) value
     )
     or v_uid=any(v_collabs)
     or exists(select 1 from unnest(v_collabs) value where value is null) then
    raise exception 'invalid_community_draft_collaborators'
      using errcode='22023';
  end if;

  if cardinality(v_collabs)>0 and (
    select count(*)::integer
    from public.bil_public_profiles p
    join public.bil_social_handles_v2 h
      on h.user_id=p.user_id and h.chosen
    where p.user_id=any(v_collabs)
      and p.discoverable
      and p.profile_visibility<>'private'
      and public.bil_social_member_visible_v2(p.user_id)
  )<>cardinality(v_collabs) then
    raise exception 'community_draft_collaborator_unavailable'
      using errcode='42501';
  end if;

  select coalesce(
    pg_catalog.array_agg(lower(ltrim(btrim(value),'#')) order by ord),
    array[]::text[]
  )
  into v_hashtags
  from unnest(coalesce(p_hashtags,array[]::text[]))
    with ordinality item(value,ord);

  if cardinality(v_hashtags)>10
     or cardinality(v_hashtags)<>(
       select count(distinct value) from unnest(v_hashtags) value
     )
     or exists(
       select 1 from unnest(v_hashtags) value
       where value is null
          or char_length(value) not between 1 and 40
          or value ~ '[#[:space:][:cntrl:]]'
     ) then
    raise exception 'invalid_community_draft_hashtags'
      using errcode='22023';
  end if;

  select coalesce(
    pg_catalog.array_agg(btrim(value) order by ord),
    array[]::text[]
  )
  into v_poll_options
  from unnest(v_poll_options) with ordinality item(value,ord);

  if (v_poll_question is null and cardinality(v_poll_options)<>0)
     or (v_poll_question is not null and (
       char_length(v_poll_question) not between 1 and 200
       or v_poll_question ~ '[[:cntrl:]]'
       or cardinality(v_poll_options) not between 2 and 6
       or cardinality(v_poll_options)<>(
         select count(distinct lower(value)) from unnest(v_poll_options) value
       )
       or exists(
         select 1 from unnest(v_poll_options) value
         where char_length(value) not between 1 and 120
            or value ~ '[[:cntrl:]]'
       )
     )) then
    raise exception 'invalid_community_draft_poll'
      using errcode='22023';
  end if;

  insert into public.bil_community_post_drafts_v1(
    draft_id,owner_id,title,body,topic_slugs,circle_slug,location_label,
    mentioned_user_ids,collaborator_user_ids,hashtags,
    poll_question,poll_options,poll_allow_multiple
  ) values(
    p_draft_id,v_uid,v_title,v_body,v_topics,v_circle,v_location,
    v_mentions,v_collabs,v_hashtags,
    v_poll_question,v_poll_options,coalesce(p_poll_allow_multiple,false)
  )
  on conflict(draft_id) do update
  set title=excluded.title,
      body=excluded.body,
      topic_slugs=excluded.topic_slugs,
      circle_slug=excluded.circle_slug,
      location_label=excluded.location_label,
      mentioned_user_ids=excluded.mentioned_user_ids,
      collaborator_user_ids=excluded.collaborator_user_ids,
      hashtags=excluded.hashtags,
      poll_question=excluded.poll_question,
      poll_options=excluded.poll_options,
      poll_allow_multiple=excluded.poll_allow_multiple,
      updated_at=pg_catalog.clock_timestamp()
  where bil_community_post_drafts_v1.owner_id=v_uid;

  if not found then
    raise exception 'community_draft_not_owned' using errcode='42501';
  end if;

  return p_draft_id;
end
$$;

create or replace function public.bil_set_my_community_post_draft_media_v1(
  p_draft_id uuid,
  p_items jsonb
)
returns text[]
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_stale text[];
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_draft_id is null
     or p_items is null
     or pg_catalog.jsonb_typeof(p_items)<>'array'
     or pg_catalog.jsonb_array_length(p_items)>4 then
    raise exception 'invalid_community_draft_media' using errcode='22023';
  end if;
  if not exists(
    select 1 from public.bil_community_post_drafts_v1 d
    where d.draft_id=p_draft_id and d.owner_id=v_uid
  ) then
    raise exception 'community_draft_not_owned' using errcode='42501';
  end if;

  if exists(
    select 1
    from pg_catalog.jsonb_array_elements(p_items)
      with ordinality e(item,ord)
    where pg_catalog.jsonb_typeof(e.item)<>'object'
       or not (e.item ?& array[
         'object_path','mime_type','bytes','width','height'
       ])
       or pg_catalog.jsonb_typeof(e.item->'object_path')<>'string'
       or pg_catalog.jsonb_typeof(e.item->'mime_type')<>'string'
       or pg_catalog.jsonb_typeof(e.item->'bytes')<>'number'
       or pg_catalog.jsonb_typeof(e.item->'width')<>'number'
       or pg_catalog.jsonb_typeof(e.item->'height')<>'number'
       or (e.item->>'object_path') not like
          (v_uid::text||'/'||p_draft_id::text||'/%')
       or (e.item->>'object_path') !~
          '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpg|png|webp)$'
       or (e.item->>'mime_type') not in(
         'image/jpeg','image/png','image/webp'
       )
       or ((e.item->>'bytes')::bigint not between 1 and 5242880)
       or ((e.item->>'width')::bigint not between 1 and 8192)
       or ((e.item->>'height')::bigint not between 1 and 8192)
       or (
         (e.item->>'width')::bigint*(e.item->>'height')::bigint
       )>40000000
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
       or not exists(
         select 1 from storage.objects o
         where o.bucket_id='community-post-images'
           and o.name=e.item->>'object_path'
           and o.owner_id=v_uid::text
       )
  ) then
    raise exception 'invalid_community_draft_media_item'
      using errcode='22023';
  end if;

  if (
    select count(distinct e.item->>'object_path')
    from pg_catalog.jsonb_array_elements(p_items) e(item)
  )<>pg_catalog.jsonb_array_length(p_items) then
    raise exception 'duplicate_community_draft_media_path'
      using errcode='22023';
  end if;

  select coalesce(
    pg_catalog.array_agg(m.object_path order by m.position),
    array[]::text[]
  )
  into v_stale
  from public.bil_community_post_draft_media_v1 m
  where m.draft_id=p_draft_id
    and not exists(
      select 1
      from pg_catalog.jsonb_array_elements(p_items) e(item)
      where e.item->>'object_path'=m.object_path
    );

  delete from public.bil_community_post_draft_media_v1
  where draft_id=p_draft_id;

  insert into public.bil_community_post_draft_media_v1(
    draft_id,position,object_path,mime_type,bytes,width,height
  )
  select
    p_draft_id,(e.ord-1)::smallint,
    e.item->>'object_path',
    e.item->>'mime_type',
    (e.item->>'bytes')::integer,
    (e.item->>'width')::integer,
    (e.item->>'height')::integer
  from pg_catalog.jsonb_array_elements(p_items)
    with ordinality e(item,ord)
  order by e.ord;

  update public.bil_community_post_drafts_v1
  set updated_at=pg_catalog.clock_timestamp()
  where draft_id=p_draft_id and owner_id=v_uid;

  return v_stale;
end
$$;

create or replace function public.bil_list_my_community_post_drafts_v1(
  p_before timestamptz default null,
  p_before_id uuid default null,
  p_limit integer default 20
)
returns table(
  draft_id uuid,
  title text,
  body text,
  updated_at timestamptz,
  media_count integer
)
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if (p_before is null)<>(p_before_id is null)
     or p_limit is null or p_limit<1 or p_limit>50 then
    raise exception 'invalid_community_draft_cursor' using errcode='22023';
  end if;
  return query
  select
    d.draft_id,d.title,d.body,d.updated_at,
    (
      select count(*)::integer
      from public.bil_community_post_draft_media_v1 m
      where m.draft_id=d.draft_id
    )
  from public.bil_community_post_drafts_v1 d
  where d.owner_id=v_uid
    and (
      p_before is null
      or (d.updated_at,d.draft_id)<(p_before,p_before_id)
    )
  order by d.updated_at desc,d.draft_id desc
  limit p_limit;
end
$$;

create or replace function public.bil_get_my_community_post_draft_v1(
  p_draft_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_draft public.bil_community_post_drafts_v1%rowtype;
  v_media jsonb;
  v_mentions jsonb;
  v_collaborators jsonb;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  select * into v_draft
  from public.bil_community_post_drafts_v1 d
  where d.draft_id=p_draft_id and d.owner_id=v_uid;
  if not found then
    raise exception 'community_draft_not_found' using errcode='P0002';
  end if;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'user_id',p.user_id,
        'handle',h.handle,
        'display_name',p.display_name,
        'avatar_url',p.avatar_url
      )
      order by x.ord
    ),
    '[]'::jsonb
  )
  into v_mentions
  from unnest(v_draft.mentioned_user_ids)
    with ordinality x(user_id,ord)
  join public.bil_public_profiles p on p.user_id=x.user_id
  join public.bil_social_handles_v2 h
    on h.user_id=x.user_id and h.chosen;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'user_id',p.user_id,
        'handle',h.handle,
        'display_name',p.display_name,
        'avatar_url',p.avatar_url
      )
      order by x.ord
    ),
    '[]'::jsonb
  )
  into v_collaborators
  from unnest(v_draft.collaborator_user_ids)
    with ordinality x(user_id,ord)
  join public.bil_public_profiles p on p.user_id=x.user_id
  join public.bil_social_handles_v2 h
    on h.user_id=x.user_id and h.chosen;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'position',m.position,
        'object_path',m.object_path,
        'mime_type',m.mime_type,
        'bytes',m.bytes,
        'width',m.width,
        'height',m.height
      )
      order by m.position
    ),
    '[]'::jsonb
  )
  into v_media
  from public.bil_community_post_draft_media_v1 m
  where m.draft_id=p_draft_id;

  return pg_catalog.jsonb_build_object(
    'draft_id',v_draft.draft_id,
    'title',v_draft.title,
    'body',v_draft.body,
    'topic_slugs',v_draft.topic_slugs,
    'circle_slug',v_draft.circle_slug,
    'location_label',v_draft.location_label,
    'mentions',v_mentions,
    'collaborators',v_collaborators,
    'hashtags',v_draft.hashtags,
    'poll_question',v_draft.poll_question,
    'poll_options',v_draft.poll_options,
    'poll_allow_multiple',v_draft.poll_allow_multiple,
    'created_at',v_draft.created_at,
    'updated_at',v_draft.updated_at,
    'media',v_media
  );
end
$$;

create or replace function public.bil_delete_my_community_post_draft_v1(
  p_draft_id uuid
)
returns text[]
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_paths text[];
  v_rows integer;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_draft_id is null then
    raise exception 'invalid_community_draft_id' using errcode='22023';
  end if;

  select coalesce(
    pg_catalog.array_agg(m.object_path order by m.position),
    array[]::text[]
  )
  into v_paths
  from public.bil_community_post_draft_media_v1 m
  join public.bil_community_post_drafts_v1 d
    on d.draft_id=m.draft_id
  where d.draft_id=p_draft_id and d.owner_id=v_uid;

  delete from public.bil_community_post_drafts_v1 d
  where d.draft_id=p_draft_id and d.owner_id=v_uid;
  get diagnostics v_rows=row_count;
  if v_rows<>1 then
    raise exception 'community_draft_not_found' using errcode='P0002';
  end if;
  return v_paths;
end
$$;

revoke all on function public.bil_set_my_community_post_reference_metadata_v1(
  uuid,text,text[],uuid[]
) from public,anon,service_role;
grant execute on function public.bil_set_my_community_post_reference_metadata_v1(
  uuid,text,text[],uuid[]
) to authenticated;

revoke all on function public.bil_community_post_reference_metadata_v1(uuid[])
  from public,anon,service_role;
grant execute on function public.bil_community_post_reference_metadata_v1(uuid[])
  to authenticated;

revoke all on function public.bil_upsert_my_community_post_draft_v1(
  uuid,text,text,text[],text,text,uuid[],uuid[],text[],text,text[],boolean
) from public,anon,service_role;
grant execute on function public.bil_upsert_my_community_post_draft_v1(
  uuid,text,text,text[],text,text,uuid[],uuid[],text[],text,text[],boolean
) to authenticated;

revoke all on function public.bil_set_my_community_post_draft_media_v1(uuid,jsonb)
  from public,anon,service_role;
grant execute on function public.bil_set_my_community_post_draft_media_v1(uuid,jsonb)
  to authenticated;

revoke all on function public.bil_list_my_community_post_drafts_v1(
  timestamptz,uuid,integer
) from public,anon,service_role;
grant execute on function public.bil_list_my_community_post_drafts_v1(
  timestamptz,uuid,integer
) to authenticated;

revoke all on function public.bil_get_my_community_post_draft_v1(uuid)
  from public,anon,service_role;
grant execute on function public.bil_get_my_community_post_draft_v1(uuid)
  to authenticated;

revoke all on function public.bil_delete_my_community_post_draft_v1(uuid)
  from public,anon,service_role;
grant execute on function public.bil_delete_my_community_post_draft_v1(uuid)
  to authenticated;

do $postconditions$
begin
  if to_regprocedure(
      'public.bil_set_my_community_post_reference_metadata_v1(uuid,text,text[],uuid[])'
    ) is null
    or to_regprocedure(
      'public.bil_community_post_reference_metadata_v1(uuid[])'
    ) is null
    or to_regprocedure(
      'public.bil_upsert_my_community_post_draft_v1(uuid,text,text,text[],text,text,uuid[],uuid[],text[],text,text[],boolean)'
    ) is null
    or to_regprocedure(
      'public.bil_set_my_community_post_draft_media_v1(uuid,jsonb)'
    ) is null
    or to_regprocedure(
      'public.bil_list_my_community_post_drafts_v1(timestamptz,uuid,integer)'
    ) is null
    or to_regprocedure(
      'public.bil_get_my_community_post_draft_v1(uuid)'
    ) is null
    or to_regprocedure(
      'public.bil_delete_my_community_post_draft_v1(uuid)'
    ) is null then
    raise exception 'community_reference_composer_postcondition_failed';
  end if;
end
$postconditions$;

     ) then
    raise exception 'invalid_community_draft_topics'
      using errcode='22023';
  end if;

  if v_circle is not null
     and v_circle !~ '^[a-z][a-z0-9_]{2,47}$' then
    raise exception 'invalid_community_draft_circle'
      using errcode='22023';
  end if;

  if cardinality(v_mentions)>10
     or cardinality(v_mentions)<>(
       select count(distinct value) from unnest(v_mentions) value
     )
     or v_uid=any(v_mentions)
     or exists(select 1 from unnest(v_mentions) value where value is null) then
    raise exception 'invalid_community_draft_mentions'
      using errcode='22023';
  end if;

  if cardinality(v_mentions)>0 and (
    select count(*)::integer
    from public.bil_public_profiles p
    join public.bil_social_handles_v2 h
      on h.user_id=p.user_id and h.chosen
    where p.user_id=any(v_mentions)
      and p.discoverable
      and p.profile_visibility<>'private'
      and public.bil_social_member_visible_v2(p.user_id)
  )<>cardinality(v_mentions) then
    raise exception 'community_draft_mention_unavailable'
      using errcode='42501';
  end if;

  if cardinality(v_collabs)>3
     or cardinality(v_collabs)<>(
       select count(distinct value) from unnest(v_collabs) value
     )
     or v_uid=any(v_collabs)
     or exists(select 1 from unnest(v_collabs) value where value is null) then
    raise exception 'invalid_community_draft_collaborators'
      using errcode='22023';
  end if;

  if cardinality(v_collabs)>0 and (
    select count(*)::integer
    from public.bil_public_profiles p
    join public.bil_social_handles_v2 h
      on h.user_id=p.user_id and h.chosen
    where p.user_id=any(v_collabs)
      and p.discoverable
      and p.profile_visibility<>'private'
      and public.bil_social_member_visible_v2(p.user_id)
  )<>cardinality(v_collabs) then
    raise exception 'community_draft_collaborator_unavailable'
      using errcode='42501';
  end if;

  select coalesce(
    pg_catalog.array_agg(lower(ltrim(btrim(value),'#')) order by ord),
    array[]::text[]
  )
  into v_hashtags
  from unnest(coalesce(p_hashtags,array[]::text[]))
    with ordinality item(value,ord);

  if cardinality(v_hashtags)>10
     or cardinality(v_hashtags)<>(
       select count(distinct value) from unnest(v_hashtags) value
     )
     or exists(
       select 1 from unnest(v_hashtags) value
       where value is null
          or char_length(value) not between 1 and 40
          or value ~ '[#[:space:][:cntrl:]]'
     ) then
    raise exception 'invalid_community_draft_hashtags'
      using errcode='22023';
  end if;

  select coalesce(
    pg_catalog.array_agg(btrim(value) order by ord),
    array[]::text[]
  )
  into v_poll_options
  from unnest(v_poll_options) with ordinality item(value,ord);

  if (v_poll_question is null and cardinality(v_poll_options)<>0)
     or (v_poll_question is not null and (
       char_length(v_poll_question) not between 1 and 200
       or v_poll_question ~ '[[:cntrl:]]'
       or cardinality(v_poll_options) not between 2 and 6
       or cardinality(v_poll_options)<>(
         select count(distinct lower(value)) from unnest(v_poll_options) value
       )
       or exists(
         select 1 from unnest(v_poll_options) value
         where char_length(value) not between 1 and 120
            or value ~ '[[:cntrl:]]'
       )
     )) then
    raise exception 'invalid_community_draft_poll'
      using errcode='22023';
  end if;

  insert into public.bil_community_post_drafts_v1(
    draft_id,owner_id,title,body,topic_slugs,circle_slug,location_label,
    mentioned_user_ids,collaborator_user_ids,hashtags,
    poll_question,poll_options,poll_allow_multiple
  ) values(
    p_draft_id,v_uid,v_title,v_body,v_topics,v_circle,v_location,
    v_mentions,v_collabs,v_hashtags,
    v_poll_question,v_poll_options,coalesce(p_poll_allow_multiple,false)
  )
  on conflict(draft_id) do update
  set title=excluded.title,
      body=excluded.body,
      topic_slugs=excluded.topic_slugs,
      circle_slug=excluded.circle_slug,
      location_label=excluded.location_label,
      mentioned_user_ids=excluded.mentioned_user_ids,
      collaborator_user_ids=excluded.collaborator_user_ids,
      hashtags=excluded.hashtags,
      poll_question=excluded.poll_question,
      poll_options=excluded.poll_options,
      poll_allow_multiple=excluded.poll_allow_multiple,
      updated_at=pg_catalog.clock_timestamp()
  where bil_community_post_drafts_v1.owner_id=v_uid;

  if not found then
    raise exception 'community_draft_not_owned' using errcode='42501';
  end if;

  return p_draft_id;
end
$$;

create or replace function public.bil_set_my_community_post_draft_media_v1(
  p_draft_id uuid,
  p_items jsonb
)
returns text[]
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_stale text[];
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_draft_id is null
     or p_items is null
     or pg_catalog.jsonb_typeof(p_items)<>'array'
     or pg_catalog.jsonb_array_length(p_items)>4 then
    raise exception 'invalid_community_draft_media' using errcode='22023';
  end if;
  if not exists(
    select 1 from public.bil_community_post_drafts_v1 d
    where d.draft_id=p_draft_id and d.owner_id=v_uid
  ) then
    raise exception 'community_draft_not_owned' using errcode='42501';
  end if;

  if exists(
    select 1
    from pg_catalog.jsonb_array_elements(p_items)
      with ordinality e(item,ord)
    where pg_catalog.jsonb_typeof(e.item)<>'object'
       or not (e.item ?& array[
         'object_path','mime_type','bytes','width','height'
       ])
       or pg_catalog.jsonb_typeof(e.item->'object_path')<>'string'
       or pg_catalog.jsonb_typeof(e.item->'mime_type')<>'string'
       or pg_catalog.jsonb_typeof(e.item->'bytes')<>'number'
       or pg_catalog.jsonb_typeof(e.item->'width')<>'number'
       or pg_catalog.jsonb_typeof(e.item->'height')<>'number'
       or (e.item->>'object_path') not like
          (v_uid::text||'/'||p_draft_id::text||'/%')
       or (e.item->>'object_path') !~
          '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpg|png|webp)$'
       or (e.item->>'mime_type') not in(
         'image/jpeg','image/png','image/webp'
       )
       or ((e.item->>'bytes')::bigint not between 1 and 5242880)
       or ((e.item->>'width')::bigint not between 1 and 8192)
       or ((e.item->>'height')::bigint not between 1 and 8192)
       or (
         (e.item->>'width')::bigint*(e.item->>'height')::bigint
       )>40000000
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
       or not exists(
         select 1 from storage.objects o
         where o.bucket_id='community-post-images'
           and o.name=e.item->>'object_path'
           and o.owner_id=v_uid::text
       )
  ) then
    raise exception 'invalid_community_draft_media_item'
      using errcode='22023';
  end if;

  if (
    select count(distinct e.item->>'object_path')
    from pg_catalog.jsonb_array_elements(p_items) e(item)
  )<>pg_catalog.jsonb_array_length(p_items) then
    raise exception 'duplicate_community_draft_media_path'
      using errcode='22023';
  end if;

  select coalesce(
    pg_catalog.array_agg(m.object_path order by m.position),
    array[]::text[]
  )
  into v_stale
  from public.bil_community_post_draft_media_v1 m
  where m.draft_id=p_draft_id
    and not exists(
      select 1
      from pg_catalog.jsonb_array_elements(p_items) e(item)
      where e.item->>'object_path'=m.object_path
    );

  delete from public.bil_community_post_draft_media_v1
  where draft_id=p_draft_id;

  insert into public.bil_community_post_draft_media_v1(
    draft_id,position,object_path,mime_type,bytes,width,height
  )
  select
    p_draft_id,(e.ord-1)::smallint,
    e.item->>'object_path',
    e.item->>'mime_type',
    (e.item->>'bytes')::integer,
    (e.item->>'width')::integer,
    (e.item->>'height')::integer
  from pg_catalog.jsonb_array_elements(p_items)
    with ordinality e(item,ord)
  order by e.ord;

  update public.bil_community_post_drafts_v1
  set updated_at=pg_catalog.clock_timestamp()
  where draft_id=p_draft_id and owner_id=v_uid;

  return v_stale;
end
$$;

create or replace function public.bil_list_my_community_post_drafts_v1(
  p_before timestamptz default null,
  p_before_id uuid default null,
  p_limit integer default 20
)
returns table(
  draft_id uuid,
  title text,
  body text,
  updated_at timestamptz,
  media_count integer
)
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if (p_before is null)<>(p_before_id is null)
     or p_limit is null or p_limit<1 or p_limit>50 then
    raise exception 'invalid_community_draft_cursor' using errcode='22023';
  end if;
  return query
  select
    d.draft_id,d.title,d.body,d.updated_at,
    (
      select count(*)::integer
      from public.bil_community_post_draft_media_v1 m
      where m.draft_id=d.draft_id
    )
  from public.bil_community_post_drafts_v1 d
  where d.owner_id=v_uid
    and (
      p_before is null
      or (d.updated_at,d.draft_id)<(p_before,p_before_id)
    )
  order by d.updated_at desc,d.draft_id desc
  limit p_limit;
end
$$;

create or replace function public.bil_get_my_community_post_draft_v1(
  p_draft_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_draft public.bil_community_post_drafts_v1%rowtype;
  v_media jsonb;
  v_mentions jsonb;
  v_collaborators jsonb;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  select * into v_draft
  from public.bil_community_post_drafts_v1 d
  where d.draft_id=p_draft_id and d.owner_id=v_uid;
  if not found then
    raise exception 'community_draft_not_found' using errcode='P0002';
  end if;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'user_id',p.user_id,
        'handle',h.handle,
        'display_name',p.display_name,
        'avatar_url',p.avatar_url
      )
      order by x.ord
    ),
    '[]'::jsonb
  )
  into v_mentions
  from unnest(v_draft.mentioned_user_ids)
    with ordinality x(user_id,ord)
  join public.bil_public_profiles p on p.user_id=x.user_id
  join public.bil_social_handles_v2 h
    on h.user_id=x.user_id and h.chosen;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'user_id',p.user_id,
        'handle',h.handle,
        'display_name',p.display_name,
        'avatar_url',p.avatar_url
      )
      order by x.ord
    ),
    '[]'::jsonb
  )
  into v_collaborators
  from unnest(v_draft.collaborator_user_ids)
    with ordinality x(user_id,ord)
  join public.bil_public_profiles p on p.user_id=x.user_id
  join public.bil_social_handles_v2 h
    on h.user_id=x.user_id and h.chosen;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'position',m.position,
        'object_path',m.object_path,
        'mime_type',m.mime_type,
        'bytes',m.bytes,
        'width',m.width,
        'height',m.height
      )
      order by m.position
    ),
    '[]'::jsonb
  )
  into v_media
  from public.bil_community_post_draft_media_v1 m
  where m.draft_id=p_draft_id;

  return pg_catalog.jsonb_build_object(
    'draft_id',v_draft.draft_id,
    'title',v_draft.title,
    'body',v_draft.body,
    'topic_slugs',v_draft.topic_slugs,
    'circle_slug',v_draft.circle_slug,
    'location_label',v_draft.location_label,
    'mentions',v_mentions,
    'collaborators',v_collaborators,
    'hashtags',v_draft.hashtags,
    'poll_question',v_draft.poll_question,
    'poll_options',v_draft.poll_options,
    'poll_allow_multiple',v_draft.poll_allow_multiple,
    'created_at',v_draft.created_at,
    'updated_at',v_draft.updated_at,
    'media',v_media
  );
end
$$;

create or replace function public.bil_delete_my_community_post_draft_v1(
  p_draft_id uuid
)
returns text[]
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_paths text[];
  v_rows integer;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_draft_id is null then
    raise exception 'invalid_community_draft_id' using errcode='22023';
  end if;

  select coalesce(
    pg_catalog.array_agg(m.object_path order by m.position),
    array[]::text[]
  )
  into v_paths
  from public.bil_community_post_draft_media_v1 m
  join public.bil_community_post_drafts_v1 d
    on d.draft_id=m.draft_id
  where d.draft_id=p_draft_id and d.owner_id=v_uid;

  delete from public.bil_community_post_drafts_v1 d
  where d.draft_id=p_draft_id and d.owner_id=v_uid;
  get diagnostics v_rows=row_count;
  if v_rows<>1 then
    raise exception 'community_draft_not_found' using errcode='P0002';
  end if;
  return v_paths;
end
$$;

revoke all on function public.bil_set_my_community_post_reference_metadata_v1(
  uuid,text,text[],uuid[]
) from public,anon,service_role;
grant execute on function public.bil_set_my_community_post_reference_metadata_v1(
  uuid,text,text[],uuid[]
) to authenticated;

revoke all on function public.bil_community_post_reference_metadata_v1(uuid[])
  from public,anon,service_role;
grant execute on function public.bil_community_post_reference_metadata_v1(uuid[])
  to authenticated;

revoke all on function public.bil_upsert_my_community_post_draft_v1(
  uuid,text,text,text[],text,text,uuid[],uuid[],text[],text,text[],boolean
) from public,anon,service_role;
grant execute on function public.bil_upsert_my_community_post_draft_v1(
  uuid,text,text,text[],text,text,uuid[],uuid[],text[],text,text[],boolean
) to authenticated;

revoke all on function public.bil_set_my_community_post_draft_media_v1(uuid,jsonb)
  from public,anon,service_role;
grant execute on function public.bil_set_my_community_post_draft_media_v1(uuid,jsonb)
  to authenticated;

revoke all on function public.bil_list_my_community_post_drafts_v1(
  timestamptz,uuid,integer
) from public,anon,service_role;
grant execute on function public.bil_list_my_community_post_drafts_v1(
  timestamptz,uuid,integer
) to authenticated;

revoke all on function public.bil_get_my_community_post_draft_v1(uuid)
  from public,anon,service_role;
grant execute on function public.bil_get_my_community_post_draft_v1(uuid)
  to authenticated;

revoke all on function public.bil_delete_my_community_post_draft_v1(uuid)
  from public,anon,service_role;
grant execute on function public.bil_delete_my_community_post_draft_v1(uuid)
  to authenticated;

do $postconditions$
begin
  if to_regprocedure(
      'public.bil_set_my_community_post_reference_metadata_v1(uuid,text,text[],uuid[])'
    ) is null
    or to_regprocedure(
      'public.bil_community_post_reference_metadata_v1(uuid[])'
    ) is null
    or to_regprocedure(
      'public.bil_upsert_my_community_post_draft_v1(uuid,text,text,text[],text,text,uuid[],uuid[],text[],text,text[],boolean)'
    ) is null
    or to_regprocedure(
      'public.bil_set_my_community_post_draft_media_v1(uuid,jsonb)'
    ) is null
    or to_regprocedure(
      'public.bil_list_my_community_post_drafts_v1(timestamptz,uuid,integer)'
    ) is null
    or to_regprocedure(
      'public.bil_get_my_community_post_draft_v1(uuid)'
    ) is null
    or to_regprocedure(
      'public.bil_delete_my_community_post_draft_v1(uuid)'
    ) is null then
    raise exception 'community_reference_composer_postcondition_failed';
  end if;
end
$postconditions$;

     ) then
    raise exception 'invalid_community_draft_circle'
      using errcode='22023';
  end if;

  if cardinality(v_mentions)>10
     or cardinality(v_mentions)<>(
       select count(distinct value) from unnest(v_mentions) value
     )
     or v_uid=any(v_mentions)
     or exists(select 1 from unnest(v_mentions) value where value is null) then
    raise exception 'invalid_community_draft_mentions'
      using errcode='22023';
  end if;

  if cardinality(v_mentions)>0 and (
    select count(*)::integer
    from public.bil_public_profiles p
    join public.bil_social_handles_v2 h
      on h.user_id=p.user_id and h.chosen
    where p.user_id=any(v_mentions)
      and p.discoverable
      and p.profile_visibility<>'private'
      and public.bil_social_member_visible_v2(p.user_id)
  )<>cardinality(v_mentions) then
    raise exception 'community_draft_mention_unavailable'
      using errcode='42501';
  end if;

  if cardinality(v_collabs)>3
     or cardinality(v_collabs)<>(
       select count(distinct value) from unnest(v_collabs) value
     )
     or v_uid=any(v_collabs)
     or exists(select 1 from unnest(v_collabs) value where value is null) then
    raise exception 'invalid_community_draft_collaborators'
      using errcode='22023';
  end if;

  if cardinality(v_collabs)>0 and (
    select count(*)::integer
    from public.bil_public_profiles p
    join public.bil_social_handles_v2 h
      on h.user_id=p.user_id and h.chosen
    where p.user_id=any(v_collabs)
      and p.discoverable
      and p.profile_visibility<>'private'
      and public.bil_social_member_visible_v2(p.user_id)
  )<>cardinality(v_collabs) then
    raise exception 'community_draft_collaborator_unavailable'
      using errcode='42501';
  end if;

  select coalesce(
    pg_catalog.array_agg(lower(ltrim(btrim(value),'#')) order by ord),
    array[]::text[]
  )
  into v_hashtags
  from unnest(coalesce(p_hashtags,array[]::text[]))
    with ordinality item(value,ord);

  if cardinality(v_hashtags)>10
     or cardinality(v_hashtags)<>(
       select count(distinct value) from unnest(v_hashtags) value
     )
     or exists(
       select 1 from unnest(v_hashtags) value
       where value is null
          or char_length(value) not between 1 and 40
          or value ~ '[#[:space:][:cntrl:]]'
     ) then
    raise exception 'invalid_community_draft_hashtags'
      using errcode='22023';
  end if;

  select coalesce(
    pg_catalog.array_agg(btrim(value) order by ord),
    array[]::text[]
  )
  into v_poll_options
  from unnest(v_poll_options) with ordinality item(value,ord);

  if (v_poll_question is null and cardinality(v_poll_options)<>0)
     or (v_poll_question is not null and (
       char_length(v_poll_question) not between 1 and 200
       or v_poll_question ~ '[[:cntrl:]]'
       or cardinality(v_poll_options) not between 2 and 6
       or cardinality(v_poll_options)<>(
         select count(distinct lower(value)) from unnest(v_poll_options) value
       )
       or exists(
         select 1 from unnest(v_poll_options) value
         where char_length(value) not between 1 and 120
            or value ~ '[[:cntrl:]]'
       )
     )) then
    raise exception 'invalid_community_draft_poll'
      using errcode='22023';
  end if;

  insert into public.bil_community_post_drafts_v1(
    draft_id,owner_id,title,body,topic_slugs,circle_slug,location_label,
    mentioned_user_ids,collaborator_user_ids,hashtags,
    poll_question,poll_options,poll_allow_multiple
  ) values(
    p_draft_id,v_uid,v_title,v_body,v_topics,v_circle,v_location,
    v_mentions,v_collabs,v_hashtags,
    v_poll_question,v_poll_options,coalesce(p_poll_allow_multiple,false)
  )
  on conflict(draft_id) do update
  set title=excluded.title,
      body=excluded.body,
      topic_slugs=excluded.topic_slugs,
      circle_slug=excluded.circle_slug,
      location_label=excluded.location_label,
      mentioned_user_ids=excluded.mentioned_user_ids,
      collaborator_user_ids=excluded.collaborator_user_ids,
      hashtags=excluded.hashtags,
      poll_question=excluded.poll_question,
      poll_options=excluded.poll_options,
      poll_allow_multiple=excluded.poll_allow_multiple,
      updated_at=pg_catalog.clock_timestamp()
  where bil_community_post_drafts_v1.owner_id=v_uid;

  if not found then
    raise exception 'community_draft_not_owned' using errcode='42501';
  end if;

  return p_draft_id;
end
$$;

create or replace function public.bil_set_my_community_post_draft_media_v1(
  p_draft_id uuid,
  p_items jsonb
)
returns text[]
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_stale text[];
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_draft_id is null
     or p_items is null
     or pg_catalog.jsonb_typeof(p_items)<>'array'
     or pg_catalog.jsonb_array_length(p_items)>4 then
    raise exception 'invalid_community_draft_media' using errcode='22023';
  end if;
  if not exists(
    select 1 from public.bil_community_post_drafts_v1 d
    where d.draft_id=p_draft_id and d.owner_id=v_uid
  ) then
    raise exception 'community_draft_not_owned' using errcode='42501';
  end if;

  if exists(
    select 1
    from pg_catalog.jsonb_array_elements(p_items)
      with ordinality e(item,ord)
    where pg_catalog.jsonb_typeof(e.item)<>'object'
       or not (e.item ?& array[
         'object_path','mime_type','bytes','width','height'
       ])
       or pg_catalog.jsonb_typeof(e.item->'object_path')<>'string'
       or pg_catalog.jsonb_typeof(e.item->'mime_type')<>'string'
       or pg_catalog.jsonb_typeof(e.item->'bytes')<>'number'
       or pg_catalog.jsonb_typeof(e.item->'width')<>'number'
       or pg_catalog.jsonb_typeof(e.item->'height')<>'number'
       or (e.item->>'object_path') not like
          (v_uid::text||'/'||p_draft_id::text||'/%')
       or (e.item->>'object_path') !~
          '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpg|png|webp)$'
       or (e.item->>'mime_type') not in(
         'image/jpeg','image/png','image/webp'
       )
       or ((e.item->>'bytes')::bigint not between 1 and 5242880)
       or ((e.item->>'width')::bigint not between 1 and 8192)
       or ((e.item->>'height')::bigint not between 1 and 8192)
       or (
         (e.item->>'width')::bigint*(e.item->>'height')::bigint
       )>40000000
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
       or not exists(
         select 1 from storage.objects o
         where o.bucket_id='community-post-images'
           and o.name=e.item->>'object_path'
           and o.owner_id=v_uid::text
       )
  ) then
    raise exception 'invalid_community_draft_media_item'
      using errcode='22023';
  end if;

  if (
    select count(distinct e.item->>'object_path')
    from pg_catalog.jsonb_array_elements(p_items) e(item)
  )<>pg_catalog.jsonb_array_length(p_items) then
    raise exception 'duplicate_community_draft_media_path'
      using errcode='22023';
  end if;

  select coalesce(
    pg_catalog.array_agg(m.object_path order by m.position),
    array[]::text[]
  )
  into v_stale
  from public.bil_community_post_draft_media_v1 m
  where m.draft_id=p_draft_id
    and not exists(
      select 1
      from pg_catalog.jsonb_array_elements(p_items) e(item)
      where e.item->>'object_path'=m.object_path
    );

  delete from public.bil_community_post_draft_media_v1
  where draft_id=p_draft_id;

  insert into public.bil_community_post_draft_media_v1(
    draft_id,position,object_path,mime_type,bytes,width,height
  )
  select
    p_draft_id,(e.ord-1)::smallint,
    e.item->>'object_path',
    e.item->>'mime_type',
    (e.item->>'bytes')::integer,
    (e.item->>'width')::integer,
    (e.item->>'height')::integer
  from pg_catalog.jsonb_array_elements(p_items)
    with ordinality e(item,ord)
  order by e.ord;

  update public.bil_community_post_drafts_v1
  set updated_at=pg_catalog.clock_timestamp()
  where draft_id=p_draft_id and owner_id=v_uid;

  return v_stale;
end
$$;

create or replace function public.bil_list_my_community_post_drafts_v1(
  p_before timestamptz default null,
  p_before_id uuid default null,
  p_limit integer default 20
)
returns table(
  draft_id uuid,
  title text,
  body text,
  updated_at timestamptz,
  media_count integer
)
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if (p_before is null)<>(p_before_id is null)
     or p_limit is null or p_limit<1 or p_limit>50 then
    raise exception 'invalid_community_draft_cursor' using errcode='22023';
  end if;
  return query
  select
    d.draft_id,d.title,d.body,d.updated_at,
    (
      select count(*)::integer
      from public.bil_community_post_draft_media_v1 m
      where m.draft_id=d.draft_id
    )
  from public.bil_community_post_drafts_v1 d
  where d.owner_id=v_uid
    and (
      p_before is null
      or (d.updated_at,d.draft_id)<(p_before,p_before_id)
    )
  order by d.updated_at desc,d.draft_id desc
  limit p_limit;
end
$$;

create or replace function public.bil_get_my_community_post_draft_v1(
  p_draft_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_draft public.bil_community_post_drafts_v1%rowtype;
  v_media jsonb;
  v_mentions jsonb;
  v_collaborators jsonb;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  select * into v_draft
  from public.bil_community_post_drafts_v1 d
  where d.draft_id=p_draft_id and d.owner_id=v_uid;
  if not found then
    raise exception 'community_draft_not_found' using errcode='P0002';
  end if;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'user_id',p.user_id,
        'handle',h.handle,
        'display_name',p.display_name,
        'avatar_url',p.avatar_url
      )
      order by x.ord
    ),
    '[]'::jsonb
  )
  into v_mentions
  from unnest(v_draft.mentioned_user_ids)
    with ordinality x(user_id,ord)
  join public.bil_public_profiles p on p.user_id=x.user_id
  join public.bil_social_handles_v2 h
    on h.user_id=x.user_id and h.chosen;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'user_id',p.user_id,
        'handle',h.handle,
        'display_name',p.display_name,
        'avatar_url',p.avatar_url
      )
      order by x.ord
    ),
    '[]'::jsonb
  )
  into v_collaborators
  from unnest(v_draft.collaborator_user_ids)
    with ordinality x(user_id,ord)
  join public.bil_public_profiles p on p.user_id=x.user_id
  join public.bil_social_handles_v2 h
    on h.user_id=x.user_id and h.chosen;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'position',m.position,
        'object_path',m.object_path,
        'mime_type',m.mime_type,
        'bytes',m.bytes,
        'width',m.width,
        'height',m.height
      )
      order by m.position
    ),
    '[]'::jsonb
  )
  into v_media
  from public.bil_community_post_draft_media_v1 m
  where m.draft_id=p_draft_id;

  return pg_catalog.jsonb_build_object(
    'draft_id',v_draft.draft_id,
    'title',v_draft.title,
    'body',v_draft.body,
    'topic_slugs',v_draft.topic_slugs,
    'circle_slug',v_draft.circle_slug,
    'location_label',v_draft.location_label,
    'mentions',v_mentions,
    'collaborators',v_collaborators,
    'hashtags',v_draft.hashtags,
    'poll_question',v_draft.poll_question,
    'poll_options',v_draft.poll_options,
    'poll_allow_multiple',v_draft.poll_allow_multiple,
    'created_at',v_draft.created_at,
    'updated_at',v_draft.updated_at,
    'media',v_media
  );
end
$$;

create or replace function public.bil_delete_my_community_post_draft_v1(
  p_draft_id uuid
)
returns text[]
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_paths text[];
  v_rows integer;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_draft_id is null then
    raise exception 'invalid_community_draft_id' using errcode='22023';
  end if;

  select coalesce(
    pg_catalog.array_agg(m.object_path order by m.position),
    array[]::text[]
  )
  into v_paths
  from public.bil_community_post_draft_media_v1 m
  join public.bil_community_post_drafts_v1 d
    on d.draft_id=m.draft_id
  where d.draft_id=p_draft_id and d.owner_id=v_uid;

  delete from public.bil_community_post_drafts_v1 d
  where d.draft_id=p_draft_id and d.owner_id=v_uid;
  get diagnostics v_rows=row_count;
  if v_rows<>1 then
    raise exception 'community_draft_not_found' using errcode='P0002';
  end if;
  return v_paths;
end
$$;

revoke all on function public.bil_set_my_community_post_reference_metadata_v1(
  uuid,text,text[],uuid[]
) from public,anon,service_role;
grant execute on function public.bil_set_my_community_post_reference_metadata_v1(
  uuid,text,text[],uuid[]
) to authenticated;

revoke all on function public.bil_community_post_reference_metadata_v1(uuid[])
  from public,anon,service_role;
grant execute on function public.bil_community_post_reference_metadata_v1(uuid[])
  to authenticated;

revoke all on function public.bil_upsert_my_community_post_draft_v1(
  uuid,text,text,text[],text,text,uuid[],uuid[],text[],text,text[],boolean
) from public,anon,service_role;
grant execute on function public.bil_upsert_my_community_post_draft_v1(
  uuid,text,text,text[],text,text,uuid[],uuid[],text[],text,text[],boolean
) to authenticated;

revoke all on function public.bil_set_my_community_post_draft_media_v1(uuid,jsonb)
  from public,anon,service_role;
grant execute on function public.bil_set_my_community_post_draft_media_v1(uuid,jsonb)
  to authenticated;

revoke all on function public.bil_list_my_community_post_drafts_v1(
  timestamptz,uuid,integer
) from public,anon,service_role;
grant execute on function public.bil_list_my_community_post_drafts_v1(
  timestamptz,uuid,integer
) to authenticated;

revoke all on function public.bil_get_my_community_post_draft_v1(uuid)
  from public,anon,service_role;
grant execute on function public.bil_get_my_community_post_draft_v1(uuid)
  to authenticated;

revoke all on function public.bil_delete_my_community_post_draft_v1(uuid)
  from public,anon,service_role;
grant execute on function public.bil_delete_my_community_post_draft_v1(uuid)
  to authenticated;

do $postconditions$
begin
  if to_regprocedure(
      'public.bil_set_my_community_post_reference_metadata_v1(uuid,text,text[],uuid[])'
    ) is null
    or to_regprocedure(
      'public.bil_community_post_reference_metadata_v1(uuid[])'
    ) is null
    or to_regprocedure(
      'public.bil_upsert_my_community_post_draft_v1(uuid,text,text,text[],text,text,uuid[],uuid[],text[],text,text[],boolean)'
    ) is null
    or to_regprocedure(
      'public.bil_set_my_community_post_draft_media_v1(uuid,jsonb)'
    ) is null
    or to_regprocedure(
      'public.bil_list_my_community_post_drafts_v1(timestamptz,uuid,integer)'
    ) is null
    or to_regprocedure(
      'public.bil_get_my_community_post_draft_v1(uuid)'
    ) is null
    or to_regprocedure(
      'public.bil_delete_my_community_post_draft_v1(uuid)'
    ) is null then
    raise exception 'community_reference_composer_postcondition_failed';
  end if;
end
$postconditions$;

     ) then
    raise exception 'invalid_community_draft_topics'
      using errcode='22023';
  end if;

  if v_circle is not null
     and v_circle !~ '^[a-z][a-z0-9_]{2,47}$' then
    raise exception 'invalid_community_draft_circle'
      using errcode='22023';
  end if;

  if cardinality(v_mentions)>10
     or cardinality(v_mentions)<>(
       select count(distinct value) from unnest(v_mentions) value
     )
     or v_uid=any(v_mentions)
     or exists(select 1 from unnest(v_mentions) value where value is null) then
    raise exception 'invalid_community_draft_mentions'
      using errcode='22023';
  end if;

  if cardinality(v_mentions)>0 and (
    select count(*)::integer
    from public.bil_public_profiles p
    join public.bil_social_handles_v2 h
      on h.user_id=p.user_id and h.chosen
    where p.user_id=any(v_mentions)
      and p.discoverable
      and p.profile_visibility<>'private'
      and public.bil_social_member_visible_v2(p.user_id)
  )<>cardinality(v_mentions) then
    raise exception 'community_draft_mention_unavailable'
      using errcode='42501';
  end if;

  if cardinality(v_collabs)>3
     or cardinality(v_collabs)<>(
       select count(distinct value) from unnest(v_collabs) value
     )
     or v_uid=any(v_collabs)
     or exists(select 1 from unnest(v_collabs) value where value is null) then
    raise exception 'invalid_community_draft_collaborators'
      using errcode='22023';
  end if;

  if cardinality(v_collabs)>0 and (
    select count(*)::integer
    from public.bil_public_profiles p
    join public.bil_social_handles_v2 h
      on h.user_id=p.user_id and h.chosen
    where p.user_id=any(v_collabs)
      and p.discoverable
      and p.profile_visibility<>'private'
      and public.bil_social_member_visible_v2(p.user_id)
  )<>cardinality(v_collabs) then
    raise exception 'community_draft_collaborator_unavailable'
      using errcode='42501';
  end if;

  select coalesce(
    pg_catalog.array_agg(lower(ltrim(btrim(value),'#')) order by ord),
    array[]::text[]
  )
  into v_hashtags
  from unnest(coalesce(p_hashtags,array[]::text[]))
    with ordinality item(value,ord);

  if cardinality(v_hashtags)>10
     or cardinality(v_hashtags)<>(
       select count(distinct value) from unnest(v_hashtags) value
     )
     or exists(
       select 1 from unnest(v_hashtags) value
       where value is null
          or char_length(value) not between 1 and 40
          or value ~ '[#[:space:][:cntrl:]]'
     ) then
    raise exception 'invalid_community_draft_hashtags'
      using errcode='22023';
  end if;

  select coalesce(
    pg_catalog.array_agg(btrim(value) order by ord),
    array[]::text[]
  )
  into v_poll_options
  from unnest(v_poll_options) with ordinality item(value,ord);

  if (v_poll_question is null and cardinality(v_poll_options)<>0)
     or (v_poll_question is not null and (
       char_length(v_poll_question) not between 1 and 200
       or v_poll_question ~ '[[:cntrl:]]'
       or cardinality(v_poll_options) not between 2 and 6
       or cardinality(v_poll_options)<>(
         select count(distinct lower(value)) from unnest(v_poll_options) value
       )
       or exists(
         select 1 from unnest(v_poll_options) value
         where char_length(value) not between 1 and 120
            or value ~ '[[:cntrl:]]'
       )
     )) then
    raise exception 'invalid_community_draft_poll'
      using errcode='22023';
  end if;

  insert into public.bil_community_post_drafts_v1(
    draft_id,owner_id,title,body,topic_slugs,circle_slug,location_label,
    mentioned_user_ids,collaborator_user_ids,hashtags,
    poll_question,poll_options,poll_allow_multiple
  ) values(
    p_draft_id,v_uid,v_title,v_body,v_topics,v_circle,v_location,
    v_mentions,v_collabs,v_hashtags,
    v_poll_question,v_poll_options,coalesce(p_poll_allow_multiple,false)
  )
  on conflict(draft_id) do update
  set title=excluded.title,
      body=excluded.body,
      topic_slugs=excluded.topic_slugs,
      circle_slug=excluded.circle_slug,
      location_label=excluded.location_label,
      mentioned_user_ids=excluded.mentioned_user_ids,
      collaborator_user_ids=excluded.collaborator_user_ids,
      hashtags=excluded.hashtags,
      poll_question=excluded.poll_question,
      poll_options=excluded.poll_options,
      poll_allow_multiple=excluded.poll_allow_multiple,
      updated_at=pg_catalog.clock_timestamp()
  where bil_community_post_drafts_v1.owner_id=v_uid;

  if not found then
    raise exception 'community_draft_not_owned' using errcode='42501';
  end if;

  return p_draft_id;
end
$$;

create or replace function public.bil_set_my_community_post_draft_media_v1(
  p_draft_id uuid,
  p_items jsonb
)
returns text[]
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_stale text[];
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_draft_id is null
     or p_items is null
     or pg_catalog.jsonb_typeof(p_items)<>'array'
     or pg_catalog.jsonb_array_length(p_items)>4 then
    raise exception 'invalid_community_draft_media' using errcode='22023';
  end if;
  if not exists(
    select 1 from public.bil_community_post_drafts_v1 d
    where d.draft_id=p_draft_id and d.owner_id=v_uid
  ) then
    raise exception 'community_draft_not_owned' using errcode='42501';
  end if;

  if exists(
    select 1
    from pg_catalog.jsonb_array_elements(p_items)
      with ordinality e(item,ord)
    where pg_catalog.jsonb_typeof(e.item)<>'object'
       or not (e.item ?& array[
         'object_path','mime_type','bytes','width','height'
       ])
       or pg_catalog.jsonb_typeof(e.item->'object_path')<>'string'
       or pg_catalog.jsonb_typeof(e.item->'mime_type')<>'string'
       or pg_catalog.jsonb_typeof(e.item->'bytes')<>'number'
       or pg_catalog.jsonb_typeof(e.item->'width')<>'number'
       or pg_catalog.jsonb_typeof(e.item->'height')<>'number'
       or (e.item->>'object_path') not like
          (v_uid::text||'/'||p_draft_id::text||'/%')
       or (e.item->>'object_path') !~
          '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpg|png|webp)$'
       or (e.item->>'mime_type') not in(
         'image/jpeg','image/png','image/webp'
       )
       or ((e.item->>'bytes')::bigint not between 1 and 5242880)
       or ((e.item->>'width')::bigint not between 1 and 8192)
       or ((e.item->>'height')::bigint not between 1 and 8192)
       or (
         (e.item->>'width')::bigint*(e.item->>'height')::bigint
       )>40000000
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
       or not exists(
         select 1 from storage.objects o
         where o.bucket_id='community-post-images'
           and o.name=e.item->>'object_path'
           and o.owner_id=v_uid::text
       )
  ) then
    raise exception 'invalid_community_draft_media_item'
      using errcode='22023';
  end if;

  if (
    select count(distinct e.item->>'object_path')
    from pg_catalog.jsonb_array_elements(p_items) e(item)
  )<>pg_catalog.jsonb_array_length(p_items) then
    raise exception 'duplicate_community_draft_media_path'
      using errcode='22023';
  end if;

  select coalesce(
    pg_catalog.array_agg(m.object_path order by m.position),
    array[]::text[]
  )
  into v_stale
  from public.bil_community_post_draft_media_v1 m
  where m.draft_id=p_draft_id
    and not exists(
      select 1
      from pg_catalog.jsonb_array_elements(p_items) e(item)
      where e.item->>'object_path'=m.object_path
    );

  delete from public.bil_community_post_draft_media_v1
  where draft_id=p_draft_id;

  insert into public.bil_community_post_draft_media_v1(
    draft_id,position,object_path,mime_type,bytes,width,height
  )
  select
    p_draft_id,(e.ord-1)::smallint,
    e.item->>'object_path',
    e.item->>'mime_type',
    (e.item->>'bytes')::integer,
    (e.item->>'width')::integer,
    (e.item->>'height')::integer
  from pg_catalog.jsonb_array_elements(p_items)
    with ordinality e(item,ord)
  order by e.ord;

  update public.bil_community_post_drafts_v1
  set updated_at=pg_catalog.clock_timestamp()
  where draft_id=p_draft_id and owner_id=v_uid;

  return v_stale;
end
$$;

create or replace function public.bil_list_my_community_post_drafts_v1(
  p_before timestamptz default null,
  p_before_id uuid default null,
  p_limit integer default 20
)
returns table(
  draft_id uuid,
  title text,
  body text,
  updated_at timestamptz,
  media_count integer
)
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if (p_before is null)<>(p_before_id is null)
     or p_limit is null or p_limit<1 or p_limit>50 then
    raise exception 'invalid_community_draft_cursor' using errcode='22023';
  end if;
  return query
  select
    d.draft_id,d.title,d.body,d.updated_at,
    (
      select count(*)::integer
      from public.bil_community_post_draft_media_v1 m
      where m.draft_id=d.draft_id
    )
  from public.bil_community_post_drafts_v1 d
  where d.owner_id=v_uid
    and (
      p_before is null
      or (d.updated_at,d.draft_id)<(p_before,p_before_id)
    )
  order by d.updated_at desc,d.draft_id desc
  limit p_limit;
end
$$;

create or replace function public.bil_get_my_community_post_draft_v1(
  p_draft_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_draft public.bil_community_post_drafts_v1%rowtype;
  v_media jsonb;
  v_mentions jsonb;
  v_collaborators jsonb;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  select * into v_draft
  from public.bil_community_post_drafts_v1 d
  where d.draft_id=p_draft_id and d.owner_id=v_uid;
  if not found then
    raise exception 'community_draft_not_found' using errcode='P0002';
  end if;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'user_id',p.user_id,
        'handle',h.handle,
        'display_name',p.display_name,
        'avatar_url',p.avatar_url
      )
      order by x.ord
    ),
    '[]'::jsonb
  )
  into v_mentions
  from unnest(v_draft.mentioned_user_ids)
    with ordinality x(user_id,ord)
  join public.bil_public_profiles p on p.user_id=x.user_id
  join public.bil_social_handles_v2 h
    on h.user_id=x.user_id and h.chosen;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'user_id',p.user_id,
        'handle',h.handle,
        'display_name',p.display_name,
        'avatar_url',p.avatar_url
      )
      order by x.ord
    ),
    '[]'::jsonb
  )
  into v_collaborators
  from unnest(v_draft.collaborator_user_ids)
    with ordinality x(user_id,ord)
  join public.bil_public_profiles p on p.user_id=x.user_id
  join public.bil_social_handles_v2 h
    on h.user_id=x.user_id and h.chosen;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'position',m.position,
        'object_path',m.object_path,
        'mime_type',m.mime_type,
        'bytes',m.bytes,
        'width',m.width,
        'height',m.height
      )
      order by m.position
    ),
    '[]'::jsonb
  )
  into v_media
  from public.bil_community_post_draft_media_v1 m
  where m.draft_id=p_draft_id;

  return pg_catalog.jsonb_build_object(
    'draft_id',v_draft.draft_id,
    'title',v_draft.title,
    'body',v_draft.body,
    'topic_slugs',v_draft.topic_slugs,
    'circle_slug',v_draft.circle_slug,
    'location_label',v_draft.location_label,
    'mentions',v_mentions,
    'collaborators',v_collaborators,
    'hashtags',v_draft.hashtags,
    'poll_question',v_draft.poll_question,
    'poll_options',v_draft.poll_options,
    'poll_allow_multiple',v_draft.poll_allow_multiple,
    'created_at',v_draft.created_at,
    'updated_at',v_draft.updated_at,
    'media',v_media
  );
end
$$;

create or replace function public.bil_delete_my_community_post_draft_v1(
  p_draft_id uuid
)
returns text[]
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_paths text[];
  v_rows integer;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_draft_id is null then
    raise exception 'invalid_community_draft_id' using errcode='22023';
  end if;

  select coalesce(
    pg_catalog.array_agg(m.object_path order by m.position),
    array[]::text[]
  )
  into v_paths
  from public.bil_community_post_draft_media_v1 m
  join public.bil_community_post_drafts_v1 d
    on d.draft_id=m.draft_id
  where d.draft_id=p_draft_id and d.owner_id=v_uid;

  delete from public.bil_community_post_drafts_v1 d
  where d.draft_id=p_draft_id and d.owner_id=v_uid;
  get diagnostics v_rows=row_count;
  if v_rows<>1 then
    raise exception 'community_draft_not_found' using errcode='P0002';
  end if;
  return v_paths;
end
$$;

revoke all on function public.bil_set_my_community_post_reference_metadata_v1(
  uuid,text,text[],uuid[]
) from public,anon,service_role;
grant execute on function public.bil_set_my_community_post_reference_metadata_v1(
  uuid,text,text[],uuid[]
) to authenticated;

revoke all on function public.bil_community_post_reference_metadata_v1(uuid[])
  from public,anon,service_role;
grant execute on function public.bil_community_post_reference_metadata_v1(uuid[])
  to authenticated;

revoke all on function public.bil_upsert_my_community_post_draft_v1(
  uuid,text,text,text[],text,text,uuid[],uuid[],text[],text,text[],boolean
) from public,anon,service_role;
grant execute on function public.bil_upsert_my_community_post_draft_v1(
  uuid,text,text,text[],text,text,uuid[],uuid[],text[],text,text[],boolean
) to authenticated;

revoke all on function public.bil_set_my_community_post_draft_media_v1(uuid,jsonb)
  from public,anon,service_role;
grant execute on function public.bil_set_my_community_post_draft_media_v1(uuid,jsonb)
  to authenticated;

revoke all on function public.bil_list_my_community_post_drafts_v1(
  timestamptz,uuid,integer
) from public,anon,service_role;
grant execute on function public.bil_list_my_community_post_drafts_v1(
  timestamptz,uuid,integer
) to authenticated;

revoke all on function public.bil_get_my_community_post_draft_v1(uuid)
  from public,anon,service_role;
grant execute on function public.bil_get_my_community_post_draft_v1(uuid)
  to authenticated;

revoke all on function public.bil_delete_my_community_post_draft_v1(uuid)
  from public,anon,service_role;
grant execute on function public.bil_delete_my_community_post_draft_v1(uuid)
  to authenticated;

do $postconditions$
begin
  if to_regprocedure(
      'public.bil_set_my_community_post_reference_metadata_v1(uuid,text,text[],uuid[])'
    ) is null
    or to_regprocedure(
      'public.bil_community_post_reference_metadata_v1(uuid[])'
    ) is null
    or to_regprocedure(
      'public.bil_upsert_my_community_post_draft_v1(uuid,text,text,text[],text,text,uuid[],uuid[],text[],text,text[],boolean)'
    ) is null
    or to_regprocedure(
      'public.bil_set_my_community_post_draft_media_v1(uuid,jsonb)'
    ) is null
    or to_regprocedure(
      'public.bil_list_my_community_post_drafts_v1(timestamptz,uuid,integer)'
    ) is null
    or to_regprocedure(
      'public.bil_get_my_community_post_draft_v1(uuid)'
    ) is null
    or to_regprocedure(
      'public.bil_delete_my_community_post_draft_v1(uuid)'
    ) is null then
    raise exception 'community_reference_composer_postcondition_failed';
  end if;
end
$postconditions$;
