/**
 * BIL global moderation: least-privilege read and owner-confirmed decision gateway.
 * All requests require a Supabase verified session, AAL2, active SQL authority,
 * and an exact HTTPS origin. Service-key access never crosses this runtime.
 */
import {
  WebAdminError, exactOrigins, ownersAllowlist, readBearer,
  verifiedClaims, requireAal2, requireRecentTotp, requireObject,
} from './policy.mjs';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const REVISION = /^[0-9a-f]{64}$/;
const CONTROLS = /[\x00-\x1f\x7f]/;
const SAFE_MIME = new Set(['image/jpeg','image/png','image/webp']);
const OPERATIONS = new Set(['status','posts.queue','posts.detail','posts.review','earn.queue','earn.policy','earn.request','earn.decide','reports.content','reports.decide','safety.decide']);
const WRITES = new Set(['posts.review','earn.request','earn.decide','reports.decide','safety.decide']);
const VERSION = '2026-10-18-ugc-review-v1';
const ALLOWED_HEADERS = 'authorization, apikey, content-type, x-client-info';
const HEADERS = Object.freeze({
  'content-type':'application/json; charset=utf-8',
  'cache-control':'no-store, private',
  'x-content-type-options':'nosniff',
  'referrer-policy':'no-referrer',
  'x-frame-options':'DENY',
  'vary':'Origin',
});

function reply(body,status=200,origin=null){
  const headers={...HEADERS};
  if(origin) {
    headers['access-control-allow-origin']=origin;
    headers['access-control-allow-methods']='POST, OPTIONS';
    headers['access-control-allow-headers']=ALLOWED_HEADERS;
    headers['access-control-max-age']='240';
  }
  return new Response(JSON.stringify(body),{status,headers});
}
function requireCondition(v,name='invalid_request',status=400){
  if(!v) throw new WebAdminError(name,status);
}
function uuid(v) {requireCondition(typeof v==='string'&&UUID.test(v),'invalid_id');return v;}
function revision(v) {requireCondition(typeof v==='string'&&REVISION.test(v),'invalid_revision');return v;}
function textValue(v,{required=false,max=160}={}){
  const x=typeof v==='string'?v.trim():'';
  requireCondition(!CONTROLS.test(x)&&[...x].length<=max&&(!required||x.length>0),'invalid_text');
  return x;
}
function requiredMatch(x,y){requireCondition(x===y,'confirmation_required');}
function requireArray(v,max=20){requireCondition(Array.isArray(v)&&v.length<=max&&v.every(x=>typeof x==='string'&&UUID.test(x)),'invalid_ids');return [...new Set(v)];}
function parse(body){
  requireObject(body);
  const operation=body.operation;
  requireCondition(typeof operation==='string'&&OPERATIONS.has(operation),'invalid_operation');
  if(operation==='status'||operation==='earn.queue'||operation==='earn.policy')return {operation};
  if(operation==='posts.queue') {
    requireCondition(body.limit===undefined||Number.isInteger(body.limit)&&body.limit>=1&&body.limit<=30,'invalid_limit');
    return {operation,limit:body.limit??12};
  }
  if(operation==='posts.detail')return {operation,post_id:uuid(body.post_id)};
  if(operation==='reports.content'){
    requireCondition(['community','comment'].includes(body.source),'invalid_source');
    return {operation,report_id:uuid(body.report_id),source:body.source};
  }
  if(operation==='posts.review'){
    requireCondition(['approved','rejected'].includes(body.decision),'invalid_decision');
    const post_id=uuid(body.post_id);
    requiredMatch(body.confirm_post_id,post_id);
    requireCondition(body.acknowledge_full_content===true,'review_not_acknowledged');
    const reason=textValue(body.reason,{required:body.decision==='rejected'});
    return {operation,post_id,expected_revision:revision(body.expected_revision),decision:body.decision,
      operation_id:uuid(body.operation_id),reason};
  }
  if(operation==='earn.request'){
    const post_id=uuid(body.post_id);requiredMatch(body.confirm_post_id,post_id);
    return {operation,post_id,expected_revision:revision(body.expected_revision)};
  }
  if(operation==='earn.decide'){
    const request_id=uuid(body.request_id);requiredMatch(body.confirm_request_id,request_id);
    requireCondition(typeof body.approve==='boolean','invalid_earn_decision');
    return {operation,request_id,approve:body.approve,reason:textValue(body.reason,{required:!body.approve})};
  }
  if(operation==='reports.decide'){
    const report_id=uuid(body.report_id);requiredMatch(body.confirm_report_id,report_id);
    requireCondition(['community','comment'].includes(body.source)&&typeof body.remove==='boolean','invalid_report_decision');
    if(body.remove)requireCondition(body.confirm_remove===true,'confirmation_required');
    return {operation,report_id,source:body.source,expected_revision:revision(body.expected_revision),
      remove:body.remove,operation_id:uuid(body.operation_id)};
  }
  if(operation==='safety.decide'){
    const report_id=uuid(body.report_id);requiredMatch(body.confirm_report_id,report_id);
    requireCondition(['no_violation','confirmed_safety_issue'].includes(body.decision),'invalid_safety_decision');
    return {operation,report_id,decision:body.decision,operation_id:uuid(body.operation_id)};
  }
  throw new WebAdminError('invalid_operation');
}
function errorFromProvider(err,operation){
  const detail=String(err?.message||'');
  if((operation==='bil_admin_web_review_context_v1'||operation==='bil_admin_web_review_reward_policy_v1') &&
     /42501|permission denied|service_role_required/i.test(detail))
    throw new WebAdminError('review_context_configuration_error',503);
  if(/42501|administrator_required|moderator_required|not.authorized|permission denied/i.test(detail))
    throw new WebAdminError('not_authorized',403);
  if(/conflict|content.changed|review_content_changed|already.moderated|already_reviewed|40001/i.test(detail))
    throw new WebAdminError('stale_content',409);
  if(/rate.limit.exceeded/i.test(detail))throw new WebAdminError('rate_limited',429);
  throw new WebAdminError(operation==='signed_media'?'media_unavailable':'backend_unavailable',503);
}
async function rpc(client,name,args){
  const {data,error}=await client.rpc(name,args);
  if(error)errorFromProvider(error,name);
  return data;
}
function checkedRecords(value,max=40){
  requireCondition(Array.isArray(value)&&value.length<=max,'invalid_backend_result',503);
  return value;
}
function mediaPath(v){
  return typeof v==='string'&&v.length>0&&v.length<=512&&
    !CONTROLS.test(v)&&!v.includes('?')&&!v.includes('#')&&!v.includes('\\')&&
    !v.startsWith('/')&&!v.startsWith('//')&&!v.includes('://')&&
    !v.split('/').includes('..')&&!v.split('/').includes('.')&&
    !v.startsWith('community-post-images/');
}
function postIsReviewable(post,actor){
  return post && typeof post==='object'&&UUID.test(post.id||'')&&
    post.author_id!==actor&&post.deleted_at==null&&post.moderation_status==='pending';
}
function safeSnapshot(snap,id,actor){
  requireCondition(snap && typeof snap==='object'&&postIsReviewable(snap.post,actor)&&
    snap.post.id===id&&typeof snap.revision==='string'&&REVISION.test(snap.revision),
    'post_not_reviewable',409);
  return snap;
}
async function postSnapshot(user,id,actor){
  const rows=checkedRecords(await rpc(user,'bil_community_review_snapshots_v2',{p_post_ids:[id]}),2);
  const snap=rows.find(v=>v?.post?.id===id);
  return safeSnapshot(snap,id,actor);
}
// All privileged case metadata is read through a service-role-only,
// active-admin-checked SECURITY DEFINER RPC. No direct SELECT grants to the
// browser, authenticated role, or even service_role on private tables.
async function reviewContext(service,post,actor){
  const context=await rpc(service,'bil_admin_web_review_context_v1',{
    p_actor_id:actor,p_post_id:post.id
  });
  requireCondition(context && typeof context==='object' &&
    context.post_id===post.id && context.author_id===post.author_id &&
    Array.isArray(context.media) && context.media.length<=12,
    'review_context_unavailable',503);
  return context;
}
async function signedMedia(service,post,context){
  const id=post.id;
  const manifest=checkedRecords(context?.media,12).map(m=>({...m}));
  if(post.media_object_path && !manifest.some(m=>m.object_path===post.media_object_path)){
    manifest.unshift({post_id:id,position:-1,object_path:post.media_object_path,mime_type:post.media_mime_type,
      bytes:post.media_bytes,width:post.media_width,height:post.media_height});
  }
  // Legacy URL metadata must not be silently accepted as an image-free post.
  if(post.media_url && !post.media_object_path && manifest.length===0)
    throw new WebAdminError('legacy_media_needs_verification',503);
  requireCondition(manifest.length<=12,'too_many_media',503);
  const media=[];
  for(const m of manifest){
    requireCondition(m?.post_id===id && mediaPath(m.object_path),'invalid_media_reference',503);
    if(m.mime_type!=null)requireCondition(SAFE_MIME.has(m.mime_type),'unsupported_media',503);
    if(m.bytes!=null)requireCondition(Number.isFinite(m.bytes)&&m.bytes>0&&m.bytes<=5242880,'invalid_media_size',503);
    const signed=await service.storage.from('community-post-images').createSignedUrl(m.object_path,180);
    if(signed?.error||typeof signed?.data?.signedUrl!=='string'||
      !signed.data.signedUrl.startsWith('https://'))errorFromProvider(signed?.error||new Error('missing_signed_url'),'signed_media');
    media.push({position:m.position,path_label:`${media.length+1}/${manifest.length}`,
      url:signed.data.signedUrl,width:m.width??null,height:m.height??null,mime_type:m.mime_type??null});
  }
  return media;
}
async function postDetail(user,service,id,actor){
  const snap=await postSnapshot(user,id,actor);
  const post=snap.post;
  const context=await reviewContext(service,post,actor);
  const media=await signedMedia(service,post,context);
  const emailRecords=checkedRecords(await rpc(service,'bil_admin_web_reporter_contacts_v1',{
    p_actor_id:actor,p_report_kind:'posts',p_report_ids:[id]
  }),1);
  const matching=emailRecords.find(x=>x.record_id===id&&x.reporter_user_id===post.author_id);
  return {
    post_id:id,revision:snap.revision,author_id:post.author_id,author_name:context.author_name??null,
    author_email:typeof matching?.reporter_email==='string'?matching.reporter_email:null,
    title:post.title??context.title??null,body:post.body??'',created_at:post.created_at,edited_at:post.edited_at,
    visibility:post.visibility??null,location:context.location??post.location_label??null,
    hashtags:Array.isArray(context.hashtags)?context.hashtags:[],
    topics:Array.isArray(context.topics)?context.topics:[],
    circles:Array.isArray(context.circles)?context.circles:[],
    poll:context.poll??null,
    images:media,media_count:media.length,media_complete:true,
    expires_in_seconds:media.length?180:null,
    moderation_status:post.moderation_status,
  };
}
async function allQueue(user,service,actor,limit){
  const raw=checkedRecords(await rpc(user,'bil_list_pending_community_posts',{p_limit:limit}),limit);
  const rows=[];
  for(const item of raw){
    if(!item||!UUID.test(item.id||'')||item.author_id===actor)continue;
    try{
      const detail=await postDetail(user,service,item.id,actor);
      rows.push({...item,...detail,author_name:detail.author_name??item.author_name??null});
    }catch(err){
      // Never silently approve a post whose media cannot be reviewed.
      rows.push({id:item.id,post_id:item.id,author_id:item.author_id,
        author_name:item.author_name??null,title:item.title??null,body:item.body??null,
        created_at:item.created_at,media_complete:false,
        preview_error:err instanceof WebAdminError?err.code:'preview_unavailable',
        can_decide:false});
    }
  }
  return {rows,has_more:raw.length===limit};
}
async function rewardPolicy(service,actor){
  const policy=await rpc(service,'bil_admin_web_review_reward_policy_v1',{p_actor_id:actor});
  requireCondition(policy&&Number.isSafeInteger(policy.tokens_per_approval)&&policy.tokens_per_approval>=0&&
    Number.isSafeInteger(policy.max_rewarded_posts_per_owner_per_utc_day)&&policy.max_rewarded_posts_per_owner_per_utc_day>=0&&
    policy.max_daily_tokens===policy.tokens_per_approval*policy.max_rewarded_posts_per_owner_per_utc_day,
    'reward_policy_unavailable',503);
  return policy;
}
async function earnQueue(user,service,actor){
  const raw=checkedRecords(await rpc(user,'bil_community_reward_review_queue_v2',{p_limit:35}),35);
  const rows=[];
  for(const row of raw){
    const post=row?.post;
    if(!post||!UUID.test(post.id||'')||post.author_id===actor)continue;
    let email=null;
    // ID comes exclusively from the owner-authorized queue, never the browser.
    if(UUID.test(post.author_id||'')) {
      const {data,error}=await service.auth.admin.getUserById(post.author_id);
      if(error)errorFromProvider(error,'earned_author');
      const value=data?.user?.email;
      if(typeof value==='string'&&value.length<=254&&value.includes('@'))email=value.toLowerCase();
    }
    let images=[],context=null,media_complete=false,preview_error=null;
    try{
      context=await reviewContext(service,post,actor);
      images=await signedMedia(service,post,context);media_complete=true;
    }catch(e){preview_error=e instanceof WebAdminError?e.code:'preview_unavailable';}
    rows.push({post_id:post.id,title:post.title??context?.title??null,body:post.body??'',
      author_id:post.author_id,author_name:context?.author_name??null,
      author_email:email,revision:row.revision,
      request_id:row.request_id,status:row.status,can_grant:row.can_grant===true,
      reviewed_at:post.reviewed_at,created_at:post.created_at,
      location:context?.location??null,hashtags:context?.hashtags??[],topics:context?.topics??[],
      circles:context?.circles??[],poll:context?.poll??null,
      images:media_complete?images:undefined,media_count:media_complete?images.length:null,
      media_complete,preview_error});
  }
  return rows;
}
function safeReceipt(op,d){
  requireCondition(d!=null&&typeof d==='object'&&!Array.isArray(d),'invalid_receipt',503);
  if(op==='posts.review') {
    requireCondition(['approved','rejected'].includes(d.decision)&&Number.isSafeInteger(d.tokens_granted)&&
      d.tokens_granted>=0&&d.tokens_granted<=5&&typeof d.reward_reason==='string'&&
      d.receipt_state==='executed','invalid_post_receipt',503);
  }
  if(op==='earn.request'||op==='earn.decide'){
    requireCondition(typeof d.status==='string'&&Number.isSafeInteger(d.tokens_granted)&&d.tokens_granted>=0&&d.tokens_granted<=5,
      'invalid_earn_receipt',503);
  }
  return d;
}
async function run(op,body,user,service,actor){
  switch(op){
    case 'posts.queue':return allQueue(user,service,actor,body.limit);
    case 'posts.detail':return postDetail(user,service,body.post_id,actor);
    case 'earn.queue':return earnQueue(user,service,actor);
    case 'earn.policy':return rewardPolicy(service,actor);
    case 'reports.content':return rpc(user,'bil_community_report_content_v1',{
      p_report_id:body.report_id,p_source:body.source});
    case 'posts.review': {
      // Rechecking the same revision immediately before mutation detects edits.
      const snap=await postSnapshot(user,body.post_id,actor);
      requireCondition(snap.revision===body.expected_revision,'stale_content',409);
      const material=await reviewContext(service,snap.post,actor);
      await signedMedia(service,snap.post,material);
      const d=await rpc(user,'bil_moderate_community_post_v2',{
        p_post_id:body.post_id,p_expected_revision:body.expected_revision,p_decision:body.decision,
        p_operation_id:body.operation_id,p_reason:body.reason,p_reward_mode:'eligible'
      });
      return safeReceipt(op,d);
    }
    case 'earn.request': {
      const list=await earnQueue(user,service,actor);
      const row=list.find(x=>x.post_id===body.post_id&&x.revision===body.expected_revision&&
        (x.request_id==null||x.status==='requested'));
      requireCondition(!!row,'reward_request_not_eligible',409);
      const d=await rpc(user,'bil_request_community_post_reward_v2',{
        p_post_id:body.post_id,p_expected_revision:body.expected_revision});
      return safeReceipt(op,d);
    }
    case 'earn.decide':{
      const list=await earnQueue(user,service,actor);
      const row=list.find(x=>x.request_id===body.request_id&&x.can_grant);
      requireCondition(!!row&&row.media_complete===true,'reward_decision_not_eligible',409);
      return safeReceipt(op,await rpc(user,'bil_decide_community_post_reward_v2',{
        p_request_id:body.request_id,p_approve:body.approve,p_reason:body.reason}));
    }
    case 'reports.decide':{
      const snap=await rpc(user,'bil_community_report_content_v1',{
        p_report_id:body.report_id,p_source:body.source});
      requireCondition(snap?.revision===body.expected_revision,'stale_content',409);
      return rpc(user,'bil_decide_community_report_v1',{
        p_report_id:body.report_id,p_source:body.source,
        p_expected_revision:body.expected_revision,p_remove:body.remove,
        p_operation_id:body.operation_id});
    }
    case 'safety.decide': {
      const list=checkedRecords(await rpc(user,'bil_list_ai_coach_safety_reports_v1'),100);
      requireCondition(list.some(x=>x.report_id===body.report_id&&x.status==='open'),'report_not_reviewable',409);
      return rpc(user,'bil_review_ai_coach_safety_report_v1',{
        p_report_id:body.report_id,p_decision:body.decision,p_operation_id:body.operation_id});
    }
  }
  throw new WebAdminError('invalid_operation');
}
export async function handleReview(request,deps){
  const env=deps.env??(()=>undefined);
  const origin=request.headers.get('origin')??'';
  const valid=exactOrigins(env('BIL_ADMIN_WEB_ALLOWED_ORIGINS')).includes(origin);
  if(!valid)return reply({error:'forbidden_origin'},403);
  if(request.method==='OPTIONS')return new Response(null,{status:204,headers:{
    ...HEADERS,'access-control-allow-origin':origin,
    'access-control-allow-methods':'POST, OPTIONS','access-control-allow-headers':ALLOWED_HEADERS,
    'access-control-max-age':'240'
  }});
  if(request.method!=='POST')return reply({error:'method_not_allowed'},405,origin);
  if(env('BIL_ADMIN_REVIEW_ENABLED')!=='true')return reply({error:'review_unavailable'},503,origin);
  try{
    const jwt=readBearer(request.headers.get('authorization'));
    const contentType=request.headers.get('content-type')??'';
    requireCondition(/^application\/json(?:\s*;|\s*$)/i.test(contentType),'content_type_required',415);
    requireCondition(Number(request.headers.get('content-length')||0)<=8192,'request_too_large',413);
    const input=await request.text();
    requireCondition(new TextEncoder().encode(input).length<=8192,'request_too_large',413);
    let raw;try{raw=JSON.parse(input)}catch{throw new WebAdminError('invalid_json')}
    const user=deps.makeUserClient(jwt);
    const check=await user.auth.getUser(jwt);
    const actor=check?.data?.user?.id;
    requireCondition(!check?.error&&typeof actor==='string'&&UUID.test(actor),'invalid_session',401);
    const now=Math.floor((deps.now?.()??Date.now())/1000);
    const claims=verifiedClaims(jwt,actor,now);
    requireAal2(claims);
    requireCondition(ownersAllowlist(env('BIL_ADMIN_WEB_FINANCE_OWNER_IDS')).has(actor.toLowerCase()),'not_authorized',403);
    const canManage=await user.rpc('bil_can_manage_ai_coach');
    requireCondition(!canManage?.error&&canManage?.data===true,'not_authorized',403);
    const body=parse(raw);
    const write=WRITES.has(body.operation);
    const writeEnabled=env('BIL_ADMIN_REVIEW_WRITE_ENABLED')==='true';
    if(body.operation==='status')return reply({access:'authorized',version:VERSION,
      read_enabled:true,moderation_writes_enabled:writeEnabled,
      reward_policy_source:'postgres',requires_fresh_totp:true},200,origin);
    if(write&&!writeEnabled)throw new WebAdminError('moderation_writes_locked',423);
    if(write) requireRecentTotp(claims,now);
    const limitResult=await user.rpc('bil_consume_rate_limit',{
      p_action:write?'admin_subscription_grant':'admin_subscription_list',
      p_limit:write?20:120,p_window_seconds:3600
    });
    if(limitResult?.error)errorFromProvider(limitResult.error,'rate_check');
    const service=deps.makeServiceClient();
    const value=await run(body.operation,body,user,service,actor);
    return reply({operation:body.operation,state:'verified_response',receipt:value,version:VERSION},200,origin);
  }catch(err){
    if(err instanceof WebAdminError)return reply({error:err.code},err.status,origin);
    return reply({error:'review_backend_unavailable'},503,origin);
  }
}