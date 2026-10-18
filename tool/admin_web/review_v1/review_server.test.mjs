import {test} from 'node:test';
import assert from 'node:assert/strict';
import {assertRpcArguments} from '../rpc_contracts/assert_arguments.mjs';
import {handleReview} from './review_server.mjs';

const actor='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const author='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const postId='cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const requestId='dddddddd-dddd-4ddd-8ddd-dddddddddddd';
const reportId='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
const revision='f'.repeat(64),now=1800000000;
const origin='https://bilhealth-secure-admin.bilhealth-app.workers.dev';
const authorEmail='synthetic.user@example.invalid';
const fakePost={id:postId,author_id:author,title:'All details matter',body:'Complete post content',
  created_at:'2026-10-18T03:30:00Z',visibility:'community',
  moderation_status:'pending',deleted_at:null,media_object_path:null};

function jwt({id=actor,aal='aal2',timestamp=now-20,role='authenticated',exp=now+1000}={}){
  return ['eyJhbGciOiJub25lIn0', Buffer.from(JSON.stringify({sub:id,role,aal,amr:[{method:'totp',timestamp}],exp})).toString('base64url'),'signature'].join('.');
}
function request(body,opts={}){
  return new Request('https://supabase.invalid/functions/v1/bil-admin-web-review-v1',{
    method:opts.method??'POST',
    headers:{Origin:opts.origin??origin,Authorization:opts.noAuth?'':`Bearer ${opts.token??jwt()}`,
      'content-type':'application/json'},
    ...(opts.method==='OPTIONS'?{}:{body:JSON.stringify(body)})
  });
}
function fake(options={}){
  let calls=[],signs=[];
  const user={
    auth:{getUser:async()=>({data:{user:{id:options.verifiedUser||actor}},error:options.authFailure?{message:'invalid'}:null})},
    rpc:async(name,args)=>{
      assertRpcArguments(name,args);
      calls.push({kind:'user',name,args});
      if(name==='bil_can_manage_ai_coach')return {data:options.ownerAuthorized===false?false:true};
      if(name==='bil_consume_rate_limit'){
        const accepted=args.p_window_seconds===3600 &&
          ((args.p_action==='admin_subscription_list'&&args.p_limit===120)||
           (args.p_action==='admin_subscription_grant'&&args.p_limit===60));
        return accepted?{data:null}:{data:null,error:{code:'22023',message:'invalid_rate_limit_contract'}};
      }
      if(name==='bil_list_pending_community_posts')return {data:options.emptyQueue?[]:[{
        id:postId,author_id:author,author_name:'Alice Synthetic',body:fakePost.body,created_at:fakePost.created_at
      }]};
      if(name==='bil_community_review_snapshots_v2')return {data:options.staleSnapshot?[{post:{...fakePost},revision:'a'.repeat(64)}]:[{post:{...fakePost},revision}]};
      if(name==='bil_community_reward_review_queue_v2')return {data:[{
        post:{...fakePost,moderation_status:'approved',reviewed_at:fakePost.created_at},
        revision,request_id:options.rewardUnrequested?null:requestId,
        status:options.rewardUnrequested?'not_requested':'requested',can_grant:true
      }]};
      if(name==='bil_moderate_community_post_v2')return {data:{post_id:postId,decision:args.p_decision,
        duplicate:false,tokens_granted:options.dailyCap?0:5,
        reward_reason:options.dailyCap?'daily_cap_reached':'granted',receipt_state:'executed'}};
      if(name==='bil_decide_community_post_reward_v2')return {data:{request_id:requestId,
        status:args.p_approve?'executed':'rejected',tokens_granted:args.p_approve?5:0,reward_reason:'granted'}};
      if(name==='bil_request_community_post_reward_v2')return {data:{request_id:requestId,
        status:'requested',tokens_granted:0}};
      if(name==='bil_community_report_content_v1')return {data:{revision,body:'Synthetic reported content'}};
      if(name==='bil_decide_community_report_v1')return {data:{status:'closed',content_removed:args.p_remove}};
      if(name==='bil_list_ai_coach_safety_reports_v1')return {data:[{report_id:reportId,status:'open'}]};
      if(name==='bil_review_ai_coach_safety_report_v1')return {data:{status:'reviewed',decision:args.p_decision}};
      return {data:null,error:{message:'unknown rpc '+name}};
    }
  };
  // The service role intentionally has no direct table SELECT privileges.
  // Any service.from(...) call is a production security regression.
  const fromTable=table=>{throw new Error('FORBIDDEN_DIRECT_TABLE_READ:'+table)};
  const service={
    from:fromTable,
    storage:{from:()=>({createSignedUrl:async(path,ttl)=>{
      signs.push({path,ttl});
      if(options.mediaFailure)return {error:{message:'permission denied'}};
      return {data:{signedUrl:`https://test-bil.supabase.co/storage/v1/object/sign/community-post-images/${path}?token=synthetic`}};
    }})},
    auth:{admin:{getUserById:async()=>({data:{user:{id:author,email:authorEmail}}})}},
    rpc:async(name,args)=>{
      assertRpcArguments(name,args);
      calls.push({kind:'service',name,args});
      if(name==='bil_admin_web_reporter_contacts_v1')return {data:[{
        record_id:postId,reporter_user_id:author,reporter_email:authorEmail
      }]};
      if(name==='bil_admin_web_review_context_v1'){
        if(options.contextPermissionFailure)return {data:null,error:{message:'permission denied for table bil_community_post_media_v1'}};
        return {data:{post_id:postId,author_id:author,author_name:'Alice Synthetic',title:fakePost.title,
          location:'Amman',hashtags:['nutrition'],topics:['fitness'],circles:['strength'],
          poll:{question:'What is right?',allow_multiple:false,closes_at:null,options:['A','B']},
          media_count:2,media:[
            {post_id:postId,position:0,object_path:'bbbb/post1/first.jpg',mime_type:'image/jpeg',bytes:1200,width:640,height:800},
            {post_id:postId,position:1,object_path:'bbbb/post1/second.jpg',mime_type:'image/jpeg',bytes:1200,width:640,height:800}
          ]}};
      }
      if(name==='bil_admin_web_review_reward_policy_v1'){
        if(options.policyPermissionFailure)return {data:null,error:{message:'permission denied for table bil_community_post_reward_policy'}};
        return {data:{tokens_per_approval:5,max_rewarded_posts_per_owner_per_utc_day:5,
          max_daily_tokens:25,updated_at:'2026-10-18T00:00:00Z'}};
      }
      return {data:null,error:{message:'unknown service rpc '+name}};
    }
  };
  return {calls,signs,deps:{
    now:()=>now*1000,
    env:name=>({BIL_ADMIN_WEB_ALLOWED_ORIGINS:origin,
      BIL_ADMIN_WEB_FINANCE_OWNER_IDS:actor,
      BIL_ADMIN_REVIEW_ENABLED:'true',
      BIL_ADMIN_REVIEW_WRITE_ENABLED:options.write?'true':'false',
      ...options.env})[name],
    makeUserClient:()=>user,makeServiceClient:()=>service
  }};
}
async function response(body,opts={}){const v=fake(opts);const res=await handleReview(request(body,opts),v.deps);return {status:res.status,headers:res.headers,data:res.status===204?null:await res.json(),...v}}

test('denies unknown origin before any data access',async()=>{
  const r=await response({operation:'status'},{origin:'https://attacker.example'});
  assert.equal(r.status,403);assert.equal(r.headers.get('access-control-allow-origin'),null);
  assert.equal(r.calls.length,0);
});
test('allows exact Cloudflare origin CORS preflight',async()=>{
  const r=await response({}, {method:'OPTIONS'});assert.equal(r.status,204);
  assert.equal(r.headers.get('access-control-allow-origin'),origin);
});
test('rejects unauthenticated, MFA AAL1, false owner and stale sessions',async()=>{
  assert.equal((await response({operation:'status'},{noAuth:true})).status,401);
  assert.equal((await response({operation:'status'},{token:jwt({aal:'aal1'})})).status,403);
  assert.equal((await response({operation:'status'},{ownerAuthorized:false})).status,403);
  assert.equal((await response({operation:'status'},{token:jwt({exp:now-20})})).status,401);
});
test('write operations locked by default; status says so precisely',async()=>{
  const r=await response({operation:'status'});assert.equal(r.data.moderation_writes_enabled,false);
  const body={operation:'posts.review',post_id:postId,confirm_post_id:postId,
    expected_revision:revision,acknowledge_full_content:true,reason:'',decision:'approved',operation_id:reportId};
  const denied=await response(body);assert.equal(denied.status,423);
  assert.equal(denied.calls.some(x=>x.name==='bil_moderate_community_post_v2'),false);
});
test('pending queue includes full title, body, author and both private images with short-lived URLs',async()=>{
  const r=await response({operation:'posts.queue',limit:10});assert.equal(r.status,200);
  assert.equal(r.data.receipt.rows.length,1);const row=r.data.receipt.rows[0];
  assert.equal(row.title,'All details matter');assert.equal(row.body,'Complete post content');
  assert.equal(row.author_email,authorEmail);assert.equal(row.images.length,2);
  assert.equal(row.images[0].url.startsWith('https://test-bil.supabase.co/storage/'),true);
  assert.equal(row.media_complete,true);
  assert.equal(r.signs.length,2);assert.deepEqual(r.signs.map(x=>x.ttl),[180,180]);
  assert.equal(row.poll.options.length,2);assert.deepEqual(row.hashtags,['nutrition']);
});
test('media signing failure blocks decisions and omits broken image urls',async()=>{
  const r=await response({operation:'posts.queue',limit:5},{mediaFailure:true});
  assert.equal(r.status,200);const row=r.data.receipt.rows[0];
  assert.equal(row.media_complete,false);assert.equal(row.can_decide,false);
  assert.equal(row.images,undefined);
});
test('direct post detail must belong to the current reviewer queue',async()=>{
  const r=await response({operation:'posts.detail',post_id:postId},{staleSnapshot:true});
  assert.equal(r.status,200);
  assert.equal(r.data.receipt.revision,'a'.repeat(64));
});
test('returns actual configured Earn reward and daily cap from PostgreSQL',async()=>{
  const r=await response({operation:'earn.policy'});assert.equal(r.status,200);
  assert.deepEqual({tokens:r.data.receipt.tokens_per_approval,cap:r.data.receipt.max_rewarded_posts_per_owner_per_utc_day,
    max:r.data.receipt.max_daily_tokens},{tokens:5,cap:5,max:25});
});
test('Earn request queue is distinct from pending new posts',async()=>{
  const r=await response({operation:'earn.queue'});assert.equal(r.status,200);
  assert.equal(r.data.receipt[0].status,'requested');
  assert.equal(r.data.receipt[0].author_email,authorEmail);
  assert.ok(r.calls.some(x=>x.name==='bil_community_reward_review_queue_v2'));
  assert.ok(!r.calls.some(x=>x.name==='bil_list_pending_community_posts'));
});
test('normal approval uses versioned RPC and 5 earned tokens, never arbitrary amount',async()=>{
  const r=await response({operation:'posts.review',post_id:postId,confirm_post_id:postId,
    decision:'approved',expected_revision:revision,acknowledge_full_content:true,
    operation_id:reportId,reason:''},{write:true});
  assert.equal(r.status,200);assert.equal(r.data.receipt.tokens_granted,5);
  const call=r.calls.find(x=>x.name==='bil_moderate_community_post_v2');
  assert.equal(call.args.p_reward_mode,'eligible');assert.equal('p_tokens' in call.args,false);
});
test('approved post can earn zero after reaching daily cap; receipt stays truthful',async()=>{
  const r=await response({operation:'posts.review',post_id:postId,confirm_post_id:postId,
    decision:'approved',expected_revision:revision,acknowledge_full_content:true,
    operation_id:reportId,reason:''},{write:true,dailyCap:true});
  assert.equal(r.status,200);assert.equal(r.data.receipt.tokens_granted,0);
  assert.equal(r.data.receipt.reward_reason,'daily_cap_reached');
});
test('rejection requires actual reason; no silent action without full content acknowledgement',async()=>{
  const body={operation:'posts.review',post_id:postId,confirm_post_id:postId,
    decision:'rejected',expected_revision:revision,acknowledge_full_content:true,
    operation_id:reportId,reason:''};
  assert.equal((await response(body,{write:true})).status,400);
  assert.equal((await response({...body,reason:'Advertising',acknowledge_full_content:false},{write:true})).status,400);
});
test('fresh TOTP required, old factor is rejected without writes',async()=>{
  const body={operation:'posts.review',post_id:postId,confirm_post_id:postId,
    decision:'approved',expected_revision:revision,acknowledge_full_content:true,
    operation_id:reportId,reason:''};
  const r=await response(body,{write:true,token:jwt({timestamp:now-120})});
  assert.equal(r.status,403);assert.equal(r.data.error,'fresh_mfa_required');
  assert.ok(!r.calls.some(x=>x.name==='bil_moderate_community_post_v2'));
});
test('revision changed after inspection causes safe 409 without write',async()=>{
  const body={operation:'posts.review',post_id:postId,confirm_post_id:postId,
    decision:'approved',expected_revision:revision,acknowledge_full_content:true,
    operation_id:reportId,reason:''};
  const r=await response(body,{write:true,staleSnapshot:true});assert.equal(r.status,409);
  assert.ok(!r.calls.some(x=>x.name==='bil_moderate_community_post_v2'));
});
test('Earn requests and decisions call existing actor-authorized SQL, no double token grants',async()=>{
  const newRequest=await response({operation:'earn.request',post_id:postId,confirm_post_id:postId,
    expected_revision:revision},{write:true,rewardUnrequested:true});
  assert.equal(newRequest.status,200);
  assert.ok(newRequest.calls.some(x=>x.name==='bil_request_community_post_reward_v2'));
  const decision=await response({operation:'earn.decide',request_id:requestId,confirm_request_id:requestId,
    approve:true,reason:''},{write:true});
  assert.equal(decision.status,200);assert.equal(decision.data.receipt.tokens_granted,5);
  assert.ok(decision.calls.some(x=>x.name==='bil_decide_community_post_reward_v2'));
});
test('safety decision requires report currently open',async()=>{
  const r=await response({operation:'safety.decide',report_id:reportId,confirm_report_id:reportId,
    decision:'no_violation',operation_id:postId},{write:true});
  assert.equal(r.status,200);assert.equal(r.data.receipt.status,'reviewed');
});
test('report decision checks current content revision in SQL before action',async()=>{
  const r=await response({operation:'reports.decide',report_id:reportId,confirm_report_id:reportId,
    source:'community',expected_revision:revision,remove:false,operation_id:postId},{write:true});
  assert.equal(r.status,200);assert.equal(r.data.receipt.status,'closed');
});
test('invalid operation never calls provider and never reflects user text',async()=>{
  const r=await response({operation:'secret.admin.dump'});
  assert.equal(r.status,400);assert.equal(r.calls.some(x=>x.kind==='service'),false);
  assert.ok(!JSON.stringify(r.data).includes('stack'));
});


test('new metadata context is scoped to owner via service RPC and no direct SQL table select',async()=>{
  const r=await response({operation:'posts.queue',limit:10});
  assert.equal(r.status,200);
  const context=r.calls.find(x=>x.name==='bil_admin_web_review_context_v1');
  assert.equal(context.kind,'service');
  assert.equal(context.args.p_actor_id,actor);
  assert.equal(context.args.p_post_id,postId);
  const policy=await response({operation:'earn.policy'});
  assert.equal(policy.status,200);
  const receipt=policy.calls.find(x=>x.name==='bil_admin_web_review_reward_policy_v1');
  assert.equal(receipt.args.p_actor_id,actor);
});
test('permission failure on read context cannot mislabel authenticated owner as unauthorized',async()=>{
  const r=await response({operation:'posts.queue'}, {contextPermissionFailure:true});
  assert.equal(r.status,200);
  assert.equal(r.data.receipt.rows[0].media_complete,false);
  assert.equal(r.data.receipt.rows[0].preview_error,'review_context_configuration_error');
  assert.equal(r.data.receipt.rows[0].body,fakePost.body);
  const p=await response({operation:'earn.policy'},{policyPermissionFailure:true});
  assert.equal(p.status,503);
  assert.equal(p.data.error,'review_context_configuration_error');
});
test('post context includes title, location, topics, circle and poll without leaking service role',async()=>{
  const r=await response({operation:'posts.detail',post_id:postId});
  assert.equal(r.status,200);
  assert.equal(r.data.receipt.author_name,'Alice Synthetic');
  assert.equal(r.data.receipt.location,'Amman');
  assert.deepEqual(r.data.receipt.topics,['fitness']);
  assert.deepEqual(r.data.receipt.circles,['strength']);
  assert.deepEqual(r.data.receipt.poll.options,['A','B']);
  assert.equal(JSON.stringify(r.data).includes('serviceRole'),false);
});
