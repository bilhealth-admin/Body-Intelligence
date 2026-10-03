set local lock_timeout='5s';
set local statement_timeout='30s';

do $$
begin
  if to_regclass('public.bil_community_posts') is null
     or to_regprocedure('public.bil_social_post_visible_v2(uuid)') is null then
    raise exception 'community_topics_post_contract_missing';
  end if;
  if to_regclass('public.bil_community_topics') is not null
     or to_regclass('public.bil_community_topic_follows') is not null
     or to_regclass('public.bil_community_post_topics') is not null then
    raise exception 'community_topics_v1_already_exists';
  end if;
end
$$;

create table public.bil_community_topics (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique
    check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' and char_length(slug)<=48),
  title_copy_key text not null
    check (title_copy_key ~ '^[a-z][a-z0-9_]{2,63}$'),
  description_copy_key text not null
    check (description_copy_key ~ '^[a-z][a-z0-9_]{2,63}$'),
  icon_key text not null
    check (icon_key ~ '^[a-z][a-z0-9_]{1,47}$'),
  featured boolean not null default false,
  active boolean not null default true,
  rank_weight integer not null default 0 check (rank_weight between -10000 and 10000),
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp()
);

create table public.bil_community_topic_follows (
  owner_id uuid not null references auth.users(id) on delete cascade,
  topic_id uuid not null references public.bil_community_topics(id) on delete cascade,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  primary key(owner_id,topic_id)
);

create table public.bil_community_post_topics (
  post_id uuid not null references public.bil_community_posts(id) on delete cascade,
  topic_id uuid not null references public.bil_community_topics(id) on delete cascade,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  primary key(post_id,topic_id)
);

create index bil_community_topic_follows_topic_idx
  on public.bil_community_topic_follows(topic_id,created_at desc,owner_id);
create index bil_community_post_topics_topic_feed_idx
  on public.bil_community_post_topics(topic_id,created_at desc,post_id);

alter table public.bil_community_topics enable row level security;
alter table public.bil_community_topic_follows enable row level security;
alter table public.bil_community_post_topics enable row level security;

revoke all on table public.bil_community_topics
  from public,anon,authenticated,service_role;
revoke all on table public.bil_community_topic_follows
  from public,anon,authenticated,service_role;
revoke all on table public.bil_community_post_topics
  from public,anon,authenticated,service_role;

insert into public.bil_community_topics(
  slug,title_copy_key,description_copy_key,icon_key,featured,rank_weight
)
values
  ('getting-started','community_topic_getting_started','community_topic_getting_started_body','rocket',true,100),
  ('nutrition','community_topic_nutrition','community_topic_nutrition_body','nutrition',true,95),
  ('recipes','community_topic_recipes','community_topic_recipes_body','recipe',true,90),
  ('fitness','community_topic_fitness','community_topic_fitness_body','fitness',true,90),
  ('wellness','community_topic_wellness','community_topic_wellness_body','wellness',true,85),
  ('weight-loss','community_topic_weight_loss','community_topic_weight_loss_body','weight',false,70),
  ('maintenance','community_topic_maintenance','community_topic_maintenance_body','maintenance',false,65),
  ('muscle-gain','community_topic_muscle_gain','community_topic_muscle_gain_body','strength',false,65),
  ('success-stories','community_topic_success_stories','community_topic_success_stories_body','trophy',false,60),
  ('motivation-support','community_topic_motivation_support','community_topic_motivation_support_body','support',false,60),
  ('challenges','community_topic_challenges','community_topic_challenges_body','challenge',false,55),
  ('social','community_topic_social','community_topic_social_body','social',false,40);

create or replace function public.bil_list_community_topics_v1()
returns table(
  slug text,
  title_copy_key text,
  description_copy_key text,
  icon_key text,
  featured boolean,
  follower_count integer,
  post_count integer,
  following boolean
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

  return query
  select
    t.slug,
    t.title_copy_key,
    t.description_copy_key,
    t.icon_key,
    t.featured,
    (
      select count(*)::integer
      from public.bil_community_topic_follows f
      where f.topic_id=t.id
        and not exists(
          select 1
          from private.bil_community_member_access a
          where a.user_id=f.owner_id and a.suspended
        )
    ),
    (
      select count(*)::integer
      from public.bil_community_post_topics pt
      join public.bil_community_posts p on p.id=pt.post_id
      where pt.topic_id=t.id
        and p.deleted_at is null
        and p.moderation_status='approved'
        and public.bil_social_post_visible_v2(p.id)
    ),
    exists(
      select 1
      from public.bil_community_topic_follows f
      where f.topic_id=t.id and f.owner_id=v_uid
    )
  from public.bil_community_topics t
  where t.active
  order by t.featured desc,t.rank_weight desc,t.slug;
end
$$;

create or replace function public.bil_follow_community_topic_v1(
  p_slug text,
  p_follow boolean
)
returns boolean
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_topic uuid;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_slug is null or p_follow is null then
    raise exception 'invalid_topic_follow_request' using errcode='22023';
  end if;
  if exists(
    select 1 from private.bil_community_member_access a
    where a.user_id=v_uid and a.suspended
  ) then
    raise exception 'community_access_suspended' using errcode='42501';
  end if;

  select t.id into v_topic
  from public.bil_community_topics t
  where t.slug=p_slug and t.active;

  if v_topic is null then
    raise exception 'community_topic_not_found' using errcode='22023';
  end if;

  if p_follow then
    if not exists(
      select 1 from public.bil_community_topic_follows f
      where f.owner_id=v_uid and f.topic_id=v_topic
    ) and (
      select count(*) from public.bil_community_topic_follows f
      where f.owner_id=v_uid
    )>=100 then
      raise exception 'community_topic_follow_limit' using errcode='22023';
    end if;

    insert into public.bil_community_topic_follows(owner_id,topic_id)
    values(v_uid,v_topic)
    on conflict do nothing;
  else
    delete from public.bil_community_topic_follows
    where owner_id=v_uid and topic_id=v_topic;
  end if;

  return p_follow;
end
$$;

create or replace function public.bil_set_my_community_post_topics_v1(
  p_post_id uuid,
  p_slugs text[]
)
returns integer
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_requested integer;
  v_active integer;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_post_id is null
     or p_slugs is null
     or cardinality(p_slugs)>3
     or cardinality(p_slugs)<>(
       select count(distinct value)
       from unnest(p_slugs) value
     ) then
    raise exception 'invalid_post_topics' using errcode='22023';
  end if;
  if not exists(
    select 1 from public.bil_community_posts p
    where p.id=p_post_id
      and p.author_id=v_uid
      and p.deleted_at is null
  ) then
    raise exception 'community_post_not_owned' using errcode='42501';
  end if;

  delete from public.bil_community_post_topics
  where post_id=p_post_id;

  v_requested:=cardinality(p_slugs);
  if v_requested=0 then
    return 0;
  end if;

  select count(*)::integer into v_active
  from public.bil_community_topics t
  where t.active and t.slug=any(p_slugs);

  if v_active<>v_requested then
    raise exception 'community_topic_not_found' using errcode='22023';
  end if;

  insert into public.bil_community_post_topics(post_id,topic_id)
  select p_post_id,t.id
  from public.bil_community_topics t
  where t.slug=any(p_slugs);

  return v_requested;
end
$$;

create or replace function public.bil_community_topic_post_refs_v1(
  p_slug text,
  p_before timestamptz default null,
  p_before_id uuid default null,
  p_limit integer default 30
)
returns table(
  post_id uuid,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_topic uuid;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_slug is null
     or (p_before is null)<>(p_before_id is null)
     or p_limit is null or p_limit<1 or p_limit>60 then
    raise exception 'invalid_topic_feed_request' using errcode='22023';
  end if;

  select t.id into v_topic
  from public.bil_community_topics t
  where t.slug=p_slug and t.active;
  if v_topic is null then
    raise exception 'community_topic_not_found' using errcode='22023';
  end if;

  return query
  select p.id,p.created_at
  from public.bil_community_post_topics pt
  join public.bil_community_posts p on p.id=pt.post_id
  where pt.topic_id=v_topic
    and p.deleted_at is null
    and p.moderation_status='approved'
    and public.bil_social_post_visible_v2(p.id)
    and (
      p_before is null
      or (p.created_at,p.id)<(p_before,p_before_id)
    )
  order by p.created_at desc,p.id desc
  limit p_limit;
end
$$;

revoke all on function public.bil_list_community_topics_v1()
  from public,anon,service_role;
grant execute on function public.bil_list_community_topics_v1()
  to authenticated;

revoke all on function public.bil_follow_community_topic_v1(text,boolean)
  from public,anon,service_role;
grant execute on function public.bil_follow_community_topic_v1(text,boolean)
  to authenticated;

revoke all on function public.bil_set_my_community_post_topics_v1(uuid,text[])
  from public,anon,service_role;
grant execute on function public.bil_set_my_community_post_topics_v1(uuid,text[])
  to authenticated;

revoke all on function public.bil_community_topic_post_refs_v1(
  text,timestamptz,uuid,integer
) from public,anon,service_role;
grant execute on function public.bil_community_topic_post_refs_v1(
  text,timestamptz,uuid,integer
) to authenticated;

do $$
begin
  if to_regprocedure('public.bil_list_community_topics_v1()') is null
     or to_regprocedure('public.bil_follow_community_topic_v1(text,boolean)') is null
     or to_regprocedure('public.bil_set_my_community_post_topics_v1(uuid,text[])') is null
     or to_regprocedure('public.bil_community_topic_post_refs_v1(text,timestamptz,uuid,integer)') is null then
    raise exception 'community_topics_v1_postcondition_failed';
  end if;
end
$$;
