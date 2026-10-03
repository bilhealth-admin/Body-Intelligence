-- BIL Community reference parity: profile/creator/follow/view/review foundation.
-- Forward-only. No reference UI in this migration is synthetic: every projected
-- metric is derived from authoritative Community rows or immutable ledgers.
set local lock_timeout='5s';
set local statement_timeout='30s';

do $preflight$
begin
  if to_regclass('public.bil_community_posts') is null
     or to_regclass('public.bil_public_profiles') is null
     or to_regclass('public.bil_follows') is null
     or to_regclass('public.bil_social_post_likes_v2') is null
     or to_regclass('public.bil_social_comments_v2') is null
     or to_regclass('public.bil_community_reputation_accounts') is null
     or to_regclass('public.bil_community_level_policy') is null
     or to_regclass('public.bil_community_food_submissions') is null
     or to_regprocedure('public.bil_social_profile_visible_v2(uuid)') is null
     or to_regprocedure('public.bil_social_post_visible_v2(uuid)') is null
     or to_regprocedure('public.bil_social_member_visible_v2(uuid)') is null then
    raise exception 'community_reference_profile_dependencies_missing';
  end if;

  if exists(
    select 1
    from public.bil_community_level_policy p
    where not (p.level=1 and p.min_xp=0 and p.active)
  ) then
    raise exception 'community_level_policy_unexpected_preexisting_rows';
  end if;
end
$preflight$;

insert into public.bil_community_level_policy(
  level,min_xp,title_copy_key,active,updated_at
) values
  (2,100,'community_level_2',true,pg_catalog.clock_timestamp()),
  (3,300,'community_level_3',true,pg_catalog.clock_timestamp()),
  (4,700,'community_level_4',true,pg_catalog.clock_timestamp()),
  (5,1500,'community_level_5',true,pg_catalog.clock_timestamp()),
  (6,3000,'community_level_6',true,pg_catalog.clock_timestamp()),
  (7,6000,'community_level_7',true,pg_catalog.clock_timestamp());

create table public.bil_community_creator_certifications_v1(
  owner_id uuid primary key references auth.users(id) on delete cascade,
  status text not null check(status in ('approved','revoked')),
  certified_at timestamptz,
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  constraint bil_community_creator_certification_time check(
    (status='approved' and certified_at is not null)
    or status='revoked'
  )
);
alter table public.bil_community_creator_certifications_v1 enable row level security;
revoke all on table public.bil_community_creator_certifications_v1
  from public,anon,authenticated,service_role;

create table public.bil_community_post_views_v1(
  post_id uuid not null references public.bil_community_posts(id) on delete cascade,
  viewer_id uuid not null references auth.users(id) on delete cascade,
  viewed_at timestamptz not null default pg_catalog.clock_timestamp(),
  primary key(post_id,viewer_id)
);
create index bil_community_post_views_viewer_idx
  on public.bil_community_post_views_v1(viewer_id,viewed_at desc,post_id);
alter table public.bil_community_post_views_v1 enable row level security;
revoke all on table public.bil_community_post_views_v1
  from public,anon,authenticated,service_role;

create or replace function public.bil_record_community_post_view_v1(
  p_post_id uuid
)
returns bigint
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_author uuid;
  v_count bigint;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_post_id is null then
    raise exception 'invalid_post_id' using errcode='22023';
  end if;

  select p.author_id into v_author
  from public.bil_community_posts p
  where p.id=p_post_id and p.deleted_at is null;

  if v_author is null
     or (v_author<>v_uid and not public.bil_social_post_visible_v2(p_post_id)) then
    raise exception 'post_unavailable' using errcode='42501';
  end if;

  if v_author<>v_uid then
    insert into public.bil_community_post_views_v1(post_id,viewer_id)
    values(p_post_id,v_uid)
    on conflict(post_id,viewer_id) do nothing;
  end if;

  select count(*) into v_count
  from public.bil_community_post_views_v1 v
  where v.post_id=p_post_id;

  return v_count;
end
$$;

revoke all on function public.bil_record_community_post_view_v1(uuid)
  from public,anon,service_role;
grant execute on function public.bil_record_community_post_view_v1(uuid)
  to authenticated;

create or replace function public.bil_community_post_view_counts_v1(
  p_post_ids uuid[]
)
returns table(post_id uuid,view_count bigint)
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
  if p_post_ids is null
     or cardinality(p_post_ids)>100
     or cardinality(p_post_ids)<>(
       select count(distinct value) from unnest(p_post_ids) value
     ) then
    raise exception 'invalid_post_view_count_request' using errcode='22023';
  end if;

  return query
  select p.id,count(v.viewer_id)::bigint
  from public.bil_community_posts p
  left join public.bil_community_post_views_v1 v on v.post_id=p.id
  where p.id=any(p_post_ids)
    and p.deleted_at is null
    and (p.author_id=v_uid or public.bil_social_post_visible_v2(p.id))
  group by p.id
  order by p.id;
end
$$;

revoke all on function public.bil_community_post_view_counts_v1(uuid[])
  from public,anon,service_role;
grant execute on function public.bil_community_post_view_counts_v1(uuid[])
  to authenticated;

create or replace function public.bil_community_profile_projection_v1(
  p_user_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_viewer uuid:=(select auth.uid());
  v_profile public.bil_public_profiles%rowtype;
  v_handle text;
  v_relationship text:='none';
  v_post_count integer;
  v_follower_count integer;
  v_following_count integer;
  v_friend_count integer;
  v_xp bigint:=0;
  v_level integer:=1;
  v_level_copy_key text:='community_level_1';
  v_level_min_xp bigint:=0;
  v_next_level integer;
  v_next_level_min_xp bigint;
  v_gold bigint;
  v_viewer_follows boolean:=false;
  v_follows_viewer boolean:=false;
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

  select h.handle into v_handle
  from public.bil_social_handles_v2 h
  where h.user_id=p_user_id and h.chosen;

  if p_user_id=v_viewer then
    v_relationship:='self';
  else
    select case
      when f.status='accepted' then 'accepted'
      when f.status='pending' and f.requester_id=v_viewer then 'pending'
      when f.status='pending' and f.addressee_id=v_viewer then 'incoming'
      else 'none'
    end
    into v_relationship
    from public.bil_friendships f
    where (f.requester_id=v_viewer and f.addressee_id=p_user_id)
       or (f.addressee_id=v_viewer and f.requester_id=p_user_id)
    order by f.created_at desc
    limit 1;
    v_relationship:=coalesce(v_relationship,'none');

    select exists(
      select 1 from public.bil_follows f
      where f.follower_id=v_viewer and f.followed_id=p_user_id
    ) into v_viewer_follows;
    select exists(
      select 1 from public.bil_follows f
      where f.follower_id=p_user_id and f.followed_id=v_viewer
    ) into v_follows_viewer;
  end if;

  if p_user_id=v_viewer or v_profile.show_posts then
    select count(*)::integer into v_post_count
    from public.bil_community_posts p
    where p.author_id=p_user_id
      and p.deleted_at is null
      and (p_user_id=v_viewer or public.bil_social_post_visible_v2(p.id));
  end if;

  if p_user_id=v_viewer or v_profile.show_followers then
    select count(*)::integer into v_follower_count
    from public.bil_follows f
    where f.followed_id=p_user_id
      and public.bil_social_member_visible_v2(f.follower_id);
  end if;

  if p_user_id=v_viewer or v_profile.show_following then
    select count(*)::integer into v_following_count
    from public.bil_follows f
    where f.follower_id=p_user_id
      and public.bil_social_member_visible_v2(f.followed_id);
  end if;

  if p_user_id=v_viewer or v_profile.show_friends then
    select count(*)::integer into v_friend_count
    from public.bil_friendships f
    where f.status='accepted'
      and (
        (f.requester_id=p_user_id
         and public.bil_social_member_visible_v2(f.addressee_id))
        or (f.addressee_id=p_user_id
         and public.bil_social_member_visible_v2(f.requester_id))
      );
  end if;

  select coalesce(a.xp,0) into v_xp
  from (select 1) seed
  left join public.bil_community_reputation_accounts a on a.owner_id=p_user_id;

  select p.level,p.title_copy_key,p.min_xp
  into v_level,v_level_copy_key,v_level_min_xp
  from public.bil_community_level_policy p
  where p.active and p.min_xp<=v_xp
  order by p.min_xp desc,p.level desc
  limit 1;

  select p.level,p.min_xp
  into v_next_level,v_next_level_min_xp
  from public.bil_community_level_policy p
  where p.active and p.min_xp>v_xp
  order by p.min_xp,p.level
  limit 1;

  if p_user_id=v_viewer then
    select coalesce(a.balance,0) into v_gold
    from (select 1) seed
    left join public.bil_gold_accounts a on a.owner_id=p_user_id;
  end if;

  return pg_catalog.jsonb_build_object(
    'user_id',v_profile.user_id,
    'display_name',v_profile.display_name,
    'avatar_url',v_profile.avatar_url,
    'bio',v_profile.bio,
    'locale_code',v_profile.locale_code,
    'country_code',v_profile.country_code,
    'handle',v_handle,
    'is_self',p_user_id=v_viewer,
    'relationship',v_relationship,
    'allow_friend_requests',v_profile.allow_friend_requests,
    'allow_follows',v_profile.allow_follows,
    'viewer_follows',v_viewer_follows,
    'follows_viewer',v_follows_viewer,
    'show_followers',v_profile.show_followers,
    'show_following',v_profile.show_following,
    'show_friends',v_profile.show_friends,
    'show_posts',v_profile.show_posts,
    'show_membership_tier',v_profile.show_membership_tier,
    'follower_count',v_follower_count,
    'following_count',v_following_count,
    'friend_count',v_friend_count,
    'post_count',v_post_count,
    'community_xp',v_xp,
    'community_level',coalesce(v_level,1),
    'community_level_copy_key',coalesce(v_level_copy_key,'community_level_1'),
    'current_level_min_xp',coalesce(v_level_min_xp,0),
    'next_community_level',v_next_level,
    'next_level_min_xp',v_next_level_min_xp,
    'gold_balance',v_gold
  );
end
$$;

create or replace function public.bil_community_profile_connections_v2(
  p_user_id uuid,
  p_kind text,
  p_before timestamptz default null,
  p_before_user_id uuid default null,
  p_limit integer default 30
)
returns table(
  user_id uuid,
  handle text,
  display_name text,
  avatar_url text,
  relationship text,
  connected_at timestamptz,
  viewer_follows boolean,
  follows_viewer boolean,
  allow_follows boolean
)
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_viewer uuid:=(select auth.uid());
  v_profile public.bil_public_profiles%rowtype;
begin
  if v_viewer is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_user_id is null
     or p_kind not in ('followers','following','friends')
     or (p_before is null)<>(p_before_user_id is null)
     or p_limit is null or p_limit<1 or p_limit>60 then
    raise exception 'invalid_profile_connections_request' using errcode='22023';
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

  if p_user_id<>v_viewer and (
    (p_kind='followers' and not v_profile.show_followers)
    or (p_kind='following' and not v_profile.show_following)
    or (p_kind='friends' and not v_profile.show_friends)
  ) then
    return;
  end if;

  return query
  with relations as (
    select f.follower_id as member_id,f.created_at
    from public.bil_follows f
    where p_kind='followers' and f.followed_id=p_user_id
    union all
    select f.followed_id as member_id,f.created_at
    from public.bil_follows f
    where p_kind='following' and f.follower_id=p_user_id
    union all
    select case when f.requester_id=p_user_id
      then f.addressee_id else f.requester_id end as member_id,
      f.created_at
    from public.bil_friendships f
    where p_kind='friends'
      and f.status='accepted'
      and (f.requester_id=p_user_id or f.addressee_id=p_user_id)
  ),
  visible as (
    select r.member_id,r.created_at
    from relations r
    where public.bil_social_profile_visible_v2(r.member_id)
      and (p_before is null or (r.created_at,r.member_id)<(p_before,p_before_user_id))
    order by r.created_at desc,r.member_id desc
    limit p_limit
  )
  select
    v.member_id,h.handle,p.display_name,p.avatar_url,
    case
      when v.member_id=v_viewer then 'self'
      when exists(
        select 1 from public.bil_friendships f
        where f.status='accepted'
          and ((f.requester_id=v_viewer and f.addressee_id=v.member_id)
            or (f.addressee_id=v_viewer and f.requester_id=v.member_id))
      ) then 'accepted'
      when exists(
        select 1 from public.bil_friendships f
        where f.status='pending'
          and f.requester_id=v_viewer and f.addressee_id=v.member_id
      ) then 'pending'
      when exists(
        select 1 from public.bil_friendships f
        where f.status='pending'
          and f.addressee_id=v_viewer and f.requester_id=v.member_id
      ) then 'incoming'
      else 'none'
    end,
    v.created_at,
    exists(select 1 from public.bil_follows f
      where f.follower_id=v_viewer and f.followed_id=v.member_id),
    exists(select 1 from public.bil_follows f
      where f.follower_id=v.member_id and f.followed_id=v_viewer),
    p.allow_follows
  from visible v
  join public.bil_public_profiles p on p.user_id=v.member_id
  left join public.bil_social_handles_v2 h
    on h.user_id=v.member_id and h.chosen
  order by v.created_at desc,v.member_id desc;
end
$$;

revoke all on function public.bil_community_profile_connections_v2(
  uuid,text,timestamptz,uuid,integer
) from public,anon,service_role;
grant execute on function public.bil_community_profile_connections_v2(
  uuid,text,timestamptz,uuid,integer
) to authenticated;

create or replace function public.bil_community_creator_projection_v1(
  p_user_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
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

  select h.handle into v_handle
  from public.bil_social_handles_v2 h
  where h.user_id=p_user_id and h.chosen;

  select count(*) into v_approved_posts
  from public.bil_community_posts p
  where p.author_id=p_user_id
    and p.deleted_at is null
    and p.moderation_status='approved'
    and p.moderation_visibility='visible';

  select count(*) into v_followers
  from public.bil_follows f
  where f.followed_id=p_user_id;

  select count(*) into v_likes_received
  from public.bil_social_post_likes_v2 l
  join public.bil_community_posts p on p.id=l.post_id
  where p.author_id=p_user_id
    and p.deleted_at is null
    and p.moderation_status='approved';

  select count(*) into v_comments_received
  from public.bil_social_comments_v2 c
  join public.bil_community_posts p on p.id=c.post_id
  where p.author_id=p_user_id
    and p.deleted_at is null
    and p.moderation_status='approved'
    and c.deleted_at is null
    and c.removed_at is null
    and c.author_id<>p_user_id;

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

  select count(*)::integer into v_badge_count
  from pg_catalog.jsonb_array_elements(v_badges) badge
  where (badge->>'earned')::boolean;

  return pg_catalog.jsonb_build_object(
    'user_id',p_user_id,
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
    'total_badge_count',7,
    'badges',v_badges,
    'certification_status',v_certification
  );
end
$$;

revoke all on function public.bil_community_creator_projection_v1(uuid)
  from public,anon,service_role;
grant execute on function public.bil_community_creator_projection_v1(uuid)
  to authenticated;

create or replace function public.bil_community_profile_reviews_v1(
  p_user_id uuid,
  p_before timestamptz default null,
  p_before_id uuid default null,
  p_limit integer default 24
)
returns table(
  review_id uuid,
  product_kind text,
  canonical_name text,
  brand text,
  review_note text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_viewer uuid:=(select auth.uid());
  v_profile public.bil_public_profiles%rowtype;
begin
  if v_viewer is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_user_id is null
     or (p_before is null)<>(p_before_id is null)
     or p_limit is null or p_limit<1 or p_limit>60 then
    raise exception 'invalid_profile_reviews_request' using errcode='22023';
  end if;

  select * into v_profile
  from public.bil_public_profiles p
  where p.user_id=p_user_id;
  if not found then
    raise exception 'community_profile_not_found' using errcode='P0002';
  end if;
  if p_user_id<>v_viewer
     and (not public.bil_social_profile_visible_v2(p_user_id)
       or not v_profile.show_posts) then
    return;
  end if;

  return query
  select s.id,s.product_kind,s.canonical_name,s.brand,s.review_note,s.created_at
  from public.bil_community_food_submissions s
  where s.contributor_id=p_user_id
    and s.status='approved'
    and s.withdrawn_at is null
    and (p_before is null or (s.created_at,s.id)<(p_before,p_before_id))
  order by s.created_at desc,s.id desc
  limit p_limit;
end
$$;

revoke all on function public.bil_community_profile_reviews_v1(
  uuid,timestamptz,uuid,integer
) from public,anon,service_role;
grant execute on function public.bil_community_profile_reviews_v1(
  uuid,timestamptz,uuid,integer
) to authenticated;

do $postconditions$
begin
  if to_regprocedure('public.bil_record_community_post_view_v1(uuid)') is null
     or to_regprocedure('public.bil_community_post_view_counts_v1(uuid[])') is null
     or to_regprocedure('public.bil_community_profile_connections_v2(uuid,text,timestamptz,uuid,integer)') is null
     or to_regprocedure('public.bil_community_creator_projection_v1(uuid)') is null
     or to_regprocedure('public.bil_community_profile_reviews_v1(uuid,timestamptz,uuid,integer)') is null then
    raise exception 'community_reference_profile_postcondition_failed';
  end if;
end
$postconditions$;
