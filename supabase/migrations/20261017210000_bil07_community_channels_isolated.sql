-- BIL-07 CHANNELS — ISOLATED PROPOSAL, NOT APPROVED FOR PRODUCTION.
-- No seed channels or fabricated users. A separate owner-reviewed decision is
-- required for which public channels to publish and for moderator reporting.
-- Reads/sends are authenticated server-side only; tables grant NO direct access.
begin;
set local lock_timeout='5s';
set local statement_timeout='40s';

do $preflight$
begin
  if pg_catalog.to_regclass('auth.users') is null
    or pg_catalog.to_regclass('public.bil_public_profiles') is null
    or pg_catalog.to_regclass('public.bil_blocks') is null
    or pg_catalog.to_regprocedure('public.bil_can_use_community()') is null
    or pg_catalog.to_regprocedure('private.bil_assert_current_community_policy()') is null
    or pg_catalog.to_regprocedure('private.bil_is_blocked_with(uuid)') is null then
    raise exception 'bil07_channel_dependencies_missing' using errcode='55000';
  end if;
  if pg_catalog.to_regclass('public.bil07_channels_v1') is not null
    or pg_catalog.to_regclass('public.bil07_channel_messages_v1') is not null then
    raise exception 'bil07_channel_schema_already_present_review_required' using errcode='55000';
  end if;
end
$preflight$;

create table public.bil07_channels_v1 (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'
                               and pg_catalog.char_length(slug) between 3 and 60),
  title text not null check (pg_catalog.char_length(title) between 1 and 100),
  description text not null default '' check (pg_catalog.char_length(description)<=500),
  visibility text not null default 'public' check (visibility in ('public','members')),
  enabled boolean not null default false,
  max_text_code_points integer not null default 2000
    check(max_text_code_points=2000),
  latest_sequence bigint not null default 0
    check (latest_sequence between 0 and 9007199254740991),
  created_at timestamptz not null default pg_catalog.clock_timestamp()
);

create table public.bil07_channel_memberships_v1 (
  channel_id uuid not null references public.bil07_channels_v1(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  status text not null check(status in ('active','banned')),
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  primary key (channel_id,owner_id)
);

create table public.bil07_channel_messages_v1 (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  channel_id uuid not null references public.bil07_channels_v1(id) on delete cascade,
  sequence bigint not null check(sequence between 1 and 9007199254740991),
  author_id uuid not null references auth.users(id) on delete cascade,
  client_message_id uuid not null,
  text text not null
    check(pg_catalog.char_length(text) between 1 and 2000
      and pg_catalog.btrim(text) <> ''
      and text !~ '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'),
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  hidden_at timestamptz,
  unique (channel_id,sequence),
  unique (channel_id,author_id,client_message_id)
);

create table private.bil07_channel_read_receipts_v1 (
  channel_id uuid not null references public.bil07_channels_v1(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  message_id uuid not null references public.bil07_channel_messages_v1(id) on delete cascade,
  seen_at timestamptz not null default pg_catalog.clock_timestamp(),
  primary key(channel_id,owner_id,message_id)
);

create table private.bil07_channel_presence_v1 (
  channel_id uuid not null references public.bil07_channels_v1(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  expires_at timestamptz not null,
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  primary key(channel_id,owner_id)
);

create index bil07_channel_messages_browse_idx
  on public.bil07_channel_messages_v1(channel_id,sequence desc)
  where hidden_at is null;
create index bil07_channel_read_owner_idx
  on private.bil07_channel_read_receipts_v1(owner_id,channel_id);
create index bil07_channel_presence_active_idx
  on private.bil07_channel_presence_v1(channel_id,expires_at);

alter table public.bil07_channels_v1 enable row level security;
alter table public.bil07_channel_memberships_v1 enable row level security;
alter table public.bil07_channel_messages_v1 enable row level security;
alter table private.bil07_channel_read_receipts_v1 enable row level security;
alter table private.bil07_channel_presence_v1 enable row level security;

revoke all on public.bil07_channels_v1,
  public.bil07_channel_memberships_v1,public.bil07_channel_messages_v1
  from public,anon,authenticated,service_role;
revoke all on private.bil07_channel_read_receipts_v1,
  private.bil07_channel_presence_v1 from public,anon,authenticated,service_role;

-- A member-only room is invisible to outsiders. Public rooms have implicit
-- active membership unless an explicit ban exists. Do not mutate memberships
-- during a directory read; owner/admin provisioning is a separate concern.
create function private.bil07_channel_access_v1(p_channel_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $fn$
declare
  v_owner uuid := (select auth.uid());
  v_channel public.bil07_channels_v1%rowtype;
  v_explicit text;
  v_membership text;
  v_read boolean;
begin
  if v_owner is null or not public.bil_can_use_community() then
    raise exception 'community_access_required' using errcode='42501';
  end if;
  select * into v_channel from public.bil07_channels_v1
    where id=p_channel_id;
  if not found then
    raise exception 'channel_unavailable' using errcode='42501';
  end if;
  select status into v_explicit from public.bil07_channel_memberships_v1
    where channel_id=p_channel_id and owner_id=v_owner;
  v_membership := coalesce(v_explicit,
    case when v_channel.visibility='public' then 'active' else 'none' end);
  v_read := v_channel.enabled and v_membership<>'banned'
    and (v_channel.visibility='public' or v_membership='active');
  return pg_catalog.jsonb_build_object(
    'membership',v_membership,
    'can_read',v_read,
    'can_send',v_read and v_membership='active',
    'enabled',v_channel.enabled,
    'visibility',v_channel.visibility);
end
$fn$;

create function private.bil07_channel_assert_v1(
  p_channel_id uuid,p_send boolean default false
) returns jsonb language plpgsql stable security definer set search_path=''
as $fn$
declare
  v_permission jsonb := private.bil07_channel_access_v1(p_channel_id);
begin
  if not coalesce((v_permission->>'can_read')::boolean,false)
    or (p_send and not coalesce((v_permission->>'can_send')::boolean,false)) then
    raise exception 'channel_access_denied' using errcode='42501';
  end if;
  return v_permission;
end
$fn$;

create function public.bil07_channel_capabilities_v1()
returns jsonb language plpgsql stable security definer set search_path=''
as $fn$
declare v_owner uuid := (select auth.uid());
begin
  if v_owner is null or not public.bil_can_use_community() then
    raise exception 'community_access_required' using errcode='42501';
  end if;
  return pg_catalog.jsonb_build_object(
    'contract_version',1,'owner_id',v_owner,
    'server_time',pg_catalog.clock_timestamp(),
    'max_text_code_points',2000,'max_page_size',100,
    'max_receipt_ids',100,'presence_ttl_seconds',90,
    'presence_heartbeat_seconds',30,'read_receipts','exact_message_ids_v1',
    'realtime_available',false);
end
$fn$;

create function public.bil07_channel_directory_v1(
  p_after_id uuid default null,p_limit integer default 50
) returns jsonb language plpgsql stable security definer set search_path=''
as $fn$
declare
  v_owner uuid := (select auth.uid());
  v_rows jsonb := '[]'::jsonb;
  v_row record;
  v_perm jsonb;
  v_unread integer;
  v_count integer := 0;
  v_after uuid;
  v_more boolean := false;
begin
  if v_owner is null or not public.bil_can_use_community() then
    raise exception 'community_access_required' using errcode='42501';
  end if;
  if p_limit is null or p_limit not between 1 and 100 then
    raise exception 'invalid_channel_limit' using errcode='22023';
  end if;
  for v_row in
    select c.id,c.slug,c.title,c.description,c.visibility,
      c.enabled,c.latest_sequence,c.max_text_code_points
    from public.bil07_channels_v1 c
    left join public.bil07_channel_memberships_v1 m
      on m.channel_id=c.id and m.owner_id=v_owner
    where (p_after_id is null or c.id>p_after_id)
      and (c.visibility='public' or m.status in ('active','banned'))
    order by c.id
    limit p_limit+1
  loop
    if v_count >= p_limit then
      v_more := true;
      exit;
    end if;
    v_perm := private.bil07_channel_access_v1(v_row.id);
    v_unread := null;
    if (v_perm->>'can_read')::boolean then
      select pg_catalog.count(*)::integer into v_unread
      from public.bil07_channel_messages_v1 message
      where message.channel_id=v_row.id
        and message.hidden_at is null
        and message.author_id<>v_owner
        and not private.bil_is_blocked_with(message.author_id)
        and not exists (
          select 1 from private.bil07_channel_read_receipts_v1 receipt
          where receipt.channel_id=v_row.id and receipt.owner_id=v_owner
            and receipt.message_id=message.id);
    end if;
    v_rows:=v_rows||pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'id',v_row.id,'slug',v_row.slug,'title',v_row.title,
      'description',v_row.description,'visibility',v_row.visibility,
      'enabled',v_row.enabled,'membership',v_perm->>'membership',
      'can_read',(v_perm->>'can_read')::boolean,
      'can_send',(v_perm->>'can_send')::boolean,
      'unread_count',v_unread,'latest_sequence',v_row.latest_sequence,
      'max_text_code_points',v_row.max_text_code_points));
    v_after := v_row.id;
    v_count := v_count+1;
  end loop;
  return pg_catalog.jsonb_build_object(
    'contract_version',1,'owner_id',v_owner,
    'server_time',pg_catalog.clock_timestamp(),
    'channels',v_rows,
    'next_after_id',case when v_more then v_after else null end);
end
$fn$;

create function public.bil07_channel_messages_v1(
  p_channel_id uuid,p_before_sequence bigint default null,
  p_after_sequence bigint default null,p_limit integer default 50
) returns jsonb language plpgsql stable security definer set search_path=''
as $fn$
declare
  v_owner uuid := (select auth.uid());
  v_messages jsonb := '[]'::jsonb;
  v_row record;
  v_first bigint;
  v_last bigint;
  v_has_more boolean := false;
begin
  perform private.bil07_channel_assert_v1(p_channel_id,false);
  if p_limit is null or p_limit not between 1 and 100
     or (p_before_sequence is not null and p_after_sequence is not null)
     or (p_before_sequence is not null and p_before_sequence<1)
     or (p_after_sequence is not null and p_after_sequence<0) then
    raise exception 'invalid_channel_paging' using errcode='22023';
  end if;
  for v_row in
    select limited.*,profile.display_name,
      (limited.author_id=v_owner or receipt.message_id is not null) as is_read
    from (
      select message.* from public.bil07_channel_messages_v1 message
      where message.channel_id=p_channel_id and message.hidden_at is null
        and (p_before_sequence is null or message.sequence<p_before_sequence)
        and (p_after_sequence is null or message.sequence>p_after_sequence)
        and not private.bil_is_blocked_with(message.author_id)
      order by case when p_after_sequence is not null
        then message.sequence else -message.sequence end
      limit p_limit
    ) limited
    left join public.bil_public_profiles profile on profile.user_id=limited.author_id
    left join private.bil07_channel_read_receipts_v1 receipt
      on receipt.channel_id=limited.channel_id
      and receipt.owner_id=v_owner and receipt.message_id=limited.id
    order by limited.sequence
  loop
    v_first:=coalesce(v_first,v_row.sequence);
    v_last:=v_row.sequence;
    v_messages:=v_messages||pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'id',v_row.id,'channel_id',p_channel_id,
      'sequence',v_row.sequence,'author_id',v_row.author_id,
      'author_display_name',v_row.display_name,
      'text',v_row.text,'client_message_id',v_row.client_message_id,
      'created_at',v_row.created_at,'is_read',v_row.is_read));
  end loop;
  if v_first is not null then
    select exists(
      select 1 from public.bil07_channel_messages_v1 message
      where message.channel_id=p_channel_id and message.hidden_at is null
        and not private.bil_is_blocked_with(message.author_id)
        and (case when p_after_sequence is null
          then message.sequence<v_first else message.sequence>v_last end)
    ) into v_has_more;
  end if;
  return pg_catalog.jsonb_build_object(
    'contract_version',1,'owner_id',v_owner,'channel_id',p_channel_id,
    'server_time',pg_catalog.clock_timestamp(),'messages',v_messages,
    'has_more',v_has_more,
    'next_before_sequence',v_first,'next_after_sequence',v_last);
end
$fn$;

create function public.bil07_channel_send_v1(
  p_channel_id uuid,p_client_message_id uuid,p_text text
) returns jsonb language plpgsql volatile security definer set search_path=''
as $fn$
declare
  v_owner uuid := (select auth.uid());
  v_channel public.bil07_channels_v1%rowtype;
  v_existing public.bil07_channel_messages_v1%rowtype;
  v_created public.bil07_channel_messages_v1%rowtype;
  v_name text;
  v_replay boolean := false;
begin
  if p_channel_id is null or p_client_message_id is null or p_text is null
    or pg_catalog.char_length(p_text) not between 1 and 2000
    or pg_catalog.btrim(p_text)=''
    or p_text ~ '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]' then
    raise exception 'invalid_channel_text' using errcode='22023';
  end if;
  perform private.bil07_channel_assert_v1(p_channel_id,true);
  perform private.bil_assert_current_community_policy();
  -- Serializes idempotent retries and global sequence, including concurrent
  -- requests from different clients and mobile devices.
  select * into v_channel from public.bil07_channels_v1
    where id=p_channel_id for update;
  if not found then
    raise exception 'channel_unavailable' using errcode='42501';
  end if;
  perform private.bil07_channel_assert_v1(p_channel_id,true);
  select * into v_existing from public.bil07_channel_messages_v1
    where channel_id=p_channel_id and author_id=v_owner
      and client_message_id=p_client_message_id;
  if found then
    if v_existing.text<>p_text then
      raise exception 'idempotency_payload_mismatch' using errcode='22023';
    end if;
    v_created:=v_existing;
    v_replay:=true;
  else
    if v_channel.latest_sequence>=9007199254740990 then
      raise exception 'channel_sequence_exhausted' using errcode='55000';
    end if;
    insert into public.bil07_channel_messages_v1(
      channel_id,sequence,author_id,client_message_id,text)
    values(p_channel_id,v_channel.latest_sequence+1,v_owner,p_client_message_id,p_text)
    returning * into v_created;
    update public.bil07_channels_v1
      set latest_sequence=v_created.sequence where id=p_channel_id;
  end if;
  select display_name into v_name from public.bil_public_profiles
    where user_id=v_owner;
  return pg_catalog.jsonb_build_object(
    'contract_version',1,'owner_id',v_owner,'channel_id',p_channel_id,
    'server_time',pg_catalog.clock_timestamp(),'idempotent_replay',v_replay,
    'message',pg_catalog.jsonb_build_object(
      'id',v_created.id,'channel_id',p_channel_id,
      'sequence',v_created.sequence,'author_id',v_owner,
      'author_display_name',v_name,'text',v_created.text,
      'client_message_id',v_created.client_message_id,
      'created_at',v_created.created_at,'is_read',true));
end
$fn$;

create function public.bil07_channel_read_v1(
  p_channel_id uuid,p_message_ids uuid[]
) returns jsonb language plpgsql volatile security definer set search_path=''
as $fn$
declare
  v_owner uuid := (select auth.uid());
  v_count integer;
begin
  perform private.bil07_channel_assert_v1(p_channel_id,false);
  if p_message_ids is null or pg_catalog.cardinality(p_message_ids) not between 1 and 100
    or (select pg_catalog.count(distinct id)
        from pg_catalog.unnest(p_message_ids) id)
       <>pg_catalog.cardinality(p_message_ids) then
    raise exception 'invalid_channel_read_batch' using errcode='22023';
  end if;
  select pg_catalog.count(*) into v_count
  from public.bil07_channel_messages_v1 message
  where message.id=any(p_message_ids) and message.channel_id=p_channel_id
    and message.hidden_at is null
    and not private.bil_is_blocked_with(message.author_id);
  if v_count<>pg_catalog.cardinality(p_message_ids) then
    raise exception 'channel_read_denied' using errcode='42501';
  end if;
  insert into private.bil07_channel_read_receipts_v1(channel_id,owner_id,message_id)
  select p_channel_id,v_owner,id from pg_catalog.unnest(p_message_ids) id
  on conflict do nothing;
  return pg_catalog.jsonb_build_object('contract_version',1,
    'owner_id',v_owner,'channel_id',p_channel_id,
    'server_time',pg_catalog.clock_timestamp());
end
$fn$;

create function public.bil07_channel_readback_v1(
  p_channel_id uuid,p_message_ids uuid[]
) returns jsonb language plpgsql stable security definer set search_path=''
as $fn$
declare
  v_owner uuid := (select auth.uid());
  v_confirmed jsonb;
  v_unread integer;
begin
  perform private.bil07_channel_assert_v1(p_channel_id,false);
  if p_message_ids is null or pg_catalog.cardinality(p_message_ids) not between 1 and 100 then
    raise exception 'invalid_channel_read_batch' using errcode='22023';
  end if;
  select coalesce(pg_catalog.jsonb_agg(receipt.message_id order by receipt.message_id),'[]'::jsonb)
    into v_confirmed
  from private.bil07_channel_read_receipts_v1 receipt
  where receipt.channel_id=p_channel_id and receipt.owner_id=v_owner
    and receipt.message_id=any(p_message_ids);
  select pg_catalog.count(*)::integer into v_unread
  from public.bil07_channel_messages_v1 message
  where message.channel_id=p_channel_id and message.hidden_at is null
    and message.author_id<>v_owner
    and not private.bil_is_blocked_with(message.author_id)
    and not exists (
      select 1 from private.bil07_channel_read_receipts_v1 receipt
      where receipt.channel_id=p_channel_id and receipt.owner_id=v_owner
        and receipt.message_id=message.id);
  return pg_catalog.jsonb_build_object(
    'contract_version',1,'owner_id',v_owner,'channel_id',p_channel_id,
    'server_time',pg_catalog.clock_timestamp(),
    'acknowledged_message_ids',v_confirmed,'unread_count',v_unread);
end
$fn$;

create function public.bil07_channel_presence_v1(
  p_channel_id uuid,p_heartbeat boolean
) returns jsonb language plpgsql volatile security definer set search_path=''
as $fn$
declare
  v_owner uuid := (select auth.uid());
  v_now timestamptz := pg_catalog.clock_timestamp();
  v_own timestamptz;
  v_total integer;
begin
  perform private.bil07_channel_assert_v1(p_channel_id,false);
  if p_heartbeat is null then
    raise exception 'invalid_channel_presence' using errcode='22023';
  end if;
  if p_heartbeat then
    insert into private.bil07_channel_presence_v1(
      channel_id,owner_id,expires_at,updated_at)
    values(p_channel_id,v_owner,v_now+interval '90 seconds',v_now)
    on conflict(channel_id,owner_id) do update set
      expires_at=excluded.expires_at,updated_at=excluded.updated_at;
  end if;
  select expires_at into v_own from private.bil07_channel_presence_v1
    where channel_id=p_channel_id and owner_id=v_owner and expires_at>v_now;
  select pg_catalog.count(*)::integer into v_total
    from private.bil07_channel_presence_v1 p
    where p.channel_id=p_channel_id and p.expires_at>v_now;
  return pg_catalog.jsonb_build_object(
    'contract_version',1,'owner_id',v_owner,'channel_id',p_channel_id,
    'server_time',v_now,'online_count',v_total,
    'valid_until',v_now+interval '30 seconds',
    'ttl_seconds',90,'expires_at',v_own);
end
$fn$;

-- No direct SQL or realtime exposure of messages, read receipts, presence.
revoke all on function private.bil07_channel_access_v1(uuid),
  private.bil07_channel_assert_v1(uuid,boolean)
  from public,anon,authenticated,service_role;
revoke all on function public.bil07_channel_capabilities_v1(),
  public.bil07_channel_directory_v1(uuid,integer),
  public.bil07_channel_messages_v1(uuid,bigint,bigint,integer),
  public.bil07_channel_send_v1(uuid,uuid,text),
  public.bil07_channel_read_v1(uuid,uuid[]),
  public.bil07_channel_readback_v1(uuid,uuid[]),
  public.bil07_channel_presence_v1(uuid,boolean)
  from public,anon,authenticated,service_role;
grant execute on function public.bil07_channel_capabilities_v1(),
  public.bil07_channel_directory_v1(uuid,integer),
  public.bil07_channel_messages_v1(uuid,bigint,bigint,integer),
  public.bil07_channel_send_v1(uuid,uuid,text),
  public.bil07_channel_read_v1(uuid,uuid[]),
  public.bil07_channel_readback_v1(uuid,uuid[]),
  public.bil07_channel_presence_v1(uuid,boolean)
  to authenticated;

-- Intentionally NO room seeds, grants, table exposure, or publication to
-- realtime. Owner moderation/approved room provisioning must be reviewed
-- before any production rollout of this additive migration.
commit;
