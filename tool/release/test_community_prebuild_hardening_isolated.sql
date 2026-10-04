-- DISPOSABLE PostgreSQL 17 database only. NOT a Production migration.
-- Run through test_community_prebuild_hardening_isolated.mjs, which injects
-- unchanged transport RPC definitions verbatim from the referenced Git SQL.
\set ON_ERROR_STOP on
begin;
do $$ declare role_name text; begin
 foreach role_name in array array['anon','authenticated','service_role'] loop
  if not exists(select 1 from pg_roles where rolname=role_name) then
   execute format('create role %I nologin nosuperuser nobypassrls',role_name);
  end if;
 end loop;
 if exists(select 1 from pg_roles where rolname in('anon','authenticated') and (rolsuper or rolbypassrls)) then
  raise exception 'Fixture app roles must be ordinary non-bypass roles';
 end if;
end $$;
create schema auth;
create schema private;
create schema extensions;
create extension pgcrypto with schema extensions;
grant usage on schema public,auth to authenticated,anon,service_role;
revoke create on schema public from public;
create function auth.uid() returns uuid language sql stable as $$
 select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
create function auth.jwt() returns jsonb language sql stable as $$
 select coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb,'{}'::jsonb)
$$;
create table auth.users(id uuid primary key,created_at timestamptz not null default now(),email text);
create table private.bil_ai_coach_admins(user_id uuid primary key,active boolean not null);
create table private.bil_community_member_access(
 user_id uuid primary key,suspended boolean not null,reason text,
 suspended_by uuid,suspended_at timestamptz default clock_timestamp(),
 reinstated_by uuid,reinstated_at timestamptz,updated_at timestamptz default clock_timestamp()
);
create table private.bil_community_member_access_audit(
 id bigint generated always as identity primary key,idempotency_key text unique,
 actor_id uuid,target_id uuid,action text,request_digest text,result jsonb,
 occurred_at timestamptz default clock_timestamp()
);
create table public.bil_community_moderators(user_id uuid primary key);
create table public.bil_blocks(blocker_id uuid,blocked_id uuid,primary key(blocker_id,blocked_id));
create table public.bil_friendships(requester_id uuid,addressee_id uuid,status text);
create table public.bil_public_profiles(
 user_id uuid primary key,display_name text,avatar_url text,locale_code text default 'en',
 bio text,discoverable boolean default true,allow_friend_requests boolean default true,
 profile_visibility text default 'public',show_posts boolean default true,show_followers boolean default true
);
create table public.bil_social_handles_v2(user_id uuid primary key,handle text,chosen boolean);
create table public.bil_community_posts(
 id uuid primary key,author_id uuid,body text default '',title text,
 visibility text default 'community',moderation_status text default 'approved',
 moderation_visibility text default 'visible',reviewed_at timestamptz,deleted_at timestamptz,
 created_at timestamptz default now(),media_url text,media_object_path text,media_mime_type text,
 media_bytes integer,media_width integer,media_height integer,location_label text
);
create table public.bil_follows(follower_id uuid,followed_id uuid,primary key(follower_id,followed_id));
create table public.bil_social_post_likes_v2(post_id uuid,user_id uuid,primary key(post_id,user_id));
create table public.bil_social_comments_v2(id uuid primary key,post_id uuid,author_id uuid,deleted_at timestamptz,removed_at timestamptz);
create table public.bil_community_reputation_accounts(owner_id uuid primary key,xp bigint);
create table public.bil_community_level_policy(level integer primary key,min_xp bigint,active boolean);
create table public.bil_community_referral_attributions(inviter_id uuid,relationship_qualified_at timestamptz,reward_eligible boolean);
create table public.bil_community_creator_certifications_v1(owner_id uuid primary key,status text);
create table public.bil_community_referral_policy(singleton boolean primary key,invite_links_enabled boolean,invite_ttl_days integer,max_invites_per_owner_per_utc_day integer);
create table public.bil_community_invites(id uuid primary key default gen_random_uuid(),inviter_id uuid,token_hash text unique,created_at timestamptz default clock_timestamp(),expires_at timestamptz);
create table public.bil_community_post_drafts_v1(
 draft_id uuid primary key,owner_id uuid not null,title text,body text,topic_slugs text[],
 circle_slug text,location_label text,mentioned_user_ids uuid[],collaborator_user_ids uuid[],
 hashtags text[],poll_question text,poll_options text[],poll_allow_multiple boolean,
 created_at timestamptz default clock_timestamp(),updated_at timestamptz default clock_timestamp()
);
create table public.bil_community_post_draft_media_v1(
 draft_id uuid references public.bil_community_post_drafts_v1(draft_id) on delete cascade,
 position smallint,object_path text,mime_type text,bytes integer,width integer,height integer
);
create table public.bil_community_post_media_v1(post_id uuid,object_path text);
create table public.bil_community_post_locations_v1(post_id uuid,label text);
create table public.bil_community_post_mentions_v1(post_id uuid,mentioned_user_id uuid);
create table public.bil_community_polls(post_id uuid primary key,allow_multiple boolean,closes_at timestamptz);
create table public.bil_community_poll_options(post_id uuid,id uuid,primary key(post_id,id));
create table public.bil_community_poll_votes(
 post_id uuid,option_id uuid,voter_id uuid references auth.users(id),
 primary key(post_id,option_id,voter_id),
 foreign key(post_id,option_id) references public.bil_community_poll_options(post_id,id)
);
create table public.bil_rate_limit_buckets(
 user_id uuid not null references auth.users(id) on delete cascade,
 action text not null,window_started_at timestamptz not null,hit_count integer not null default 1,
 primary key(user_id,action,window_started_at)
);
create table public.bil_content_policies(
 version text primary key,locale_code text not null default 'en',document_url text not null,
 effective_at timestamptz not null,active boolean not null default false
);
create unique index bil_content_policies_single_active_uidx
on public.bil_content_policies((active)) where active;
create table public.bil_content_policy_acceptances(
 user_id uuid references auth.users(id) on delete cascade,
 policy_version text references public.bil_content_policies(version),
 accepted_at timestamptz not null default now(),primary key(user_id,policy_version)
);

-- No behavior substitute for the guards/helpers: the runner injects their
-- unchanged real Git definitions, then the exact forward migration below.
-- auth.uid() above only emulates the trusted PostgREST JWT subject boundary.
-- PREBUILD_EXACT_HELPERS
do $$ declare t record; begin
 for t in select tablename from pg_tables where schemaname='public' loop
 execute format('alter table public.%I enable row level security',t.tablename);
 end loop;
end $$;

-- PREBUILD_EXACT_TRANSPORT
\ir ../../supabase/migrations/20261004073453_community_prebuild_privacy_write_hardening_v1.sql
create trigger qa_posts_member_access before insert or update on public.bil_community_posts
for each row execute function public.bil_guard_community_member_access();
create function public.qa_assert(ok boolean,label text) returns void language plpgsql as $$
begin if ok is not true then raise exception 'FAIL: %',label; end if; raise notice 'PASS: %',label; end
$$;
create function public.qa_expect_error(command text,expected text,label text) returns void language plpgsql as $$
declare caught text;
begin
 begin execute command; exception when others then get stacked diagnostics caught=returned_sqlstate; end;
 perform public.qa_assert(caught=expected,label);
end
$$;

-- Seed as fixture owner before lowering role. No app-role table CRUD grant.
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into auth.users values
('11111111-1111-4111-8111-111111111111',now()),
('22222222-2222-4222-8222-222222222222',now()),
('33333333-3333-4333-8333-333333333333',now()),
('44444444-4444-4444-8444-444444444444',now()),
('55555555-5555-4555-8555-555555555555',now());
update auth.users set email='fixture-invite-owner@example.invalid'
where id='11111111-1111-4111-8111-111111111111';
insert into auth.users(id,email) values
('66666666-6666-4666-8666-666666666666','fixture-admin@example.invalid');
insert into private.bil_ai_coach_admins values
('66666666-6666-4666-8666-666666666666',true);
insert into public.bil_public_profiles(user_id,display_name,bio,profile_visibility,show_posts,show_followers) values
('11111111-1111-4111-8111-111111111111','Fixture viewer','bio','public',true,true),
('22222222-2222-4222-8222-222222222222','Fixture target','bio','public',false,false),
('33333333-3333-4333-8333-333333333333','Fixture private','bio','private',true,true),
('44444444-4444-4444-8444-444444444444','Fixture suspended','bio','public',true,true),
('55555555-5555-4555-8555-555555555555','Fixture blocked','bio','public',true,true);
insert into public.bil_social_handles_v2 select id,'fixture_'||left(id::text,1),true from auth.users;
insert into public.bil_content_policies(version,document_url,effective_at,active)
values('community-policy-v1','https://www.bilhealth.com/community-policy',now()-interval '1 day',true);
insert into public.bil_content_policy_acceptances(user_id,policy_version)
select id,'community-policy-v1' from auth.users;
insert into private.bil_community_member_access values('44444444-4444-4444-8444-444444444444',true);
insert into public.bil_blocks values('55555555-5555-4555-8555-555555555555','11111111-1111-4111-8111-111111111111');
insert into public.bil_community_level_policy values(1,0,true),(2,100,true);
insert into public.bil_follows values('11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222');
insert into public.bil_community_posts(id,author_id,visibility,location_label) values
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','22222222-2222-4222-8222-222222222222','community','Cairo'),
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2','22222222-2222-4222-8222-222222222222','friends',null),
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3','11111111-1111-4111-8111-111111111111','community','Location for deletion'),
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4','11111111-1111-4111-8111-111111111111','community','Location kept private');
insert into public.bil_social_post_likes_v2 values
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','11111111-1111-4111-8111-111111111111'),
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2','11111111-1111-4111-8111-111111111111');
insert into public.bil_social_comments_v2 values
('cccccccc-cccc-4ccc-8ccc-ccccccccccc1','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','11111111-1111-4111-8111-111111111111',null,null),
('cccccccc-cccc-4ccc-8ccc-ccccccccccc2','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2','11111111-1111-4111-8111-111111111111',null,null);
insert into public.bil_community_referral_policy values(true,true,7,1);
insert into public.bil_community_polls values('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',false,null);
insert into public.bil_community_poll_options values
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','dddddddd-dddd-4ddd-8ddd-ddddddddddd1'),
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','dddddddd-dddd-4ddd-8ddd-ddddddddddd2');

set local role authenticated;
select qa_assert(current_user='authenticated','RPC tests use ordinary authenticated role');
select qa_expect_error('select * from public.bil_follows','42501','no direct social table read grant');
select qa_expect_error('insert into public.bil_follows values(gen_random_uuid(),gen_random_uuid())','42501','no direct social table write grant');
select qa_expect_error('select bil_consume_rate_limit(''community_handle_search_v2'',999,60)','22023','canonical quota cannot be raised by caller');
do $$ declare result jsonb; begin
 result:=bil_community_creator_projection_v1('22222222-2222-4222-8222-222222222222');
 perform qa_assert(result->'followers'='null'::jsonb and result->'approved_posts'='null'::jsonb and result->'likes_received'='null'::jsonb and result->'comments_received'='null'::jsonb and result->'contributor'='null'::jsonb,'non-owner hidden metrics are null, not fake zero');
 perform qa_assert(not exists(select 1 from jsonb_array_elements(result->'badges') b where b->>'badge_key' in('first_moment','contributor','appreciated','conversation_starter','connector')),'all hidden-metric-derived badges omitted');
end $$;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select qa_assert((bil_community_creator_projection_v1(auth.uid())->>'approved_posts')::int=2 and (bil_community_creator_projection_v1(auth.uid())->>'followers')::int=1,'owner retains genuine complete metrics');
reset role;
update public.bil_public_profiles set show_posts=true,show_followers=true where user_id='22222222-2222-4222-8222-222222222222';
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
set local role authenticated;
select qa_assert((bil_community_creator_projection_v1('22222222-2222-4222-8222-222222222222')->>'approved_posts')::int=1 and (bil_community_creator_projection_v1('22222222-2222-4222-8222-222222222222')->>'likes_received')::int=1 and (bil_community_creator_projection_v1('22222222-2222-4222-8222-222222222222')->>'comments_received')::int=1,'nonfriend counts only viewer-visible posts/reactions');
select qa_assert((select count(*)=1 and bool_and(user_id='22222222-2222-4222-8222-222222222222') from bil_search_community_profiles('Fixture',30)),'legacy discovery excludes private suspended and reverse-blocked targets');
select qa_expect_error('select bil_community_creator_projection_v1(''33333333-3333-4333-8333-333333333333'')','42501','private creator projection denied');
select qa_expect_error(format('select * from bil_search_community_profiles(%L,30)','bad'||chr(1)),'22023','legacy discovery rejects unsafe controls');
-- All 61 calls share one statement_timestamp(), so this quota regression does
-- not race a wall-clock minute rollover. The inner error rolls back its writes.
select qa_expect_error($command$do $quota$ begin
 for attempt in 1..61 loop perform * from bil_search_community_profiles('Fixture',30); end loop;
end $quota$;$command$,'P0001','legacy discovery consumes real canonical quota');
reset role;
delete from public.bil_rate_limit_buckets where user_id='11111111-1111-4111-8111-111111111111';
delete from public.bil_content_policy_acceptances where user_id='11111111-1111-4111-8111-111111111111';
set local role authenticated;
select qa_expect_error('select bil_upsert_my_community_post_draft_v1(''eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1'',p_body=>''unaccepted'')','42501','draft write requires genuine current policy receipt');
reset role;
insert into public.bil_content_policy_acceptances values('11111111-1111-4111-8111-111111111111','community-policy-v1',now());
set local role authenticated;
select bil_upsert_my_community_post_draft_v1(
 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1',p_title=>'Real title',p_body=>E'سطر عربي\nEnglish line\tmore',
 p_mentioned_user_ids=>array['22222222-2222-4222-8222-222222222222'::uuid],
 p_collaborator_user_ids=>array['22222222-2222-4222-8222-222222222222'::uuid],p_hashtags=>array['#Bil']);
select qa_assert(bil_get_my_community_post_draft_v1('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1')->>'body'=E'سطر عربي\nEnglish line\tmore','Arabic English multiline/tab draft preserved exactly');
select qa_assert(bil_get_my_community_post_draft_v1('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1')->>'title'='Real title' and bil_get_my_community_post_draft_v1('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1')->'hashtags'='["bil"]'::jsonb,'title and normalized hashtag persistence');
select qa_expect_error(format('select bil_upsert_my_community_post_draft_v1(''eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee2'',p_body=>%L)','bad'||chr(1)),'22023','unsafe control remains rejected');
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select qa_expect_error('select bil_get_my_community_post_draft_v1(''eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1'')','P0002','nonowner draft read denied');
select qa_expect_error('select bil_upsert_my_community_post_draft_v1(''eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1'',p_body=>''steal'')','42501','nonowner draft overwrite denied');
select qa_expect_error('select bil_delete_my_community_post_draft_v1(''eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1'')','P0002','nonowner draft delete denied');
select qa_expect_error('select bil_consume_my_community_post_draft_v1(''eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1'',''aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4'')','42501','nonowner draft consume denied');
reset role;
update public.bil_public_profiles set profile_visibility='private' where user_id='22222222-2222-4222-8222-222222222222';
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
set local role authenticated;
select qa_assert(bil_get_my_community_post_draft_v1('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1')->'mentions'='[]'::jsonb and bil_get_my_community_post_draft_v1('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1')->'collaborators'='[]'::jsonb,'saved identity removed after profile becomes private');
reset role;
update public.bil_public_profiles set profile_visibility='public' where user_id='22222222-2222-4222-8222-222222222222';
insert into public.bil_blocks values('11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222');
set local role authenticated;
select qa_assert(bil_get_my_community_post_draft_v1('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1')->'mentions'='[]'::jsonb and bil_get_my_community_post_draft_v1('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1')->'collaborators'='[]'::jsonb,'saved identity removed after block');
reset role;
delete from public.bil_blocks where blocker_id='11111111-1111-4111-8111-111111111111';
insert into private.bil_community_member_access values('22222222-2222-4222-8222-222222222222',true);
set local role authenticated;
select qa_assert(bil_get_my_community_post_draft_v1('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1')->'mentions'='[]'::jsonb and bil_get_my_community_post_draft_v1('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1')->'collaborators'='[]'::jsonb,'saved identity removed after suspension');
select qa_assert(bil_delete_my_community_post_draft_v1('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1')='{}'::text[],'owner delete exact draft succeeds');
reset role;
delete from private.bil_community_member_access where user_id='22222222-2222-4222-8222-222222222222';
insert into private.bil_community_member_access values('11111111-1111-4111-8111-111111111111',true);
set local role authenticated;
select qa_assert(bil_delete_community_post('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3'),'suspended owner may delete location-bearing post');
select qa_assert(not bil_delete_community_post('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'),'nonowner cannot delete another post');
select qa_expect_error('select * from bil_search_community_profiles(''Fixture'',30)','42501','suspended caller legacy discovery denied');
reset role;
-- Trigger still applies inside a definer owner-only mutation, without granting
-- direct authenticated access to the post table to make this test work.
create function public.qa_try_owner_post_edit() returns void language plpgsql security definer set search_path='' as $$
begin update public.bil_community_posts set body='unauthorized edit' where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4' and author_id=auth.uid(); end
$$;
set local role authenticated;
select qa_expect_error('select qa_try_owner_post_edit()','42501','suspended owner general edit remains denied');
reset role;
delete from private.bil_community_member_access where user_id='11111111-1111-4111-8111-111111111111';
update public.bil_community_posts set moderation_status='pending' where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4';
set local role authenticated;
select bil_upsert_my_community_post_draft_v1('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee3',p_body=>'Publish draft');
select qa_assert(bil_consume_my_community_post_draft_v1('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee3','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4')='{}'::text[],'own draft consume tied to own pending post');
select qa_expect_error('select bil_get_my_community_post_draft_v1(''eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee3'')','P0002','consumed draft no longer exists');
select qa_assert(bil_vote_community_poll_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',array['dddddddd-dddd-4ddd-8ddd-ddddddddddd1'::uuid])=1,'one genuine poll choice accepted');
select qa_expect_error('select bil_vote_community_poll_v1(''aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'',array[''dddddddd-dddd-4ddd-8ddd-ddddddddddd1''::uuid,''dddddddd-dddd-4ddd-8ddd-ddddddddddd2''::uuid])','22023','single-choice rejects two options');
reset role;
delete from public.bil_community_poll_votes;
select qa_assert(not has_function_privilege('anon','public.bil_community_creator_projection_v1(uuid)','execute') and not has_function_privilege('anon','public.bil_search_community_profiles(text,integer)','execute'),'anonymous changed data RPCs denied');
select qa_assert(not has_function_privilege('authenticated','public.bil_guard_community_member_access()','execute'),'trigger helper cannot be called as RPC');
select qa_assert((select bool_and(relrowsecurity) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r'),'fixture app tables keep RLS enabled');
select qa_assert((select bool_and(not has_table_privilege('authenticated',c.oid,'SELECT,INSERT,UPDATE,DELETE')) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r'),'no direct authenticated CRUD grants added');
commit;
\echo ISOLATED_FUNCTION_AND_ROLE_ASSERTIONS_PASSED

