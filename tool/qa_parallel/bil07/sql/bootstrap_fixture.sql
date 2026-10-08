-- Empty disposable PostgreSQL only. Identity/table shapes below are synthetic;
-- base_helpers_fixture.sql supplies the unchanged canonical function bodies.
do $guard$
begin
  if current_database() !~ '^bil07_local_[a-z0-9_]+$'
     or coalesce(pg_catalog.host(inet_server_addr()), '') not in ('127.0.0.1', '::1')
     or exists (select 1 from pg_catalog.pg_tables
       where schemaname in ('public', 'auth', 'private')) then
    raise exception 'bil07_fixture_requires_empty_loopback_database';
  end if;
end
$guard$;
create schema auth;
create schema private;
do $roles$
begin
  if not exists (select 1 from pg_catalog.pg_roles where rolname = 'anon') then
    create role anon nologin nosuperuser nobypassrls;
  end if;
  if not exists (select 1 from pg_catalog.pg_roles where rolname = 'authenticated') then
    create role authenticated nologin nosuperuser nobypassrls;
  end if;
  if not exists (select 1 from pg_catalog.pg_roles where rolname = 'service_role') then
    create role service_role nologin nosuperuser nobypassrls;
  end if;
  if exists (select 1 from pg_catalog.pg_roles
    where rolname in ('anon', 'authenticated') and (rolsuper or rolbypassrls)) then
    raise exception 'bil07_fixture_client_roles_must_obey_rls';
  end if;
end
$roles$;
grant usage on schema auth, public to anon, authenticated, service_role;

-- Same GUC-bound auth.uid() body as the committed BASE schema-only fixture.
create function auth.uid() returns uuid language sql stable as $fn$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$fn$;
create table auth.users(id uuid primary key);
create table private.bil_community_member_access(
  user_id uuid primary key references auth.users(id),
  suspended boolean not null
);
create table public.bil_public_profiles(
  user_id uuid primary key references auth.users(id),
  display_name text not null,
  discoverable boolean not null default true,
  profile_visibility text not null default 'public'
);
create table public.bil_blocks(
  blocker_id uuid not null references auth.users(id),
  blocked_id uuid not null references auth.users(id),
  primary key (blocker_id, blocked_id)
);
create table public.bil_friendships(
  requester_id uuid not null references auth.users(id),
  addressee_id uuid not null references auth.users(id),
  status text not null,
  primary key (requester_id, addressee_id)
);
create table public.bil_content_policies(
  version text primary key,
  active boolean not null,
  effective_at timestamptz not null
);
create unique index bil_content_policies_single_active_uidx
  on public.bil_content_policies(active) where active;
create table public.bil_content_policy_acceptances(
  user_id uuid not null references auth.users(id),
  policy_version text not null references public.bil_content_policies(version),
  accepted_at timestamptz not null,
  primary key (user_id, policy_version)
);
-- Sentinel for proving channels never change private messaging/unread.
create table public.bil_messages(
  id uuid primary key,
  sender_id uuid not null references auth.users(id),
  recipient_id uuid not null references auth.users(id),
  body text not null,
  read_at timestamptz
);
alter table private.bil_community_member_access enable row level security;
alter table public.bil_public_profiles enable row level security;
alter table public.bil_blocks enable row level security;
alter table public.bil_friendships enable row level security;
alter table public.bil_content_policies enable row level security;
alter table public.bil_content_policy_acceptances enable row level security;
alter table public.bil_messages enable row level security;
revoke all on all tables in schema public, private, auth
  from public, anon, authenticated, service_role;
grant select on public.bil_messages to authenticated;
create policy fixture_private_message_owner on public.bil_messages
  for select to authenticated
  using (sender_id = (select auth.uid()) or recipient_id = (select auth.uid()));

insert into auth.users(id) values
  ('11111111-1111-4111-8111-111111111111'),
  ('22222222-2222-4222-8222-222222222222'),
  ('33333333-3333-4333-8333-333333333333'),
  ('44444444-4444-4444-8444-444444444444'),
  ('55555555-5555-4555-8555-555555555555'),
  ('66666666-6666-4666-8666-666666666666'),
  ('77777777-7777-4777-8777-777777777777');
insert into public.bil_public_profiles(user_id, display_name)
  select id, 'Fixture member ' || left(id::text, 1) from auth.users;
update public.bil_public_profiles set profile_visibility = 'private',
  discoverable = false where user_id = '77777777-7777-4777-8777-777777777777';
insert into private.bil_community_member_access values
  ('55555555-5555-4555-8555-555555555555', true);
insert into public.bil_content_policies values
  ('fixture-policy-v1', true, '2000-01-01T00:00:00Z');
insert into public.bil_content_policy_acceptances
  select id, 'fixture-policy-v1', pg_catalog.clock_timestamp() from auth.users
  where id <> '66666666-6666-4666-8666-666666666666';
insert into public.bil_messages values (
  '90000000-0000-4000-8000-000000000001',
  '22222222-2222-4222-8222-222222222222',
  '11111111-1111-4111-8111-111111111111',
  'Synthetic private unread sentinel', null
);
