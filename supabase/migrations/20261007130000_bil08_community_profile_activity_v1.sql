begin;

set local lock_timeout = '5s';
set local statement_timeout = '30s';

-- BIL-08 local proposal only. Do not apply to production from this worker.
do $preflight$
begin
  if pg_catalog.to_regclass('public.bil_public_profiles') is null
     or pg_catalog.to_regclass('public.bil_community_posts') is null
     or pg_catalog.to_regclass('public.bil_social_comments_v2') is null
     or pg_catalog.to_regclass('public.bil_social_post_likes_v2') is null
     or pg_catalog.to_regprocedure('public.bil_social_profile_visible_v2(uuid)') is null
     or pg_catalog.to_regprocedure('public.bil_social_member_visible_v2(uuid)') is null
     or pg_catalog.to_regprocedure('public.bil_social_post_visible_v2(uuid)') is null then
    raise exception 'bil08_profile_activity_dependencies_missing';
  end if;
end;
$preflight$;

create or replace function public.bil_community_profile_replies_v1(
  p_user_id uuid,
  p_before timestamptz default null,
  p_before_id uuid default null,
  p_limit integer default 24
)
returns table(
  id uuid,
  author_id uuid,
  parent_id uuid,
  body text,
  created_at timestamptz,
  author_name text,
  avatar_url text,
  handle text,
  like_count bigint,
  liked boolean,
  reply_count integer,
  post_id uuid
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_viewer uuid := (select auth.uid());
  v_show_posts boolean;
begin
  if v_viewer is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if p_user_id is null
     or (p_before is null) <> (p_before_id is null)
     or p_limit is null
     or p_limit < 1
     or p_limit > 60 then
    raise exception 'invalid_profile_reply_request' using errcode = '22023';
  end if;

  if p_user_id <> v_viewer then
    select profile.show_posts
      into v_show_posts
    from public.bil_public_profiles as profile
    where profile.user_id = p_user_id;

    if not found
       or not coalesce(v_show_posts, false)
       or not public.bil_social_profile_visible_v2(p_user_id) then
      return;
    end if;
  end if;

  return query
  select
    comment.id,
    comment.author_id,
    comment.parent_id,
    comment.body,
    comment.created_at,
    profile.display_name,
    profile.avatar_url,
    social_handle.handle,
    (
      select count(*)
      from public.bil_social_comment_likes_v2 as comment_like
      where comment_like.comment_id = comment.id
    ),
    exists(
      select 1
      from public.bil_social_comment_likes_v2 as my_like
      where my_like.comment_id = comment.id
        and my_like.user_id = v_viewer
    ),
    (
      select count(*)::integer
      from public.bil_social_comments_v2 as child
      where child.parent_id = comment.id
        and child.post_id = comment.post_id
        and child.deleted_at is null
        and child.removed_at is null
        and public.bil_social_member_visible_v2(child.author_id)
    ),
    comment.post_id
  from public.bil_social_comments_v2 as comment
  left join public.bil_public_profiles as profile
    on profile.user_id = comment.author_id
   and public.bil_social_profile_visible_v2(profile.user_id)
  left join public.bil_social_handles_v2 as social_handle
    on social_handle.user_id = profile.user_id
   and social_handle.chosen
  where comment.author_id = p_user_id
    and comment.deleted_at is null
    and comment.removed_at is null
    and public.bil_social_member_visible_v2(comment.author_id)
    and public.bil_social_post_visible_v2(comment.post_id)
    and (
      comment.parent_id is null
      or exists(
        select 1
        from public.bil_social_comments_v2 as root
        where root.id = comment.parent_id
          and root.post_id = comment.post_id
          and root.parent_id is null
          and root.deleted_at is null
          and root.removed_at is null
          and public.bil_social_member_visible_v2(root.author_id)
      )
    )
    and (
      p_before is null
      or comment.created_at < p_before
      or (comment.created_at = p_before and comment.id < p_before_id)
    )
  order by comment.created_at desc, comment.id desc
  limit p_limit;
end;
$function$;

create or replace function public.bil_community_profile_likes_v1(
  p_user_id uuid,
  p_before timestamptz default null,
  p_before_id uuid default null,
  p_limit integer default 24
)
returns table(
  post_id uuid,
  liked_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_viewer uuid := (select auth.uid());
begin
  if v_viewer is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if p_user_id is null
     or (p_before is null) <> (p_before_id is null)
     or p_limit is null
     or p_limit < 1
     or p_limit > 60 then
    raise exception 'invalid_profile_like_request' using errcode = '22023';
  end if;
  if p_user_id <> v_viewer then
    raise exception 'community_profile_likes_private' using errcode = '42501';
  end if;

  return query
  select post_like.post_id, post_like.created_at
  from public.bil_social_post_likes_v2 as post_like
  where post_like.user_id = p_user_id
    and public.bil_social_post_visible_v2(post_like.post_id)
    and (
      p_before is null
      or post_like.created_at < p_before
      or (post_like.created_at = p_before and post_like.post_id < p_before_id)
    )
  order by post_like.created_at desc, post_like.post_id desc
  limit p_limit;
end;
$function$;

revoke all on function public.bil_community_profile_replies_v1(
  uuid,timestamptz,uuid,integer
) from public, anon, authenticated, service_role;
grant execute on function public.bil_community_profile_replies_v1(
  uuid,timestamptz,uuid,integer
) to authenticated;

revoke all on function public.bil_community_profile_likes_v1(
  uuid,timestamptz,uuid,integer
) from public, anon, authenticated, service_role;
grant execute on function public.bil_community_profile_likes_v1(
  uuid,timestamptz,uuid,integer
) to authenticated;

do $postcondition$
begin
  if pg_catalog.to_regprocedure(
       'public.bil_community_profile_replies_v1(uuid,timestamp with time zone,uuid,integer)'
     ) is null
     or pg_catalog.to_regprocedure(
       'public.bil_community_profile_likes_v1(uuid,timestamp with time zone,uuid,integer)'
     ) is null then
    raise exception 'bil08_profile_activity_postcondition_failed';
  end if;
end;
$postcondition$;

notify pgrst, 'reload schema';

commit;
