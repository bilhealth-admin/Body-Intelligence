
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {handleOps} from './ops_server.mjs';

const uid='cabcec51-9f56-4bd8-af59-ec0cc5c09e72';
const origin='https://guilty-crazy-operation--bilhealthapp.replit.app';
const now=1800000000;
function token(aal='aal2',amr=[{method:'totp',timestamp:now-30}],sub=uid){
  const payload={sub,role:'authenticated',exp:now+1200,aal,amr};
  return ['eyJhbGciOiJub25lIn0',Buffer.from(JSON.stringify(payload)).toString('base64url'),'sig'].join('.');
}
function request(body={},options={}){
  return new Request('https://supabase.invalid/functions/v1/bil-admin-web-ops-v1',{
    method:options.method??'POST',
    headers:{Origin:options.origin??origin,Authorization:'Bearer '+(options.jwt??token()),
      'content-type':'application/json'},
    ...(options.method==='OPTIONS'?{}:{body:JSON.stringify(body)})
  });
}
function dependencies({allow=true,write=false,serviceSpy=[],userSpy=[],override={}}={}){
  return {
    now:()=>now*1000,
    env:key=>({
      BIL_ADMIN_WEB_ALLOWED_ORIGINS:origin,
      BIL_ADMIN_WEB_FINANCE_OWNER_IDS:uid,
      BIL_ADMIN_OPS_ENABLED:'true',
      BIL_ADMIN_OPS_WRITE_ENABLED:String(write),
      ...override
    })[key],
    makeUserClient:()=>({
      auth:{getUser:async()=>({data:{user:{id:uid}}})},
      rpc:async(name,args)=>{userSpy.push({name,args});return {data:name==='bil_can_manage_ai_coach'?allow:name==='bil_consume_rate_limit'?null:[{id:uid}],error:null}}
    }),
    makeServiceClient:()=>({
      rpc:async(name,args)=>{serviceSpy.push({name,args});return {data:[{id:uid}],error:null}}
    })
  };
}
const read=async x=>[x.status,await x.json()];
test('unlisted origin fails without reflective CORS',async()=>{
  const r=await handleOps(request({operation:'status'},{origin:'https://attacker.example'}),dependencies());
  assert.equal(r.status,403);assert.equal(r.headers.get('access-control-allow-origin'),null);
});
test('approved origin preflight is 204 and no JWT needed',async()=>{
  const r=await handleOps(request({}, {method:'OPTIONS'}),dependencies());
  assert.equal(r.status,204);assert.equal(r.headers.get('access-control-allow-origin'),origin);
});
test('missing JWT rejected',async()=>{
  const req=request({operation:'status'});req.headers.delete('authorization');
  const [status,value]=await read(await handleOps(req,dependencies()));
  assert.equal(status,401);assert.equal(value.error,'authentication_required');
});
test('AAL1 is insufficient',async()=>{
  const [status,v]=await read(await handleOps(request({operation:'status'},{jwt:token('aal1')}),dependencies()));
  assert.equal(status,403);assert.equal(v.error,'mfa_required');
});
test('SQL admin role required beyond allowlist',async()=>{
  const [status,v]=await read(await handleOps(request({operation:'status'}),dependencies({allow:false})));
  assert.equal(status,404);assert.equal(v.error,'not_found');
});
test('owner status confirms read-only staging',async()=>{
  const [status,v]=await read(await handleOps(request({operation:'status'}),dependencies()));
  assert.equal(status,200);assert.equal(v.read_enabled,true);assert.equal(v.writes_enabled,false);
});
test('moderator list only uses service RPC with verified actor',async()=>{
  const calls=[], [status,v]=await read(await handleOps(request({operation:'moderators.list'}),dependencies({serviceSpy:calls})));
  assert.equal(status,200);assert.equal(v.operation,'moderators.list');
  assert.equal(calls[0].name,'bil_list_community_moderators_for_admin');
  assert.equal(calls[0].args.p_actor_id,uid);
});
test('safety review listing uses user-scoped RPC',async()=>{
  const calls=[], [status,v]=await read(await handleOps(request({operation:'moderation.safety.open'}),dependencies({userSpy:calls})));
  assert.equal(status,200);assert.equal(v.operation,'moderation.safety.open');
  assert.ok(calls.some(x=>x.name==='bil_list_ai_coach_safety_reports_v1'));
});
test('financial-like writes hard locked by default',async()=>{
  const reqBody={operation:'moderators.add',email:'test@example.com',confirm_email:'test@example.com',idempotency_key:'test-key-12345678'};
  const [status,v]=await read(await handleOps(request(reqBody),dependencies()));
  assert.equal(status,423);assert.equal(v.error,'admin_ops_writes_locked');
});
test('fresh TOTP required when writes enabled',async()=>{
  const reqBody={operation:'moderators.add',email:'test@example.com',confirm_email:'test@example.com',idempotency_key:'test-key-12345678'};
  const [status,v]=await read(await handleOps(request(reqBody,{jwt:token('aal2',[{method:'totp',timestamp:now-400}])}),dependencies({write:true})));
  assert.equal(status,403);assert.equal(v.error,'fresh_mfa_required');
});
test('confirmed add moderator uses service RPC not browser RPC',async()=>{
  const calls=[],reqBody={operation:'moderators.add',email:'test@example.com',confirm_email:'test@example.com',idempotency_key:'test-key-12345678'};
  const [status,v]=await read(await handleOps(request(reqBody),dependencies({write:true,serviceSpy:calls})));
  assert.equal(status,200);assert.equal(v.state,'executed');
  assert.equal(calls[0].name,'bil_add_community_moderator_by_email');
  assert.equal(calls[0].args.p_email,'test@example.com');
});
test('global reset requires explicit phrase',async()=>{
  const body={operation:'coach.reset.all',message:'required',confirm_phrase:'yes',idempotency_key:'test-key-12345678'};
  const [status,v]=await read(await handleOps(request(body),dependencies({write:true})));
  assert.equal(status,400);assert.equal(v.error,'explicit_confirmation_required');
});
test('notification compensation requires acknowledging token effect',async()=>{
  const body={operation:'notifications.send',kind:'gift',audience:'all',confirm_target:'SEND TO ALL',
    message:'Test',idempotency_key:'test-key-12345678'};
  const [status,v]=await read(await handleOps(request(body),dependencies({write:true})));
  assert.equal(status,400);assert.equal(v.error,'token_grant_acknowledgment_required');
});
test('post reward approval idempotency uses user identity and exact revision',async()=>{
  const body={operation:'moderation.posts.review',post_id:uid,expected_revision:'a'.repeat(64),
    decision:'approved',reward_mode:'eligible',reason:'',operation_id:uid,
    idempotency_key:'test-key-12345678'};
  const calls=[],[status,v]=await read(await handleOps(request(body),dependencies({write:true,userSpy:calls})));
  assert.equal(status,200);
  assert.ok(calls.some(x=>x.name==='bil_moderate_community_post_v2'));
});
test('origin is exact, not wildcard or HTTP',async()=>{
  const deps=dependencies({override:{BIL_ADMIN_WEB_ALLOWED_ORIGINS:'*'}});
  const [status]=await read(await handleOps(request({operation:'status'}),deps));
  assert.equal(status,403);
});

test('pending moderation uses pending posts and never substitutes reward requests',async()=>{
 const calls=[], [status,v]=await read(await handleOps(
   request({operation:'moderation.posts.pending',limit:20}),dependencies({userSpy:calls})));
 assert.equal(status,200);
 assert.equal(v.operation,'moderation.posts.pending');
 assert.ok(calls.some(x=>x.name==='bil_list_pending_community_posts'&&x.args.p_limit===20));
 assert.ok(!calls.some(x=>x.name==='bil_community_reward_review_queue_v2'));
});
