-- Every product call below executes its genuine function under authenticated.
-- Postgres inspection/seeding is explicit fixture setup, never app-table grants.
begin;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select set_config('request.jwt.claims','{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}',true);
select set_config('storage.operation','storage.object.get_authenticated',true);
select set_config('storage.allow_delete_query','true',true);
select qa_atomic_assert(not has_table_privilege('authenticated','private.bil_community_publish_operations_v1','SELECT,INSERT,UPDATE,DELETE')
 and not has_table_privilege('anon','private.bil_community_publish_operations_v1','SELECT,INSERT,UPDATE,DELETE')
 and not has_table_privilege('service_role','private.bil_community_publish_operations_v1','SELECT,INSERT,UPDATE,DELETE'),'Journal is RPC-only');
set local role anon;
select qa_atomic_error($q$select public.bil_begin_my_community_publish_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',qa_atomic_payload())$q$,'42501');
reset role;
set local role authenticated;
select qa_atomic_error('select * from private.bil_community_publish_operations_v1','42501');
select qa_atomic_error($q$select public.bil_begin_my_community_publish_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa99',qa_atomic_payload('[]','{"unexpected":"client"}'))$q$,'22023');
select qa_atomic_error($q$select public.bil_begin_my_community_publish_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa99',qa_atomic_payload('[{"object_path":"22222222-2222-4222-8222-222222222222/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa99/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3.png","mime_type":"image/png","bytes":100,"width":10,"height":10}]'))$q$,'22023');
select qa_atomic_error($q$select public.bil_begin_my_community_publish_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa99',qa_atomic_payload('[{"object_path":"11111111-1111-4111-8111-111111111111/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa99/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3.png","mime_type":"image/png","bytes":100.5,"width":10,"height":10}]'))$q$,'22023');
select qa_atomic_error($q$select private.bil_lock_community_publish_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1')$q$,'42501');
select qa_atomic_assert(public.bil_begin_my_community_publish_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',qa_atomic_payload())->>'status'='prepared','Begin prepared');
select qa_atomic_assert(public.bil_begin_my_community_publish_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',qa_atomic_payload())->>'payload'=qa_atomic_payload()::text,'Retry preserves exact payload');
reset role;
insert into private.bil_community_member_access(user_id,suspended,reason) values('11111111-1111-4111-8111-111111111111',true,'Local isolated suspension fixture');
set local role authenticated;
select qa_atomic_assert(public.bil_begin_my_community_publish_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',qa_atomic_payload())->>'status'='prepared','Suspension does not hide existing operation');
select qa_atomic_error($q$select public.bil_publish_community_post_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',qa_atomic_payload())$q$,'42501');
select qa_atomic_error($q$select public.bil_begin_my_community_publish_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa98',qa_atomic_payload())$q$,'42501');
select qa_atomic_assert(public.bil_abort_my_community_publish_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1')->>'aborted'='true','Suspended owner retains privacy cancellation');
reset role;
delete from private.bil_community_member_access where user_id='11111111-1111-4111-8111-111111111111';
set local role authenticated;
select qa_atomic_error($q$select public.bil_begin_my_community_publish_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',qa_atomic_payload('[]','{"body":"changed"}'))$q$,'22023','community_publish_payload_conflict');
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select qa_atomic_error($q$select public.bil_abort_my_community_publish_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1')$q$,'42501','community_publish_operation_not_owned');
select qa_atomic_error($q$select public.bil_begin_my_community_publish_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',qa_atomic_payload())$q$,'42501','community_publish_operation_not_owned');
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select qa_atomic_assert(public.bil_abort_my_community_publish_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1')->>'status'='aborted','Prepared abort');
select qa_atomic_assert(public.bil_begin_my_community_publish_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',qa_atomic_payload())->>'status'='aborted','Aborted ID cannot revive');
select qa_atomic_assert(public.bil_abort_my_community_publish_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2') @>
 '{"status":"aborted","aborted":true,"payload":null,"media_paths":[]}'::jsonb,'Missing abort persists full null-payload tombstone');
select qa_atomic_assert(public.bil_begin_my_community_publish_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',qa_atomic_payload())->>'status'='aborted','Delayed begin sees tombstone');
select qa_atomic_error($q$insert into storage.objects(bucket_id,name,owner_id,metadata) values('community-post-images','11111111-1111-4111-8111-111111111111/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2.png','11111111-1111-4111-8111-111111111111','{"size":100,"mimetype":"image/png"}')$q$,'42501');
-- Genuine full rich payload, failed near the END of commit (foreign draft).
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select public.bil_upsert_my_community_post_draft_v1('dddddddd-dddd-4ddd-8ddd-ddddddddddd1',p_body=>'Foreign draft');
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select public.bil_upsert_my_community_post_draft_v1('dddddddd-dddd-4ddd-8ddd-ddddddddddd2',p_body=>'Owner draft');
reset role;
create temp table qa_rich(payload jsonb);
insert into qa_rich values(qa_atomic_payload(
 '[{"object_path":"11111111-1111-4111-8111-111111111111/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3.png","mime_type":"image/png","bytes":100,"width":10,"height":10}]',
 '{"title":"Atomic title","hashtags":["nutrition"],"topic_slugs":["nutrition"],"circle_slug":"healthy-circle","location_label":"Local fixture","mentioned_user_ids":["22222222-2222-4222-8222-222222222222"],"collaborator_user_ids":["22222222-2222-4222-8222-222222222222"],"poll":{"question":"Choose","options":["One","Two"],"allow_multiple":false,"closes_at":null},"persistent_draft_id":"dddddddd-dddd-4ddd-8ddd-ddddddddddd1"}'));
grant select on qa_rich to authenticated; -- fixture payload only, never an app table
set local role authenticated;
select public.bil_begin_my_community_publish_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3',(select payload from qa_rich));
select qa_atomic_error($q$select public.bil_publish_community_post_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3',(select payload from qa_rich))$q$,'42501','community_publish_media_unverified');
insert into storage.objects(bucket_id,name,owner_id,metadata) values('community-post-images',
 '11111111-1111-4111-8111-111111111111/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3.png',
 '11111111-1111-4111-8111-111111111111','{"size":100,"mimetype":"image/png","eTag":"genuine-fixture"}');
select qa_atomic_error($q$select public.bil_publish_community_post_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3',(select payload from qa_rich))$q$,'42501','community_draft_publish_draft_unavailable');
reset role;
select qa_atomic_assert(not exists(select 1 from public.bil_community_posts where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3')
 and not exists(select 1 from public.bil_community_post_hashtags_v1 where post_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3')
 and not exists(select 1 from public.bil_community_polls where post_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3')
 and not exists(select 1 from public.bil_push_outbox where source_key='community_post_review:aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3')
 and exists(select 1 from public.bil_community_post_drafts_v1 where draft_id='dddddddd-dddd-4ddd-8ddd-ddddddddddd1')
 and (select status='prepared' from private.bil_community_publish_operations_v1 where operation_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3'),
 'Final draft failure rolled back genuine post/metadata/poll/outbox, preserved draft and prepared journal');
set local role authenticated;
select qa_atomic_assert(public.bil_abort_my_community_publish_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3')->'media_paths'=
 '["11111111-1111-4111-8111-111111111111/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3.png"]'::jsonb,'Prepared abort returns exact media paths');
delete from storage.objects where name='11111111-1111-4111-8111-111111111111/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3.png';
reset role;
update qa_rich set payload=replace(replace(payload::text,'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4'),
 'dddddddd-dddd-4ddd-8ddd-ddddddddddd1','dddddddd-dddd-4ddd-8ddd-ddddddddddd2')::jsonb;
set local role authenticated;
select public.bil_begin_my_community_publish_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4',(select payload from qa_rich));
select qa_atomic_error($q$insert into storage.objects(bucket_id,name,owner_id,metadata) values('community-post-images','11111111-1111-4111-8111-111111111111/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb4.png','11111111-1111-4111-8111-111111111111','{"size":100,"mimetype":"image/png"}')$q$,'42501');
insert into storage.objects(bucket_id,name,owner_id,metadata) values('community-post-images',
 '11111111-1111-4111-8111-111111111111/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3.png',
 '11111111-1111-4111-8111-111111111111','{"size":100,"mimetype":"image/png","eTag":"genuine-fixture"}');
reset role;
update storage.objects set metadata='{"size":101,"mimetype":"image/png","eTag":"genuine-fixture"}'
 where name='11111111-1111-4111-8111-111111111111/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3.png';
set local role authenticated;
select qa_atomic_error($q$select public.bil_publish_community_post_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4',(select payload from qa_rich))$q$,'42501','community_publish_media_unverified');
reset role;
update storage.objects set metadata='{"size":100,"mimetype":"image/jpeg","eTag":"genuine-fixture"}'
 where name='11111111-1111-4111-8111-111111111111/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3.png';
set local role authenticated;
select qa_atomic_error($q$select public.bil_publish_community_post_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4',(select payload from qa_rich))$q$,'42501','community_publish_media_unverified');
reset role;
update storage.objects set metadata='{"size":100,"mimetype":"image/png","eTag":"genuine-fixture"}',owner_id='22222222-2222-4222-8222-222222222222'
 where name='11111111-1111-4111-8111-111111111111/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3.png';
set local role authenticated;
select qa_atomic_error($q$select public.bil_publish_community_post_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4',(select payload from qa_rich))$q$,'42501','community_publish_media_unverified');
reset role;
update storage.objects set owner_id='11111111-1111-4111-8111-111111111111'
 where name='11111111-1111-4111-8111-111111111111/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3.png';
set local role authenticated;
select qa_atomic_assert(public.bil_publish_community_post_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4',(select payload from qa_rich)) @>
 '{"committed":true,"status":"committed","post_id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4"}'::jsonb,'Atomic full commit');
select qa_atomic_assert(public.bil_publish_community_post_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4',(select payload from qa_rich))->>'committed'='true','Lost-response commit retry');
select qa_atomic_assert(public.bil_abort_my_community_publish_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4')->'payload'=(select payload from qa_rich),'Committed abort returns complete verified receipt');
reset role;
select qa_atomic_assert((select moderation_status='pending' and title='Atomic title' from public.bil_community_posts where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4')
 and (select count(*)=1 from public.bil_community_post_topics where post_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4')
 and (select count(*)=1 from public.bil_community_post_circles where post_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4')
 and (select count(*)=1 from public.bil_community_post_locations_v1 where post_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4')
 and (select count(*)=1 from public.bil_community_post_mentions_v1 where post_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4')
 and (select count(*)=1 from public.bil_community_post_collaborators_v1 where post_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4')
 and (select count(*)=2 from public.bil_community_poll_options where post_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4')
 and not exists(select 1 from public.bil_community_post_drafts_v1 where draft_id='dddddddd-dddd-4ddd-8ddd-ddddddddddd2')
 and not exists(select 1 from public.bil_community_notifications where entity_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4'),
 'Actual pending post+all metadata+poll+draft consumed, NO pre-human-approval Activity');
select qa_atomic_assert((select coalesce(sum(hit_count),0)=1 from public.bil_rate_limit_buckets where user_id='11111111-1111-4111-8111-111111111111' and action='post'),
 'Only one genuine post quota charged, not failed commit/retry');
update public.bil_community_posts set moderation_status='approved',reviewed_at=now() where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4';
select qa_atomic_assert((select count(*)=1 from public.bil_community_notifications where entity_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4' and kind='collaboration_invite'),
 'Genuine approval trigger emits collaborator invite only after human review');
set local role authenticated;
select qa_atomic_assert(public.bil_begin_my_community_publish_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4',(select payload from qa_rich))->>'committed'='true','Human approval does not invalidate submission receipt');
delete from storage.objects where name='11111111-1111-4111-8111-111111111111/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3.png';
select qa_atomic_error($q$insert into storage.objects(bucket_id,name,owner_id,metadata) values('community-post-images','11111111-1111-4111-8111-111111111111/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3.png','11111111-1111-4111-8111-111111111111','{"size":100,"mimetype":"image/png"}')$q$,'42501');
select qa_atomic_assert(public.bil_abort_my_community_publish_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4') @>
 '{"status":"unavailable","committed":false,"was_committed":true,"post_available":false,"cleanup_allowed":false,"media_paths":[]}'::jsonb,'Missing media never gets committed/cleanup success');
reset role;
-- Restore fixture object as admin solely to test independent mutation/deletion checks.
insert into storage.objects(bucket_id,name,owner_id,metadata,id,version) select 'community-post-images',
 x->>'path',x->>'owner_id',jsonb_build_object('size',x->'size','mimetype',x->>'mimetype','eTag',x->>'etag'),(x->>'object_id')::uuid,x->>'version'
 from private.bil_community_publish_operations_v1 j,jsonb_array_elements(j.committed_projection->'storage') x
 where j.operation_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4';
update public.bil_community_posts set title='Changed after receipt' where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4';
set local role authenticated;
select qa_atomic_assert(public.bil_begin_my_community_publish_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4',(select payload from qa_rich)) @>
 '{"status":"unavailable","committed":false,"cleanup_allowed":false,"media_paths":[]}'::jsonb,'Changed content never gets false committed receipt');
reset role;
update public.bil_community_posts set title='Atomic title',deleted_at=now() where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4';
set local role authenticated;
select qa_atomic_assert(public.bil_publish_community_post_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4',(select payload from qa_rich)) @>
 '{"status":"unavailable","committed":false,"cleanup_allowed":false,"media_paths":[]}'::jsonb,'Deleted post never gets false committed receipt');
-- Genuine canonical owner deletion after an ambiguous/lost commit response.
select public.bil_begin_my_community_publish_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8',qa_atomic_payload());
select public.bil_publish_community_post_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8',qa_atomic_payload());
select qa_atomic_assert(public.bil_delete_community_post('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8'),'Canonical owner deletion succeeds');
select qa_atomic_assert(public.bil_begin_my_community_publish_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8',qa_atomic_payload()) @>
 jsonb_build_object('operation_id','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8','owner_id','11111111-1111-4111-8111-111111111111',
 'status','unavailable','committed',false,'was_committed',true,'post_available',false,'cleanup_allowed',false,
 'media_paths','[]'::jsonb,'payload',qa_atomic_payload()),'Deleted historical commit explicitly cannot claim publication success');
select qa_atomic_assert(public.bil_abort_my_community_publish_operation_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8') @>
 jsonb_build_object('status','unavailable','post_id','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8','aborted',false,
 'committed',false,'was_committed',true,'post_available',false,'cleanup_allowed',false,'media_paths','[]'::jsonb,
 'payload',qa_atomic_payload()),'Explicit cancel can abandon only local journal, never media or server terminal journal');
reset role;
select qa_atomic_assert((select status='committed' from private.bil_community_publish_operations_v1
 where operation_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8'),'Historical committed journal remains terminal');
set local role authenticated;
-- Eight prepared operations cap is checked under the same owner lock.
do $$ declare v_id uuid; begin
 for i in 1..8 loop v_id:=('cccccccc-cccc-4ccc-8ccc-'||lpad(i::text,12,'0'))::uuid;
  perform public.bil_begin_my_community_publish_operation_v1(v_id,qa_atomic_payload()); end loop;
end $$;
select qa_atomic_error($q$select public.bil_begin_my_community_publish_operation_v1('cccccccc-cccc-4ccc-8ccc-000000000009',qa_atomic_payload())$q$,'54000','community_publish_prepared_limit');
select public.bil_abort_my_community_publish_operation_v1('cccccccc-cccc-4ccc-8ccc-000000000001');
select qa_atomic_assert(public.bil_begin_my_community_publish_operation_v1('cccccccc-cccc-4ccc-8ccc-000000000009',qa_atomic_payload())->>'status'='prepared','Abort releases prepared cap');
-- NEW-ID budget is shared by absent abort and begin; retries remain available.
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
do $$ begin for i in 1..60 loop
 perform public.bil_abort_my_community_publish_operation_v1(('eeeeeeee-eeee-4eee-8eee-'||lpad(i::text,12,'0'))::uuid);
end loop; end $$;
select qa_atomic_error($q$select public.bil_abort_my_community_publish_operation_v1('eeeeeeee-eeee-4eee-8eee-000000000061')$q$,'54000','community_publish_new_operation_minute_limit');
select qa_atomic_error($q$select public.bil_begin_my_community_publish_operation_v1('eeeeeeee-eeee-4eee-8eee-000000000061',qa_atomic_payload())$q$,'54000','community_publish_new_operation_minute_limit');
select qa_atomic_assert(public.bil_abort_my_community_publish_operation_v1('eeeeeeee-eeee-4eee-8eee-000000000001')->>'aborted'='true','Existing abort not quota limited');
reset role;
insert into private.bil_community_publish_operations_v1(operation_id,owner_id,status,created_at)
 select ('ffffffff-ffff-4fff-8fff-'||lpad(i::text,12,'0'))::uuid,'55555555-5555-4555-8555-555555555555','aborted',now()-interval '1 hour'
 from generate_series(1,1000) i;
set local role authenticated;
select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
select qa_atomic_error($q$select public.bil_abort_my_community_publish_operation_v1('ffffffff-ffff-4fff-8fff-000000001001')$q$,'54000','community_publish_new_operation_day_limit');
select qa_atomic_assert(public.bil_abort_my_community_publish_operation_v1('ffffffff-ffff-4fff-8fff-000000000001')->>'aborted'='true','Existing retry not day limited');
reset role;
rollback;
select 'ATOMIC_FUNCTION_AND_ROLE_ASSERTIONS_PASSED';
