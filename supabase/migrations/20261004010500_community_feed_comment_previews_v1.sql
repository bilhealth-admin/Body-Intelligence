set local lock_timeout='5s';
set local statement_timeout='30s';

do $$
begin
  if to_regclass('public.bil_social_comments_v2') is null
     or to_regprocedure('public.bil_social_post_visible_v2(uuid)') is null
     or to_regprocedure('public.bil_social_member_visible_v2(uuid)') is null
     or to_regprocedure('public.bil_social_profile_visible_v2(uuid)') is null then
    raise exception 'community_feed_comment_preview_dependencies_missing';
  end if;
end
$$;

create or replace function public.bil_community_feed_comment_previews_v1(
  p_post_ids uuid[]
)
returns table(
  post_id uuid,
  comment jsonb
)
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;

  if p_post_ids is null
     or cardinality(p_post_ids) < 1
     or cardinality(p_post_ids) > 100
     or array_position(p_post_ids,null) is not null
     or cardinality(p_post_ids) <> (
       select count(distinct value)
       from unnest(p_post_ids) value
     ) then
    raise exception 'invalid_feed_comment_preview_request'
      using errcode='22023';
  end if;

  if not public.bil_can_use_community() then
    raise exception 'community_access_denied' using errcode='42501';
  end if;

  return query
  select
    requested.post_id,
    jsonb_build_object(
      'id', preview.id,
      'author_id', preview.author_id,
      'parent_id', null,
      'body', preview.body,
      'created_at', preview.created_at,
      'author_name', profile.display_name,
      'avatar_url', profile.avatar_url,
      'handle', social_handle.handle,
      'like_count', (
        select count(*)
        from public.bil_social_comment_likes_v2 comment_like
        where comment_like.comment_id=preview.id
      ),
      'liked', exists(
        select 1
        from public.bil_social_comment_likes_v2 comment_like
        where comment_like.comment_id=preview.id
          and comment_like.user_id=v_uid
      ),
      'reply_count', (
        select count(*)::integer
        from public.bil_social_comments_v2 reply
        where reply.parent_id=preview.id
          and reply.post_id=preview.post_id
          and reply.deleted_at is null
          and reply.removed_at is null
          and public.bil_social_member_visible_v2(reply.author_id)
      )
    ) as comment
  from unnest(p_post_ids) requested(post_id)
  join lateral (
    select root.*
    from public.bil_social_comments_v2 root
    where root.post_id=requested.post_id
      and root.parent_id is null
      and root.deleted_at is null
      and root.removed_at is null
      and public.bil_social_member_visible_v2(root.author_id)
      and public.bil_social_post_visible_v2(root.post_id)
    order by root.created_at desc,root.id desc
    limit 1
  ) preview on true
  left join public.bil_public_profiles profile
    on profile.user_id=preview.author_id
   and public.bil_social_profile_visible_v2(profile.user_id)
  left join public.bil_social_handles_v2 social_handle
    on social_handle.user_id=profile.user_id
  order by requested.post_id;
end
$$;

revoke all on function public.bil_community_feed_comment_previews_v1(uuid[])
  from public,anon,service_role;
grant execute on function public.bil_community_feed_comment_previews_v1(uuid[])
  to authenticated;

do $$
begin
  if to_regprocedure(
       'public.bil_community_feed_comment_previews_v1(uuid[])'
     ) is null then
    raise exception 'community_feed_comment_previews_v1_postcondition_failed';
  end if;
end
$$;
