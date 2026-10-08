-- BIL-07 / BASE 1744788e6bfbdffc3a168bbaf36b3abf3e2c698a
-- UNPUBLISHED forward-only proposal. The bundled runner uses a fresh loopback
-- PostgreSQL database. No production migration, publication, seed or grant to
-- a live deployment is authorized by this file.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $preflight$
begin
  if current_database() !~ '^bil07_local_[a-z0-9_]+$'
     or coalesce(pg_catalog.host(inet_server_addr()), '') not in ('127.0.0.1', '::1')
     or current_setting('server_encoding') <> 'UTF8' then
    raise exception 'bil07_requires_disposable_loopback_utf8'
      using errcode = '55000';
  end if;
  if to_regclass('auth.users') is null
     or to_regclass('public.bil_public_profiles') is null
     or to_regclass('public.bil_content_policies') is null
     or to_regprocedure('auth.uid()') is null
     or to_regprocedure('public.bil_can_use_community()') is null
     or to_regprocedure('public.bil_assert_community_publish_ready()') is null
     or to_regprocedure('public.bil_social_member_visible_v2(uuid)') is null
     or to_regprocedure('public.bil_social_profile_visible_v2(uuid)') is null
     or to_regprocedure('public.bil_community_contact_exchange_violation(text)') is null then
    raise exception 'bil07_base_dependencies_missing' using errcode = '55000';
  end if;
  if to_regclass('public.bil07_channels_v1') is not null
     or to_regprocedure('public.bil07_channel_capabilities_v1()') is not null then
    raise exception 'bil07_contract_already_exists' using errcode = '55000';
  end if;
end
$preflight$;

create table public.bil07_channels_v1 (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  slug text not null unique
    check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and char_length(slug) <= 48),
  title text not null check (char_length(title) between 1 and 100),
  description text not null default '' check (char_length(description) <= 600),
  visibility text not null default 'public'
    check (visibility in ('public', 'members')),
  enabled boolean not null default true,
  -- A transactional row counter, deliberately NOT a PostgreSQL sequence.
  -- Increment and insert hold this channel's row lock until commit/rollback.
  latest_sequence bigint not null default 0
    check (latest_sequence between 0 and 9007199254740991),
  created_at timestamptz not null default pg_catalog.clock_timestamp()
);

create table public.bil07_channel_memberships_v1 (
  channel_id uuid not null references public.bil07_channels_v1(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  status text not null check (status in ('active', 'banned')),
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  primary key (channel_id, owner_id)
);
create index bil07_memberships_owner_v1
  on public.bil07_channel_memberships_v1(owner_id, status, channel_id);

create table public.bil07_channel_messages_v1 (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  channel_id uuid not null references public.bil07_channels_v1(id) on delete cascade,
  sequence bigint not null check (sequence between 1 and 9007199254740991),
  author_id uuid not null references auth.users(id) on delete cascade,
  client_message_id uuid not null,
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  removed_at timestamptz,
  unique (channel_id, sequence),
  unique (channel_id, id),
  unique (channel_id, author_id, client_message_id)
);
create index bil07_messages_author_v1
  on public.bil07_channel_messages_v1(author_id, channel_id);
create index bil07_messages_visible_page_v1
  on public.bil07_channel_messages_v1(channel_id, sequence)
  where removed_at is null;

create table public.bil07_channel_reads_v1 (
  channel_id uuid not null,
  owner_id uuid not null references auth.users(id) on delete cascade,
  message_id uuid not null,
  read_at timestamptz not null default pg_catalog.clock_timestamp(),
  primary key (channel_id, owner_id, message_id),
  foreign key (channel_id, message_id)
    references public.bil07_channel_messages_v1(channel_id, id) on delete cascade
);
create index bil07_reads_owner_v1
  on public.bil07_channel_reads_v1(owner_id, channel_id, message_id);
create index bil07_reads_message_v1
  on public.bil07_channel_reads_v1(channel_id, message_id);

create table public.bil07_channel_presence_v1 (
  channel_id uuid not null references public.bil07_channels_v1(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  heartbeat_at timestamptz not null,
  expires_at timestamptz not null,
  primary key (channel_id, owner_id),
  check (expires_at = heartbeat_at + interval '90 seconds')
);
create index bil07_presence_owner_v1
  on public.bil07_channel_presence_v1(owner_id, channel_id);
create index bil07_presence_expiry_v1
  on public.bil07_channel_presence_v1(channel_id, expires_at, owner_id);

-- Tables are deliberately RPC-only. Default-deny RLS is a second boundary
-- behind the revoked grants. There are no broad/permissive client policies.
alter table public.bil07_channels_v1 enable row level security;
alter table public.bil07_channel_memberships_v1 enable row level security;
alter table public.bil07_channel_messages_v1 enable row level security;
alter table public.bil07_channel_reads_v1 enable row level security;
alter table public.bil07_channel_presence_v1 enable row level security;
revoke all on table
  public.bil07_channels_v1, public.bil07_channel_memberships_v1,
  public.bil07_channel_messages_v1, public.bil07_channel_reads_v1,
  public.bil07_channel_presence_v1
  from public, anon, authenticated, service_role;

-- Helpers are invokers; they run inside the narrowly granted private
-- definer endpoints. No helper accepts an actor/owner supplied by a caller.
create function private.bil07_actor_v1()
returns uuid language plpgsql volatile security invoker set search_path = ''
as $fn$
declare v_owner uuid := (select auth.uid());
begin
  if v_owner is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if not public.bil_can_use_community() then
    raise exception 'community_access_suspended' using errcode = '42501';
  end if;
  return v_owner;
end
$fn$;

create function private.bil07_require_channel_v1(
  p_channel_id uuid, p_send boolean default false
)
returns public.bil07_channels_v1
language plpgsql volatile security invoker set search_path = ''
as $fn$
declare
  v_owner uuid := private.bil07_actor_v1();
  v_channel public.bil07_channels_v1%rowtype;
  v_membership text;
begin
  if p_channel_id is null or p_send is null then
    raise exception 'channel_invalid_request' using errcode = '22023';
  end if;
  if p_send then
    select * into v_channel from public.bil07_channels_v1 c
      where c.id = p_channel_id for update;
  else
    select * into v_channel from public.bil07_channels_v1 c
      where c.id = p_channel_id for share;
  end if;
  if not found or not v_channel.enabled then
    raise exception 'channel_unavailable' using errcode = '42501';
  end if;
  select m.status into v_membership
    from public.bil07_channel_memberships_v1 m
    where m.channel_id = p_channel_id and m.owner_id = v_owner for share;
  if v_membership = 'banned'
     or (v_channel.visibility = 'members' and v_membership is distinct from 'active') then
    raise exception 'channel_unavailable' using errcode = '42501';
  end if;
  if p_send and v_membership is distinct from 'active' then
    raise exception 'channel_membership_required' using errcode = '42501';
  end if;
  return v_channel;
end
$fn$;

create function private.bil07_validate_text_v1(p_text text)
returns void language plpgsql immutable security invoker set search_path = ''
as $fn$
declare
  v_space text := U&'\0009\000a\000d\0020\00a0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200a\2028\2029\202f\205f\3000\feff';
  v_reason text;
begin
  -- Unicode scalar/code-point count matches Dart String.runes.length.
  -- Preserve p_text byte-for-byte: no btrim, normalization or truncation.
  if p_text is null or char_length(p_text) not between 1 and 2000
     or pg_catalog.translate(p_text, v_space, '') = ''
     or exists (
       select 1 from pg_catalog.generate_series(1, char_length(p_text)) i
       where pg_catalog.ascii(pg_catalog.substr(p_text, i, 1))
         in (1,2,3,4,5,6,7,8,11,12,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,127)
     ) then
    -- PostgreSQL rejects U+0000 before a value can enter a text argument.
    raise exception 'channel_invalid_text' using errcode = '22023';
  end if;
  v_reason := public.bil_community_contact_exchange_violation(p_text);
  if v_reason is not null then
    raise exception 'community_contact_exchange_not_allowed'
      using errcode = 'P0001', detail = 'surface=channel;reason=' || v_reason;
  end if;
end
$fn$;

create function private.bil07_unread_v1(p_channel_id uuid)
returns bigint language sql stable security invoker set search_path = ''
as $fn$
  select count(*)
  from public.bil07_channel_messages_v1 m
  where m.channel_id = p_channel_id and m.removed_at is null
    and m.author_id <> (select auth.uid())
    and public.bil_social_member_visible_v2(m.author_id)
    and not exists (
      select 1 from public.bil07_channel_reads_v1 r
      where r.channel_id = m.channel_id and r.message_id = m.id
        and r.owner_id = (select auth.uid())
    );
$fn$;

create function private.bil07_message_json_v1(
  p_message public.bil07_channel_messages_v1
)
returns jsonb language sql stable security invoker set search_path = ''
as $fn$
  select pg_catalog.jsonb_build_object(
    'id', p_message.id, 'channel_id', p_message.channel_id,
    'sequence', p_message.sequence, 'author_id', p_message.author_id,
    'author_display_name', (
      select p.display_name from public.bil_public_profiles p
      where p.user_id = p_message.author_id
        and (p.user_id = (select auth.uid())
          or public.bil_social_profile_visible_v2(p.user_id))
    ),
    'text', p_message.body,
    'client_message_id', case
      when p_message.author_id = (select auth.uid()) then p_message.client_message_id
      else null end,
    'created_at', p_message.created_at,
    'is_read', p_message.author_id = (select auth.uid()) or exists (
      select 1 from public.bil07_channel_reads_v1 r
      where r.channel_id = p_message.channel_id and r.message_id = p_message.id
        and r.owner_id = (select auth.uid())
    )
  );
$fn$;

create function private.bil07_validate_receipts_v1(p_message_ids uuid[])
returns void language plpgsql immutable security invoker set search_path = ''
as $fn$
begin
  if p_message_ids is null or cardinality(p_message_ids) > 100
     or array_position(p_message_ids, null) is not null
     or coalesce(array_ndims(p_message_ids), 1) <> 1 then
    raise exception 'channel_invalid_receipts' using errcode = '22023';
  end if;
end
$fn$;

create function private.bil07_channel_capabilities_v1()
returns jsonb language plpgsql volatile security definer set search_path = ''
as $fn$
declare v_owner uuid := private.bil07_actor_v1();
begin
  return pg_catalog.jsonb_build_object(
    'contract_version', 1, 'owner_id', v_owner,
    'server_time', pg_catalog.clock_timestamp(),
    'max_text_code_points', 2000, 'max_page_size', 100,
    'max_receipt_ids', 100, 'read_receipts', 'exact_message_ids_v1',
    'presence_ttl_seconds', 90, 'presence_heartbeat_seconds', 30,
    'heartbeat_seconds', 30, 'realtime_available', false
  );
end
$fn$;

create function private.bil07_channel_directory_v1(
  p_after_id uuid default null, p_limit integer default 50
)
returns jsonb language plpgsql volatile security definer set search_path = ''
as $fn$
declare
  v_owner uuid := private.bil07_actor_v1();
  v_rows jsonb;
  v_last uuid;
  v_count integer;
  v_policy_ready boolean := false;
  v_snapshot_time timestamptz;
begin
  if p_limit is null or p_limit not between 1 and 100 then
    raise exception 'channel_invalid_limit' using errcode = '22023';
  end if;
  begin
    perform public.bil_assert_community_publish_ready();
    v_policy_ready := true;
  exception when sqlstate '42501' or sqlstate '55000' then
    v_policy_ready := false;
  end;
  -- Timestamp the read before its snapshot, never after a long query returns.
  -- A later-ending stale directory must not supersede newer receipt readback.
  v_snapshot_time := pg_catalog.clock_timestamp();
  with candidates as materialized (
    select c.*, coalesce(m.status, 'none') as membership
    from public.bil07_channels_v1 c
    left join public.bil07_channel_memberships_v1 m
      on m.channel_id = c.id and m.owner_id = v_owner
    where c.enabled and coalesce(m.status, 'none') <> 'banned'
      and (c.visibility = 'public' or m.status = 'active')
      and (p_after_id is null or c.id > p_after_id)
    order by c.id limit p_limit + 1
  ), page as (
    select * from candidates order by id limit p_limit
  )
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'id', p.id, 'slug', p.slug, 'title', p.title,
      'description', p.description, 'visibility', p.visibility,
      'enabled', p.enabled, 'membership', p.membership,
      'can_read', true, 'can_send', p.membership = 'active' and v_policy_ready,
      'max_text_code_points', 2000,
      'unread_count', private.bil07_unread_v1(p.id),
      'latest_sequence', p.latest_sequence
    ) order by p.id), '[]'::jsonb),
    (select id from page order by id desc limit 1),
    (select count(*)::integer from candidates)
  into v_rows, v_last, v_count from page p;
  return pg_catalog.jsonb_build_object(
    'contract_version', 1, 'owner_id', v_owner,
    'server_time', v_snapshot_time, 'channels', v_rows,
    'next_after_id', case when v_count > p_limit then v_last else null end
  );
end
$fn$;

create function private.bil07_channel_messages_v1(
  p_channel_id uuid, p_before_sequence bigint default null,
  p_after_sequence bigint default null, p_limit integer default 50
)
returns jsonb language plpgsql volatile security definer set search_path = ''
as $fn$
declare
  v_owner uuid := private.bil07_actor_v1();
  v_rows jsonb;
  v_min bigint;
  v_max bigint;
  v_count integer;
begin
  perform private.bil07_require_channel_v1(p_channel_id, false);
  if p_limit is null or p_limit not between 1 and 100
     or (p_before_sequence is not null and p_after_sequence is not null)
     or p_before_sequence < 1 or p_after_sequence < 0
     or p_before_sequence > 9007199254740991
     or p_after_sequence > 9007199254740991 then
    raise exception 'channel_invalid_page' using errcode = '22023';
  end if;
  with candidates as materialized (
    select m.*
    from public.bil07_channel_messages_v1 m
    where m.channel_id = p_channel_id and m.removed_at is null
      and public.bil_social_member_visible_v2(m.author_id)
      and (p_before_sequence is null or m.sequence < p_before_sequence)
      and (p_after_sequence is null or m.sequence > p_after_sequence)
    order by
      case when p_after_sequence is not null then m.sequence end asc,
      case when p_after_sequence is null then m.sequence end desc
    limit p_limit + 1
  ), page as (
    select * from candidates
    order by
      case when p_after_sequence is not null then sequence end asc,
      case when p_after_sequence is null then sequence end desc
    limit p_limit
  )
  select coalesce(pg_catalog.jsonb_agg(private.bil07_message_json_v1(
      p::public.bil07_channel_messages_v1
    ) order by p.sequence), '[]'::jsonb),
    min(p.sequence), max(p.sequence),
    (select count(*)::integer from candidates)
  into v_rows, v_min, v_max, v_count from page p;
  return pg_catalog.jsonb_build_object(
    'contract_version', 1, 'owner_id', v_owner,
    'server_time', pg_catalog.clock_timestamp(), 'channel_id', p_channel_id,
    'messages', v_rows, 'has_more', v_count > p_limit,
    'next_before_sequence', v_min, 'next_after_sequence', v_max
  );
end
$fn$;

create function private.bil07_channel_send_v1(
  p_channel_id uuid, p_client_message_id uuid, p_text text
)
returns jsonb language plpgsql volatile security definer set search_path = ''
as $fn$
declare
  v_owner uuid := private.bil07_actor_v1();
  v_message public.bil07_channel_messages_v1%rowtype;
  v_sequence bigint;
  v_replay boolean := false;
begin
  if p_client_message_id is null then
    raise exception 'channel_invalid_idempotency_key' using errcode = '22023';
  end if;
  perform private.bil07_validate_text_v1(p_text);
  -- Order: canonical member-state lock -> channel row -> membership -> policy.
  -- All sends for this channel wait here, including cross-owner sends.
  perform private.bil07_require_channel_v1(p_channel_id, true);
  perform 1 from public.bil_content_policies p where p.active for share;
  perform public.bil_assert_community_publish_ready();
  select * into v_message from public.bil07_channel_messages_v1 m
    where m.channel_id = p_channel_id and m.author_id = v_owner
      and m.client_message_id = p_client_message_id;
  if found then
    if v_message.body is distinct from p_text then
      raise exception 'channel_idempotency_payload_mismatch' using errcode = '22023';
    end if;
    if v_message.removed_at is not null then
      raise exception 'channel_message_unavailable' using errcode = '42501';
    end if;
    v_replay := true;
  else
    update public.bil07_channels_v1
      set latest_sequence = latest_sequence + 1
      where id = p_channel_id returning latest_sequence into v_sequence;
    insert into public.bil07_channel_messages_v1(
      channel_id, sequence, author_id, client_message_id, body
    ) values (p_channel_id, v_sequence, v_owner, p_client_message_id, p_text)
    returning * into v_message;
  end if;
  return pg_catalog.jsonb_build_object(
    'contract_version', 1, 'owner_id', v_owner,
    'server_time', pg_catalog.clock_timestamp(), 'channel_id', p_channel_id,
    'message', private.bil07_message_json_v1(v_message),
    'idempotent_replay', v_replay
  );
end
$fn$;

create function private.bil07_channel_readback_v1(
  p_channel_id uuid, p_message_ids uuid[]
)
returns jsonb language plpgsql volatile security definer set search_path = ''
as $fn$
declare
  v_owner uuid := private.bil07_actor_v1();
  v_ids jsonb;
  v_unread bigint;
  v_snapshot_time timestamptz;
begin
  perform private.bil07_require_channel_v1(p_channel_id, false);
  perform private.bil07_validate_receipts_v1(p_message_ids);
  v_snapshot_time := pg_catalog.clock_timestamp();
  select coalesce(pg_catalog.jsonb_agg(m.id order by m.sequence), '[]'::jsonb)
    into v_ids
  from public.bil07_channel_messages_v1 m
  join public.bil07_channel_reads_v1 r
    on r.channel_id = m.channel_id and r.message_id = m.id and r.owner_id = v_owner
  where m.channel_id = p_channel_id and m.id = any(p_message_ids)
    and m.author_id <> v_owner and m.removed_at is null
    and public.bil_social_member_visible_v2(m.author_id);
  v_unread := private.bil07_unread_v1(p_channel_id);
  return pg_catalog.jsonb_build_object(
    'contract_version', 1, 'owner_id', v_owner,
    'server_time', v_snapshot_time, 'channel_id', p_channel_id,
    'acknowledged_message_ids', v_ids,
    'unread_count', v_unread
  );
end
$fn$;

create function private.bil07_channel_read_v1(
  p_channel_id uuid, p_message_ids uuid[]
)
returns jsonb language plpgsql volatile security definer set search_path = ''
as $fn$
declare v_owner uuid := private.bil07_actor_v1();
begin
  perform private.bil07_require_channel_v1(p_channel_id, false);
  perform private.bil07_validate_receipts_v1(p_message_ids);
  insert into public.bil07_channel_reads_v1(channel_id, owner_id, message_id)
  select p_channel_id, v_owner, m.id
  from public.bil07_channel_messages_v1 m
  where m.channel_id = p_channel_id and m.id = any(p_message_ids)
    and m.author_id <> v_owner and m.removed_at is null
    and public.bil_social_member_visible_v2(m.author_id)
  on conflict (channel_id, owner_id, message_id) do nothing;
  -- Client must subsequently call readback in a separate request; a mutation
  -- response alone must never optimistically mark all requested IDs as read.
  return private.bil07_channel_readback_v1(p_channel_id, p_message_ids);
end
$fn$;

create function private.bil07_channel_presence_v1(
  p_channel_id uuid, p_heartbeat boolean default false
)
returns jsonb language plpgsql volatile security definer set search_path = ''
as $fn$
declare
  v_owner uuid := private.bil07_actor_v1();
  v_now timestamptz;
  v_expires timestamptz;
  v_first_expiry timestamptz;
  v_count bigint;
begin
  perform private.bil07_require_channel_v1(p_channel_id, false);
  if p_heartbeat is null then
    raise exception 'channel_invalid_presence' using errcode = '22023';
  end if;
  if p_heartbeat then
    -- Reading a public channel never creates a membership or presence row.
    if not exists (
      select 1 from public.bil07_channel_memberships_v1 m
      where m.channel_id = p_channel_id and m.owner_id = v_owner
        and m.status = 'active'
    ) then
      raise exception 'channel_membership_required' using errcode = '42501';
    end if;
    v_now := pg_catalog.clock_timestamp();
    insert into public.bil07_channel_presence_v1(
      channel_id, owner_id, heartbeat_at, expires_at
    ) values (p_channel_id, v_owner, v_now, v_now + interval '90 seconds')
    on conflict (channel_id, owner_id) do update
      set heartbeat_at = excluded.heartbeat_at, expires_at = excluded.expires_at
    returning expires_at into v_expires;
  end if;
  v_now := pg_catalog.clock_timestamp();
  select count(*), min(p.expires_at) into v_count, v_first_expiry
  from public.bil07_channel_presence_v1 p
  join public.bil07_channel_memberships_v1 m
    on m.channel_id = p.channel_id and m.owner_id = p.owner_id and m.status = 'active'
  where p.channel_id = p_channel_id and p.expires_at > v_now
    and public.bil_social_member_visible_v2(p.owner_id);
  return pg_catalog.jsonb_build_object(
    'contract_version', 1, 'owner_id', v_owner, 'server_time', v_now,
    'channel_id', p_channel_id, 'online_count', v_count,
    'expires_at', v_expires, 'ttl_seconds', 90,
    'valid_until', least(v_now + interval '30 seconds',
      coalesce(v_first_expiry, v_now + interval '30 seconds'))
  );
end
$fn$;

-- Only the private implementations require definer rights: clients have no
-- direct table access. Public RPC surfaces remain fixed-path invokers.
create function public.bil07_channel_capabilities_v1()
returns jsonb language sql volatile security invoker set search_path = ''
as $fn$ select private.bil07_channel_capabilities_v1(); $fn$;
create function public.bil07_channel_directory_v1(
  p_after_id uuid default null, p_limit integer default 50
)
returns jsonb language sql volatile security invoker set search_path = ''
as $fn$ select private.bil07_channel_directory_v1(p_after_id, p_limit); $fn$;
create function public.bil07_channel_messages_v1(
  p_channel_id uuid, p_before_sequence bigint default null,
  p_after_sequence bigint default null, p_limit integer default 50
)
returns jsonb language sql volatile security invoker set search_path = ''
as $fn$ select private.bil07_channel_messages_v1(
  p_channel_id, p_before_sequence, p_after_sequence, p_limit
); $fn$;
create function public.bil07_channel_send_v1(
  p_channel_id uuid, p_client_message_id uuid, p_text text
)
returns jsonb language sql volatile security invoker set search_path = ''
as $fn$ select private.bil07_channel_send_v1(
  p_channel_id, p_client_message_id, p_text
); $fn$;
create function public.bil07_channel_read_v1(p_channel_id uuid, p_message_ids uuid[])
returns jsonb language sql volatile security invoker set search_path = ''
as $fn$ select private.bil07_channel_read_v1(p_channel_id, p_message_ids); $fn$;
create function public.bil07_channel_readback_v1(p_channel_id uuid, p_message_ids uuid[])
returns jsonb language sql volatile security invoker set search_path = ''
as $fn$ select private.bil07_channel_readback_v1(p_channel_id, p_message_ids); $fn$;
create function public.bil07_channel_presence_v1(
  p_channel_id uuid, p_heartbeat boolean default false
)
returns jsonb language sql volatile security invoker set search_path = ''
as $fn$ select private.bil07_channel_presence_v1(p_channel_id, p_heartbeat); $fn$;

-- New functions receive PUBLIC EXECUTE by default; revoke it transactionally
-- before granting just the seven endpoints and their private equivalents.
do $grants$
declare v_function record;
begin
  for v_function in
    select p.oid::regprocedure as signature, n.nspname, p.proname
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'private') and p.proname in (
      'bil07_actor_v1', 'bil07_require_channel_v1', 'bil07_validate_text_v1',
      'bil07_unread_v1', 'bil07_message_json_v1', 'bil07_validate_receipts_v1',
      'bil07_channel_capabilities_v1', 'bil07_channel_directory_v1',
      'bil07_channel_messages_v1', 'bil07_channel_send_v1',
      'bil07_channel_read_v1', 'bil07_channel_readback_v1',
      'bil07_channel_presence_v1'
    )
  loop
    execute pg_catalog.format(
      'revoke all on function %s from public, anon, authenticated, service_role',
      v_function.signature
    );
    if v_function.proname in (
      'bil07_channel_capabilities_v1', 'bil07_channel_directory_v1',
      'bil07_channel_messages_v1', 'bil07_channel_send_v1',
      'bil07_channel_read_v1', 'bil07_channel_readback_v1',
      'bil07_channel_presence_v1'
    ) then
      execute pg_catalog.format(
        'grant execute on function %s to authenticated', v_function.signature
      );
    end if;
  end loop;
end
$grants$;
grant usage on schema private to authenticated;

-- No change to bil_messages, its read_at, private unread, or realtime schema.
-- No channels or memberships are seeded by the contract itself.
commit;
