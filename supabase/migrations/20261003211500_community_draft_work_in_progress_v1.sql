set local lock_timeout='5s';
set local statement_timeout='30s';

do $preflight$
begin
  if to_regclass('public.bil_community_post_drafts_v1') is null
     or to_regclass('public.bil_community_post_draft_media_v1') is null
     or to_regprocedure(
       'public.bil_upsert_my_community_post_draft_v1(uuid,text,text,text[],text,text,uuid[],uuid[],text[],text,text[],boolean)'
     ) is null then
    raise exception 'community_draft_wip_dependencies_missing';
  end if;
  if to_regprocedure(
    'public.bil_consume_my_community_post_draft_v1(uuid,uuid)'
  ) is not null then
    raise exception 'community_draft_wip_v1_already_exists';
  end if;
end
$preflight$;

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
       where value is null or value !~ '^[a-z][a-z0-9_]{2,39}$'
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

  if (v_poll_question is not null and (
        char_length(v_poll_question)>200
        or v_poll_question ~ '[[:cntrl:]]'
      ))
     or cardinality(v_poll_options)>6
     or exists(
       select 1 from unnest(v_poll_options) value
       where char_length(value)>120
          or value ~ '[[:cntrl:]]'
     ) then
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

create or replace function public.bil_consume_my_community_post_draft_v1(
  p_draft_id uuid,
  p_post_id uuid
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
  if p_draft_id is null or p_post_id is null then
    raise exception 'invalid_community_draft_publish_receipt'
      using errcode='22023';
  end if;

  if not exists(
    select 1
    from public.bil_community_posts p
    where p.id=p_post_id
      and p.author_id=v_uid
      and p.deleted_at is null
      and p.moderation_status='pending'
      and p.visibility='community'
  ) then
    raise exception 'community_draft_publish_post_unavailable'
      using errcode='42501';
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
    raise exception 'community_draft_publish_draft_unavailable'
      using errcode='42501';
  end if;

  return v_paths;
end
$$;

revoke all on function public.bil_consume_my_community_post_draft_v1(
  uuid,uuid
) from public,anon,service_role;
grant execute on function public.bil_consume_my_community_post_draft_v1(
  uuid,uuid
) to authenticated;

do $postconditions$
begin
  if to_regprocedure(
      'public.bil_consume_my_community_post_draft_v1(uuid,uuid)'
    ) is null then
    raise exception 'community_draft_wip_postcondition_failed';
  end if;
end
$postconditions$;
