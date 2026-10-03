set local lock_timeout='5s';
set local statement_timeout='30s';

do $preflight$
begin
  if to_regclass('public.bil_community_post_collaborators_v1') is null
     or to_regclass('public.bil_community_notifications') is null
     or to_regprocedure(
       'private.bil_activity_pair_allowed_v1(uuid,uuid)'
     ) is null
     or to_regprocedure(
       'private.bil_emit_community_activity_v2(uuid,uuid,text,text,text,text,text,text,jsonb)'
     ) is null
     or to_regprocedure(
       'public.bil_list_community_activity_v2(timestamptz,uuid,text[],integer)'
     ) is null then
    raise exception 'community_reference_collaboration_dependencies_missing';
  end if;
  if to_regprocedure(
    'public.bil_respond_community_collaboration_v1(uuid,boolean)'
  ) is not null then
    raise exception 'community_reference_collaboration_v1_already_exists';
  end if;
end
$preflight$;

alter table public.bil_community_notifications
  drop constraint bil_community_notifications_kind_check;
alter table public.bil_community_notifications
  add constraint bil_community_notifications_kind_check check(
    kind in(
      'friend_request',
      'friend_accepted',
      'post_like',
      'post_save',
      'comment',
      'reply',
      'follow',
      'mention',
      'reward_earned',
      'quest_completed',
      'badge_earned',
      'challenge_update',
      'collaboration_invite',
      'collaboration_accepted'
    )
  );

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
        'mention',
        'reward_earned',
        'quest_completed',
        'badge_earned',
        'challenge_update',
        'collaboration_invite',
        'collaboration_accepted'
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

create or replace function private.bil_emit_post_collaboration_on_approval_v1()
returns trigger
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  v_collaborator record;
begin
  if old.moderation_status is distinct from 'approved'
     and new.moderation_status='approved'
     and new.deleted_at is null then
    for v_collaborator in
      select c.collaborator_id
      from public.bil_community_post_collaborators_v1 c
      where c.post_id=new.id and c.status='pending'
    loop
      if private.bil_activity_pair_allowed_v1(
        v_collaborator.collaborator_id,new.author_id
      ) then
        perform private.bil_emit_community_activity_v2(
          v_collaborator.collaborator_id,
          new.author_id,
          'collaboration_invite',
          'post_collab_invite:'||new.id::text||':'||
            v_collaborator.collaborator_id::text,
          'post',
          new.id::text,
          'post_collaboration_invite_v1',
          '/community',
          pg_catalog.jsonb_build_object('post_id',new.id::text)
        );
      end if;
    end loop;
  end if;
  return new;
end
$$;

revoke all on function private.bil_emit_post_collaboration_on_approval_v1()
  from public,anon,authenticated,service_role;

create trigger bil_post_collaboration_activity_v1
after update of moderation_status on public.bil_community_posts
for each row
execute function private.bil_emit_post_collaboration_on_approval_v1();

create or replace function public.bil_respond_community_collaboration_v1(
  p_post_id uuid,
  p_accept boolean
)
returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_author uuid;
  v_current text;
  v_next text;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_post_id is null or p_accept is null then
    raise exception 'invalid_community_collaboration_response'
      using errcode='22023';
  end if;

  select p.author_id into v_author
  from public.bil_community_posts p
  where p.id=p_post_id
    and p.deleted_at is null
    and p.moderation_status='approved';

  if v_author is null then
    raise exception 'community_collaboration_post_unavailable'
      using errcode='42501';
  end if;

  if not private.bil_activity_pair_allowed_v1(v_author,v_uid) then
    raise exception 'community_collaboration_unavailable'
      using errcode='42501';
  end if;

  select c.status into v_current
  from public.bil_community_post_collaborators_v1 c
  where c.post_id=p_post_id and c.collaborator_id=v_uid
  for update;

  if not found then
    raise exception 'community_collaboration_unavailable'
      using errcode='42501';
  end if;

  v_next:=case when p_accept then 'accepted' else 'declined' end;

  if v_current<>'pending' then
    if v_current=v_next then
      return pg_catalog.jsonb_build_object(
        'post_id',p_post_id,
        'status',v_current,
        'duplicate',true
      );
    end if;
    raise exception 'community_collaboration_already_responded'
      using errcode='23505';
  end if;

  update public.bil_community_post_collaborators_v1 c
  set status=v_next,
      responded_at=pg_catalog.clock_timestamp()
  where c.post_id=p_post_id
    and c.collaborator_id=v_uid
    and c.status='pending';

  if p_accept then
    perform private.bil_emit_community_activity_v2(
      v_author,
      v_uid,
      'collaboration_accepted',
      'post_collab_accepted:'||p_post_id::text||':'||v_uid::text,
      'post',
      p_post_id::text,
      'post_collaboration_accepted_v1',
      '/community',
      pg_catalog.jsonb_build_object('post_id',p_post_id::text)
    );
  end if;

  return pg_catalog.jsonb_build_object(
    'post_id',p_post_id,
    'status',v_next,
    'duplicate',false
  );
end
$$;

revoke all on function public.bil_respond_community_collaboration_v1(
  uuid,boolean
) from public,anon,service_role;
grant execute on function public.bil_respond_community_collaboration_v1(
  uuid,boolean
) to authenticated;

do $postconditions$
begin
  if to_regprocedure(
      'public.bil_respond_community_collaboration_v1(uuid,boolean)'
    ) is null
    or not exists(
      select 1 from pg_catalog.pg_trigger t
      where t.tgrelid='public.bil_community_posts'::regclass
        and t.tgname='bil_post_collaboration_activity_v1'
        and not t.tgisinternal
    ) then
    raise exception 'community_reference_collaboration_postcondition_failed';
  end if;
end
$postconditions$;
