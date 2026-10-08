\set ON_ERROR_STOP on

-- BIL-08 QA only. Runs against a disposable PostgreSQL 17 CI database.
-- Visibility doubles are synthetic; no Supabase Production connection exists.
create role anon;
create role authenticated;
create role service_role;
create schema auth;
grant usage on schema auth to authenticated;
create or replace function auth.uid() returns uuid
language sql stable
as $fn$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $fn$;

create table public.bil_public_profiles(
  user_id uuid primary key, display_name text, avatar_url text,
  show_posts boolean not null default true
);
create table public.bil_community_posts(
  id uuid primary key, author_id uuid not null, visible boolean not null default true
);
create table public.bil_social_comments_v2(
  id uuid primary key, post_id uuid not null, author_id uuid not null,
  parent_id uuid, body text, created_at timestamptz not null,
  deleted_at timestamptz, removed_at timestamptz
);
create table public.bil_social_post_likes_v2(
  post_id uuid not null, user_id uuid not null, created_at timestamptz not null
);
create table public.bil_social_comment_likes_v2(
  comment_id uuid not null, user_id uuid not null
);
create table public.bil_social_handles_v2(
  user_id uuid not null, handle text, chosen boolean not null default false
);

-- Deliberate narrow doubles for existing visibility dependencies.
create or replace function public.bil_social_profile_visible_v2(subject uuid)
returns boolean language sql stable as $fn$
  select exists(select 1 from public.bil_public_profiles p
                where p.user_id=subject and p.show_posts)
$fn$;
create or replace function public.bil_social_member_visible_v2(subject uuid)
returns boolean language sql stable as $fn$
  select subject <> '44444444-4444-4444-8444-444444444444'::uuid
$fn$;
create or replace function public.bil_social_post_visible_v2(subject uuid)
returns boolean language sql stable as $fn$
  select exists(select 1 from public.bil_community_posts p
                where p.id=subject and p.visible)
$fn$;
create or replace function public.qa_assert(ok boolean, label text)
returns void language plpgsql as $fn$
begin
  if not coalesce(ok,false) then
    raise exception 'BIL08 isolated SQL contract failed: %',label;
  end if;
end
$fn$;

-- Compile and execute the real BIL-08 migration twice (idempotency).
\ir ../../supabase/migrations/20261007130000_bil08_community_profile_activity_v1.sql
\ir ../../supabase/migrations/20261007130000_bil08_community_profile_activity_v1.sql

insert into public.bil_public_profiles(user_id,display_name,avatar_url,show_posts) values
('22222222-2222-4222-8222-222222222222','BIL sample',null,true),
('44444444-4444-4444-8444-444444444444','Blocked member',null,true);
insert into public.bil_social_handles_v2(user_id,handle,chosen) values
('22222222-2222-4222-8222-222222222222','bil_sample',true);
insert into public.bil_community_posts(id,author_id,visible) values
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','22222222-2222-4222-8222-222222222222',true),
('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','22222222-2222-4222-8222-222222222222',false);
insert into public.bil_social_comments_v2(
  id,post_id,author_id,parent_id,body,created_at,deleted_at,removed_at
) values
('00000000-0000-4000-8000-000000000001','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','22222222-2222-4222-8222-222222222222',null,'Visible root','2026-10-07 08:00+00',null,null),
('00000000-0000-4000-8000-000000000002','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','22222222-2222-4222-8222-222222222222','00000000-0000-4000-8000-000000000001','Visible reply','2026-10-07 09:00+00',null,null),
('00000000-0000-4000-8000-000000000003','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','22222222-2222-4222-8222-222222222222',null,'Removed','2026-10-07 10:00+00',null,'2026-10-08 00:00+00'),
('00000000-0000-4000-8000-000000000004','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','22222222-2222-4222-8222-222222222222',null,'Deleted','2026-10-07 11:00+00','2026-10-08 00:00+00',null),
('00000000-0000-4000-8000-000000000005','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','22222222-2222-4222-8222-222222222222',null,'Hidden post','2026-10-07 12:00+00',null,null),
('00000000-0000-4000-8000-000000000006','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','22222222-2222-4222-8222-222222222222','ffffffff-ffff-4fff-8fff-ffffffffffff','Orphan','2026-10-07 13:00+00',null,null),
('00000000-0000-4000-8000-000000000007','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','22222222-2222-4222-8222-222222222222',null,'Removed parent','2026-10-07 14:00+00',null,'2026-10-08 00:00+00'),
('00000000-0000-4000-8000-000000000008','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','22222222-2222-4222-8222-222222222222','00000000-0000-4000-8000-000000000007','Reply to removed root','2026-10-07 15:00+00',null,null),
('00000000-0000-4000-8000-000000000009','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','44444444-4444-4444-8444-444444444444',null,'Blocked member','2026-10-07 16:00+00',null,null);
insert into public.bil_social_comment_likes_v2(comment_id,user_id) values
('00000000-0000-4000-8000-000000000001','11111111-1111-4111-8111-111111111111'),
('00000000-0000-4000-8000-000000000001','33333333-3333-4333-8333-333333333333');
insert into public.bil_social_post_likes_v2(post_id,user_id,created_at) values
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','22222222-2222-4222-8222-222222222222','2026-10-07 10:00+00'),
('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','22222222-2222-4222-8222-222222222222','2026-10-07 11:00+00');

select public.qa_assert(
  not has_function_privilege('anon','public.bil_community_profile_replies_v1(uuid,timestamptz,uuid,integer)','EXECUTE')
  and not has_function_privilege('service_role','public.bil_community_profile_likes_v1(uuid,timestamptz,uuid,integer)','EXECUTE'),
  'No unintended role has RPC EXECUTE'
);
select public.qa_assert(
  has_function_privilege('authenticated','public.bil_community_profile_replies_v1(uuid,timestamptz,uuid,integer)','EXECUTE')
  and has_function_privilege('authenticated','public.bil_community_profile_likes_v1(uuid,timestamptz,uuid,integer)','EXECUTE'),
  'Authenticated EXECUTE grants'
);
select public.qa_assert(
  (select prosecdef from pg_catalog.pg_proc where oid='public.bil_community_profile_replies_v1(uuid,timestamptz,uuid,integer)'::regprocedure)
  and (select prosecdef from pg_catalog.pg_proc where oid='public.bil_community_profile_likes_v1(uuid,timestamptz,uuid,integer)'::regprocedure),
  'Both RPCs are SECURITY DEFINER'
);

set role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
select public.qa_assert(
  (select count(*) from public.bil_community_profile_replies_v1('22222222-2222-4222-8222-222222222222'))=2,
  'Other member sees only live replies under visible post'
);
select public.qa_assert(
  (select like_count=2 and liked and reply_count=1
   from public.bil_community_profile_replies_v1('22222222-2222-4222-8222-222222222222')
   where id='00000000-0000-4000-8000-000000000001'),
  'Visible root aggregated likes and child count'
);
select public.qa_assert(
  (select author_name='BIL sample' and handle='bil_sample'
   from public.bil_community_profile_replies_v1('22222222-2222-4222-8222-222222222222')
   where id='00000000-0000-4000-8000-000000000001'),
  'Visible author identity and handle'
);
select public.qa_assert(
  (select count(*) from public.bil_community_profile_replies_v1(
    '22222222-2222-4222-8222-222222222222','2026-10-07 09:00+00',
    '00000000-0000-4000-8000-000000000002',24
  ))=1,
  'Keyset pagination excludes the cursor'
);
do $qa$
declare denied boolean := false;
begin
  begin
    perform public.bil_community_profile_likes_v1('22222222-2222-4222-8222-222222222222');
  exception when insufficient_privilege then
    denied := SQLERRM='community_profile_likes_private';
  end;
  if not denied then raise exception 'BIL08 likes privacy check failed'; end if;
end
$qa$;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false);
select public.qa_assert(
  (select count(*) from public.bil_community_profile_likes_v1('22222222-2222-4222-8222-222222222222'))=1,
  'Own likes exclude hidden posts'
);
reset role;
update public.bil_public_profiles set show_posts=false
where user_id='22222222-2222-4222-8222-222222222222';
set role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
select public.qa_assert(
  (select count(*) from public.bil_community_profile_replies_v1('22222222-2222-4222-8222-222222222222'))=0,
  'Private profile hides replies from others'
);
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false);
select public.qa_assert(
  (select count(*) from public.bil_community_profile_replies_v1('22222222-2222-4222-8222-222222222222'))=2,
  'Owner retains access to own replies'
);
do $qa$
declare denied boolean := false;
begin
  begin
    perform public.bil_community_profile_replies_v1('22222222-2222-4222-8222-222222222222',null,null,61);
  exception when invalid_parameter_value then
    denied := SQLERRM='invalid_profile_reply_request';
  end;
  if not denied then raise exception 'BIL08 bad pagination accepted'; end if;
end
$qa$;
select set_config('request.jwt.claim.sub','',false);
do $qa$
declare denied boolean := false;
begin
  begin
    perform public.bil_community_profile_replies_v1('22222222-2222-4222-8222-222222222222');
  exception when insufficient_privilege then
    denied := SQLERRM='authentication_required';
  end;
  if not denied then raise exception 'BIL08 anonymous request accepted'; end if;
end
$qa$;
reset role;
select 'BIL08 isolated activity SQL contracts passed' as result;
