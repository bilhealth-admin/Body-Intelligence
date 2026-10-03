-- Community Activity v2: evolve the durable notification inbox without
-- breaking v1 clients that only understand friend_accepted.
set local lock_timeout='5s';
set local statement_timeout='30s';

do $$
begin
  if to_regclass('public.bil_community_notifications') is null then
    raise exception 'community_notifications_missing';
  end if;
  if to_regprocedure('public.bil_list_community_notifications(integer)') is null
     or to_regprocedure('public.bil_mark_community_notifications_seen(uuid[])') is null
     or to_regprocedure('private.bil_attention_snapshot_v1(uuid)') is null then
    raise exception 'community_activity_v1_contract_missing';
  end if;
end
$$;

alter table public.bil_community_notifications
  add column entity_kind text,
  add column entity_id text,
  add column copy_key text,
  add column deep_link_path text,
  add column metadata jsonb not null default '{}'::jsonb;

update public.bil_community_notifications
set entity_kind='friendship',
    entity_id=friendship_id::text,
    copy_key='friend_accepted_v1',
    deep_link_path='/community/notifications'
where kind='friend_accepted';

do $$
begin
  if exists(
    select 1
    from public.bil_community_notifications
    where entity_kind is null
       or entity_id is null
       or copy_key is null
       or deep_link_path is null
  ) then
    raise exception 'community_activity_backfill_incomplete';
  end if;
end
$$;

alter table public.bil_community_notifications
  alter column entity_kind set not null,
  alter column entity_id set not null,
  alter column copy_key set not null,
  alter column deep_link_path set not null;

alter table public.bil_community_notifications
  drop constraint bil_community_notifications_kind_check;

alter table public.bil_community_notifications
  add constraint bil_community_notifications_kind_check check (
    kind in (
      'friend_request',
      'friend_accepted',
      'post_like',
      'post_save',
      'comment',
      'reply',
      'follow',
      'reward_earned',
      'quest_completed',
      'badge_earned',
      'challenge_update'
    )
  ),
  add constraint bil_community_notifications_entity_kind_check check (
    entity_kind in (
      'friendship',
      'post',
      'comment',
      'profile',
      'reward',
      'quest',
      'badge',
      'challenge'
    )
  ),
  add constraint bil_community_notifications_entity_id_check check (
    char_length(entity_id) between 1 and 160
  ),
  add constraint bil_community_notifications_copy_key_check check (
    copy_key ~ '^[a-z][a-z0-9_]{2,63}$'
  ),
  add constraint bil_community_notifications_deep_link_path_check check (
    char_length(deep_link_path) between 2 and 240
    and deep_link_path ~ '^/community(/[A-Za-z0-9._~-]+)*$'
  ),
  add constraint bil_community_notifications_metadata_check check (
    jsonb_typeof(metadata)='object'
    and octet_length(metadata::text)<=4096
  );

create index bil_community_notifications_recipient_history_v2_idx
  on public.bil_community_notifications(recipient_id,created_at desc,id desc);

create index bil_community_notifications_recipient_kind_unseen_v2_idx
  on public.bil_community_notifications(
    recipient_id,kind,created_at desc,id desc
  )
  where seen_at is null;

create or replace function public.bil_enqueue_friendship_acceptance_notification()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare v_notification_id uuid;
begin
  if old.status='pending' and new.status='accepted' then
    insert into public.bil_community_notifications(
      recipient_id,
      actor_id,
      kind,
      friendship_id,
      source_key,
      entity_kind,
      entity_id,
      copy_key,
      deep_link_path,
      metadata
    )
    values(
      new.requester_id,
      new.addressee_id,
      'friend_accepted',
      new.id,
      'friend_accepted:'||new.id::text,
      'friendship',
      new.id::text,
      'friend_accepted_v1',
      '/community/notifications',
      '{}'::jsonb
    )
    on conflict(source_key) do nothing
    returning id into v_notification_id;

    if v_notification_id is not null then
      insert into public.bil_push_outbox(
        recipient_id,category,title,body,deep_link,copy_key,source_key
      )
      values(
        new.requester_id,
        'community',
        'BIL',
        'Your friend request was accepted.',
        'bil://community/notifications',
        'friend_accepted_v1',
        'friend_accepted:'||new.id::text
      )
      on conflict(recipient_id,source_key)
        where source_key is not null
      do nothing;
    end if;
  end if;
  return new;
end
$$;

-- v1 remains deliberately narrow until every shipped client can parse the
-- broader Activity kind set.
create or replace function public.bil_list_community_notifications(
  p_limit integer default 30
)
returns table(
  id uuid,
  kind text,
  actor_id uuid,
  actor_display_name text,
  actor_avatar_url text,
  friendship_id uuid,
  created_at timestamptz,
  seen_at timestamptz
)
language plpgsql
stable
security definer
set search_path=''
as $$
declare v_uid uuid:=(select auth.uid());
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_limit is null or p_limit<1 or p_limit>100 then
    raise exception 'invalid_notification_limit' using errcode='22023';
  end if;

  return query
  select
    n.id,n.kind,n.actor_id,p.display_name,p.avatar_url,
    n.friendship_id,n.created_at,n.seen_at
  from public.bil_community_notifications n
  left join public.bil_public_profiles p on p.user_id=n.actor_id
  where n.recipient_id=v_uid
    and n.kind='friend_accepted'
    and (
      n.actor_id is null
      or (
        not exists(
          select 1
          from public.bil_blocks b
          where (b.blocker_id=v_uid and b.blocked_id=n.actor_id)
             or (b.blocker_id=n.actor_id and b.blocked_id=v_uid)
        )
        and not exists(
          select 1
          from private.bil_community_member_access a
          where a.user_id=n.actor_id and a.suspended
        )
      )
    )
  order by n.created_at desc,n.id desc
  limit p_limit;
end
$$;

create or replace function private.bil_attention_snapshot_v1(p_owner uuid)
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
with eligible_owner as (
  select p_owner as user_id
  where p_owner is not null
    and not exists(
      select 1
      from private.bil_community_member_access a
      where a.user_id=p_owner and a.suspended
    )
),
unread as (
  select m.sender_id,count(*)::integer as amount
  from public.bil_messages m
  join eligible_owner o on o.user_id=m.recipient_id
  where m.read_at is null
    and m.deleted_by_recipient_at is null
    and not exists(
      select 1 from public.bil_blocks b
      where (b.blocker_id=p_owner and b.blocked_id=m.sender_id)
         or (b.blocker_id=m.sender_id and b.blocked_id=p_owner)
    )
    and not exists(
      select 1 from private.bil_community_member_access a
      where a.user_id=m.sender_id and a.suspended
    )
  group by m.sender_id
),
requests as (
  select count(*)::integer as amount
  from public.bil_friendships f
  join eligible_owner o on o.user_id=f.addressee_id
  where f.status='pending'
    and not exists(
      select 1 from public.bil_blocks b
      where (b.blocker_id=p_owner and b.blocked_id=f.requester_id)
         or (b.blocker_id=f.requester_id and b.blocked_id=p_owner)
    )
    and not exists(
      select 1 from private.bil_community_member_access a
      where a.user_id=f.requester_id and a.suspended
    )
),
updates as (
  select count(*)::integer as amount
  from public.bil_community_notifications n
  join eligible_owner o on o.user_id=n.recipient_id
  where n.seen_at is null
    and n.kind='friend_accepted'
    and (
      n.actor_id is null
      or (
        not exists(
          select 1 from public.bil_blocks b
          where (b.blocker_id=p_owner and b.blocked_id=n.actor_id)
             or (b.blocker_id=n.actor_id and b.blocked_id=p_owner)
        )
        and not exists(
          select 1 from private.bil_community_member_access a
          where a.user_id=n.actor_id and a.suspended
        )
      )
    )
)
select pg_catalog.jsonb_build_object(
  'unread_messages',coalesce((select sum(amount) from unread),0),
  'incoming_requests',coalesce((select amount from requests),0),
  'community_updates',coalesce((select amount from updates),0),
  'unread_by_sender',coalesce(
    (select pg_catalog.jsonb_object_agg(sender_id::text,amount) from unread),
    '{}'::jsonb
  )
);
$$;

create or replace function public.bil_list_community_activity_v2(
  p_before timestamptz default null,
  p_before_id uuid default null,
  p_kinds text[] default null,
  p_limit integer default 30
)
returns table(
  id uuid,
  kind text,
  actor_id uuid,
  actor_display_name text,
  actor_avatar_url text,
  entity_kind text,
  entity_id text,
  copy_key text,
  deep_link_path text,
  metadata jsonb,
  created_at timestamptz,
  seen_at timestamptz
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
  if p_limit is null or p_limit<1 or p_limit>100 then
    raise exception 'invalid_activity_limit' using errcode='22023';
  end if;
  if (p_before is null)<>(p_before_id is null) then
    raise exception 'invalid_activity_cursor' using errcode='22023';
  end if;
  if p_kinds is not null and (
    cardinality(p_kinds)<1
    or cardinality(p_kinds)>20
    or exists(
      select 1
      from unnest(p_kinds) requested(kind)
      where requested.kind not in (
        'friend_request',
        'friend_accepted',
        'post_like',
        'post_save',
        'comment',
        'reply',
        'follow',
        'reward_earned',
        'quest_completed',
        'badge_earned',
        'challenge_update'
      )
    )
  ) then
    raise exception 'invalid_activity_kinds' using errcode='22023';
  end if;

  return query
  select
    n.id,n.kind,n.actor_id,p.display_name,p.avatar_url,
    n.entity_kind,n.entity_id,n.copy_key,n.deep_link_path,n.metadata,
    n.created_at,n.seen_at
  from public.bil_community_notifications n
  left join public.bil_public_profiles p on p.user_id=n.actor_id
  where n.recipient_id=v_uid
    and (p_kinds is null or n.kind=any(p_kinds))
    and (
      p_before is null
      or (n.created_at,n.id)<(p_before,p_before_id)
    )
    and (
      n.actor_id is null
      or (
        not exists(
          select 1
          from public.bil_blocks b
          where (b.blocker_id=v_uid and b.blocked_id=n.actor_id)
             or (b.blocker_id=n.actor_id and b.blocked_id=v_uid)
        )
        and not exists(
          select 1
          from private.bil_community_member_access a
          where a.user_id=n.actor_id and a.suspended
        )
      )
    )
  order by n.created_at desc,n.id desc
  limit p_limit;
end
$$;

create or replace function public.bil_mark_community_activity_seen_v2(
  p_ids uuid[]
)
returns integer
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_count integer;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_ids is null or cardinality(p_ids)=0 or cardinality(p_ids)>100 then
    raise exception 'invalid_activity_ids' using errcode='22023';
  end if;

  update public.bil_community_notifications
  set seen_at=coalesce(seen_at,pg_catalog.clock_timestamp())
  where recipient_id=v_uid
    and id=any(p_ids)
    and seen_at is null;
  get diagnostics v_count=row_count;
  return v_count;
end
$$;

create or replace function private.bil_attention_snapshot_v2(p_owner uuid)
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
with visible_unseen as (
  select n.kind
  from public.bil_community_notifications n
  where n.recipient_id=p_owner
    and n.seen_at is null
    and not exists(
      select 1
      from private.bil_community_member_access owner_access
      where owner_access.user_id=p_owner and owner_access.suspended
    )
    and (
      n.actor_id is null
      or (
        not exists(
          select 1
          from public.bil_blocks b
          where (b.blocker_id=p_owner and b.blocked_id=n.actor_id)
             or (b.blocker_id=n.actor_id and b.blocked_id=p_owner)
        )
        and not exists(
          select 1
          from private.bil_community_member_access actor_access
          where actor_access.user_id=n.actor_id and actor_access.suspended
        )
      )
    )
),
kind_counts as (
  select kind,count(*)::integer as amount
  from visible_unseen
  group by kind
),
base as (
  select private.bil_attention_snapshot_v1(p_owner) as snapshot
)
select
  (select snapshot from base)
  || pg_catalog.jsonb_build_object(
    'community_updates',
      coalesce((
        select sum(amount)
        from kind_counts
        where kind<>'friend_request'
      ),0),
    'activity_unseen_by_kind',
      coalesce(
        (select pg_catalog.jsonb_object_agg(kind,amount) from kind_counts),
        '{}'::jsonb
      )
  );
$$;

create or replace function public.bil_community_attention_v2()
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
begin
  if auth.uid() is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  return private.bil_attention_snapshot_v2(auth.uid());
end
$$;

revoke all on function public.bil_list_community_activity_v2(
  timestamptz,uuid,text[],integer
) from public,anon,service_role;
grant execute on function public.bil_list_community_activity_v2(
  timestamptz,uuid,text[],integer
) to authenticated;

revoke all on function public.bil_mark_community_activity_seen_v2(uuid[])
  from public,anon,service_role;
grant execute on function public.bil_mark_community_activity_seen_v2(uuid[])
  to authenticated;

revoke all on function private.bil_attention_snapshot_v2(uuid)
  from public,anon,authenticated,service_role;

revoke all on function public.bil_community_attention_v2()
  from public,anon,service_role;
grant execute on function public.bil_community_attention_v2()
  to authenticated;

do $$
begin
  if to_regprocedure('public.bil_list_community_activity_v2(timestamptz,uuid,text[],integer)') is null
     or to_regprocedure('public.bil_mark_community_activity_seen_v2(uuid[])') is null
     or to_regprocedure('private.bil_attention_snapshot_v2(uuid)') is null
     or to_regprocedure('public.bil_community_attention_v2()') is null then
    raise exception 'community_activity_v2_postcondition_failed';
  end if;
end
$$;
