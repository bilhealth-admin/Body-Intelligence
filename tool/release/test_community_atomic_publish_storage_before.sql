-- The original LIVE Storage policies are replayed unchanged. This reproduces
-- the database authorization boundary, NOT an HTTP/cloud byte transport.
begin;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select set_config('request.jwt.claims','{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}',true);
select set_config('storage.operation','storage.object.get_authenticated',true);
select set_config('storage.allow_delete_query','true',true); -- actual Storage API deletion GUC
set local role authenticated;
insert into storage.objects(bucket_id,name,owner_id,metadata) values('community-post-images',
 '11111111-1111-4111-8111-111111111111/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1.png',
 '11111111-1111-4111-8111-111111111111','{"size":100,"mimetype":"image/png","eTag":"reviewed-bytes"}');
reset role;
insert into public.bil_community_posts(id,author_id,body,visibility) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','11111111-1111-4111-8111-111111111111','Storage policy reproduction','community');
select public.bil_set_my_community_post_media_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
 '[{"object_path":"11111111-1111-4111-8111-111111111111/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1.png","mime_type":"image/png","bytes":100,"width":10,"height":10}]');
update public.bil_community_posts set moderation_status='approved',reviewed_at=now()
 where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
set local role authenticated;
delete from storage.objects where name='11111111-1111-4111-8111-111111111111/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1.png';
insert into storage.objects(bucket_id,name,owner_id,metadata) values('community-post-images',
 '11111111-1111-4111-8111-111111111111/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1.png',
 '11111111-1111-4111-8111-111111111111','{"size":100,"mimetype":"image/png","eTag":"unreviewed-replacement"}');
reset role;
select qa_atomic_assert((select moderation_status='approved' from public.bil_community_posts
 where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'),'Post stayed approved after replacement');
select qa_atomic_assert((select metadata->>'eTag'='unreviewed-replacement' from storage.objects
 where name='11111111-1111-4111-8111-111111111111/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1.png'),
 'Ordinary owner removed reviewed image and inserted new object at the same approved path');
rollback;
select 'ORIGINAL_STORAGE_REPLACEMENT_DEFECT_REPRODUCED';
