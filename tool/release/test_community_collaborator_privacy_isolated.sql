-- Core actors: author111, accepted collaborator222, unrelated viewer444.
-- Trusted moderator333 and administrator555 separately exercise review access.
-- All identities are synthetic in an EMPTY local disposable database only.
\set ON_ERROR_STOP on
begin;
set local statement_timeout='20s';
set local lock_timeout='5s';
-- COLLAB_PRIVACY_EXACT_SEED
create function public.qa_collab_assert(p_ok boolean,p_label text)
returns void language plpgsql as $$ begin
 if p_ok is distinct from true then
  perform set_config('qa.collab_failure_count',
   (coalesce(nullif(current_setting('qa.collab_failure_count',true),''),'0')::integer+1)::text,true);
  raise notice 'FAIL: %',p_label;
 else
  raise notice 'PASS: %',p_label;
 end if;
end $$;
create function public.qa_collab_actor(p_id uuid) returns void language plpgsql as $$ begin
 perform set_config('request.jwt.claim.sub',p_id::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',p_id,'role','authenticated')::text,true);
end $$;
create function public.qa_collab_count() returns integer language sql as $$
 select jsonb_array_length(collaborators)
 from public.bil_community_post_reference_metadata_v1(array['aaaaaaaa-aaaa-4aaa-8aaa-000000000301'::uuid])
$$;
create function public.qa_collab_error(p_sql text,p_state text,p_label text)
returns void language plpgsql as $$ declare v_state text; begin
 begin execute p_sql; exception when others then get stacked diagnostics v_state=returned_sqlstate; end;
 perform public.qa_collab_assert(v_state=p_state,p_label);
end $$;
insert into private.bil_ai_coach_admins(user_id,active,reason)
values('55555555-5555-4555-8555-555555555555',true,'Local collaborator fixture admin');
update public.bil_public_profiles set display_name='Accepted collaborator',avatar_url='https://example.invalid/collab.png'
where user_id='22222222-2222-4222-8222-222222222222';
update public.bil_social_handles_v2 set handle='accepted_collab',chosen=true
where user_id='22222222-2222-4222-8222-222222222222';

set local role authenticated;
select qa_collab_actor('11111111-1111-4111-8111-111111111111');
select qa_collab_assert(not (select rolsuper or rolbypassrls from pg_roles where rolname=current_user),
 'genuine ordinary authenticated role has no RLS bypass');
select qa_collab_assert(not has_table_privilege(current_user,'public.bil_community_post_collaborators_v1','SELECT')
 and not has_table_privilege(current_user,'public.bil_community_post_collaborators_v1','UPDATE'),
 'RPC-only collaboration table remains inaccessible directly');
reset role;
-- Seed only the pending post as fixture owner. The immutable live baseline
-- deliberately grants no direct post INSERT: never grant it to make QA green.
-- All metadata setter, moderation, response, and projection calls below use
-- the ordinary authenticated role and genuine RPCs.
insert into public.bil_community_posts(id,author_id,body,visibility)
values('aaaaaaaa-aaaa-4aaa-8aaa-000000000301',auth.uid(),'Three actor privacy fixture','community');
set local role authenticated;
select bil_set_my_community_post_reference_metadata_v1('aaaaaaaa-aaaa-4aaa-8aaa-000000000301',
 'Privacy fixture title',array['habits'],array['22222222-2222-4222-8222-222222222222'::uuid]);
select bil_set_my_community_post_topics_v1('aaaaaaaa-aaaa-4aaa-8aaa-000000000301',array['nutrition']);
select bil_set_my_community_post_circle_v1('aaaaaaaa-aaaa-4aaa-8aaa-000000000301','healthy-circle');
select qa_collab_assert(qa_collab_count()=1,'author sees own pending invitation');
select qa_collab_actor('22222222-2222-4222-8222-222222222222');
select qa_collab_error($q$select bil_respond_community_collaboration_v1('aaaaaaaa-aaaa-4aaa-8aaa-000000000301',true)$q$,
 '42501','real acceptance denied before human approval');
select qa_collab_actor('44444444-4444-4444-8444-444444444444');
select qa_collab_assert(qa_collab_count() is null,'unrelated viewer cannot see pending post or invitation');
reset role;
select qa_collab_assert(not exists(select 1 from public.bil_community_notifications
 where entity_id='aaaaaaaa-aaaa-4aaa-8aaa-000000000301' and kind='collaboration_invite'),
 'no synthetic or premature invitation delivery before approval');
set local role authenticated;
select qa_collab_actor('33333333-3333-4333-8333-333333333333');
select bil_moderate_community_post('aaaaaaaa-aaaa-4aaa-8aaa-000000000301','approved');
select qa_collab_assert(qa_collab_count()=1,'trusted moderator sees pending collaborator after actual approval');
select qa_collab_actor('44444444-4444-4444-8444-444444444444');
select qa_collab_assert(qa_collab_count()=0,'unrelated viewer sees post but no unaccepted collaborator');
select qa_collab_actor('22222222-2222-4222-8222-222222222222');
select qa_collab_assert(qa_collab_count()=1,'collaborator sees own pending invitation');
select qa_collab_assert(bil_respond_community_collaboration_v1('aaaaaaaa-aaaa-4aaa-8aaa-000000000301',true)
 @> '{"status":"accepted","duplicate":false}'::jsonb,'real collaborator acceptance commits');
select qa_collab_assert(bil_respond_community_collaboration_v1('aaaaaaaa-aaaa-4aaa-8aaa-000000000301',true)
 @> '{"status":"accepted","duplicate":true}'::jsonb,'duplicate acceptance remains idempotent');
select qa_collab_actor('44444444-4444-4444-8444-444444444444');
select qa_collab_assert((select collaborators @> '[{"user_id":"22222222-2222-4222-8222-222222222222","handle":"accepted_collab","display_name":"Accepted collaborator","avatar_url":"https://example.invalid/collab.png","status":"accepted"}]'::jsonb
 from bil_community_post_reference_metadata_v1(array['aaaaaaaa-aaaa-4aaa-8aaa-000000000301'::uuid])),
 'public accepted collaborator identity is actual authoritative metadata');
reset role;
update public.bil_public_profiles set profile_visibility='private'
where user_id='22222222-2222-4222-8222-222222222222';
set local role authenticated;
select qa_collab_assert(qa_collab_count()=0,
 'CURRENT PRIVATE accepted third-party collaborator is hidden from unrelated viewer');
select qa_collab_actor('11111111-1111-4111-8111-111111111111');
select qa_collab_assert(qa_collab_count()=0,'author does not override another member private identity');
select qa_collab_actor('22222222-2222-4222-8222-222222222222');
select qa_collab_assert(qa_collab_count()=1,'private collaborator can still see own accepted identity');
select qa_collab_actor('33333333-3333-4333-8333-333333333333');
select qa_collab_assert(qa_collab_count()=1,'trusted moderator retains legitimate private-identity review');
select qa_collab_actor('55555555-5555-4555-8555-555555555555');
select qa_collab_assert(qa_collab_count()=1,'active server administrator retains legitimate review');
select qa_collab_actor('44444444-4444-4444-8444-444444444444');
select set_config('request.jwt.claims','{"sub":"44444444-4444-4444-8444-444444444444","role":"authenticated","user_metadata":{"role":"admin","is_moderator":true}}',true);
select qa_collab_assert(qa_collab_count()=0,'editable user metadata cannot forge moderator exception');
reset role;

update public.bil_public_profiles set profile_visibility='public',discoverable=false
where user_id='22222222-2222-4222-8222-222222222222';
set local role authenticated;
select qa_collab_assert(qa_collab_count()=0,'undiscoverable public collaborator is not projected to stranger');
reset role;
update public.bil_public_profiles set discoverable=true,profile_visibility='friends'
where user_id='22222222-2222-4222-8222-222222222222';
set local role authenticated;
select qa_collab_assert(qa_collab_count()=0,'friends-only collaborator hidden without mutual accepted friendship');
reset role;
insert into public.bil_friendships(requester_id,addressee_id,status,responded_at)
values('44444444-4444-4444-8444-444444444444','22222222-2222-4222-8222-222222222222','accepted',now());
set local role authenticated;
select qa_collab_assert(qa_collab_count()=1,'accepted friend can see friends-only collaborator');
reset role;
delete from public.bil_friendships;
update public.bil_public_profiles set profile_visibility='public'
where user_id='22222222-2222-4222-8222-222222222222';

insert into public.bil_blocks(blocker_id,blocked_id)
values('22222222-2222-4222-8222-222222222222','44444444-4444-4444-8444-444444444444');
set local role authenticated;
select qa_collab_assert(qa_collab_count()=0,'collaborator blocking unrelated viewer suppresses identity');
reset role;
delete from public.bil_blocks;
insert into public.bil_blocks(blocker_id,blocked_id)
values('44444444-4444-4444-8444-444444444444','22222222-2222-4222-8222-222222222222');
set local role authenticated;
select qa_collab_assert(qa_collab_count()=0,'viewer blocking collaborator suppresses identity in reverse direction');
reset role;
delete from public.bil_blocks;
insert into public.bil_blocks(blocker_id,blocked_id)
values('22222222-2222-4222-8222-222222222222','11111111-1111-4111-8111-111111111111');
set local role authenticated;
select qa_collab_actor('11111111-1111-4111-8111-111111111111');
select qa_collab_assert(qa_collab_count()=0,'post author exception cannot bypass collaborator block');
reset role;
delete from public.bil_blocks;
insert into private.bil_community_member_access(user_id,suspended,reason)
values('22222222-2222-4222-8222-222222222222',true,'Local suspension fixture');
set local role authenticated;
select qa_collab_actor('44444444-4444-4444-8444-444444444444');
select qa_collab_assert(qa_collab_count()=0,'suspended third-party accepted collaborator is not public');
select qa_collab_actor('33333333-3333-4333-8333-333333333333');
select qa_collab_assert(qa_collab_count()=1,'trusted moderation retains suspended-identity evidence');
reset role;
delete from private.bil_community_member_access;

-- Visibility guard never removes title/hashtags/topics/circle, consumes rows,
-- fabricates a declined response, or permanently revokes the stored acceptance.
set local role authenticated;
select qa_collab_actor('44444444-4444-4444-8444-444444444444');
select qa_collab_assert((select title='Privacy fixture title' and hashtags=array['habits']
 and qa_collab_count()=1
 and topics @> '[{"slug":"nutrition","post_count":1}]'::jsonb
 and circle @> '{"slug":"healthy-circle","post_count":1,"member_count":1}'::jsonb
 from bil_community_post_reference_metadata_v1(array['aaaaaaaa-aaaa-4aaa-8aaa-000000000301'::uuid])),
 'privacy changes do not corrupt accepted record or unrelated post metadata');
select qa_collab_error($q$select * from bil_community_post_reference_metadata_v1(null)$q$,'22023','null batch still denied');
select qa_collab_error($q$select * from bil_community_post_reference_metadata_v1(array[]::uuid[])$q$,'22023','empty batch still denied');
select qa_collab_error($q$select * from bil_community_post_reference_metadata_v1(array(select gen_random_uuid() from generate_series(1,101)))$q$,
 '22023','batch over100 remains denied');
select qa_collab_error($q$select * from bil_community_post_reference_metadata_v1(array['aaaaaaaa-aaaa-4aaa-8aaa-000000000301'::uuid,'aaaaaaaa-aaaa-4aaa-8aaa-000000000301'::uuid])$q$,
 '22023','duplicate batch still denied');
reset role;
update public.bil_community_post_collaborators_v1 set status='declined',responded_at=now();
set local role authenticated;
select qa_collab_assert(qa_collab_count()=0,'declined identity remains hidden from unrelated viewer');
select qa_collab_actor('11111111-1111-4111-8111-111111111111');
select qa_collab_assert(qa_collab_count()=1,'author still sees visible declined invitation status');
select qa_collab_actor('22222222-2222-4222-8222-222222222222');
select qa_collab_assert(qa_collab_count()=1,'collaborator still sees own declined status');
reset role;
update public.bil_community_post_collaborators_v1 set status='accepted';
insert into public.bil_blocks(blocker_id,blocked_id)
values('44444444-4444-4444-8444-444444444444','11111111-1111-4111-8111-111111111111');
set local role authenticated;
select qa_collab_actor('44444444-4444-4444-8444-444444444444');
select qa_collab_assert(qa_collab_count() is null,'blocked post author continues hiding entire post metadata');
reset role;
delete from public.bil_blocks;
select qa_collab_actor('33333333-3333-4333-8333-333333333333');
update public.bil_community_posts set moderation_visibility='hidden_by_moderator' where id='aaaaaaaa-aaaa-4aaa-8aaa-000000000301';
set local role authenticated;
select qa_collab_actor('44444444-4444-4444-8444-444444444444');
select qa_collab_assert(qa_collab_count() is null,'hidden post still has no public metadata');
select qa_collab_actor('33333333-3333-4333-8333-333333333333');
select qa_collab_assert(qa_collab_count()=1,'moderator retains hidden post review');
reset role;
update public.bil_community_posts set deleted_at=now() where id='aaaaaaaa-aaaa-4aaa-8aaa-000000000301';
set local role authenticated;
select qa_collab_assert(qa_collab_count() is null,'deleted post remains absent even for moderator');
select qa_collab_error($q$select * from public.bil_community_post_collaborators_v1$q$,'42501','no direct-table read bypass introduced');
reset role;
set local role anon;
select qa_collab_error($q$select * from bil_community_post_reference_metadata_v1(array['aaaaaaaa-aaaa-4aaa-8aaa-000000000301'::uuid])$q$,
 '42501','anonymous caller remains denied');
reset role;
do $$ begin
 if coalesce(nullif(current_setting('qa.collab_failure_count',true),''),'0')::integer<>0 then
  raise exception 'COLLABORATOR_PRIVACY_ASSERTIONS_FAILED: %',current_setting('qa.collab_failure_count',true);
 end if;
end $$;
select 'COLLABORATOR_PRIVACY_ROLE_ASSERTIONS_PASSED';
rollback;
