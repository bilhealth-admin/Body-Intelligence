begin;

create table if not exists public.bil_diary_share_settings (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  visibility text not null default 'private'
    check (visibility in ('private', 'friends', 'public', 'locked')),
  access_key_sha256 text,
  updated_at timestamptz not null default now(),
  check (
    (visibility = 'locked' and access_key_sha256 ~ '^[0-9a-f]{64}$') or
    (visibility <> 'locked' and access_key_sha256 is null)
  )
);

create table if not exists public.bil_shared_diary_snapshots (
  owner_id uuid not null references auth.users(id) on delete cascade,
  diary_day date not null,
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  source_revision integer not null default 1 check (source_revision > 0),
  updated_at timestamptz not null default now(),
  primary key (owner_id, diary_day),
  check (octet_length(payload::text) <= 262144)
);

alter table public.bil_diary_share_settings enable row level security;
alter table public.bil_shared_diary_snapshots enable row level security;

create policy bil_diary_share_settings_owner_read
  on public.bil_diary_share_settings for select to authenticated
  using (owner_id = (select auth.uid()));
create policy bil_diary_share_settings_owner_delete
  on public.bil_diary_share_settings for delete to authenticated
  using (owner_id = (select auth.uid()));
create policy bil_shared_diary_snapshots_owner_read
  on public.bil_shared_diary_snapshots for select to authenticated
  using (owner_id = (select auth.uid()));
create policy bil_shared_diary_snapshots_owner_delete
  on public.bil_shared_diary_snapshots for delete to authenticated
  using (owner_id = (select auth.uid()));

create or replace function public.bil_set_diary_share_settings(
  p_visibility text,
  p_access_key_sha256 text default null
) returns void
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_owner uuid := auth.uid();
  v_visibility text := lower(trim(coalesce(p_visibility, '')));
  v_key text := lower(trim(coalesce(p_access_key_sha256, '')));
begin
  if v_owner is null then raise exception 'authentication required'; end if;
  if v_visibility not in ('private', 'friends', 'public', 'locked') then
    raise exception 'invalid diary visibility';
  end if;
  if v_visibility = 'locked' and v_key !~ '^[0-9a-f]{64}$' then
    raise exception 'locked diary requires a SHA-256 access key';
  end if;
  insert into public.bil_diary_share_settings(owner_id, visibility, access_key_sha256, updated_at)
  values (v_owner, v_visibility, case when v_visibility = 'locked' then v_key else null end, now())
  on conflict (owner_id) do update set
    visibility = excluded.visibility,
    access_key_sha256 = excluded.access_key_sha256,
    updated_at = now();
end;
$$;

create or replace function public.bil_publish_diary_snapshot(
  p_diary_day date,
  p_payload jsonb,
  p_source_revision integer
) returns void
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare v_owner uuid := auth.uid();
begin
  if v_owner is null then raise exception 'authentication required'; end if;
  if p_diary_day is null or p_diary_day > current_date + 1 then
    raise exception 'invalid diary day';
  end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' or octet_length(p_payload::text) > 262144 then
    raise exception 'invalid diary payload';
  end if;
  if p_source_revision is null or p_source_revision < 1 then raise exception 'invalid source revision'; end if;
  insert into public.bil_shared_diary_snapshots(owner_id, diary_day, payload, source_revision, updated_at)
  values (v_owner, p_diary_day, p_payload, p_source_revision, now())
  on conflict (owner_id, diary_day) do update set
    payload = excluded.payload,
    source_revision = excluded.source_revision,
    updated_at = now()
  where public.bil_shared_diary_snapshots.source_revision <= excluded.source_revision;
end;
$$;

create or replace function public.bil_read_shared_diary(
  p_owner_id uuid,
  p_diary_day date,
  p_access_key_sha256 text default null
) returns jsonb
language plpgsql security definer stable
set search_path = public, pg_temp
as $$
declare
  v_viewer uuid := auth.uid();
  v_settings public.bil_diary_share_settings%rowtype;
  v_allowed boolean := false;
  v_payload jsonb;
begin
  if v_viewer is null then raise exception 'authentication required'; end if;
  select * into v_settings from public.bil_diary_share_settings where owner_id = p_owner_id;
  if not found then return null; end if;
  if exists (
    select 1 from public.bil_blocks b
    where (b.blocker_id = v_viewer and b.blocked_id = p_owner_id)
       or (b.blocker_id = p_owner_id and b.blocked_id = v_viewer)
  ) then return null; end if;
  v_allowed := v_viewer = p_owner_id
    or v_settings.visibility = 'public'
    or (v_settings.visibility = 'locked'
      and lower(trim(coalesce(p_access_key_sha256, ''))) = v_settings.access_key_sha256)
    or (v_settings.visibility = 'friends' and exists (
      select 1 from public.bil_friendships f
      where f.status = 'accepted' and
        ((f.requester_id = p_owner_id and f.addressee_id = v_viewer) or
         (f.addressee_id = p_owner_id and f.requester_id = v_viewer))
    ));
  if not v_allowed then return null; end if;
  select payload into v_payload from public.bil_shared_diary_snapshots
    where owner_id = p_owner_id and diary_day = p_diary_day;
  return v_payload;
end;
$$;

create table if not exists public.bil_support_requests (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  category text not null check (category in ('account', 'billing', 'technical', 'privacy', 'feedback', 'other')),
  subject text not null check (length(subject) between 3 and 120),
  message text not null check (length(message) between 10 and 4000),
  client_context jsonb not null default '{}'::jsonb check (jsonb_typeof(client_context) = 'object'),
  queue_class text not null check (queue_class in ('standard', 'paid')),
  status text not null default 'received' check (status in ('received', 'reviewing', 'resolved', 'closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.bil_support_requests enable row level security;
create policy bil_support_requests_owner_read on public.bil_support_requests
  for select to authenticated using (owner_id = (select auth.uid()));

create or replace function public.bil_create_support_request(
  p_category text,
  p_subject text,
  p_message text,
  p_client_context jsonb default '{}'::jsonb
) returns uuid
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_owner uuid := auth.uid();
  v_id uuid;
  v_queue text := 'standard';
begin
  if v_owner is null then raise exception 'authentication required'; end if;
  if lower(trim(coalesce(p_category, ''))) not in ('account','billing','technical','privacy','feedback','other') then
    raise exception 'invalid support category';
  end if;
  if length(trim(coalesce(p_subject, ''))) not between 3 and 120 then raise exception 'invalid subject'; end if;
  if length(trim(coalesce(p_message, ''))) not between 10 and 4000 then raise exception 'invalid message'; end if;
  if p_client_context is null or jsonb_typeof(p_client_context) <> 'object' or octet_length(p_client_context::text) > 32768 then
    raise exception 'invalid client context';
  end if;
  if exists (
    select 1 from public.bil_entitlements e
    where e.owner_id = v_owner and e.active and (e.expires_at is null or e.expires_at > now())
  ) then v_queue := 'paid'; end if;
  insert into public.bil_support_requests(owner_id, category, subject, message, client_context, queue_class)
  values (v_owner, lower(trim(p_category)), trim(p_subject), trim(p_message), p_client_context, v_queue)
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on public.bil_diary_share_settings, public.bil_shared_diary_snapshots,
  public.bil_support_requests from anon, authenticated;
grant select, delete on public.bil_diary_share_settings, public.bil_shared_diary_snapshots to authenticated;
grant select on public.bil_support_requests to authenticated;
revoke all on function public.bil_set_diary_share_settings(text, text),
  public.bil_publish_diary_snapshot(date, jsonb, integer),
  public.bil_read_shared_diary(uuid, date, text),
  public.bil_create_support_request(text, text, text, jsonb) from public, anon;
grant execute on function public.bil_set_diary_share_settings(text, text),
  public.bil_publish_diary_snapshot(date, jsonb, integer),
  public.bil_read_shared_diary(uuid, date, text),
  public.bil_create_support_request(text, text, text, jsonb) to authenticated;

commit;
