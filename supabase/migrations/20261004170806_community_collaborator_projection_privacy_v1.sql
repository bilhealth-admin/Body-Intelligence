-- Forward-only projection repair. Acceptance permits public collaboration
-- while current identity visibility permits it; it is not irrevocable consent
-- to bypass a later private/friends-only profile, block, or suspension.
-- Keep accepted records/status, all post metadata, batch bounds, and RPC ACLs.
set local lock_timeout='5s';
set local statement_timeout='30s';

do $preflight$
declare
  v_signature text;
  v_expected text;
begin
  -- Actual pg_get_functiondef fingerprints read from Production metadata at
  -- 2026-10-04 17:03:37 UTC. Normalize EOL only, never source/code semantics.
  for v_signature,v_expected in
    select * from (values
      ('public.bil_community_post_reference_metadata_v1(uuid[])','f894809c60bbcea757f94db5feeb9ee8'),
      ('public.bil_social_profile_visible_v2(uuid)','5b8631f8adb24ac5107c6190cb9137e7'),
      ('public.bil_social_member_visible_v2(uuid)','bff4a47d46555d2856374ce5b0f97317'),
      ('public.bil_social_post_visible_v2(uuid)','a0f4f2fc39c2db661685b8ba27623f18'),
      ('private.bil_resolve_community_moderation_authority(uuid)','fa473bfe2a2a2cba6170f782232b189a')
    ) expected(signature,definition_md5)
  loop
    if pg_catalog.to_regprocedure(v_signature) is null
       or pg_catalog.md5(pg_catalog.replace(
         pg_catalog.pg_get_functiondef(pg_catalog.to_regprocedure(v_signature)),
         pg_catalog.chr(13),''
       )) is distinct from v_expected then
      raise exception 'community_collaborator_privacy_prerequisite_drift: %',v_signature
        using errcode='55000';
    end if;
  end loop;
  if pg_catalog.has_function_privilege(
       'anon','public.bil_community_post_reference_metadata_v1(uuid[])','EXECUTE'
     ) or not pg_catalog.has_function_privilege(
       'authenticated','public.bil_community_post_reference_metadata_v1(uuid[])','EXECUTE'
     ) then
    raise exception 'community_collaborator_privacy_acl_drift' using errcode='55000';
  end if;
end
$preflight$;

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
            v_moderator
            or coll.collaborator_id=v_uid
            or public.bil_social_profile_visible_v2(coll.collaborator_id)
          )
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
