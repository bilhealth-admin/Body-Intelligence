-- Forward-only closure for the 2026-10-04 pre-build audit.
-- No table grants, historical migration edits, thresholds or reward changes.
set local lock_timeout='5s';
set local statement_timeout='30s';

do $preflight$
begin
  if to_regprocedure('public.bil_social_post_visible_v2(uuid)') is null
     or to_regprocedure('public.bil_social_member_visible_v2(uuid)') is null
     or to_regprocedure('public.bil_consume_rate_limit(text,integer,integer)') is null then
    raise exception 'community_prebuild_hardening_dependencies_missing';
  end if;
end
$preflight$;

CREATE OR REPLACE FUNCTION public.bil_community_creator_projection_v1(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_viewer uuid:=(select auth.uid());
  v_profile public.bil_public_profiles%rowtype;
  v_handle text;
  v_approved_posts bigint:=0;
  v_followers bigint:=0;
  v_likes_received bigint:=0;
  v_comments_received bigint:=0;
  v_xp bigint:=0;
  v_level integer:=1;
  v_level_min_xp bigint:=0;
  v_next_level integer;
  v_next_min_xp bigint;
  v_referrals bigint:=0;
  v_certification text:='not_certified';
  v_badges jsonb;
  v_badge_count integer:=0;
  v_posts_visible boolean;
  v_followers_visible boolean;
begin
  if v_viewer is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_user_id is null then
    raise exception 'invalid_profile_user' using errcode='22023';
  end if;

  select * into v_profile
  from public.bil_public_profiles p
  where p.user_id=p_user_id;
  if not found then
    raise exception 'community_profile_not_found' using errcode='P0002';
  end if;
  if p_user_id<>v_viewer
     and not public.bil_social_profile_visible_v2(p_user_id) then
    raise exception 'community_profile_unavailable' using errcode='42501';
  end if;

  v_posts_visible := p_user_id=v_viewer or v_profile.show_posts;
  v_followers_visible := p_user_id=v_viewer or v_profile.show_followers;

  select h.handle into v_handle
  from public.bil_social_handles_v2 h
  where h.user_id=p_user_id and h.chosen;

  select count(*) into v_approved_posts
  from public.bil_community_posts p
  where p.author_id=p_user_id
    and p.deleted_at is null
    and p.moderation_status='approved'
    and p.moderation_visibility='visible'
    and (p_user_id=v_viewer or public.bil_social_post_visible_v2(p.id));

  select count(*) into v_followers
  from public.bil_follows f
  where f.followed_id=p_user_id;

  select count(*) into v_likes_received
  from public.bil_social_post_likes_v2 l
  join public.bil_community_posts p on p.id=l.post_id
  where p.author_id=p_user_id
    and p.deleted_at is null
    and p.moderation_status='approved'
    and p.moderation_visibility='visible'
    and (p_user_id=v_viewer or public.bil_social_post_visible_v2(p.id));

  select count(*) into v_comments_received
  from public.bil_social_comments_v2 c
  join public.bil_community_posts p on p.id=c.post_id
  where p.author_id=p_user_id
    and p.deleted_at is null
    and p.moderation_status='approved'
    and c.deleted_at is null
    and c.removed_at is null
    and c.author_id<>p_user_id
    and (p_user_id=v_viewer or (
      public.bil_social_post_visible_v2(p.id)
      and public.bil_social_member_visible_v2(c.author_id)
    ));

  if not v_posts_visible then
    v_approved_posts := null;
    v_likes_received := null;
    v_comments_received := null;
  end if;
  if not v_followers_visible then
    v_followers := null;
  end if;

  select coalesce(a.xp,0) into v_xp
  from (select 1) seed
  left join public.bil_community_reputation_accounts a on a.owner_id=p_user_id;

  select p.level,p.min_xp into v_level,v_level_min_xp
  from public.bil_community_level_policy p
  where p.active and p.min_xp<=v_xp
  order by p.min_xp desc,p.level desc
  limit 1;

  select p.level,p.min_xp into v_next_level,v_next_min_xp
  from public.bil_community_level_policy p
  where p.active and p.min_xp>v_xp
  order by p.min_xp,p.level
  limit 1;

  select count(*) into v_referrals
  from public.bil_community_referral_attributions r
  where r.inviter_id=p_user_id
    and r.relationship_qualified_at is not null
    and r.reward_eligible;

  select coalesce(c.status,'not_certified') into v_certification
  from (select 1) seed
  left join public.bil_community_creator_certifications_v1 c
    on c.owner_id=p_user_id;

  v_badges:=pg_catalog.jsonb_build_array(
    pg_catalog.jsonb_build_object(
      'badge_key','profile_complete',
      'earned',(v_handle is not null and nullif(btrim(coalesce(v_profile.bio,'')),'') is not null)
    ),
    pg_catalog.jsonb_build_object('badge_key','first_moment','earned',v_approved_posts>=1),
    pg_catalog.jsonb_build_object('badge_key','contributor','earned',v_approved_posts>=5),
    pg_catalog.jsonb_build_object('badge_key','conversation_starter','earned',v_comments_received>=10),
    pg_catalog.jsonb_build_object('badge_key','appreciated','earned',v_likes_received>=10),
    pg_catalog.jsonb_build_object('badge_key','connector','earned',v_followers>=5),
    pg_catalog.jsonb_build_object('badge_key','referral_builder','earned',v_referrals>=1)
  );

  -- Omit opt-out-derived badges rather than disclosing hidden thresholds.
  select coalesce(pg_catalog.jsonb_agg(badge order by ordinal),'[]'::jsonb)
  into v_badges
  from pg_catalog.jsonb_array_elements(v_badges) with ordinality visible(badge,ordinal)
  where badge->'earned' <> 'null'::jsonb;

  select count(*)::integer into v_badge_count
  from pg_catalog.jsonb_array_elements(v_badges) badge
  where (badge->>'earned')::boolean;

  return pg_catalog.jsonb_build_object(
    'user_id',p_user_id,
    'posts_visible',v_posts_visible,
    'followers_visible',v_followers_visible,
    'contributor',v_approved_posts>=1,
    'approved_posts',v_approved_posts,
    'followers',v_followers,
    'likes_received',v_likes_received,
    'comments_received',v_comments_received,
    'qualified_referrals',v_referrals,
    'community_xp',v_xp,
    'community_level',coalesce(v_level,1),
    'current_level_min_xp',coalesce(v_level_min_xp,0),
    'next_community_level',v_next_level,
    'next_level_min_xp',v_next_min_xp,
    'earned_badge_count',v_badge_count,
    'total_badge_count',pg_catalog.jsonb_array_length(v_badges),
    'badges',v_badges,
    'certification_status',v_certification
  );
end
$function$;


create or replace function public.bil_search_community_profiles(
  p_query text default '',
  p_limit integer default 30
)
returns table(user_id uuid,display_name text,avatar_url text,locale_code text)
language plpgsql
volatile
security definer
set search_path=''
as $function$
declare
  v_uid uuid:=(select auth.uid());
  v_query text:=btrim(coalesce(p_query,''));
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if not public.bil_can_use_community() then
    raise exception 'community_access_suspended' using errcode='42501';
  end if;
  if char_length(v_query)>120 or v_query ~ '[[:cntrl:]]' then
    raise exception 'invalid_community_profile_query' using errcode='22023';
  end if;
  -- Share the canonical discovery quota; never open a legacy unmetered surface.
  perform public.bil_consume_rate_limit('community_handle_search_v2',60,60);
  return query
  select p.user_id,p.display_name,p.avatar_url,p.locale_code
  from public.bil_public_profiles p
  where p.user_id<>v_uid
    and p.discoverable
    and p.allow_friend_requests
    and p.profile_visibility<>'private'
    and public.bil_social_member_visible_v2(p.user_id)
    and (v_query='' or p.display_name ilike ('%'||v_query||'%'))
  order by p.display_name,p.user_id
  limit least(greatest(coalesce(p_limit,30),1),30);
end
$function$;


CREATE OR REPLACE FUNCTION public.bil_create_community_invite_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_owner uuid:=(select auth.uid());
  v_policy public.bil_community_referral_policy%rowtype;
  v_token text;
  v_hash text;
  v_invite_id uuid;
  v_expires timestamptz;
  v_today timestamptz:=
    pg_catalog.date_trunc('day',pg_catalog.clock_timestamp() at time zone 'UTC')
      at time zone 'UTC';
  v_count integer;
begin
  if v_owner is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  -- Use the canonical member-state transaction lock before the owner quota
  -- lock. A raw suspension read can become stale while quota acquisition
  -- waits and allow a new invite after administrator suspension commits.
  if not public.bil_can_use_community() then
    raise exception 'community_access_suspended' using errcode='42501';
  end if;
  if not exists(
    select 1 from public.bil_public_profiles p where p.user_id=v_owner
  ) then
    raise exception 'community_profile_required' using errcode='42501';
  end if;

  select * into v_policy
  from public.bil_community_referral_policy p
  where p.singleton
  for share;

  if not found or not v_policy.invite_links_enabled then
    return pg_catalog.jsonb_build_object('status','disabled');
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('bil.community.invite.owner:'||v_owner::text,0)
  );

  select count(*)::integer into v_count
  from public.bil_community_invites i
  where i.inviter_id=v_owner
    and i.created_at>=v_today;

  if v_count>=v_policy.max_invites_per_owner_per_utc_day then
    return pg_catalog.jsonb_build_object(
      'status','rate_limited',
      'retry_after','next_utc_day'
    );
  end if;

  v_token:=encode(extensions.gen_random_bytes(24),'hex');
  v_hash:=encode(extensions.digest(v_token,'sha256'),'hex');
  v_expires:=pg_catalog.clock_timestamp()
    + pg_catalog.make_interval(days=>v_policy.invite_ttl_days);

  insert into public.bil_community_invites(
    inviter_id,token_hash,expires_at
  ) values(v_owner,v_hash,v_expires)
  returning id into v_invite_id;

  return pg_catalog.jsonb_build_object(
    'status','active',
    'invite_id',v_invite_id,
    'token',v_token,
    'url','https://www.bilhealth.com/invite/'||v_token,
    'expires_at',v_expires
  );
end
$function$;


CREATE OR REPLACE FUNCTION public.bil_guard_community_member_access()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if public.bil_can_use_community() then
    return new;
  end if;

  -- The mobile delete flow is an owner-scoped soft delete followed by media
  -- reference cleanup. Preserve that privacy action for a suspended member,
  -- but compare every other row field so this exception cannot edit or
  -- republish content.
  if tg_op = 'UPDATE'
     and tg_table_schema = 'public'
     and tg_table_name = 'bil_community_posts' then
    -- Keep OLD/NEW post-field access inside this table-specific branch. The
    -- same function is also attached to tables with different row shapes.
    if new.author_id = (select auth.uid())
       and new.deleted_at is not null
       and new.media_url is null
       and new.media_object_path is null
       and new.media_mime_type is null
       and new.media_bytes is null
       and new.media_width is null
       and new.media_height is null
       and new.location_label is null
       and (
         pg_catalog.to_jsonb(new) - array[
           'deleted_at', 'media_url', 'media_object_path', 'media_mime_type',
           'media_bytes', 'media_width', 'media_height', 'location_label'
         ]::text[]
       ) = (
         pg_catalog.to_jsonb(old) - array[
           'deleted_at', 'media_url', 'media_object_path', 'media_mime_type',
           'media_bytes', 'media_width', 'media_height', 'location_label'
         ]::text[]
       ) then
      return new;
    end if;
  end if;

  raise exception 'community_access_suspended' using errcode = '42501';
end
$function$;


CREATE OR REPLACE FUNCTION public.bil_upsert_my_community_post_draft_v1(p_draft_id uuid, p_title text DEFAULT NULL::text, p_body text DEFAULT ''::text, p_topic_slugs text[] DEFAULT ARRAY[]::text[], p_circle_slug text DEFAULT NULL::text, p_location_label text DEFAULT NULL::text, p_mentioned_user_ids uuid[] DEFAULT ARRAY[]::uuid[], p_collaborator_user_ids uuid[] DEFAULT ARRAY[]::uuid[], p_hashtags text[] DEFAULT ARRAY[]::text[], p_poll_question text DEFAULT NULL::text, p_poll_options text[] DEFAULT ARRAY[]::text[], p_poll_allow_multiple boolean DEFAULT false)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
     or pg_catalog.translate(v_body,E'\n\r\t','') ~ '[[:cntrl:]]'
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
          or value !~ '^[a-z0-9]+(-[a-z0-9]+)*$'
     ) then
    raise exception 'invalid_community_draft_topics'
      using errcode='22023';
  end if;

  if v_circle is not null
     and (
       char_length(v_circle)>48
       or v_circle !~ '^[a-z0-9]+(-[a-z0-9]+)*$'
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
$function$;


CREATE OR REPLACE FUNCTION public.bil_get_my_community_post_draft_v1(p_draft_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
    on h.user_id=x.user_id and h.chosen
  where p.discoverable
    and p.profile_visibility<>'private'
    and public.bil_social_member_visible_v2(p.user_id);

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
    on h.user_id=x.user_id and h.chosen
  where p.discoverable
    and p.profile_visibility<>'private'
    and public.bil_social_member_visible_v2(p.user_id);

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
$function$;


CREATE OR REPLACE FUNCTION public.bil_vote_community_poll_v1(p_post_id uuid, p_option_ids uuid[])
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid:=(select auth.uid());
  v_poll public.bil_community_polls%rowtype;
  v_count integer;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_post_id is null
     or p_option_ids is null
     or cardinality(p_option_ids)<1
     or cardinality(p_option_ids)>6
     or cardinality(p_option_ids)<>(
       select count(distinct value) from unnest(p_option_ids) value
     ) then
    raise exception 'invalid_community_poll_vote' using errcode='22023';
  end if;

  -- Serialize replacement of one voter's set, not unrelated voters.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'bil.community.poll.vote:'||p_post_id::text||':'||v_uid::text,0
    )
  );

  select * into v_poll
  from public.bil_community_polls p
  where p.post_id=p_post_id
  for share;

  if not found
     or not public.bil_social_post_visible_v2(p_post_id) then
    raise exception 'community_poll_unavailable' using errcode='42501';
  end if;
  if v_poll.closes_at is not null
     and v_poll.closes_at<=pg_catalog.clock_timestamp() then
    raise exception 'community_poll_closed' using errcode='22023';
  end if;
  if not v_poll.allow_multiple and cardinality(p_option_ids)<>1 then
    raise exception 'community_poll_single_choice' using errcode='22023';
  end if;

  select count(*)::integer into v_count
  from public.bil_community_poll_options o
  where o.post_id=p_post_id
    and o.id=any(p_option_ids);
  if v_count<>cardinality(p_option_ids) then
    raise exception 'community_poll_option_invalid' using errcode='22023';
  end if;

  delete from public.bil_community_poll_votes
  where post_id=p_post_id and voter_id=v_uid;

  insert into public.bil_community_poll_votes(
    post_id,option_id,voter_id
  )
  select p_post_id,value,v_uid
  from unnest(p_option_ids) value;

  return cardinality(p_option_ids);
end
$function$;


revoke all on function public.bil_community_creator_projection_v1(uuid) from public,anon,service_role;
grant execute on function public.bil_community_creator_projection_v1(uuid) to authenticated;
revoke all on function public.bil_search_community_profiles(text,integer) from public,anon,service_role;
grant execute on function public.bil_search_community_profiles(text,integer) to authenticated;
revoke all on function public.bil_create_community_invite_v1() from public,anon,service_role;
grant execute on function public.bil_create_community_invite_v1() to authenticated;
revoke all on function public.bil_guard_community_member_access() from public,anon,service_role;
revoke all on function public.bil_guard_community_member_access() from authenticated;
revoke all on function public.bil_upsert_my_community_post_draft_v1(uuid,text,text,text[],text,text,uuid[],uuid[],text[],text,text[],boolean) from public,anon,service_role;
grant execute on function public.bil_upsert_my_community_post_draft_v1(uuid,text,text,text[],text,text,uuid[],uuid[],text[],text,text[],boolean) to authenticated;
revoke all on function public.bil_get_my_community_post_draft_v1(uuid) from public,anon,service_role;
grant execute on function public.bil_get_my_community_post_draft_v1(uuid) to authenticated;
revoke all on function public.bil_vote_community_poll_v1(uuid,uuid[]) from public,anon,service_role;
grant execute on function public.bil_vote_community_poll_v1(uuid,uuid[]) to authenticated;

notify pgrst, 'reload schema';

