
-- Community referral / invite attribution v1.
-- Backend attribution is provider-neutral. Production remains fail-closed:
-- invite links and reward progression are both disabled until a verified
-- deferred-install/integrity provider is configured.
set local lock_timeout='5s';
set local statement_timeout='30s';

do $$
begin
  if to_regclass('public.bil_community_referral_policy') is not null
     or to_regclass('public.bil_community_invites') is not null
     or to_regclass('public.bil_community_referral_attributions') is not null then
    raise exception 'community_referral_v1_already_exists';
  end if;
  if to_regprocedure(
    'private.bil_record_community_action_v1(uuid,text,text,text,text)'
  ) is null then
    raise exception 'community_quest_reward_engine_required';
  end if;
end
$$;

create table public.bil_community_referral_policy (
  singleton boolean primary key default true check(singleton),
  invite_links_enabled boolean not null default false,
  reward_progress_enabled boolean not null default false,
  invite_ttl_days integer not null default 30
    check(invite_ttl_days between 1 and 90),
  max_invites_per_owner_per_utc_day integer not null default 20
    check(max_invites_per_owner_per_utc_day between 1 and 100),
  updated_at timestamptz not null default pg_catalog.clock_timestamp()
);

insert into public.bil_community_referral_policy(singleton) values(true);

create table public.bil_community_invites (
  id uuid primary key default gen_random_uuid(),
  inviter_id uuid not null references auth.users(id) on delete cascade,
  token_hash text not null unique
    check(token_hash ~ '^[0-9a-f]{64}$'),
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  expires_at timestamptz not null,
  revoked_at timestamptz,
  consumed_at timestamptz,
  constraint bil_community_invite_window
    check(expires_at>created_at),
  constraint bil_community_invite_revoked_time
    check(revoked_at is null or revoked_at>=created_at),
  constraint bil_community_invite_consumed_time
    check(consumed_at is null or consumed_at>=created_at)
);

create index bil_community_invites_owner_history_idx
  on public.bil_community_invites(inviter_id,created_at desc,id desc);

create index bil_community_invites_active_idx
  on public.bil_community_invites(expires_at,id)
  where revoked_at is null and consumed_at is null;

create table public.bil_community_referral_attributions (
  id uuid primary key default gen_random_uuid(),
  invite_id uuid not null unique
    references public.bil_community_invites(id) on delete restrict,
  inviter_id uuid not null references auth.users(id) on delete cascade,
  invitee_id uuid not null unique references auth.users(id) on delete cascade,
  attributed_at timestamptz not null default pg_catalog.clock_timestamp(),
  relationship_qualified_at timestamptz,
  integrity_state text not null default 'pending'
    check(integrity_state in ('pending','verified','rejected')),
  integrity_provider text
    check(
      integrity_provider is null
      or integrity_provider ~ '^[a-z][a-z0-9_]{2,47}$'
    ),
  integrity_receipt_hash text
    check(
      integrity_receipt_hash is null
      or integrity_receipt_hash ~ '^[0-9a-f]{64}$'
    ),
  reward_eligible boolean not null default false,
  reward_recorded_at timestamptz,
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  constraint bil_community_referral_distinct_pair
    check(inviter_id<>invitee_id),
  constraint bil_community_referral_integrity_contract check(
    (
      integrity_state='pending'
      and integrity_provider is null
      and integrity_receipt_hash is null
      and reward_eligible=false
    )
    or
    (
      integrity_state='verified'
      and integrity_provider is not null
      and integrity_receipt_hash is not null
      and reward_eligible=true
    )
    or
    (
      integrity_state='rejected'
      and integrity_provider is not null
      and integrity_receipt_hash is not null
      and reward_eligible=false
    )
  ),
  constraint bil_community_referral_recorded_contract check(
    reward_recorded_at is null
    or (
      relationship_qualified_at is not null
      and integrity_state='verified'
      and reward_eligible
    )
  )
);

create index bil_community_referral_inviter_history_idx
  on public.bil_community_referral_attributions(
    inviter_id,attributed_at desc,id desc
  );

alter table public.bil_community_referral_policy enable row level security;
alter table public.bil_community_invites enable row level security;
alter table public.bil_community_referral_attributions enable row level security;

revoke all on table public.bil_community_referral_policy
  from public,anon,authenticated,service_role;
revoke all on table public.bil_community_invites
  from public,anon,authenticated,service_role;
revoke all on table public.bil_community_referral_attributions
  from public,anon,authenticated,service_role;

create or replace function public.bil_create_community_invite_v1()
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_owner uuid:=(select auth.uid());
  v_policy public.bil_community_referral_policy%rowtype;
  v_token text;
  v_hash text;
  v_invite_id uuid;
  v_expires timestamptz;
  v_today timestamptz:=
    pg_catalog.date_trunc('day',pg_catalog.clock_timestamp() at time zone 'UTC')
      at time zone 'UTC';
  v_count integer;
begin
  if v_owner is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if exists(
    select 1 from private.bil_community_member_access a
    where a.user_id=v_owner and a.suspended
  ) then
    raise exception 'community_access_suspended' using errcode='42501';
  end if;
  if not exists(
    select 1 from public.bil_public_profiles p where p.user_id=v_owner
  ) then
    raise exception 'community_profile_required' using errcode='42501';
  end if;

  select * into v_policy
  from public.bil_community_referral_policy p
  where p.singleton
  for share;

  if not found or not v_policy.invite_links_enabled then
    return pg_catalog.jsonb_build_object('status','disabled');
  end if;

  select count(*)::integer into v_count
  from public.bil_community_invites i
  where i.inviter_id=v_owner
    and i.created_at>=v_today;

  if v_count>=v_policy.max_invites_per_owner_per_utc_day then
    return pg_catalog.jsonb_build_object(
      'status','rate_limited',
      'retry_after','next_utc_day'
    );
  end if;

  v_token:=encode(extensions.gen_random_bytes(24),'hex');
  v_hash:=encode(extensions.digest(v_token,'sha256'),'hex');
  v_expires:=pg_catalog.clock_timestamp()
    + pg_catalog.make_interval(days=>v_policy.invite_ttl_days);

  insert into public.bil_community_invites(
    inviter_id,token_hash,expires_at
  ) values(v_owner,v_hash,v_expires)
  returning id into v_invite_id;

  return pg_catalog.jsonb_build_object(
    'status','active',
    'invite_id',v_invite_id,
    'token',v_token,
    'url','https://www.bilhealth.com/invite/'||v_token,
    'expires_at',v_expires
  );
end
$$;

create or replace function public.bil_preview_community_invite_v1(
  p_token text
)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_policy public.bil_community_referral_policy%rowtype;
  v_invite public.bil_community_invites%rowtype;
  v_hash text;
  v_name text;
  v_avatar text;
  v_handle text;
begin
  if p_token is null or p_token !~ '^[0-9a-f]{48}$' then
    return pg_catalog.jsonb_build_object('status','invalid');
  end if;

  select * into v_policy
  from public.bil_community_referral_policy p
  where p.singleton;

  if not found or not v_policy.invite_links_enabled then
    return pg_catalog.jsonb_build_object('status','disabled');
  end if;

  v_hash:=encode(extensions.digest(p_token,'sha256'),'hex');

  select * into v_invite
  from public.bil_community_invites i
  where i.token_hash=v_hash
    and i.revoked_at is null
    and i.consumed_at is null
    and i.expires_at>pg_catalog.clock_timestamp();

  if not found then
    return pg_catalog.jsonb_build_object('status','invalid');
  end if;

  if exists(
    select 1 from private.bil_community_member_access a
    where a.user_id=v_invite.inviter_id and a.suspended
  ) then
    return pg_catalog.jsonb_build_object('status','invalid');
  end if;

  select p.display_name,p.avatar_url
  into v_name,v_avatar
  from public.bil_public_profiles p
  where p.user_id=v_invite.inviter_id;

  select h.handle into v_handle
  from public.bil_social_handles_v2 h
  where h.user_id=v_invite.inviter_id and h.chosen;

  return pg_catalog.jsonb_build_object(
    'status','active',
    'inviter_id',v_invite.inviter_id,
    'display_name',coalesce(v_name,'BIL member'),
    'avatar_url',v_avatar,
    'handle',v_handle,
    'expires_at',v_invite.expires_at
  );
end
$$;

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
  v_name text;
  v_avatar text;
  v_handle text;
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
  where a.invitee_id=v_invitee;

  if found then
    if v_existing.invite_id=v_invite.id then
      return pg_catalog.jsonb_build_object(
        'status','attributed',
        'duplicate',true,
        'attribution_id',v_existing.id,
        'inviter_id',v_existing.inviter_id
      );
    end if;
    return pg_catalog.jsonb_build_object('status','already_attributed');
  end if;

  if v_invite.consumed_at is not null then
    return pg_catalog.jsonb_build_object('status','consumed');
  end if;

  insert into public.bil_community_referral_attributions(
    invite_id,inviter_id,invitee_id
  ) values(v_invite.id,v_invite.inviter_id,v_invitee)
  returning id into v_attribution;

  update public.bil_community_invites
  set consumed_at=pg_catalog.clock_timestamp()
  where id=v_invite.id;

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
    'handle',v_handle
  );
end
$$;

create or replace function public.bil_my_community_referral_v1()
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_owner uuid:=(select auth.uid());
  v_attr public.bil_community_referral_attributions%rowtype;
  v_name text;
  v_avatar text;
  v_handle text;
begin
  if v_owner is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;

  select * into v_attr
  from public.bil_community_referral_attributions a
  where a.invitee_id=v_owner;

  if not found then
    return null;
  end if;

  select p.display_name,p.avatar_url
  into v_name,v_avatar
  from public.bil_public_profiles p
  where p.user_id=v_attr.inviter_id;

  select h.handle into v_handle
  from public.bil_social_handles_v2 h
  where h.user_id=v_attr.inviter_id and h.chosen;

  return pg_catalog.jsonb_build_object(
    'attribution_id',v_attr.id,
    'inviter_id',v_attr.inviter_id,
    'display_name',coalesce(v_name,'BIL member'),
    'avatar_url',v_avatar,
    'handle',v_handle,
    'relationship_qualified',v_attr.relationship_qualified_at is not null,
    'integrity_state',v_attr.integrity_state,
    'reward_recorded',v_attr.reward_recorded_at is not null,
    'attributed_at',v_attr.attributed_at
  );
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

create or replace function private.bil_qualify_referral_friendship_v1()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  v_attribution uuid;
begin
  if old.status='pending' and new.status='accepted' then
    select a.id into v_attribution
    from public.bil_community_referral_attributions a
    where a.relationship_qualified_at is null
      and (
        (
          a.inviter_id=new.requester_id
          and a.invitee_id=new.addressee_id
        )
        or
        (
          a.inviter_id=new.addressee_id
          and a.invitee_id=new.requester_id
        )
      )
    limit 1
    for update;

    if v_attribution is not null then
      update public.bil_community_referral_attributions
      set relationship_qualified_at=pg_catalog.clock_timestamp(),
          updated_at=pg_catalog.clock_timestamp()
      where id=v_attribution;

      perform private.bil_maybe_record_referral_reward_progress_v1(
        v_attribution
      );
    end if;
  end if;
  return new;
end
$$;

create trigger bil_friendship_referral_qualification
after update of status on public.bil_friendships
for each row
execute function private.bil_qualify_referral_friendship_v1();

create or replace function public.bil_set_community_referral_integrity_v1(
  p_attribution_id uuid,
  p_verified boolean,
  p_provider text,
  p_receipt_hash text
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_count integer:=0;
begin
  if auth.role()<>'service_role' then
    raise exception 'service_role_required' using errcode='42501';
  end if;
  if p_attribution_id is null
     or p_verified is null
     or p_provider is null
     or p_provider !~ '^[a-z][a-z0-9_]{2,47}$'
     or p_receipt_hash is null
     or p_receipt_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'referral_integrity_input_invalid' using errcode='22023';
  end if;

  update public.bil_community_referral_attributions
  set integrity_state=case when p_verified then 'verified' else 'rejected' end,
      integrity_provider=p_provider,
      integrity_receipt_hash=p_receipt_hash,
      reward_eligible=p_verified,
      updated_at=pg_catalog.clock_timestamp()
  where id=p_attribution_id;

  if not found then
    return pg_catalog.jsonb_build_object('status','not_found');
  end if;

  if p_verified then
    v_count:=private.bil_maybe_record_referral_reward_progress_v1(
      p_attribution_id
    );
  end if;

  return pg_catalog.jsonb_build_object(
    'status',case when p_verified then 'verified' else 'rejected' end,
    'reward_progress_count',v_count
  );
end
$$;

create or replace function public.bil_reconcile_community_referral_v1(
  p_attribution_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_count integer;
begin
  if auth.role()<>'service_role' then
    raise exception 'service_role_required' using errcode='42501';
  end if;
  if p_attribution_id is null then
    raise exception 'referral_attribution_id_required' using errcode='22023';
  end if;
  v_count:=private.bil_maybe_record_referral_reward_progress_v1(
    p_attribution_id
  );
  return pg_catalog.jsonb_build_object(
    'status','reconciled',
    'reward_progress_count',v_count
  );
end
$$;

revoke all on function public.bil_create_community_invite_v1()
  from public,anon,service_role;
grant execute on function public.bil_create_community_invite_v1()
  to authenticated;

revoke all on function public.bil_preview_community_invite_v1(text)
  from public,service_role;
grant execute on function public.bil_preview_community_invite_v1(text)
  to anon,authenticated;

revoke all on function public.bil_accept_community_invite_v1(text)
  from public,anon,service_role;
grant execute on function public.bil_accept_community_invite_v1(text)
  to authenticated;

revoke all on function public.bil_my_community_referral_v1()
  from public,anon,service_role;
grant execute on function public.bil_my_community_referral_v1()
  to authenticated;

revoke all on function private.bil_maybe_record_referral_reward_progress_v1(uuid)
  from public,anon,authenticated,service_role;
revoke all on function private.bil_qualify_referral_friendship_v1()
  from public,anon,authenticated,service_role;

revoke all on function public.bil_set_community_referral_integrity_v1(
  uuid,boolean,text,text
) from public,anon,authenticated;
grant execute on function public.bil_set_community_referral_integrity_v1(
  uuid,boolean,text,text
) to service_role;

revoke all on function public.bil_reconcile_community_referral_v1(uuid)
  from public,anon,authenticated;
grant execute on function public.bil_reconcile_community_referral_v1(uuid)
  to service_role;

do $$
begin
  if to_regprocedure('public.bil_create_community_invite_v1()') is null
     or to_regprocedure('public.bil_preview_community_invite_v1(text)') is null
     or to_regprocedure('public.bil_accept_community_invite_v1(text)') is null
     or to_regprocedure('public.bil_my_community_referral_v1()') is null
     or to_regprocedure('private.bil_maybe_record_referral_reward_progress_v1(uuid)') is null
     or to_regprocedure('public.bil_set_community_referral_integrity_v1(uuid,boolean,text,text)') is null
     or to_regprocedure('public.bil_reconcile_community_referral_v1(uuid)') is null then
    raise exception 'community_referral_v1_postcondition_failed';
  end if;
end
$$;
