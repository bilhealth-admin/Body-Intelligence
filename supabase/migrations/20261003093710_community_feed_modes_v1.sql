set local lock_timeout='5s';
set local statement_timeout='30s';

do $$
begin
  if to_regclass('public.bil_community_posts') is null
     or to_regclass('public.bil_follows') is null
     or to_regclass('public.bil_friendships') is null
     or to_regclass('public.bil_community_topic_follows') is null
     or to_regclass('public.bil_community_post_topics') is null
     or to_regclass('public.bil_community_circle_memberships') is null
     or to_regclass('public.bil_community_post_circles') is null
     or to_regprocedure('public.bil_social_post_visible_v2(uuid)') is null then
    raise exception 'community_feed_v1_dependencies_missing';
  end if;
end
$$;

create or replace function public.bil_community_feed_refs_v1(
  p_mode text,
  p_before_priority integer default null,
  p_before timestamptz default null,
  p_before_id uuid default null,
  p_limit integer default 30
)
returns table(
  post_id uuid,
  created_at timestamptz,
  priority integer,
  reasons text[]
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

  if p_mode not in ('for_you','following','friends','explore')
     or p_limit is null or p_limit<1 or p_limit>60
     or (
       (p_before_priority is null or p_before is null or p_before_id is null)
       and not (
         p_before_priority is null and p_before is null and p_before_id is null
       )
     ) then
    raise exception 'invalid_community_feed_request' using errcode='22023';
  end if;

  return query
  with scored as (
    select
      p.id as post_id,
      p.created_at,
      case
        when p_mode<>'for_you' then 0
        else
          (case when exists(
            select 1
            from public.bil_friendships f
            where f.status='accepted'
              and (
                (f.requester_id=v_uid and f.addressee_id=p.author_id)
                or
                (f.addressee_id=v_uid and f.requester_id=p.author_id)
              )
          ) then 40 else 0 end)
          +
          (case when exists(
            select 1
            from public.bil_follows f
            where f.follower_id=v_uid and f.followed_id=p.author_id
          ) then 30 else 0 end)
          +
          (case when exists(
            select 1
            from public.bil_community_post_topics pt
            join public.bil_community_topic_follows tf
              on tf.topic_id=pt.topic_id
             and tf.owner_id=v_uid
            where pt.post_id=p.id
          ) then 20 else 0 end)
          +
          (case when exists(
            select 1
            from public.bil_community_post_circles pc
            join public.bil_community_circle_memberships cm
              on cm.circle_id=pc.circle_id
             and cm.owner_id=v_uid
             and cm.status='active'
            where pc.post_id=p.id
          ) then 15 else 0 end)
          +
          (case when p.author_id=v_uid then 5 else 0 end)
      end as priority,
      case
        when p_mode<>'for_you' then array[]::text[]
        else array_remove(array[
          case when exists(
            select 1
            from public.bil_friendships f
            where f.status='accepted'
              and (
                (f.requester_id=v_uid and f.addressee_id=p.author_id)
                or
                (f.addressee_id=v_uid and f.requester_id=p.author_id)
              )
          ) then 'friend'::text end,
          case when exists(
            select 1
            from public.bil_follows f
            where f.follower_id=v_uid and f.followed_id=p.author_id
          ) then 'followed_author'::text end,
          case when exists(
            select 1
            from public.bil_community_post_topics pt
            join public.bil_community_topic_follows tf
              on tf.topic_id=pt.topic_id
             and tf.owner_id=v_uid
            where pt.post_id=p.id
          ) then 'followed_topic'::text end,
          case when exists(
            select 1
            from public.bil_community_post_circles pc
            join public.bil_community_circle_memberships cm
              on cm.circle_id=pc.circle_id
             and cm.owner_id=v_uid
             and cm.status='active'
            where pc.post_id=p.id
          ) then 'joined_circle'::text end
        ],null)
      end as reasons
    from public.bil_community_posts p
    where p.deleted_at is null
      and p.moderation_status='approved'
      and public.bil_social_post_visible_v2(p.id)
      and (
        p_mode in ('for_you','explore')
        or (
          p_mode='following'
          and exists(
            select 1
            from public.bil_follows f
            where f.follower_id=v_uid and f.followed_id=p.author_id
          )
        )
        or (
          p_mode='friends'
          and exists(
            select 1
            from public.bil_friendships f
            where f.status='accepted'
              and (
                (f.requester_id=v_uid and f.addressee_id=p.author_id)
                or
                (f.addressee_id=v_uid and f.requester_id=p.author_id)
              )
          )
        )
      )
  )
  select s.post_id,s.created_at,s.priority,s.reasons
  from scored s
  where p_before_priority is null
     or (s.priority,s.created_at,s.post_id)
        <(p_before_priority,p_before,p_before_id)
  order by s.priority desc,s.created_at desc,s.post_id desc
  limit p_limit;
end
$$;

revoke all on function public.bil_community_feed_refs_v1(
  text,integer,timestamptz,uuid,integer
) from public,anon,service_role;
grant execute on function public.bil_community_feed_refs_v1(
  text,integer,timestamptz,uuid,integer
) to authenticated;

do $$
begin
  if to_regprocedure(
    'public.bil_community_feed_refs_v1(text,integer,timestamptz,uuid,integer)'
  ) is null then
    raise exception 'community_feed_v1_postcondition_failed';
  end if;
end
$$;
