set local lock_timeout='5s';
set local statement_timeout='30s';

do $$
begin
  if to_regclass('public.bil_public_profiles') is null
     or to_regclass('public.bil_community_posts') is null
     or to_regclass('public.bil_follows') is null
     or to_regclass('public.bil_friendships') is null then
    raise exception 'community_profile_foundation_missing';
  end if;
  if to_regprocedure('public.bil_social_profile_visible_v2(uuid)') is null
     or to_regprocedure('public.bil_social_post_visible_v2(uuid)') is null
     or to_regprocedure('public.bil_social_member_visible_v2(uuid)') is null then
    raise exception 'community_social_visibility_contract_missing';
  end if;
end
$$;

alter table public.bil_public_profiles
  add column if not exists country_code text,
  add column if not exists show_followers boolean not null default true,
  add column if not exists show_following boolean not null default true,
  add column if not exists show_friends boolean not null default true,
  add column if not exists show_posts boolean not null default true,
  add column if not exists show_membership_tier boolean not null default false;

alter table public.bil_public_profiles
  drop constraint if exists bil_public_profiles_country_code_check;
alter table public.bil_public_profiles
  add constraint bil_public_profiles_country_code_check
  check (country_code is null or country_code ~ '^[A-Z]{2}$');

create index if not exists bil_community_posts_author_profile_page_idx
  on public.bil_community_posts(author_id,created_at desc,id desc)
  where deleted_at is null;

create index if not exists bil_follows_followed_history_idx
  on public.bil_follows(followed_id,created_at desc,follower_id desc);
create index if not exists bil_follows_follower_history_idx
  on public.bil_follows(follower_id,created_at desc,followed_id desc);

create index if not exists bil_friendships_requester_accepted_history_idx
  on public.bil_friendships(requester_id,created_at desc,addressee_id desc)
  where status='accepted';
create index if not exists bil_friendships_addressee_accepted_history_idx
  on public.bil_friendships(addressee_id,created_at desc,requester_id desc)
  where status='accepted';

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
  v_gold bigint;
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
  where h.user_id=p_user_id
    and h.chosen;

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
  end if;

  if p_user_id=v_viewer or v_profile.show_posts then
    select count(*)::integer into v_post_count
    from public.bil_community_posts p
    where p.author_id=p_user_id
      and p.deleted_at is null
      and (
        p_user_id=v_viewer
        or public.bil_social_post_visible_v2(p.id)
      );
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
        or
        (f.addressee_id=p_user_id
         and public.bil_social_member_visible_v2(f.requester_id))
      );
  end if;

  select coalesce(a.xp,0) into v_xp
  from (select 1) seed
  left join public.bil_community_reputation_accounts a
    on a.owner_id=p_user_id;

  select p.level,p.title_copy_key
  into v_level,v_level_copy_key
  from public.bil_community_level_policy p
  where p.active and p.min_xp<=v_xp
  order by p.min_xp desc,p.level desc
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
    'gold_balance',v_gold
  );
end
$$;

create or replace function public.bil_community_profile_posts_v1(
  p_user_id uuid,
  p_before timestamptz default null,
  p_before_id uuid default null,
  p_limit integer default 24
)
returns table(
  id uuid,
  author_id uuid,
  body text,
  created_at timestamptz,
  media_object_path text,
  media_mime_type text,
  media_bytes integer,
  media_width integer,
  media_height integer,
  moderation_status text,
  moderation_visibility text,
  reviewed_at timestamptz
)
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_viewer uuid:=(select auth.uid());
  v_show_posts boolean;
begin
  if v_viewer is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_user_id is null
     or (p_before is null)<>(p_before_id is null)
     or p_limit is null or p_limit<1 or p_limit>60 then
    raise exception 'invalid_profile_post_request' using errcode='22023';
  end if;

  select p.show_posts into v_show_posts
  from public.bil_public_profiles p
  where p.user_id=p_user_id;

  if not found then
    raise exception 'community_profile_not_found' using errcode='P0002';
  end if;

  if p_user_id<>v_viewer then
    if not public.bil_social_profile_visible_v2(p_user_id)
       or not v_show_posts then
      return;
    end if;
  end if;

  return query
  select
    p.id,p.author_id,p.body,p.created_at,
    p.media_object_path,p.media_mime_type,p.media_bytes,
    p.media_width,p.media_height,p.moderation_status,
    p.moderation_visibility,p.reviewed_at
  from public.bil_community_posts p
  where p.author_id=p_user_id
    and p.deleted_at is null
    and (
      p_user_id=v_viewer
      or public.bil_social_post_visible_v2(p.id)
    )
    and (
      p_before is null
      or (p.created_at,p.id)<(p_before,p_before_id)
    )
  order by p.created_at desc,p.id desc
  limit p_limit;
end
$$;

create or replace function public.bil_community_profile_connections_v1(
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
  connected_at timestamptz
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
    select
      case when f.requester_id=p_user_id
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
      and (
        p_before is null
        or (r.created_at,r.member_id)<(p_before,p_before_user_id)
      )
    order by r.created_at desc,r.member_id desc
    limit p_limit
  )
  select
    v.member_id,
    h.handle,
    p.display_name,
    p.avatar_url,
    case
      when v.member_id=v_viewer then 'self'
      when exists(
        select 1 from public.bil_friendships f
        where f.status='accepted'
          and (
            (f.requester_id=v_viewer and f.addressee_id=v.member_id)
            or
            (f.addressee_id=v_viewer and f.requester_id=v.member_id)
          )
      ) then 'accepted'
      when exists(
        select 1 from public.bil_friendships f
        where f.status='pending'
          and f.requester_id=v_viewer
          and f.addressee_id=v.member_id
      ) then 'pending'
      when exists(
        select 1 from public.bil_friendships f
        where f.status='pending'
          and f.addressee_id=v_viewer
          and f.requester_id=v.member_id
      ) then 'incoming'
      else 'none'
    end,
    v.created_at
  from visible v
  join public.bil_public_profiles p on p.user_id=v.member_id
  left join public.bil_social_handles_v2 h
    on h.user_id=v.member_id and h.chosen
  order by v.created_at desc,v.member_id desc;
end
$$;

revoke all on function public.bil_community_profile_projection_v1(uuid)
from public,anon,service_role;
grant execute on function public.bil_community_profile_projection_v1(uuid)
to authenticated;

revoke all on function public.bil_community_profile_posts_v1(
  uuid,timestamptz,uuid,integer
) from public,anon,service_role;
grant execute on function public.bil_community_profile_posts_v1(
  uuid,timestamptz,uuid,integer
) to authenticated;

revoke all on function public.bil_community_profile_connections_v1(
  uuid,text,timestamptz,uuid,integer
) from public,anon,service_role;
grant execute on function public.bil_community_profile_connections_v1(
  uuid,text,timestamptz,uuid,integer
) to authenticated;

do $$
begin
  if to_regprocedure('public.bil_community_profile_projection_v1(uuid)') is null
     or to_regprocedure('public.bil_community_profile_posts_v1(uuid,timestamptz,uuid,integer)') is null
     or to_regprocedure('public.bil_community_profile_connections_v1(uuid,text,timestamptz,uuid,integer)') is null then
    raise exception 'community_profile_projection_v1_postcondition_failed';
  end if;
end
$$;
