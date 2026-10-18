import {
  WebAdminError, exactOrigins, ownersAllowlist, readBearer,
  verifiedClaims, requireAal2, requireRecentTotp, requireObject,
} from './policy.mjs';

const REPLY_HEADERS = Object.freeze({
  'content-type': 'application/json; charset=utf-8',
  'cache-control': 'no-store',
  'referrer-policy': 'no-referrer',
  'x-frame-options': 'DENY',
  'x-content-type-options': 'nosniff',
  'vary': 'Origin',
});
const CORS = 'authorization, apikey, content-type, x-client-info';
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const SHA = /^[0-9a-f]{64}$/;
const KEY = /^[A-Za-z0-9:_-]{16,128}$/;
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const CONTROL = /[\x00-\x1f\x7f]/;
const READ = new Set([
  'status','moderators.list','members.list',
  'moderation.posts.pending','moderation.posts.snapshots',
  'moderation.reports.open','moderation.reports.content','moderation.safety.open'
]);
const WRITE = new Set([
  'moderators.add','moderators.remove','members.suspend','members.reinstate',
  'coach.reset.all','coach.reset.user','notifications.send',
  'moderation.posts.review','moderation.reports.decide','moderation.safety.decide',
]);
const VERSION = '2026-10-18-web-ops-v5';

function json(obj, code=200, origin=null) {
  const headers = {...REPLY_HEADERS};
  if(origin) {
    headers['access-control-allow-origin']=origin;
    headers['access-control-allow-methods']='OPTIONS, POST';
    headers['access-control-allow-headers']=CORS;
    headers['access-control-max-age']='300';
  }
  return new Response(JSON.stringify(obj),{status:code,headers});
}
function fail(code,status=400) { throw new WebAdminError(code,status); }
function okUUID(x) { return typeof x==='string' && UUID.test(x); }
function uuid(x) { if(!okUUID(x)) fail('invalid_uuid'); return x; }
function idempotency(x) { if(typeof x!=='string'||!KEY.test(x)) fail('invalid_idempotency_key'); return x; }
function email(x) {
  if(typeof x!=='string'||!EMAIL.test(x.trim())||x.trim().length>254) fail('invalid_email');
  return x.trim().toLowerCase();
}
function limitedText(x,min=1,max=180) {
  if(typeof x!=='string'||x.trim().length<min||[...x.trim()].length>max||CONTROL.test(x)) fail('invalid_text');
  return x.trim();
}
function expect(x,y) { if(x!==y) fail('explicit_confirmation_required'); }
function revision(x){if(typeof x!=='string'||!SHA.test(x)) fail('invalid_revision');return x;}
function operationUUID(x){ return uuid(x); }
function checkedData(data){
  const str=JSON.stringify(data);
  if(str===undefined||str.length>131072) fail('response_too_large',503);
  return data;
}
function errorFromRpc(error) {
  if(!error) return;
  const message=String(error.message||'');
  if(/rate.limit.exceeded/i.test(message)) fail('rate_limited',429);
  if(/not.authorized|administrator_required|admin_required|moderator_required|permission.denied|42501/i.test(message))
    fail('not_found',404);
  if(/idempotency_conflict|request_mismatch/i.test(message)) fail('idempotency_conflict',409);
  if(/content_changed|already_reviewed/i.test(message)) fail('content_changed',409);
  fail('operation_unavailable',503);
}

function validate(op, body) {
  if(!READ.has(op) && !WRITE.has(op)) fail('unknown_operation');
  if(op==='status'||op==='moderators.list'||op==='members.list'||
     op==='moderation.reports.open'||op==='moderation.safety.open') return {};
  if(op==='moderation.posts.pending') {
    if(body.limit!==undefined && (!Number.isInteger(body.limit)||body.limit<1||body.limit>50)) fail('invalid_limit');
    return {limit:body.limit??30};
  }
  if(op==='moderation.posts.snapshots') {
    if(!Array.isArray(body.post_ids)||body.post_ids.length<1||body.post_ids.length>30||
       body.post_ids.some(x=>!okUUID(x))) fail('invalid_post_ids');
    return {post_ids:[...new Set(body.post_ids)]};
  }
  if(op==='moderation.reports.content'){
    if(!['community','comment'].includes(body.source)) fail('invalid_source');
    return {report_id:uuid(body.report_id),source:body.source};
  }
  const key=idempotency(body.idempotency_key);
  if(op==='moderators.add') {
    const target=email(body.email);expect(body.confirm_email,target);
    return {key,email:target};
  }
  if(op==='moderators.remove') {
    const user_id=uuid(body.user_id);expect(body.confirm_user_id,user_id);
    return {key,user_id};
  }
  if(op==='members.suspend') {
    const target=email(body.email);expect(body.confirm_email,target);
    return {key,email:target,reason:limitedText(body.reason,2,160)};
  }
  if(op==='members.reinstate') {
    const user_id=uuid(body.user_id);expect(body.confirm_user_id,user_id);
    return {key,user_id};
  }
  if(op==='coach.reset.all') {
    expect(body.confirm_phrase,'RESET ALL AI COACH ACCOUNTS');
    return {key,message:limitedText(body.message)};
  }
  if(op==='coach.reset.user') {
    const target=email(body.email);expect(body.confirm_email,target);
    return {key,email:target,reason:limitedText(body.reason,2,160),message:limitedText(body.message)};
  }
  if(op==='notifications.send') {
    if(!['compensation','gift','custom'].includes(body.kind)||
       !['all','email'].includes(body.audience)) fail('invalid_notification');
    const target=body.audience==='email'?email(body.email):null;
    expect(body.confirm_target, target??'SEND TO ALL');
    if(body.kind!=='custom' && body.acknowledge_token_grant!==true)
      fail('token_grant_acknowledgment_required');
    if(body.audience==='all' && body.kind!=='custom' &&
       body.confirm_mass_grant!=='GRANT 2500 AI TOKENS TO ALL USERS')
      fail('mass_grant_confirmation_required');
    return {key,kind:body.kind,audience:body.audience,email:target,message:limitedText(body.message)};
  }
  if(op==='moderation.posts.review'){
    if(!['approved','rejected'].includes(body.decision)||
       !['eligible','deferred'].includes(body.reward_mode)) fail('invalid_moderation_decision');
    const reason=body.reason===''?'':limitedText(body.reason,1,160);
    if(body.decision==='rejected'&&!reason) fail('reason_required');
    return {key,post_id:uuid(body.post_id),revision:revision(body.expected_revision),
      decision:body.decision,reward_mode:body.reward_mode,reason,operation_id:operationUUID(body.operation_id)};
  }
  if(op==='moderation.reports.decide'){
    if(!['community','comment'].includes(body.source) || typeof body.remove!=='boolean')
      fail('invalid_report_decision');
    if(body.remove && body.confirm_remove!==true) fail('explicit_confirmation_required');
    return {key,report_id:uuid(body.report_id),source:body.source,
      revision:revision(body.expected_revision),remove:body.remove,operation_id:operationUUID(body.operation_id)};
  }
  if(op==='moderation.safety.decide'){
    if(!['no_violation','confirmed_safety_issue'].includes(body.decision))
      fail('invalid_safety_decision');
    return {key,report_id:uuid(body.report_id),decision:body.decision,
      operation_id:operationUUID(body.operation_id)};
  }
  fail('unknown_operation');
}
async function rpc(client,name,args=undefined) {
  const result=await client.rpc(name,args);
  if(result?.error) errorFromRpc(result.error);
  return checkedData(result?.data);
}
function compatibleResult(value) {
  if(value===null||value===undefined) fail('operation_unavailable',503);
  return value;
}


/**
 * Enrich ONLY records supplied by an authenticated, scoped report-list RPC.
 * Never accept report IDs from a caller as a stand-alone email directory.
 * A separate service-role-only SQL function checks the verified admin again.
 */
async function attachAuthorizedReportContacts(operation,data,service,userId) {
  const kinds={
    'moderation.safety.open':'safety',
    'moderation.reports.open':'community',
    'moderation.posts.pending':'posts',
  };
  const kind=kinds[operation];
  if(!kind) return data;
  if(!Array.isArray(data)) throw new WebAdminError('invalid_report_queue_response',503);
  if(data.length>200) throw new WebAdminError('invalid_report_queue_response',503);
  const extractId=row=>kind==='safety'?row?.report_id:row?.id;
  const visibleIds=[...new Set(data.map(extractId).filter(okUUID))];
  if(data.length>0 && visibleIds.length===0)
    throw new WebAdminError('invalid_report_queue_response',503);
  if(visibleIds.length===0)return data;
  const contactById=new Map();
  for(let offset=0;offset<visibleIds.length;offset+=50){
    const ids=visibleIds.slice(offset,offset+50);
    const contacts=await rpc(service,'bil_admin_web_reporter_contacts_v1',{
      p_actor_id:userId,p_report_kind:kind,p_report_ids:ids
    });
    if(!Array.isArray(contacts)||contacts.length>ids.length)
      throw new WebAdminError('invalid_report_contact_response',503);
    for(const contact of contacts){
      if(!contact || !ids.includes(contact.record_id) ||
         !okUUID(contact.reporter_user_id) ||
         typeof contact.reporter_email!=='string' ||
         !EMAIL.test(contact.reporter_email.toLowerCase()) ||
         contact.reporter_email.length>254 || contactById.has(contact.record_id))
        throw new WebAdminError('invalid_report_contact_response',503);
      contactById.set(contact.record_id,{
        reporter_email:contact.reporter_email.toLowerCase(),
        reporter_user_id:contact.reporter_user_id,
      });
    }
  }
  return data.map(row=>({
    ...row,
    reporter_email:contactById.get(extractId(row))?.reporter_email??null,
    reporter_user_id:contactById.get(extractId(row))?.reporter_user_id??null,
  }));
}

async function perform(op,req,userId,user,service) {
  switch(op){
  case 'moderators.list': return rpc(service,'bil_list_community_moderators_for_admin',{p_actor_id:userId});
  case 'members.list': return rpc(service,'bil_list_suspended_community_members_for_admin',{p_actor_id:userId});
  case 'moderation.posts.pending': return rpc(user,'bil_list_pending_community_posts',{p_limit:req.limit});
  case 'moderation.posts.snapshots': return rpc(user,'bil_community_review_snapshots_v2',{p_post_ids:req.post_ids});
  case 'moderation.reports.open': return rpc(user,'bil_list_open_community_reports');
  case 'moderation.reports.content': return rpc(user,'bil_community_report_content_v1',{p_report_id:req.report_id,p_source:req.source});
  case 'moderation.safety.open': return rpc(user,'bil_list_ai_coach_safety_reports_v1');
  case 'moderators.add': return rpc(service,'bil_add_community_moderator_by_email',
    {p_actor_id:userId,p_email:req.email,p_idempotency_key:req.key});
  case 'moderators.remove': return rpc(service,'bil_remove_community_moderator',
    {p_actor_id:userId,p_user_id:req.user_id,p_idempotency_key:req.key});
  case 'members.suspend': return rpc(service,'bil_suspend_community_member_by_email',
    {p_actor_id:userId,p_email:req.email,p_reason:req.reason,p_idempotency_key:req.key});
  case 'members.reinstate': return rpc(service,'bil_reinstate_community_member',
    {p_actor_id:userId,p_user_id:req.user_id,p_idempotency_key:req.key});
  case 'coach.reset.all': return rpc(service,'bil_global_reset_ai_coach',
    {p_actor_id:userId,p_idempotency_key:req.key,p_message:req.message});
  case 'coach.reset.user': {
    const target=await rpc(service,'bil_resolve_ai_coach_reset_target',
      {p_actor_id:userId,p_normalized_email:req.email});
    if(!okUUID(target)) fail('target_not_found',404);
    return rpc(service,'bil_individual_reset_ai_coach',
      {p_actor_id:userId,p_target_id:target,p_reason:req.reason,
       p_idempotency_key:req.key,p_message:req.message});
  }
  case 'notifications.send':{
    let target=null;
    if(req.email!==null) {
      target=await rpc(service,'bil_resolve_admin_notification_target',
        {p_actor_id:userId,p_normalized_email:req.email});
      if(!okUUID(target)) fail('target_not_found',404);
    }
    return rpc(service,req.kind==='custom'
      ?'bil_enqueue_admin_notification':'bil_enqueue_admin_notification_with_message',
      {p_actor_id:userId,p_notification_kind:req.kind,p_audience:req.audience,
       p_target_id:target,
       ...(req.kind==='custom'?{p_custom_body:req.message}:{p_message:req.message}),
       p_idempotency_key:req.key});
  }
  case 'moderation.posts.review': return rpc(user,'bil_moderate_community_post_v2',
    {p_post_id:req.post_id,p_expected_revision:req.revision,p_decision:req.decision,
     p_operation_id:req.operation_id,p_reason:req.reason,p_reward_mode:req.reward_mode});
  case 'moderation.reports.decide': return rpc(user,'bil_decide_community_report_v1',
    {p_report_id:req.report_id,p_source:req.source,p_expected_revision:req.revision,
     p_remove:req.remove,p_operation_id:req.operation_id});
  case 'moderation.safety.decide': return rpc(user,'bil_review_ai_coach_safety_report_v1',
    {p_report_id:req.report_id,p_decision:req.decision,p_operation_id:req.operation_id});
  }
  fail('unknown_operation');
}

export async function handleOps(request,deps) {
  const env=deps.env??(()=>undefined);
  const allowed=exactOrigins(env('BIL_ADMIN_WEB_ALLOWED_ORIGINS'));
  const origin=request.headers.get('origin')||'';
  if(!allowed.includes(origin)) return json({error:'forbidden_origin'},403);
  if(request.method==='OPTIONS') return new Response(null,{status:204,headers:{
    ...REPLY_HEADERS,'access-control-allow-origin':origin,
    'access-control-allow-methods':'OPTIONS, POST',
    'access-control-allow-headers':CORS,'access-control-max-age':'300'
  }});
  if(request.method!=='POST') return json({error:'method_not_allowed'},405,origin);
  if(env('BIL_ADMIN_OPS_ENABLED')!=='true') return json({error:'admin_ops_disabled'},503,origin);
  try {
    const jwt=readBearer(request.headers.get('authorization'));
    if(Number(request.headers.get('content-length')||0)>8192)
      fail('request_too_large',413);
    const raw=await request.text();
    if(new TextEncoder().encode(raw).length>8192) fail('request_too_large',413);
    if(!/^application\/json(?:\s*;|\s*$)/i.test(request.headers.get('content-type')||''))
      fail('content_type_required',415);
    let body;try{body=JSON.parse(raw)}catch{fail('invalid_json')}
    requireObject(body);
    const user=deps.makeUserClient(jwt);
    const check=await user.auth.getUser(jwt);
    const userId=check?.data?.user?.id;
    if(check?.error||!okUUID(userId)) fail('invalid_session',401);
    const now=Math.floor((deps.now?.()??Date.now())/1000);
    const claims=verifiedClaims(jwt,userId,now);
    requireAal2(claims);
    if(!ownersAllowlist(env('BIL_ADMIN_WEB_FINANCE_OWNER_IDS')).has(userId.toLowerCase()))
      fail('not_found',404);
    const permission=await user.rpc('bil_can_manage_ai_coach');
    if(permission?.error||permission?.data!==true) fail('not_found',404);
    const op=body.operation;
    if(typeof op!=='string') fail('unknown_operation');
    const fields=validate(op,body);
    const writes=env('BIL_ADMIN_OPS_WRITE_ENABLED')==='true';
    if(op==='status')
      return json({access:'authorized',version:VERSION,read_enabled:true,
        writes_enabled:writes,require_recent_totp:true,financial_backend:'bil-admin-web-v1'},200,origin);
    const write=WRITE.has(op);
    if(write && !writes) fail('admin_ops_writes_locked',423);
    if(write) requireRecentTotp(claims,now);
    const rate=await user.rpc('bil_consume_rate_limit',{
      p_action:write?'admin_subscription_grant':'admin_subscription_list',
      p_limit:write?20:120,p_window_seconds:3600});
    if(rate?.error) errorFromRpc(rate.error);
    const service=deps.makeServiceClient();
    let data=compatibleResult(await perform(op,fields,userId,user,service));
    data=await attachAuthorizedReportContacts(op,data,service,userId);
    return json({state:'executed',operation:op,receipt:data,version:VERSION},200,origin);
  } catch(err) {
    if(err instanceof WebAdminError)
      return json({error:err.code},err.status,origin);
    return json({error:'admin_ops_unavailable'},503,origin);
  }
}
