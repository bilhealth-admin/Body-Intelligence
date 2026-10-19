// Native PostgreSQL17, fresh synthetic loopback database only. No production config.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createRequire} from 'node:module';
import {randomUUID} from 'node:crypto';
const {Client}=createRequire(process.env.BIL_PG_QA_PACKAGE)('pg');
const config=JSON.parse(fs.readFileSync(process.env.BIL_CIRCLE_REVIEW_FIXTURE,'utf8'));
assert.equal(config.host,'127.0.0.1');assert.equal(config.port,55479);
assert.match(config.database,/^bil_circle_review_20261019_r\d+$/);
const db=new Client(config);await db.connect();
const root=new URL('../../',import.meta.url);
const read=path=>fs.readFileSync(new URL(path,root),'utf8');
const actorId=n=>`${String(n).repeat(8)}-${String(n).repeat(4)}-4${String(n).repeat(3)}-8${String(n).repeat(3)}-${String(n).repeat(12)}`;
const owner=actorId(1),member=actorId(2),moderator=actorId(3),administrator=actorId(4);
const actor=async id=>{await db.query('reset role');await db.query("select set_config('request.jwt.claim.sub',$1,false),set_config('request.jwt.claims',$2,false)",[id,JSON.stringify({sub:id,role:'authenticated'})]);await db.query('set role authenticated');};
const admin=async(text,args=[])=>{await db.query('reset role');return db.query(text,args);};
const rpc=async(name,args=[])=>(await db.query(`select public.${name}(${args.map((_,i)=>'$'+(i+1)).join(',')}) value`,args)).rows[0].value;
const expectDenied=async fn=>assert.rejects(fn,error=>error.code==='42501');
const snap=(kind,id)=>rpc('bil_circle_review_content_v1',[kind,id]);
const decide=(snapshot,decision,op=randomUUID(),reason='Synthetic review')=>rpc('bil_decide_circle_review_v1',[snapshot.kind,snapshot.id,snapshot.revision,decision,op,reason]);
let groups=0;const pass=text=>{groups++;console.log('PASS '+text);};
try {
  assert.equal((await db.query("select count(*)::int n from pg_tables where schemaname='public'")).rows[0].n,0);
  await db.query(read('tool/release/community_atomic_publish_live_baseline.sql'));
  const base=read('tool/qa_parallel/bil06/sql/fixtures/base_circles_foundation.sql');
  for(const name of ['bil_list_community_circles_v1','bil_join_community_circle_v1','bil_leave_community_circle_v1','bil_set_my_community_post_circle_v1','bil_community_circle_post_refs_v1']){
    const pattern=new RegExp('create(?:\\s+or\\s+replace)?\\s+function\\s+public\\.'+name+'\\s*\\([\\s\\S]*?\\bas\\s+(\\$[A-Za-z0-9_]*\\$)[\\s\\S]*?\\1\\s*;','i');
    const match=base.match(pattern);assert.ok(match,name);await db.query(match[0]);
  }
  await db.query(read('tool/qa_parallel/bil06/sql/fixtures/base_profile_visibility.sql'));
  await db.query(read('tool/qa_parallel/bil06/sql/fixtures/base_public_code_resolver.sql'));
  await db.query(read('supabase/tests/fixtures/circle_review_authority_live_20261019.sql'));
  await db.query(read('supabase/migrations/20261019071841_community_circle_reviewed_management_v1.sql'));
  await db.query(read('supabase/migrations/20261019075549_community_circle_storage_preflight_contract_v1.sql'));
  await db.query(read('supabase/migrations/20261019075856_community_circle_multipart_preflight_contract_v1.sql'));
  await db.query(read('tool/qa_parallel/bil06/sql/fixtures/seed.sql'));
  await db.query('insert into public.bil_community_moderators(user_id) values($1)',[moderator]);
  await db.query('insert into private.bil_ai_coach_admins(user_id) values($1)',[administrator]);
  await actor(owner);
  const request=randomUUID();
  const created=await rpc('bil_circle_create_v1',[request,'Synthetic reviewed circle','Circle description','Respect other members','public','open']);
  const slug=created.circle_slug;
  assert.equal(created.circle.review_status,'pending');assert.equal(created.circle.display_name,'Synthetic reviewed circle');
  assert.equal((await rpc('bil_circle_create_v1',[request,'Synthetic reviewed circle','Circle description','Respect other members','public','open'])).circle_slug,slug);
  const circle=(await admin('select id from public.bil_community_circles where slug=$1',[slug])).rows[0].id;
  await actor(owner);assert.equal((await rpc('bil_circle_capabilities_v1',[slug])).can_invite,false);
  assert.equal((await rpc('bil_circle_membership_v1',[slug])).can_post,false);
  await expectDenied(()=>rpc('bil_circle_invite_send_v1',[randomUUID(),slug,'2'.repeat(32)]));
  await actor(member);assert.equal((await rpc('bil_circle_read_v1',[slug])).circle,null);
  assert.equal((await rpc('bil_circle_search_v1',['',false,null,60])).circles.some(c=>c.slug===slug),false);
  assert.equal((await db.query('select slug from public.bil_list_community_circles_v1()')).rows.some(c=>c.slug===slug),false);
  await assert.rejects(()=>rpc('bil_join_community_circle_v1',[slug]),e=>e.code==='22023'&&e.message==='community_circle_not_found');
  await expectDenied(()=>rpc('bil_circle_review_queue_v1'));
  await expectDenied(()=>snap('circle',circle));
  pass('pending circle visible to creator only; old/new discovery, join, invite, publish and ordinary review gates');
  await actor(moderator);const original=await snap('circle',circle);
  assert.match(original.revision,/^[0-9a-f]{64}$/);
  assert.ok((await rpc('bil_circle_review_queue_v1')).some(r=>r.kind==='circle'&&r.id===circle));
  await admin("update public.bil_circle_metadata_v1 set description='Changed after opening review' where circle_id=$1",[circle]);
  await actor(moderator);await assert.rejects(()=>decide(original,'approve'),e=>e.code==='40001');
  const current=await snap('circle',circle),op=randomUUID();
  assert.equal((await decide(current,'approve',op)).duplicate,false);
  assert.equal((await decide(current,'approve',op)).duplicate,true);
  await assert.rejects(()=>decide(current,'reject',op),e=>e.code==='22023');
  await actor(member);assert.equal((await rpc('bil_circle_read_v1',[slug])).circle.review_status,'approved');
  pass('independent moderator approves exact revision; stale revision refused; operation replay idempotent and payload bound');
  await actor(owner);
  const prepare=async()=>rpc('bil_circle_media_prepare_v1',[randomUUID(),slug,'avatar','image/jpeg',1024,640,480]);
  const upload=async record=>db.query("insert into storage.objects(bucket_id,name,owner_id,metadata) values('community-circle-media',$1,$2,$3)",[record.object_path,owner,{size:1024,mimetype:'image/jpeg'}]);
  const first=(await prepare()).media;
  for(const metadata of [null,{}, {mimetype:'image/jpeg'}, {mimetype:'image/jpeg',contentLength:1024}, {mimetype:'image/jpeg',contentLength:1300}, {mimetype:'image/jpeg',size:1024}]) {
    assert.equal(await rpc('bil_circle_media_access_v1',[first.object_path,'insert',owner,metadata===null?null:JSON.stringify(metadata)]),true);
  }
  for(const metadata of [{size:1023,mimetype:'image/jpeg'},{mimetype:'image/png'},[],{size:null}]) {
    assert.equal(await rpc('bil_circle_media_access_v1',[first.object_path,'insert',owner,metadata===null?null:JSON.stringify(metadata)]),false);
  }
  await actor(member);assert.equal(await rpc('bil_circle_media_access_v1',[first.object_path,'insert',owner,null]),false);
  await actor(owner);await assert.rejects(()=>rpc('bil_circle_media_finish_v1',[randomUUID(),first.id]),e=>e.code==='55000');
  pass('Storage preflight accepts absent/declared metadata only for the reserved owner; mismatch and unconfirmed publication denied');
  await upload(first);
  assert.equal((await rpc('bil_circle_media_finish_v1',[randomUUID(),first.id])).media.status,'pending');
  assert.equal((await rpc('bil_circle_read_v1',[slug])).circle.avatar,null);
  await actor(member);assert.equal((await db.query('select count(*)::int n from storage.objects where name=$1',[first.object_path])).rows[0].n,0);
  await actor(owner);await db.query('update storage.objects set metadata=$2 where name=$1',[first.object_path,{size:1,mimetype:'image/jpeg'}]).then(r=>assert.equal(r.rowCount,0));
  await actor(moderator);const firstReview=await snap('media',first.id);assert.equal(firstReview.images.length,1);await decide(firstReview,'approve');
  await actor(member);assert.equal((await rpc('bil_circle_read_v1',[slug])).circle.avatar.id,first.id);
  pass('uploaded image stays private and immutable until separate image approval');
  await actor(owner);const next=(await prepare()).media;await upload(next);await rpc('bil_circle_media_finish_v1',[randomUUID(),next.id]);
  await actor(member);assert.equal((await rpc('bil_circle_read_v1',[slug])).circle.avatar.id,first.id);
  await actor(administrator);await decide(await snap('media',next.id),'reject');
  await actor(member);assert.equal((await rpc('bil_circle_read_v1',[slug])).circle.avatar.id,first.id);
  await actor(owner);const missing=(await prepare()).media;await upload(missing);await rpc('bil_circle_media_finish_v1',[randomUUID(),missing.id]);
  // Loopback-only fixture simulates a Storage API deletion; production uses Storage HTTP.
  await admin("select set_config('storage.allow_delete_query','true',false)");
  await admin('delete from storage.objects where name=$1',[missing.object_path]);await actor(administrator);
  const unavailable=await snap('media',missing.id);assert.equal(unavailable.available,false);await assert.rejects(()=>decide(unavailable,'approve'),e=>e.code==='55000');
  pass('rejected or missing replacement never overwrites approved public image');
  await admin('insert into public.bil_blocks(blocker_id,blocked_id) values($1,$2)',[member,owner]);
  await actor(member);assert.equal((await rpc('bil_circle_read_v1',[slug])).circle,null);
  assert.equal((await db.query('select count(*)::int n from storage.objects where name=$1',[first.object_path])).rows[0].n,0);
  await admin('delete from public.bil_blocks where blocker_id=$1 and blocked_id=$2',[member,owner]);
  pass('blocking a creator hides the custom circle and approved image from that member');
  await admin('insert into public.bil_community_moderators(user_id) values($1)',[owner]);await actor(owner);
  await expectDenied(()=>snap('media',missing.id));
  await admin("insert into private.bil_community_member_access(user_id,reason,suspended) values($1,'Synthetic suspension',true)",[moderator]);await actor(moderator);
  await expectDenied(()=>rpc('bil_circle_review_queue_v1'));
  await actor(administrator);await admin('update private.bil_ai_coach_admins set active=false where user_id=$1',[administrator]);await actor(administrator);await expectDenied(()=>snap('media',missing.id));
  await admin('update private.bil_ai_coach_admins set active=true where user_id=$1',[administrator]);
  pass('own content, suspended moderator and inactive administrator denied by actual live authority functions');
  await actor(member);const report=await rpc('bil_report_circle_v1',[slug,'Synthetic report reason']);assert.equal(await rpc('bil_report_circle_v1',[slug,'Duplicate reason']),report);
  await actor(administrator);const reported=await snap('report',report);assert.equal(reported.images.length,1);await decide(reported,'remove');
  await actor(member);assert.equal((await rpc('bil_circle_read_v1',[slug])).circle,null);
  assert.equal((await db.query('select count(*)::int n from storage.objects where name=$1',[first.object_path])).rows[0].n,0);
  pass('member can report circle; duplicate report deduplicated; independent administrator removes circle and its public images');
  for(const table of ['bil_circle_metadata_v1','bil_circle_media_v1','bil_circle_reports_v1'])await expectDenied(()=>db.query('select * from public.'+table));
  pass('new public tables have RLS and no browser direct read/write grant');
  await actor(owner);
  const concurrent=await rpc('bil_circle_create_v1',[randomUUID(),'Concurrent review','Synthetic description','Rules for members','public','open']);
  const concurrentId=(await admin('select id from public.bil_community_circles where slug=$1',[concurrent.circle_slug])).rows[0].id;
  await actor(administrator);const concurrentSnapshot=await snap('circle',concurrentId),operation=randomUUID(),connections=[];
  try {
    for(let i=0;i<2;i++){
      const c=new Client({...config,query_timeout:10000});await c.connect();connections.push(c);
      await c.query("select set_config('request.jwt.claim.sub',$1,false)",[administrator]);await c.query('set role authenticated');
    }
    const result=await Promise.all(connections.map(c=>c.query('select public.bil_decide_circle_review_v1($1,$2,$3,$4,$5,$6) receipt',['circle',concurrentId,concurrentSnapshot.revision,'approve',operation,'Concurrent reviewed approval'])));
    assert.deepEqual(result.map(r=>r.rows[0].receipt.duplicate).sort(),[false,true]);
    assert.equal((await admin('select count(*)::int n from private.bil_circle_review_decisions_v1 where actor_id=$1 and operation_id=$2',[administrator,operation])).rows[0].n,1);
  }finally{await Promise.all(connections.map(c=>c.end()));}
  pass('simultaneous native review retry commits one decision receipt');
  await admin("insert into public.bil_community_circles(slug,title_copy_key,description_copy_key,rules_copy_key) select 'rate-fixture-'||i,'community_circle_rate','community_circle_rate_body','community_circle_standard_rules' from generate_series(1,20) i");
  await actor(member);
  for(let i=1;i<=19;i++)await rpc('bil_report_circle_v1',['rate-fixture-'+i,'Synthetic rate test']);
  await assert.rejects(()=>rpc('bil_report_circle_v1',['rate-fixture-20','Synthetic rate test']),e=>e.code==='P0001'&&e.message==='circle_report_rate_limited');
  assert.equal((await admin('select count(*)::int n from public.bil_circle_reports_v1 where reporter_id=$1',[member])).rows[0].n,20);
  pass('report rate limit counts closed reports and rolls back the over-limit insertion');
  await admin(read('supabase/migrations/20261019073511_community_circle_owner_deletion_cleanup_v1.sql'));
  await actor(member);
  const retained=await rpc('bil_circle_create_v1',[randomUUID(),'Other creator circle','Independent creator','Rules for members','public','open']);
  await admin('delete from auth.users where id=$1',[owner]);
  assert.equal((await admin('select count(*)::int n from public.bil_circle_metadata_v1 where created_by=$1',[owner])).rows[0].n,0);
  assert.equal((await admin('select count(*)::int n from public.bil_community_circles where slug=$1',[slug])).rows[0].n,0);
  assert.equal((await admin('select count(*)::int n from public.bil_circle_media_v1 where owner_id=$1',[owner])).rows[0].n,0);
  assert.equal((await admin('select count(*)::int n from public.bil_community_circles where slug=$1',[retained.circle_slug])).rows[0].n,1);
  assert.equal((await admin("select has_function_privilege('authenticated','private.bil_remove_owned_circles_before_account_delete_v1()','EXECUTE') allowed")).rows[0].allowed,false);
  pass('account deletion removes owned Circle text/media records while preserving another creator circle');
  console.log('RESULT '+groups+' native groups PASS. Hosted Auth/Storage image bytes and portal UI are not exercised by this fixture.');
} finally {await db.end();}
