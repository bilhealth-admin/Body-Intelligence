set local lock_timeout='5s';
set local statement_timeout='30s';

do $$
begin
  if to_regclass('public.bil_community_posts') is null
     or to_regprocedure('public.bil_social_post_visible_v2(uuid)') is null then
    raise exception 'community_circles_post_contract_missing';
  end if;
  if to_regclass('public.bil_community_circles') is not null
     or to_regclass('public.bil_community_circle_memberships') is not null
     or to_regclass('public.bil_community_post_circles') is not null then
    raise exception 'community_circles_v1_already_exists';
  end if;
end
$$;

create table public.bil_community_circles (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique
    check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' and char_length(slug)<=48),
  title_copy_key text not null
    check (title_copy_key ~ '^[a-z][a-z0-9_]{2,63}$'),
  description_copy_key text not null
    check (description_copy_key ~ '^[a-z][a-z0-9_]{2,63}$'),
  rules_copy_key text not null
    check (rules_copy_key ~ '^[a-z][a-z0-9_]{2,63}$'),
  access text not null default 'public'
    check (access in ('public','private')),
  join_policy text not null default 'open'
    check (join_policy in ('open','request','invite')),
  featured boolean not null default false,
  active boolean not null default true,
  rank_weight integer not null default 0 check (rank_weight between -10000 and 10000),
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp()
);

create table public.bil_community_circle_memberships (
  circle_id uuid not null references public.bil_community_circles(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member'
    check (role in ('member','moderator')),
  status text not null default 'active'
    check (status in ('active','pending','banned')),
  joined_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  primary key(circle_id,owner_id)
);

create table public.bil_community_post_circles (
  post_id uuid primary key references public.bil_community_posts(id) on delete cascade,
  circle_id uuid not null references public.bil_community_circles(id) on delete cascade,
  created_at timestamptz not null default pg_catalog.clock_timestamp()
);

create index bil_community_circle_memberships_owner_idx
  on public.bil_community_circle_memberships(owner_id,status,joined_at desc,circle_id);
create index bil_community_circle_memberships_circle_idx
  on public.bil_community_circle_memberships(circle_id,status,joined_at desc,owner_id);
create index bil_community_post_circles_feed_idx
  on public.bil_community_post_circles(circle_id,created_at desc,post_id);

alter table public.bil_community_circles enable row level security;
alter table public.bil_community_circle_memberships enable row level security;
alter table public.bil_community_post_circles enable row level security;

revoke all on table public.bil_community_circles
  from public,anon,authenticated,service_role;
revoke all on table public.bil_community_circle_memberships
  from public,anon,authenticated,service_role;
revoke all on table public.bil_community_post_circles
  from public,anon,authenticated,service_role;

insert into public.bil_community_circles(
  slug,title_copy_key,description_copy_key,rules_copy_key,
  access,join_policy,featured,rank_weight
)
values
  ('10k-steps','community_circle_10k_steps','community_circle_10k_steps_body','community_circle_standard_rules','public','open',true,100),
  ('healthy-eating','community_circle_healthy_eating','community_circle_healthy_eating_body','community_circle_standard_rules','public','open',true,95),
  ('beginner-fitness','community_circle_beginner_fitness','community_circle_beginner_fitness_body','community_circle_standard_rules','public','open',true,90),
  ('strength','community_circle_strength','community_circle_strength_body','community_circle_standard_rules','public','open',false,75),
  ('running','community_circle_running','community_circle_running_body','community_circle_standard_rules','public','open',false,75),
  ('sleep','community_circle_sleep','community_circle_sleep_body','community_circle_standard_rules','public','open',false,70),
  ('ramadan-fasting','community_circle_ramadan_fasting','community_circle_ramadan_fasting_body','community_circle_standard_rules','public','open',false,65),
  ('weight-loss-journey','community_circle_weight_loss_journey','community_circle_weight_loss_journey_body','community_circle_standard_rules','public','open',false,60);

create or replace function public.bil_list_community_circles_v1()
returns table(
  slug text,
  title_copy_key text,
  description_copy_key text,
  rules_copy_key text,
  access text,
  join_policy text,
  featured boolean,
  member_count integer,
  post_count integer,
  membership_status text,
  membership_role text
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
    c.slug,c.title_copy_key,c.description_copy_key,c.rules_copy_key,
    c.access,c.join_policy,c.featured,
    (
      select count(*)::integer
      from public.bil_community_circle_memberships m
      where m.circle_id=c.id
        and m.status='active'
        and not exists(
          select 1 from private.bil_community_member_access a
          where a.user_id=m.owner_id and a.suspended
        )
    ),
    (
      select count(*)::integer
      from public.bil_community_post_circles pc
      join public.bil_community_posts p on p.id=pc.post_id
      where pc.circle_id=c.id
        and p.deleted_at is null
        and p.moderation_status='approved'
        and public.bil_social_post_visible_v2(p.id)
    ),
    membership.status,
    membership.role
  from public.bil_community_circles c
  left join public.bil_community_circle_memberships membership
    on membership.circle_id=c.id
   and membership.owner_id=v_uid
  where c.active
    and (
      c.access='public'
      or membership.status='active'
    )
  order by c.featured desc,c.rank_weight desc,c.slug;
end
$$;

create or replace function public.bil_join_community_circle_v1(
  p_slug text
)
returns text
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_circle public.bil_community_circles%rowtype;
  v_status text;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if exists(
    select 1 from private.bil_community_member_access a
    where a.user_id=v_uid and a.suspended
  ) then
    raise exception 'community_access_suspended' using errcode='42501';
  end if;

  select * into v_circle
  from public.bil_community_circles c
  where c.slug=p_slug and c.active;

  if not found then
    raise exception 'community_circle_not_found' using errcode='22023';
  end if;
  if v_circle.join_policy='invite' then
    raise exception 'community_circle_invite_required' using errcode='42501';
  end if;

  if (
    select count(*)
    from public.bil_community_circle_memberships m
    where m.owner_id=v_uid and m.status in ('active','pending')
  )>=100 and not exists(
    select 1
    from public.bil_community_circle_memberships m
    where m.owner_id=v_uid
      and m.circle_id=v_circle.id
      and m.status in ('active','pending')
  ) then
    raise exception 'community_circle_membership_limit' using errcode='22023';
  end if;

  v_status:=case
    when v_circle.join_policy='open' then 'active'
    else 'pending'
  end;

  insert into public.bil_community_circle_memberships(
    circle_id,owner_id,role,status
  )
  values(v_circle.id,v_uid,'member',v_status)
  on conflict(circle_id,owner_id) do update
  set status=case
        when public.bil_community_circle_memberships.status='banned'
          then 'banned'
        else excluded.status
      end,
      updated_at=pg_catalog.clock_timestamp();

  select m.status into v_status
  from public.bil_community_circle_memberships m
  where m.circle_id=v_circle.id and m.owner_id=v_uid;

  return v_status;
end
$$;

create or replace function public.bil_leave_community_circle_v1(
  p_slug text
)
returns boolean
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_circle uuid;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;

  select c.id into v_circle
  from public.bil_community_circles c
  where c.slug=p_slug and c.active;

  if v_circle is null then
    raise exception 'community_circle_not_found' using errcode='22023';
  end if;

  if exists(
    select 1
    from public.bil_community_circle_memberships m
    where m.circle_id=v_circle
      and m.owner_id=v_uid
      and m.role='moderator'
      and m.status='active'
  ) then
    raise exception 'community_circle_moderator_cannot_leave'
      using errcode='42501';
  end if;

  delete from public.bil_community_circle_memberships
  where circle_id=v_circle
    and owner_id=v_uid
    and status<>'banned';

  return found;
end
$$;

create or replace function public.bil_set_my_community_post_circle_v1(
  p_post_id uuid,
  p_slug text default null
)
returns text
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_circle uuid;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_post_id is null or not exists(
    select 1
    from public.bil_community_posts p
    where p.id=p_post_id
      and p.author_id=v_uid
      and p.deleted_at is null
  ) then
    raise exception 'community_post_not_owned' using errcode='42501';
  end if;

  delete from public.bil_community_post_circles
  where post_id=p_post_id;

  if p_slug is null then
    return null;
  end if;

  select c.id into v_circle
  from public.bil_community_circles c
  where c.slug=p_slug and c.active;

  if v_circle is null then
    raise exception 'community_circle_not_found' using errcode='22023';
  end if;
  if not exists(
    select 1
    from public.bil_community_circle_memberships m
    where m.circle_id=v_circle
      and m.owner_id=v_uid
      and m.status='active'
  ) then
    raise exception 'community_circle_membership_required'
      using errcode='42501';
  end if;

  insert into public.bil_community_post_circles(post_id,circle_id)
  values(p_post_id,v_circle);

  return p_slug;
end
$$;

create or replace function public.bil_community_circle_post_refs_v1(
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
  v_circle public.bil_community_circles%rowtype;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_slug is null
     or (p_before is null)<>(p_before_id is null)
     or p_limit is null or p_limit<1 or p_limit>60 then
    raise exception 'invalid_circle_feed_request' using errcode='22023';
  end if;

  select * into v_circle
  from public.bil_community_circles c
  where c.slug=p_slug and c.active;
  if not found then
    raise exception 'community_circle_not_found' using errcode='22023';
  end if;

  if v_circle.access='private' and not exists(
    select 1
    from public.bil_community_circle_memberships m
    where m.circle_id=v_circle.id
      and m.owner_id=v_uid
      and m.status='active'
  ) then
    raise exception 'community_circle_membership_required'
      using errcode='42501';
  end if;

  return query
  select p.id,p.created_at
  from public.bil_community_post_circles pc
  join public.bil_community_posts p on p.id=pc.post_id
  where pc.circle_id=v_circle.id
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

revoke all on function public.bil_list_community_circles_v1()
  from public,anon,service_role;
grant execute on function public.bil_list_community_circles_v1()
  to authenticated;

revoke all on function public.bil_join_community_circle_v1(text)
  from public,anon,service_role;
grant execute on function public.bil_join_community_circle_v1(text)
  to authenticated;

revoke all on function public.bil_leave_community_circle_v1(text)
  from public,anon,service_role;
grant execute on function public.bil_leave_community_circle_v1(text)
  to authenticated;

revoke all on function public.bil_set_my_community_post_circle_v1(uuid,text)
  from public,anon,service_role;
grant execute on function public.bil_set_my_community_post_circle_v1(uuid,text)
  to authenticated;

revoke all on function public.bil_community_circle_post_refs_v1(
  text,timestamptz,uuid,integer
) from public,anon,service_role;
grant execute on function public.bil_community_circle_post_refs_v1(
  text,timestamptz,uuid,integer
) to authenticated;

do $$
begin
  if to_regprocedure('public.bil_list_community_circles_v1()') is null
     or to_regprocedure('public.bil_join_community_circle_v1(text)') is null
     or to_regprocedure('public.bil_leave_community_circle_v1(text)') is null
     or to_regprocedure('public.bil_set_my_community_post_circle_v1(uuid,text)') is null
     or to_regprocedure('public.bil_community_circle_post_refs_v1(text,timestamptz,uuid,integer)') is null then
    raise exception 'community_circles_v1_postcondition_failed';
  end if;
end
$$;
