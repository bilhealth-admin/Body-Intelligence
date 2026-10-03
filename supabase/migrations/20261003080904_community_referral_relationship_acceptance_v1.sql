set local lock_timeout='5s';
set local statement_timeout='30s';

do $$
begin
  if to_regclass('public.bil_community_referral_attributions') is null
     or to_regprocedure('public.bil_accept_community_invite_v1(text)') is null
     or to_regprocedure('private.bil_maybe_record_referral_reward_progress_v1(uuid)') is null then
    raise exception 'community_referral_foundation_missing';
  end if;
end
$$;

alter table public.bil_community_referral_attributions
  add column if not exists new_account_eligible boolean not null default false,
  add column if not exists friendship_id uuid
    references public.bil_friendships(id) on delete set null;

update public.bil_community_referral_attributions a
set new_account_eligible = coalesce((
  select u.created_at >= i.created_at
  from public.bil_community_invites i
  join auth.users u on u.id=a.invitee_id
  where i.id=a.invite_id
),false)
where not a.new_account_eligible;

create index if not exists bil_community_referral_friendship_idx
  on public.bil_community_referral_attributions(friendship_id)
  where friendship_id is not null;

create or replace function public.bil_enqueue_private_push()
returns trigger
language plpgsql
security definer
set search_path='public'
as $$
begin
  if tg_table_name = 'bil_messages' then
    insert into bil_push_outbox(recipient_id, category, body, deep_link)
    values(new.recipient_id, 'message', 'You have a new private message.',
           'bil://community/chat/' || new.sender_id::text);
  elsif tg_table_name = 'bil_friendships' and new.status='pending' then
    insert into bil_push_outbox(recipient_id, category, body, deep_link)
    values(new.addressee_id, 'friend_request', 'You have a new friend request.',
           'bil://community/connections');
  end if;
  return new;
end
$$;

create or replace function private.bil_maybe_record_referral_reward_progress_v1(
  p_attribution_id uuid
)
returns integer
language plpgsql
security definer
set search_path=''
as $$
declare
  v_attr public.bil_community_referral_attributions%rowtype;
  v_policy public.bil_community_referral_policy%rowtype;
  v_count integer:=0;
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'bil_referral_reward:'||p_attribution_id::text,0
    )
  );

  select * into v_attr
  from public.bil_community_referral_attributions a
  where a.id=p_attribution_id
  for update;

  if not found or v_attr.reward_recorded_at is not null then
    return 0;
  end if;

  select * into v_policy
  from public.bil_community_referral_policy p
  where p.singleton
  for share;

  if not found
     or not v_policy.reward_progress_enabled
     or not v_attr.new_account_eligible
     or v_attr.relationship_qualified_at is null
     or v_attr.integrity_state<>'verified'
     or not v_attr.reward_eligible then
    return 0;
  end if;

  v_count:=private.bil_record_community_action_v1(
    v_attr.inviter_id,
    'invite_friend_qualified',
    'referral-qualified:'||v_attr.id::text,
    'referral',
    v_attr.id::text
  );

  if v_count>0 then
    update public.bil_community_referral_attributions
    set reward_recorded_at=pg_catalog.clock_timestamp(),
        updated_at=pg_catalog.clock_timestamp()
    where id=v_attr.id;
  end if;

  return v_count;
end
$$;

create or replace function private.bil_accept_referral_friendship_v1(
  p_attribution_id uuid
)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare
  v_attr public.bil_community_referral_attributions%rowtype;
  v_friend public.bil_friendships%rowtype;
  v_friendship_id uuid;
  v_notification_id uuid;
begin
  select * into v_attr
  from public.bil_community_referral_attributions a
  where a.id=p_attribution_id
  for update;

  if not found then
    raise exception 'referral_attribution_not_found' using errcode='22023';
  end if;

  if exists(
    select 1
    from private.bil_community_member_access a
    where a.user_id in(v_attr.inviter_id,v_attr.invitee_id)
      and a.suspended
  ) or exists(
    select 1
    from public.bil_blocks b
    where (b.blocker_id=v_attr.inviter_id and b.blocked_id=v_attr.invitee_id)
       or (b.blocker_id=v_attr.invitee_id and b.blocked_id=v_attr.inviter_id)
  ) then
    raise exception 'referral_relationship_unavailable' using errcode='42501';
  end if;

  select * into v_friend
  from public.bil_friendships f
  where least(f.requester_id::text,f.addressee_id::text)
        =least(v_attr.inviter_id::text,v_attr.invitee_id::text)
    and greatest(f.requester_id::text,f.addressee_id::text)
        =greatest(v_attr.inviter_id::text,v_attr.invitee_id::text)
  limit 1
  for update;

  if found then
    if v_friend.status='declined' then
      raise exception 'referral_relationship_unavailable' using errcode='42501';
    end if;

    if v_friend.status='pending' then
      update public.bil_friendships
      set status='accepted',
          responded_at=pg_catalog.clock_timestamp()
      where id=v_friend.id;
    end if;

    v_friendship_id:=v_friend.id;
  else
    insert into public.bil_friendships(
      requester_id,
      addressee_id,
      status,
      responded_at
    )
    values(
      v_attr.inviter_id,
      v_attr.invitee_id,
      'accepted',
      pg_catalog.clock_timestamp()
    )
    returning id into v_friendship_id;

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
      v_attr.inviter_id,
      v_attr.invitee_id,
      'friend_accepted',
      v_friendship_id,
      'friend_accepted:'||v_friendship_id::text,
      'friendship',
      v_friendship_id::text,
      'friend_accepted_v1',
      '/community/notifications',
      pg_catalog.jsonb_build_object('source','community_referral')
    )
    on conflict(source_key) do nothing
    returning id into v_notification_id;

    if v_notification_id is not null then
      insert into public.bil_push_outbox(
        recipient_id,
        category,
        title,
        body,
        deep_link,
        copy_key,
        source_key
      )
      values(
        v_attr.inviter_id,
        'community',
        'BIL',
        'Your friend request was accepted.',
        'bil://community/notifications',
        'friend_accepted_v1',
        'friend_accepted:'||v_friendship_id::text
      )
      on conflict(recipient_id,source_key)
        where source_key is not null
      do nothing;
    end if;
  end if;

  update public.bil_community_referral_attributions
  set friendship_id=v_friendship_id,
      relationship_qualified_at=coalesce(
        relationship_qualified_at,
        pg_catalog.clock_timestamp()
      ),
      updated_at=pg_catalog.clock_timestamp()
  where id=v_attr.id;

  perform private.bil_maybe_record_referral_reward_progress_v1(v_attr.id);

  return v_friendship_id;
end
$$;

revoke all on function private.bil_accept_referral_friendship_v1(uuid)
  from public,anon,authenticated,service_role;

create or replace function public.bil_accept_community_invite_v1(
  p_token text
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_invitee uuid:=(select auth.uid());
  v_policy public.bil_community_referral_policy%rowtype;
  v_invite public.bil_community_invites%rowtype;
  v_existing public.bil_community_referral_attributions%rowtype;
  v_hash text;
  v_attribution uuid;
  v_friendship uuid;
  v_name text;
  v_avatar text;
  v_handle text;
  v_new_account boolean;
begin
  if v_invitee is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if exists(
    select 1 from private.bil_community_member_access a
    where a.user_id=v_invitee and a.suspended
  ) then
    raise exception 'community_access_suspended' using errcode='42501';
  end if;
  if p_token is null or p_token !~ '^[0-9a-f]{48}$' then
    return pg_catalog.jsonb_build_object('status','invalid');
  end if;

  select * into v_policy
  from public.bil_community_referral_policy p
  where p.singleton
  for share;

  if not found or not v_policy.invite_links_enabled then
    return pg_catalog.jsonb_build_object('status','disabled');
  end if;

  v_hash:=encode(extensions.digest(p_token,'sha256'),'hex');

  select * into v_invite
  from public.bil_community_invites i
  where i.token_hash=v_hash
  for update;

  if not found
     or v_invite.revoked_at is not null
     or v_invite.expires_at<=pg_catalog.clock_timestamp() then
    return pg_catalog.jsonb_build_object('status','invalid');
  end if;

  if v_invite.inviter_id=v_invitee then
    return pg_catalog.jsonb_build_object('status','self_invite');
  end if;

  if exists(
    select 1 from private.bil_community_member_access a
    where a.user_id=v_invite.inviter_id and a.suspended
  ) or exists(
    select 1 from public.bil_blocks b
    where (b.blocker_id=v_invitee and b.blocked_id=v_invite.inviter_id)
       or (b.blocker_id=v_invite.inviter_id and b.blocked_id=v_invitee)
  ) then
    return pg_catalog.jsonb_build_object('status','unavailable');
  end if;

  select * into v_existing
  from public.bil_community_referral_attributions a
  where a.invitee_id=v_invitee
  for update;

  if found then
    if v_existing.invite_id=v_invite.id then
      v_friendship:=private.bil_accept_referral_friendship_v1(v_existing.id);
      return pg_catalog.jsonb_build_object(
        'status','attributed',
        'duplicate',true,
        'attribution_id',v_existing.id,
        'inviter_id',v_existing.inviter_id,
        'friendship_id',v_friendship,
        'relationship','accepted'
      );
    end if;
    return pg_catalog.jsonb_build_object('status','already_attributed');
  end if;

  if v_invite.consumed_at is not null then
    return pg_catalog.jsonb_build_object('status','consumed');
  end if;

  select coalesce(u.created_at>=v_invite.created_at,false)
  into v_new_account
  from auth.users u
  where u.id=v_invitee;

  insert into public.bil_community_referral_attributions(
    invite_id,
    inviter_id,
    invitee_id,
    new_account_eligible
  )
  values(
    v_invite.id,
    v_invite.inviter_id,
    v_invitee,
    coalesce(v_new_account,false)
  )
  returning id into v_attribution;

  update public.bil_community_invites
  set consumed_at=pg_catalog.clock_timestamp()
  where id=v_invite.id;

  v_friendship:=private.bil_accept_referral_friendship_v1(v_attribution);

  select p.display_name,p.avatar_url
  into v_name,v_avatar
  from public.bil_public_profiles p
  where p.user_id=v_invite.inviter_id;

  select h.handle into v_handle
  from public.bil_social_handles_v2 h
  where h.user_id=v_invite.inviter_id and h.chosen;

  return pg_catalog.jsonb_build_object(
    'status','attributed',
    'duplicate',false,
    'attribution_id',v_attribution,
    'inviter_id',v_invite.inviter_id,
    'display_name',coalesce(v_name,'BIL member'),
    'avatar_url',v_avatar,
    'handle',v_handle,
    'friendship_id',v_friendship,
    'relationship','accepted',
    'new_account_eligible',coalesce(v_new_account,false)
  );
end
$$;

do $$
begin
  if to_regprocedure('private.bil_accept_referral_friendship_v1(uuid)') is null then
    raise exception 'community_referral_relationship_postcondition_failed';
  end if;
end
$$;
