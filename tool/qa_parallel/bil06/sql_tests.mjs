// Executes real RPCs and PostgreSQL role/RLS checks over the local TCP connection.
// All rows below are synthetic. Native simultaneous-session races are separate.
export async function run(t){
  const {sql,scalar,actor,admin,rpc,denied,test,identities,requestId,assert}=t;
  const create=(id,name='Walking together',access='public',join='open')=>rpc('bil_circle_create_v1',[id,name,'A real local test circle.','Be considerate.',access,join]);
  const code=n=>n.repeat(32);
  let publicCircle;let privateCircle;let privateRequest;let invite;let avatar;let cover;let recipientMembership;
  await test('New tables have RLS; all private helpers and anon RPCs are denied',async()=>{
    const r=await sql("select relname,relrowsecurity from pg_class where oid=any(array['public.bil_circle_metadata_v1'::regclass,'public.bil_circle_invites_v1'::regclass,'public.bil_circle_media_v1'::regclass,'public.bil_circle_operations_v1'::regclass])");
    assert.equal(r.rows.length,4);assert(r.rows.every(x=>x.relrowsecurity));
    assert.equal(await scalar("select bool_and(not has_function_privilege('authenticated',p.oid,'execute')) as value from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname like 'bil_circle_%_v1'"),true);
    await actor('', 'anon');
    await denied('anon capabilities',()=>rpc('bil_circle_capabilities_v1'), '42501');
    await denied('anon search',()=>rpc('bil_circle_search_v1'), '42501');
    await denied('anon create',()=>create(requestId()), '42501');
    await denied('anon invite list',()=>rpc('bil_circle_invites_v1'), '42501');
    await denied('anon media helper',()=>rpc('bil_circle_media_access_v1',['x','read']), '42501');
  });
  for(const n of ['', '1','2','3'])await test((n?'actor '+n:'anon')+' cannot bypass RPC authority with direct table DML',async()=>{
    await actor(n,n?'authenticated':'anon');
    for(const table of ['bil_circle_metadata_v1','bil_circle_invites_v1','bil_circle_media_v1','bil_circle_operations_v1']){
      await denied(table+' select',()=>sql('select * from public.'+table),'42501');
      await denied(table+' insert',()=>sql('insert into public.'+table+' default values'),'42501');
      await denied(table+' delete',()=>sql('delete from public.'+table),'42501');
      const column=table==='bil_circle_metadata_v1'?'display_name':table==='bil_circle_operations_v1'?'operation':'status';
      await denied(table+' update',()=>sql('update public.'+table+' set '+column+'='+column),'42501');
    }
  });
  await test('Create capability uses saved name+BIL Code and policy without bio/chosen handle',async()=>{
    await actor('1');const c=await rpc('bil_circle_capabilities_v1');
    assert.equal(c.owner_id,identities['1']);assert.equal(c.can_create,true);assert.equal(c.can_search,true);assert.equal(c.can_invite,false);
    const r=await admin('select bio,h.chosen from public.bil_public_profiles p join public.bil_social_handles_v2 h on h.user_id=p.user_id where p.user_id=$1',[identities['1']]);
    assert.equal(r.rows[0].bio,null);assert.equal(r.rows[0].chosen,false);
    for(const n of ['5','6','7']){await actor(n);const cap=await rpc('bil_circle_capabilities_v1');assert.equal(cap.can_create,false);await denied('unready account cannot create',()=>create(requestId()),'42501');}
    await actor('7');assert.equal((await rpc('bil_circle_capabilities_v1')).can_search,false);
  });
  await test('Policy refusal never accepts policy or leaves a create receipt',async()=>{
    await actor('1');await admin('delete from public.bil_content_policy_acceptances where user_id=$1',[identities['1']]);
    const id=requestId();assert.equal((await rpc('bil_circle_capabilities_v1')).can_create,false);
    await denied('missing policy',()=>create(id),'42501');assert.equal(await rpc('bil_circle_operation_v1',[id]),null);
    assert.equal((await admin('select count(*)::int as n from public.bil_content_policy_acceptances where user_id=$1',[identities['1']])).rows[0].n,0);
    await admin("insert into public.bil_content_policy_acceptances(user_id,policy_version) values($1,'bil06-local-v1')",[identities['1']]);
  });
  await test('Create commits real text, one real moderator and zero invented invites/media',async()=>{
    await actor('1');publicCircle=await create(requestId(),'المشي الصحي 🏃');
    assert.equal(publicCircle.committed,true);assert.equal(publicCircle.circle.display_name,'المشي الصحي 🏃');assert.equal(publicCircle.circle.member_count,1);
    assert.equal(publicCircle.circle.post_count,0);assert.equal(publicCircle.circle.membership_role,'moderator');assert.equal(publicCircle.circle.avatar,null);assert.equal(publicCircle.circle.cover,null);
    assert.equal((await rpc('bil_circle_invites_v1',[publicCircle.circle_slug])).invites.length,0);
    assert.equal((await rpc('bil_circle_read_v1',[publicCircle.circle_slug])).circle.display_name,'المشي الصحي 🏃');
  });
  await test('Duplicate create request is idempotent; changed payload is rejected',async()=>{
    await actor('1');privateRequest=requestId();privateCircle=await create(privateRequest,'Private recovery circle','private','invite');
    const repeated=await create(privateRequest,'Private recovery circle','private','invite');assert.equal(repeated.circle_slug,privateCircle.circle_slug);
    await denied('same id changed payload',()=>create(privateRequest,'Different name','private','invite'),'22023');
    const r=await admin('select count(*)::int as n from public.bil_circle_operations_v1 where owner_id=$1 and request_id=$2',[identities['1'],privateRequest]);assert.equal(r.rows[0].n,1);
  });
  await test('Authoritative receipt belongs only to actor; readback never repeats a mutation',async()=>{
    await actor('3');assert.equal(await rpc('bil_circle_operation_v1',[privateRequest]),null);
    await actor('1');for(let i=0;i<3;i++)assert.equal((await rpc('bil_circle_operation_v1',[privateRequest])).circle_slug,privateCircle.circle_slug);
    const r=await admin('select count(*)::int as n from public.bil_community_circle_memberships where circle_id=$1',[privateCircle.circle_slug.replace('c-','').replace(/^(.{8})(.{4})(.{4})(.{4})(.{12})$/,'$1-$2-$3-$4-$5')]);assert.equal(r.rows[0].n,1);
  });
  await test('Create rejects unsafe controls, invalid lengths and private open autojoin',async()=>{
    await actor('1');await denied('short name',()=>create(requestId(),'A'),'22023');await denied('long name',()=>create(requestId(),'😀'.repeat(81)),'22023');
    await denied('control name',()=>create(requestId(),'bad\tname'),'22023');await denied('private open',()=>create(requestId(),'Private unsafe','private','open'),'22023');
    const r=await create(requestId(),'😀'.repeat(80));assert.equal([...r.circle.display_name].length,80);
  });
  await test('Private circles are absent from third-party search, direct read and membership metadata',async()=>{
    await actor('3');assert.equal((await rpc('bil_circle_search_v1',['Private recovery'])).circles.length,0);
    assert.equal((await rpc('bil_circle_read_v1',[privateCircle.circle_slug])).circle,null);
    const m=await rpc('bil_circle_membership_v1',[privateCircle.circle_slug]);assert.equal(m.visible,false);assert.equal(m.is_member,false);assert.equal(m.can_read_posts,false);
    assert.equal((await rpc('bil_circle_search_v1',['hidden'])).circles.length,0);
  });
  await test('Server search pages globally after privacy filter with no duplicates and real counts',async()=>{
    await actor('3');let after=null;const found=[];let pages=0;
    do{const page=await rpc('bil_circle_search_v1',['',false,after,1]);assert.equal(page.owner_id,identities['3']);assert(page.circles.length<=1);found.push(...page.circles.map(x=>x.slug));after=page.next_after_slug;assert(++pages<30);}while(after);
    assert(found.includes(publicCircle.circle_slug));assert(found.includes('alpha-circle'));assert(!found.includes(privateCircle.circle_slug));assert(!found.includes('hidden-base'));assert.equal(new Set(found).size,found.length);assert.deepEqual(found,[...found].sort());
    const native=(await rpc('bil_circle_search_v1',['المشي'])).circles;assert.equal(native.length,1);assert.equal(native[0].display_name,'المشي الصحي 🏃');assert.equal(native[0].member_count,1);
  });
  await test('Search treats percent/underscore literally and bounds query/cursor/page',async()=>{
    await actor('1');const special=await create(requestId(),'100% _ honest');await actor('3');
    const page=await rpc('bil_circle_search_v1',['%']);assert.equal(page.circles.length,1);assert.equal(page.circles[0].slug,special.circle_slug);
    for(const limit of [0,61,null])await denied('invalid page bound',()=>rpc('bil_circle_search_v1',['',false,null,limit]),'22023');
    await denied('cursor injection',()=>rpc('bil_circle_search_v1',['',false,'../hidden',10]),'22023');await denied('control query',()=>rpc('bil_circle_search_v1',['hello\nworld']),'22023');await denied('oversize query',()=>rpc('bil_circle_search_v1',['x'.repeat(121)]),'22023');
  });
  await test('Invite send resolves actual BIL Code and duplicate clicks create one pending invite',async()=>{
    await actor('1');const id=requestId();invite=await rpc('bil_circle_invite_send_v1',[id,privateCircle.circle_slug,code('2')]);
    assert.equal(invite.invite.status,'pending');assert.equal(invite.invite.invitee_id,identities['2']);assert.equal(invite.invite.circle_name,'Private recovery circle');assert.equal(invite.invite.recipient_code,null);
    assert.equal((await rpc('bil_circle_invite_send_v1',[id,privateCircle.circle_slug,code('2')])).invite_id,invite.invite_id);
    assert.equal((await rpc('bil_circle_invite_send_v1',[requestId(),privateCircle.circle_slug,code('2')])).invite_id,invite.invite_id);
    const r=await admin('select count(*)::int as n from public.bil_circle_invites_v1 where id=$1',[invite.invite_id]);assert.equal(r.rows[0].n,1);
  });
  await test('Unauthorized member/third party cannot send, cancel or accept another invite',async()=>{
    await actor('2');await denied('recipient cannot manage',()=>rpc('bil_circle_invite_send_v1',[requestId(),privateCircle.circle_slug,code('3')]),'42501');
    await denied('recipient cannot cancel manager action',()=>rpc('bil_circle_invite_action_v1',[requestId(),invite.invite_id,'cancel']),'42501');
    await actor('3');assert.equal((await rpc('bil_circle_invite_v1',[invite.invite_id])).invite,null);
    assert.equal((await rpc('bil_circle_invites_v1',[privateCircle.circle_slug])).invites.length,0);
    await denied('third party accept',()=>rpc('bil_circle_invite_action_v1',[requestId(),invite.invite_id,'accept']),'42501');
    await denied('third party cancel',()=>rpc('bil_circle_invite_action_v1',[requestId(),invite.invite_id,'cancel']),'42501');
  });
  await test('Invite reads grant metadata preview only and never accept/subscribe/follow',async()=>{
    await actor('2');for(let i=0;i<3;i++){
      const list=await rpc('bil_circle_invites_v1');assert.equal(list.invites[0].status,'pending');assert.equal(list.invites[0].can_accept,true);
      assert.equal((await rpc('bil_circle_invite_v1',[invite.invite_id])).invite.status,'pending');
    }
    const read=await rpc('bil_circle_read_v1',[privateCircle.circle_slug]);assert.equal(read.circle.display_name,'Private recovery circle');assert.equal(read.circle.membership_status,null);
    assert.equal((await rpc('bil_circle_search_v1',['Private recovery'])).circles.length,1);
    const m=await rpc('bil_circle_membership_v1',[privateCircle.circle_slug]);assert.equal(m.is_member,false);assert.equal(m.can_read_posts,false);assert.equal(m.can_post,false);
    await denied('invited preview is not private-post read permission',()=>rpc('bil_community_circle_post_refs_v1',[privateCircle.circle_slug]),'42501');
    const r=await admin('select count(*)::int as n from public.bil_community_circle_memberships where owner_id=$1',[identities['2']]);assert.equal(r.rows[0].n,0);
    assert.equal((await admin('select count(*)::int as n from public.bil_friendships')).rows[0].n,0);
  });
  await test('Accept activates exactly one real membership and supplies authoritative terminal status',async()=>{
    await actor('2');const id=requestId();const accepted=await rpc('bil_circle_invite_action_v1',[id,invite.invite_id,'accept']);
    assert.equal(accepted.invite.status,'accepted');assert.equal(accepted.circle.membership_status,'active');assert.equal(accepted.circle.membership_role,'member');assert.equal(accepted.circle.member_count,2);
    assert.equal((await rpc('bil_circle_invite_action_v1',[id,invite.invite_id,'accept'])).invite.status,'accepted');
    recipientMembership=await rpc('bil_circle_membership_v1',[privateCircle.circle_slug]);assert.equal(recipientMembership.is_member,true);assert.equal(recipientMembership.can_read_posts,true);assert.equal(recipientMembership.can_manage,false);
  });
  await test('Unchanged BASE leave works and an old accepted invitation cannot rejoin',async()=>{
    await actor('2');assert.equal(await rpc('bil_leave_community_circle_v1',[privateCircle.circle_slug]),true);
    const repeated=await rpc('bil_circle_invite_action_v1',[requestId(),invite.invite_id,'accept']);assert.equal(repeated.invite.status,'accepted');assert.equal(repeated.circle,null);
    assert.equal((await rpc('bil_circle_membership_v1',[privateCircle.circle_slug])).is_member,false);
    await actor('1');await denied('manager still cannot leave with BASE guard',()=>rpc('bil_leave_community_circle_v1',[privateCircle.circle_slug]),'42501');
  });
  await test('Decline/cancel are role-scoped terminal transitions; stale opposing action fails',async()=>{
    await actor('1');const decline=await rpc('bil_circle_invite_send_v1',[requestId(),privateCircle.circle_slug,code('2')]);
    await actor('2');const id=requestId();assert.equal((await rpc('bil_circle_invite_action_v1',[id,decline.invite_id,'decline'])).invite.status,'declined');
    assert.equal((await rpc('bil_circle_invite_action_v1',[id,decline.invite_id,'decline'])).invite.status,'declined');
    await denied('accept declined',()=>rpc('bil_circle_invite_action_v1',[requestId(),decline.invite_id,'accept']),'55000');
    await actor('1');const cancel=await rpc('bil_circle_invite_send_v1',[requestId(),privateCircle.circle_slug,code('2')]);
    assert.equal((await rpc('bil_circle_invite_action_v1',[requestId(),cancel.invite_id,'cancel'])).invite.status,'cancelled');
    await actor('2');await denied('accept canceled',()=>rpc('bil_circle_invite_action_v1',[requestId(),cancel.invite_id,'accept']),'55000');
  });
  await test('Invites page only authorized rows by unique ascending id',async()=>{
    await actor('1');await rpc('bil_circle_invite_send_v1',[requestId(),privateCircle.circle_slug,code('4')]);
    await actor('2');const all=[];let after=null;let pages=0;do{
      const r=await rpc('bil_circle_invites_v1',[null,after,1]);assert.equal(r.owner_id,identities['2']);assert(r.invites.every(x=>x.invitee_id===identities['2']));all.push(...r.invites.map(x=>x.id));after=r.next_after_id;assert(++pages<20);
    }while(after);assert(all.length>=3);assert.equal(new Set(all).size,all.length);assert.deepEqual(all,[...all].sort());
    await denied('null invite page bound',()=>rpc('bil_circle_invites_v1',[null,null,null]),'22023');
  });
  await test('Expired invite is read-only expired; accept fails without membership',async()=>{
    await actor('1');const exp=await rpc('bil_circle_invite_send_v1',[requestId(),privateCircle.circle_slug,code('2')]);
    await admin("update public.bil_circle_invites_v1 set created_at=clock_timestamp()-interval '2 days',expires_at=clock_timestamp()-interval '1 day' where id=$1",[exp.invite_id]);
    await actor('2');assert.equal((await rpc('bil_circle_invite_v1',[exp.invite_id])).invite.status,'expired');
    await denied('expired accept',()=>rpc('bil_circle_invite_action_v1',[requestId(),exp.invite_id,'accept']),'55000');
    assert.equal((await admin('select status from public.bil_circle_invites_v1 where id=$1',[exp.invite_id])).rows[0].status,'pending');
  });
  await test('Blocked, private, rotated-code and self recipients are indistinguishably unavailable',async()=>{
    await actor('1');await denied('self invite',()=>rpc('bil_circle_invite_send_v1',[requestId(),privateCircle.circle_slug,code('1')]),'42501');
    await denied('unknown code',()=>rpc('bil_circle_invite_send_v1',[requestId(),privateCircle.circle_slug,'f'.repeat(32)]),'42501');
    await admin('insert into public.bil_blocks(blocker_id,blocked_id) values($1,$2)',[identities['3'],identities['1']]);
    await denied('reverse block',()=>rpc('bil_circle_invite_send_v1',[requestId(),privateCircle.circle_slug,code('3')]),'42501');
    await admin('delete from public.bil_blocks where blocker_id=$1',[identities['3']]);
    await admin("update public.bil_public_profiles set profile_visibility='private' where user_id=$1",[identities['3']]);
    await denied('private recipient',()=>rpc('bil_circle_invite_send_v1',[requestId(),privateCircle.circle_slug,code('3')]),'42501');
    await admin("update public.bil_public_profiles set profile_visibility='public' where user_id=$1",[identities['3']]);
    await admin('update public.bil_social_public_codes_v2 set code=$2 where user_id=$1',[identities['3'],'e'.repeat(32)]);
    await denied('rotated old code',()=>rpc('bil_circle_invite_send_v1',[requestId(),privateCircle.circle_slug,code('3')]),'42501');
    await admin('update public.bil_social_public_codes_v2 set code=$2 where user_id=$1',[identities['3'],code('3')]);
  });
  await test('Role revocation denies new invite/media actions and pending invitation acceptance',async()=>{
    await actor('1');const current=await rpc('bil_circle_invite_send_v1',[requestId(),privateCircle.circle_slug,code('2')]);
    await admin("update public.bil_community_circle_memberships set role='member' where owner_id=$1 and circle_id=(select id from public.bil_community_circles where slug=$2)",[identities['1'],privateCircle.circle_slug]);
    assert.equal((await rpc('bil_circle_capabilities_v1',[privateCircle.circle_slug])).can_invite,false);
    await denied('revoked manager send',()=>rpc('bil_circle_invite_send_v1',[requestId(),privateCircle.circle_slug,code('3')]),'42501');
    await denied('revoked manager media prepare',()=>rpc('bil_circle_media_prepare_v1',[requestId(),privateCircle.circle_slug,'avatar','image/png',100,10,10]),'42501');
    await actor('2');assert.equal((await rpc('bil_circle_invite_v1',[current.invite_id])).invite.can_accept,false);assert.equal((await rpc('bil_circle_read_v1',[privateCircle.circle_slug])).circle,null);
    await denied('issuer revoked accept',()=>rpc('bil_circle_invite_action_v1',[requestId(),current.invite_id,'accept']),'42501');
    await actor('1');await admin("update public.bil_community_circle_memberships set role='moderator' where owner_id=$1 and circle_id=(select id from public.bil_community_circles where slug=$2)",[identities['1'],privateCircle.circle_slug]);
  });
  await test('Banned membership cannot be revived through invitation acceptance',async()=>{
    await actor('1');const pending=await rpc('bil_circle_invite_send_v1',[requestId(),privateCircle.circle_slug,code('2')]);
    await admin("insert into public.bil_community_circle_memberships(circle_id,owner_id,status) select id,$1,'banned' from public.bil_community_circles where slug=$2",[identities['2'],privateCircle.circle_slug]);
    await actor('2');await denied('banned accept',()=>rpc('bil_circle_invite_action_v1',[requestId(),pending.invite_id,'accept']),'42501');assert.equal(await rpc('bil_leave_community_circle_v1',[privateCircle.circle_slug]),false);
    await admin('delete from public.bil_community_circle_memberships where owner_id=$1',[identities['2']]);
    await rpc('bil_circle_invite_action_v1',[requestId(),pending.invite_id,'accept']);
  });
  const prepare=(slot='avatar')=>rpc('bil_circle_media_prepare_v1',[requestId(),privateCircle.circle_slug,slot,'image/png',100,10,10]);
  const upload=(media,overrides={})=>sql("insert into storage.objects(bucket_id,name,owner_id,metadata) values('community-circle-media',$1,$2,$3)",[overrides.name??media.object_path,overrides.owner??media.owner_id,{size:overrides.size??media.bytes,mimetype:overrides.mime??media.mime_type}]);
  await test('Media byte, dimension and pixel bounds match client contract',async()=>{
    await actor('1');
    await denied('width above8192',()=>rpc('bil_circle_media_prepare_v1',[requestId(),privateCircle.circle_slug,'avatar','image/png',100,8193,1]),'22023');
    await denied('pixel product above40M',()=>rpc('bil_circle_media_prepare_v1',[requestId(),privateCircle.circle_slug,'avatar','image/png',100,8192,8192]),'22023');
    await denied('above5MiB',()=>rpc('bil_circle_media_prepare_v1',[requestId(),privateCircle.circle_slug,'avatar','image/png',5242881,10,10]),'22023');
  });
  await test('Media prepare reserves exact owner/circle/slot/id path with no success before upload',async()=>{
    await actor('1');const prepared=await prepare();avatar=prepared.media;assert.equal(avatar.status,'reserved');assert.equal(avatar.owner_id,identities['1']);
    assert.equal(avatar.object_path,identities['1']+'/'+privateCircle.circle_slug+'/avatar/'+avatar.id+'.png');assert.equal(prepared.circle.avatar,null);
    const finishId=requestId();await denied('missing bytes',()=>rpc('bil_circle_media_finish_v1',[finishId,avatar.id]),'55000');assert.equal(await rpc('bil_circle_operation_v1',[finishId]),null);
    assert.equal((await rpc('bil_circle_read_v1',[privateCircle.circle_slug])).circle.avatar,null);
  });
  await test('Storage RLS blocks other actors, anon, wrong paths, wrong owner, size and MIME',async()=>{
    await actor('3');await denied('third-party upload',()=>upload(avatar),'42501');await actor('2');await denied('ordinary member upload',()=>upload(avatar),'42501');
    await actor('', 'anon');await denied('anon upload',()=>upload(avatar),'42501');
    await actor('1');await denied('cross-circle path',()=>upload(avatar,{name:avatar.object_path.replace(privateCircle.circle_slug,publicCircle.circle_slug)}),'42501');
    await denied('wrong slot',()=>upload(avatar,{name:avatar.object_path.replace('/avatar/','/cover/')}),'42501');
    await denied('wrong owner id',()=>upload(avatar,{owner:identities['2']}),'42501');
    await denied('wrong bytes',()=>upload(avatar,{size:99}),'42501');await denied('wrong MIME',()=>upload(avatar,{mime:'image/jpeg'}),'42501');
  });
  await test('Reserved upload is visible only to uploader; finish binds actual Storage metadata',async()=>{
    await actor('1');await upload(avatar);
    assert.equal(await scalar("select count(*)::int as value from storage.objects where bucket_id='community-circle-media'"),1);
    await actor('2');assert.equal(await scalar("select count(*)::int as value from storage.objects where bucket_id='community-circle-media'"),0);
    await actor('1');const published=await rpc('bil_circle_media_finish_v1',[requestId(),avatar.id]);assert.equal(published.media.status,'published');assert.equal(published.circle.avatar.object_path,avatar.object_path);assert.equal(published.circle.avatar.dimensions_verified,false);
    const repeat=await rpc('bil_circle_media_finish_v1',[requestId(),avatar.id]);assert.equal(repeat.circle.avatar.id,avatar.id);
  });
  await test('Private published media is visible to members but not third parties or anon',async()=>{
    await actor('2');assert.equal(await scalar("select count(*)::int as value from storage.objects where name=$1",[avatar.object_path]),1);
    await actor('3');assert.equal(await scalar("select count(*)::int as value from storage.objects where name=$1",[avatar.object_path]),0);
    await actor('', 'anon');assert.equal(await scalar("select count(*)::int as value from storage.objects where name=$1",[avatar.object_path]),0);
    await actor('1');assert.equal((await admin("select public from storage.buckets where id='community-circle-media'")).rows[0].public,false);
  });
  await test('Published object cannot be updated, overwritten or deleted before detach',async()=>{
    await actor('1');const updated=await sql("update storage.objects set metadata=$2 where name=$1",[avatar.object_path,{size:1,mimetype:'image/png'}]);assert.equal(updated.rowCount,0);
    await denied('overwrite insert',()=>upload(avatar),'42501');
    await sql("select set_config('storage.allow_delete_query','true',false)");const deleted=await sql('delete from storage.objects where name=$1',[avatar.object_path]);assert.equal(deleted.rowCount,0);
    assert.equal((await rpc('bil_circle_read_v1',[privateCircle.circle_slug])).circle.avatar.id,avatar.id);
  });
  await test('Cancel retires reservation; late upload/finish fail and no false image is shown',async()=>{
    await actor('1');cover=(await prepare('cover')).media;const canceled=await rpc('bil_circle_media_cancel_v1',[requestId(),cover.id]);assert.equal(canceled.media.status,'cancelled');assert.equal(canceled.circle.cover,null);
    await denied('late upload after cancel',()=>upload(cover),'42501');await denied('late finish after cancel',()=>rpc('bil_circle_media_finish_v1',[requestId(),cover.id]),'55000');
  });
  await test('Revoked manager cannot upload/finish; own unfinished upload remains cancellable',async()=>{
    await actor('1');const media=(await prepare('cover')).media;await upload(media);
    await admin("update public.bil_community_circle_memberships set role='member' where owner_id=$1 and circle_id=(select id from public.bil_community_circles where slug=$2)",[identities['1'],privateCircle.circle_slug]);
    await denied('revoked finish',()=>rpc('bil_circle_media_finish_v1',[requestId(),media.id]),'42501');
    assert.equal((await rpc('bil_circle_media_cancel_v1',[requestId(),media.id])).media.status,'cancelled');
    assert.equal((await sql('delete from storage.objects where name=$1',[media.object_path])).rowCount,1);
    await admin("update public.bil_community_circle_memberships set role='moderator' where owner_id=$1 and circle_id=(select id from public.bil_community_circles where slug=$2)",[identities['1'],privateCircle.circle_slug]);
  });
  await test('Replacing media keeps one authoritative slot and retires old immutable object',async()=>{
    await actor('1');const next=(await prepare()).media;await upload(next);const replaced=await rpc('bil_circle_media_finish_v1',[requestId(),next.id]);assert.equal(replaced.circle.avatar.id,next.id);
    assert.equal((await admin('select status from public.bil_circle_media_v1 where id=$1',[avatar.id])).rows[0].status,'superseded');
    assert.equal((await sql('delete from storage.objects where name=$1',[avatar.object_path])).rowCount,1);avatar=next;
    const detached=await rpc('bil_circle_media_cancel_v1',[requestId(),avatar.id]);assert.equal(detached.circle.avatar,null);assert.equal(detached.media.status,'cancelled');assert.equal((await sql('delete from storage.objects where name=$1',[avatar.object_path])).rowCount,1);
  });
  await test('Authoritative media projection hides missing object instead of inventing an image',async()=>{
    await actor('1');const media=(await prepare()).media;await upload(media);await rpc('bil_circle_media_finish_v1',[requestId(),media.id]);
    await admin('delete from storage.objects where name=$1',[media.object_path]);assert.equal((await rpc('bil_circle_read_v1',[privateCircle.circle_slug])).circle.avatar,null);
  });
  await test('BASE join/request/cancel remains functional and no social side effects appear',async()=>{
    await actor('3');assert.equal(await rpc('bil_join_community_circle_v1',['alpha-circle']),'active');assert.equal(await rpc('bil_leave_community_circle_v1',['alpha-circle']),true);
    assert.equal(await rpc('bil_join_community_circle_v1',['beta-circle']),'pending');assert.equal(await rpc('bil_leave_community_circle_v1',['beta-circle']),true);
    assert.equal((await admin('select count(*)::int as n from public.bil_friendships')).rows[0].n,0);
  });
  await test('Membership permission read distinguishes active membership from missing publish policy',async()=>{
    await actor('2');await admin('delete from public.bil_content_policy_acceptances where user_id=$1',[identities['2']]);
    const m=await rpc('bil_circle_membership_v1',[privateCircle.circle_slug]);assert.equal(m.is_member,true);assert.equal(m.can_post,false);assert.equal(m.can_read_posts,true);
    await admin("insert into public.bil_content_policy_acceptances(user_id,policy_version) values($1,'bil06-local-v1')",[identities['2']]);
  });
  await test('Membership cap disables create while existing manager invite/media permission remains',async()=>{
    await actor('1');const before=(await admin('select count(*)::int as n from public.bil_community_circle_memberships where owner_id=$1',[identities['1']])).rows[0].n;
    await admin("insert into public.bil_community_circles(slug,title_copy_key,description_copy_key,rules_copy_key) select 'cap-fixture-'||lpad(i::text,3,'0'),'community_circle_cap','community_circle_cap_body','community_circle_standard_rules' from generate_series(1,$1::int) i",[100-before]);
    await admin("insert into public.bil_community_circle_memberships(circle_id,owner_id) select id,$1 from public.bil_community_circles where slug like 'cap-fixture-%'",[identities['1']]);
    const cap=await rpc('bil_circle_capabilities_v1',[privateCircle.circle_slug]);assert.equal(cap.can_create,false);assert.equal(cap.can_invite,true);assert.equal(cap.can_manage_media,true);
    await denied('membership cap create',()=>create(requestId()),'22023');
  });
  await test('Committed operation keeps immutable invite/media identity after current row deletion',async()=>{
    await actor('1');
    const inviteRequest=requestId();
    const sent=await rpc('bil_circle_invite_send_v1',[inviteRequest,privateCircle.circle_slug,code('4')]);
    await admin('delete from public.bil_circle_invites_v1 where id=$1',[sent.invite_id]);
    const inviteHistory=await rpc('bil_circle_operation_v1',[inviteRequest]);
    assert.equal(inviteHistory.invite_id,sent.invite_id);assert.equal(inviteHistory.invite,null);
    const mediaRequest=requestId();
    const prepared=await rpc('bil_circle_media_prepare_v1',[mediaRequest,privateCircle.circle_slug,'cover','image/png',100,10,10]);
    await admin('delete from public.bil_circle_media_v1 where id=$1',[prepared.media_id]);
    const mediaHistory=await rpc('bil_circle_operation_v1',[mediaRequest]);
    assert.equal(mediaHistory.media_id,prepared.media_id);assert.equal(mediaHistory.media,null);
  });
  await test('Asset deletion clears metadata pointer without deleting circle identity',async()=>{
    await actor('1');const media=(await prepare('cover')).media;await upload(media);await rpc('bil_circle_media_finish_v1',[requestId(),media.id]);
    await admin('delete from public.bil_circle_media_v1 where id=$1',[media.id]);
    const c=(await rpc('bil_circle_read_v1',[privateCircle.circle_slug])).circle;assert.equal(c.slug,privateCircle.circle_slug);assert.equal(c.cover,null);
    await admin('delete from storage.objects where name=$1',[media.object_path]);
  });
}
