set local lock_timeout='5s';
set local statement_timeout='30s';

do $$
begin
  if to_regclass('public.bil_social_comments_v2') is null
     or to_regclass('public.bil_social_comment_likes_v2') is null
     or to_regprocedure('public.bil_social_post_visible_v2(uuid)') is null
     or to_regprocedure('public.bil_social_member_visible_v2(uuid)') is null
     or to_regprocedure('public.bil_social_profile_visible_v2(uuid)') is null then
    raise exception 'community_comment_threads_v3_dependencies_missing';
  end if;
end
$$;

create index if not exists bil_social_comments_root_page_v3
  on public.bil_social_comments_v2(post_id,created_at,id)
  where parent_id is null and deleted_at is null and removed_at is null;

create index if not exists bil_social_comments_reply_page_v3
  on public.bil_social_comments_v2(parent_id,created_at,id)
  where parent_id is not null and deleted_at is null and removed_at is null;

create or replace function public.bil_social_comment_threads_v3(
  p_post_id uuid,
  p_after timestamptz default null,
  p_after_id uuid default null,
  p_limit integer default 20
)
returns table(
  root jsonb,
  replies jsonb,
  reply_count integer,
  root_created_at timestamptz,
  root_id uuid
)
language plpgsql
stable
security definer
set search_path=''
as $$
begin
  if not public.bil_social_post_visible_v2(p_post_id) then
    raise exception 'post_unavailable' using errcode='42501';
  end if;
  if (p_after is null)<>(p_after_id is null)
     or p_limit is null or p_limit<1 or p_limit>50 then
    raise exception 'invalid_comment_thread_cursor' using errcode='22023';
  end if;

  return query
  with roots as (
    select c.*
    from public.bil_social_comments_v2 c
    where c.post_id=p_post_id
      and c.parent_id is null
      and c.deleted_at is null
      and c.removed_at is null
      and public.bil_social_member_visible_v2(c.author_id)
      and (
        p_after is null
        or (c.created_at,c.id)>(p_after,p_after_id)
      )
    order by c.created_at,c.id
    limit p_limit
  )
  select
    pg_catalog.jsonb_build_object(
      'id',r.id,
      'author_id',r.author_id,
      'parent_id',null,
      'body',r.body,
      'created_at',r.created_at,
      'author_name',profile.display_name,
      'avatar_url',profile.avatar_url,
      'handle',social_handle.handle,
      'like_count',(
        select count(*)
        from public.bil_social_comment_likes_v2 l
        where l.comment_id=r.id
      ),
      'liked',exists(
        select 1
        from public.bil_social_comment_likes_v2 l
        where l.comment_id=r.id
          and l.user_id=(select auth.uid())
      ),
      'reply_count',reply_stats.reply_count
    ),
    coalesce(reply_rows.replies,'[]'::jsonb),
    reply_stats.reply_count,
    r.created_at,
    r.id
  from roots r
  left join public.bil_public_profiles profile
    on profile.user_id=r.author_id
   and public.bil_social_profile_visible_v2(profile.user_id)
  left join public.bil_social_handles_v2 social_handle
    on social_handle.user_id=profile.user_id
   and social_handle.chosen
  cross join lateral (
    select count(*)::integer as reply_count
    from public.bil_social_comments_v2 rc
    where rc.parent_id=r.id
      and rc.post_id=r.post_id
      and rc.deleted_at is null
      and rc.removed_at is null
      and public.bil_social_member_visible_v2(rc.author_id)
  ) reply_stats
  left join lateral (
    select pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'id',q.id,
        'author_id',q.author_id,
        'parent_id',q.parent_id,
        'body',q.body,
        'created_at',q.created_at,
        'author_name',qp.display_name,
        'avatar_url',qp.avatar_url,
        'handle',qh.handle,
        'like_count',(
          select count(*)
          from public.bil_social_comment_likes_v2 l
          where l.comment_id=q.id
        ),
        'liked',exists(
          select 1
          from public.bil_social_comment_likes_v2 l
          where l.comment_id=q.id
            and l.user_id=(select auth.uid())
        ),
        'reply_count',0
      )
      order by q.created_at,q.id
    ) as replies
    from (
      select reply.*
      from public.bil_social_comments_v2 reply
      where reply.parent_id=r.id
        and reply.post_id=r.post_id
        and reply.deleted_at is null
        and reply.removed_at is null
        and public.bil_social_member_visible_v2(reply.author_id)
      order by reply.created_at,reply.id
      limit 3
    ) q
    left join public.bil_public_profiles qp
      on qp.user_id=q.author_id
     and public.bil_social_profile_visible_v2(qp.user_id)
    left join public.bil_social_handles_v2 qh
      on qh.user_id=qp.user_id
     and qh.chosen
  ) reply_rows on true
  order by r.created_at,r.id;
end
$$;

create or replace function public.bil_social_comment_replies_v3(
  p_root_id uuid,
  p_after timestamptz default null,
  p_after_id uuid default null,
  p_limit integer default 20
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
  reply_count integer
)
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_post_id uuid;
begin
  if (p_after is null)<>(p_after_id is null)
     or p_limit is null or p_limit<1 or p_limit>50 then
    raise exception 'invalid_comment_reply_cursor' using errcode='22023';
  end if;

  select c.post_id into v_post_id
  from public.bil_social_comments_v2 c
  where c.id=p_root_id
    and c.parent_id is null
    and c.deleted_at is null
    and c.removed_at is null
    and public.bil_social_member_visible_v2(c.author_id);

  if v_post_id is null
     or not public.bil_social_post_visible_v2(v_post_id) then
    raise exception 'comment_thread_unavailable' using errcode='42501';
  end if;

  return query
  select
    reply.id,
    reply.author_id,
    reply.parent_id,
    reply.body,
    reply.created_at,
    profile.display_name,
    profile.avatar_url,
    social_handle.handle,
    (
      select count(*)
      from public.bil_social_comment_likes_v2 l
      where l.comment_id=reply.id
    ),
    exists(
      select 1
      from public.bil_social_comment_likes_v2 l
      where l.comment_id=reply.id
        and l.user_id=(select auth.uid())
    ),
    0
  from public.bil_social_comments_v2 reply
  left join public.bil_public_profiles profile
    on profile.user_id=reply.author_id
   and public.bil_social_profile_visible_v2(profile.user_id)
  left join public.bil_social_handles_v2 social_handle
    on social_handle.user_id=profile.user_id
   and social_handle.chosen
  where reply.parent_id=p_root_id
    and reply.post_id=v_post_id
    and reply.deleted_at is null
    and reply.removed_at is null
    and public.bil_social_member_visible_v2(reply.author_id)
    and (
      p_after is null
      or (reply.created_at,reply.id)>(p_after,p_after_id)
    )
  order by reply.created_at,reply.id
  limit p_limit;
end
$$;

revoke all on function public.bil_social_comment_threads_v3(
  uuid,timestamptz,uuid,integer
) from public,anon,service_role;
grant execute on function public.bil_social_comment_threads_v3(
  uuid,timestamptz,uuid,integer
) to authenticated;

revoke all on function public.bil_social_comment_replies_v3(
  uuid,timestamptz,uuid,integer
) from public,anon,service_role;
grant execute on function public.bil_social_comment_replies_v3(
  uuid,timestamptz,uuid,integer
) to authenticated;

do $$
begin
  if to_regprocedure(
      'public.bil_social_comment_threads_v3(uuid,timestamptz,uuid,integer)'
    ) is null
     or to_regprocedure(
       'public.bil_social_comment_replies_v3(uuid,timestamptz,uuid,integer)'
     ) is null then
    raise exception 'community_comment_threads_v3_postcondition_failed';
  end if;
end
$$;
