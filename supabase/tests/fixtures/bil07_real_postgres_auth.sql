-- ONLY FOR DISPOSABLE CI: synthetic JWT-based Auth stand-in, not a migration.
create role anon nologin;
create role authenticated nologin;
create role service_role nologin;
create role authenticator login noinherit password 'bil07-fixture-only-database-pass';
grant anon,authenticated to authenticator;
grant usage on schema public to anon,authenticated,authenticator;
create schema auth;
create schema private;
grant usage on schema auth to authenticated,authenticator;
create table auth.users(id uuid primary key);
create table public.bil_public_profiles(user_id uuid primary key references auth.users(id), display_name text not null, discoverable boolean not null default true);
create table public.bil_blocks(blocker_id uuid not null references auth.users(id), blocked_id uuid not null references auth.users(id), primary key(blocker_id,blocked_id));
create table public.bil_community_moderators(user_id uuid primary key references auth.users(id));
create function auth.uid() returns uuid language sql stable as $fn$
select nullif(nullif(pg_catalog.current_setting('request.jwt.claims',true),'')::jsonb->>'sub','')::uuid;
$fn$;
create function public.bil_can_use_community() returns boolean language sql stable as $fn$
select auth.uid() is not null;
$fn$;
-- Strictly a CI fake. Real community consent requires durable policy acceptance,
-- not a self-asserted client JWT; this function never ships to Production.
create function private.bil_assert_current_community_policy()
returns text language plpgsql stable security definer set search_path='' as $fn$
declare v_claims jsonb := nullif(pg_catalog.current_setting('request.jwt.claims',true),'')::jsonb;
begin
 if coalesce(v_claims->>'fixture_community_consent','false')<>'true' then
   raise exception 'community_policy_acceptance_required' using errcode='42501';
 end if;
 return 'synthetic-accepted-policy';
end $fn$;
create function private.bil_is_blocked_with(p_other uuid)
returns boolean language sql stable security definer set search_path='' as $fn$
select auth.uid() is null or p_other is null or exists (
 select 1 from public.bil_blocks b
 where (b.blocker_id=auth.uid() and b.blocked_id=p_other)
    or (b.blocked_id=auth.uid() and b.blocker_id=p_other)
);
$fn$;
