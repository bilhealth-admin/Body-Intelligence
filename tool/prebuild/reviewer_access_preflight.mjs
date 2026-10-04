import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const ASC = 'https://api.appstoreconnect.apple.com';
const CLOUD = 'https://tgmanzhqulksykhslrzb.supabase.co';
const APP = '6805349703';
const BUNDLE = 'com.bilhealth.bodyintelligencelog';

class AuditFailure extends Error {
  constructor(code, status = null) { super(code); this.status = status; }
}
const finiteDate = (value) => typeof value === 'string' ? Date.parse(value) : NaN;
export function summarizeAccess({ subscription, grant, closedTest, usage, owner }, now = Date.now()) {
  const knownPlans = new Set(['premium', 'premium_ai_coach']);
  const lifecycle = subscription?.lifecycle;
  const boundary = lifecycle === 'grace_period' ? subscription?.grace_period_ends_at : subscription?.expires_at;
  const verified = finiteDate(subscription?.verified_at);
  const started = subscription?.started_at == null ? now : finiteDate(subscription.started_at);
  const store = knownPlans.has(subscription?.plan_id) && ['apple', 'google'].includes(subscription?.provider)
    && ['active', 'trial', 'grace_period', 'cancelled'].includes(lifecycle)
    && Number.isFinite(verified) && verified <= now + 300000 && started <= now && finiteDate(boundary) > now;
  const until = finiteDate(grant?.access_until);
  const created = finiteDate(grant?.created_at);
  const expires = grant?.expires_at == null ? Infinity : finiteDate(grant.expires_at);
  const admin = grant?.owner_id === owner && knownPlans.has(grant?.plan_id)
    && until > now && until <= now + 360000 && created <= now + 60000
    && expires > now && until <= expires;
  const closed = closedTest?.active === true && finiteDate(closedTest?.expires_at) > now;
  const credits = usage?.credits?.total_remaining;
  return {
    storeSubscriptionVerifiedAndActive: store,
    administrativeLeaseValid: admin,
    closedTestGrantActive: closed,
    premiumAccessCandidate: store || admin || closed,
    storePlan: store ? subscription.plan_id : null,
    administrativePlan: admin ? grant.plan_id : null,
    aiCreditsPositive: typeof credits === 'number' && Number.isFinite(credits) && credits > 0,
    aiCreditsRemaining: typeof credits === 'number' && Number.isFinite(credits) && credits >= 0 ? credits : null,
    assessmentBoundary: 'SERVER_RESPONSE_PREFLIGHT_NOT_FLUTTER_UI_OR_NATIVE_PURCHASE',
  };
}

async function request(origin, resource, headers, body, method = body ? 'POST' : 'GET') {
  const url = new URL(resource, origin);
  if (![ASC, CLOUD].includes(url.origin) || url.origin !== origin) throw new AuditFailure('untrusted_origin');
  if (origin === ASC && method !== 'GET') throw new AuditFailure('store_write_forbidden');
  const allowedPost = /^\/auth\/v1\/(token|logout)$/.test(url.pathname)
    || ['/rest/v1/rpc/bil_get_my_admin_subscription','/rest/v1/rpc/bil_get_ai_usage_status'].includes(url.pathname);
  if (origin === CLOUD && method !== 'GET' && !(method === 'POST' && allowedPost)) throw new AuditFailure('cloud_mutation_forbidden');
  let response;
  try {
    response = await fetch(url, { method, redirect: 'error', signal: AbortSignal.timeout(15000),
      headers: { Accept: 'application/json', 'Content-Type': 'application/json', ...headers },
      body: body === undefined ? undefined : JSON.stringify(body) });
  } catch { throw new AuditFailure('transport_failed'); }
  if (!response.ok) throw new AuditFailure('http_request_failed', response.status);
  const text = await response.text();
  if (text.length > 2000000) throw new AuditFailure('response_too_large');
  try { return text ? JSON.parse(text) : null; } catch { throw new AuditFailure('invalid_json'); }
}
function appleToken() {
  const id = process.env.APP_STORE_CONNECT_KEY_ID;
  const issuer = process.env.APP_STORE_CONNECT_ISSUER_ID;
  const encoded = process.env.APP_STORE_CONNECT_PRIVATE_KEY_BASE64;
  if (!id || !issuer || !encoded) throw new AuditFailure('missing_asc_credentials');
  const now = Math.floor(Date.now() / 1000);
  const part = (v) => Buffer.from(JSON.stringify(v)).toString('base64url');
  const unsigned = `${part({alg:'ES256',kid:id,typ:'JWT'})}.${part({iss:issuer,iat:now-5,exp:now+600,aud:'appstoreconnect-v1'})}`;
  const signature = crypto.sign('sha256', Buffer.from(unsigned), {
    key: Buffer.from(encoded,'base64').toString('utf8'), dsaEncoding:'ieee-p1363',
  }).toString('base64url');
  return `${unsigned}.${signature}`;
}
export async function run(outputDir) {
  fs.mkdirSync(outputDir,{recursive:true});
  const result = { source:process.env.GITHUB_SHA ?? null, checkedAt:new Date().toISOString(),
    result:'NOT_VERIFIED', credentialSource:'APPLE_CONFIGURED_REVIEW_DETAIL', googleAccountInstructionsVerified:false,
    credentialsExported:false, storeMutationPerformed:false, entitlementMutationPerformed:false,
    nativePurchasePerformed:false, stage:'credentials', sessionCleanup:'NOT_NEEDED' };
  let accessToken;
  const apiKey = process.env.BIL_SUPABASE_PUBLISHABLE_KEY;
  try {
    if (!apiKey?.startsWith('sb_publishable_')) throw new AuditFailure('missing_publishable_key');
    const ascHeaders = {Authorization:`Bearer ${appleToken()}`};
    result.stage='store_app_identity';
    const app = await request(ASC,`/v1/apps/${APP}`,ascHeaders);
    if (app?.data?.attributes?.bundleId !== BUNDLE) throw new AuditFailure('bundle_mismatch');
    const versions = await request(ASC,`/v1/apps/${APP}/appStoreVersions?filter[platform]=IOS&limit=200`,ascHeaders);
    const version = versions?.data?.find(v=>v.attributes?.versionString==='1.0.0');
    if (!version) throw new AuditFailure('review_version_missing');
    const related = version.relationships?.appStoreReviewDetail?.links?.related;
    if (!related) throw new AuditFailure('review_details_link_missing');
    result.stage='review_credentials_present';
    const detail = await request(ASC,related,ascHeaders);
    const credentials = detail?.data?.attributes;
    const email = credentials?.demoAccountName?.trim();
    const password = credentials?.demoAccountPassword;
    if (!email || !password) throw new AuditFailure('review_credentials_missing');
    result.stage='ordinary_password_login';
    const session = await request(CLOUD,'/auth/v1/token?grant_type=password',{apikey:apiKey},{email,password});
    accessToken=session?.access_token;
    if (!accessToken || !session?.user?.id) throw new AuditFailure('login_session_missing');
    const authHeaders={apikey:apiKey,Authorization:`Bearer ${accessToken}`};
    result.stage='authenticated_identity';
    const user=await request(CLOUD,'/auth/v1/user',authHeaders);
    if (user?.id!==session.user.id || user?.email?.toLowerCase()!==email.toLowerCase()) throw new AuditFailure('review_identity_mismatch');
    result.loginVerified=true;
    const owner=encodeURIComponent(user.id);
    result.stage='server_subscription_and_credits';
    const [rows,grants,closed,usage,entitlements]=await Promise.all([
      request(CLOUD,`/rest/v1/bil_subscriptions?owner_id=eq.${owner}&limit=1&select=plan_id,lifecycle,provider,verified_at,started_at,expires_at,grace_period_ends_at`,authHeaders),
      request(CLOUD,'/rest/v1/rpc/bil_get_my_admin_subscription',authHeaders,{}),
      request(CLOUD,`/rest/v1/bil_ai_closed_test_grants?owner_id=eq.${owner}&limit=1&select=active,expires_at`,authHeaders),
      request(CLOUD,'/rest/v1/rpc/bil_get_ai_usage_status',authHeaders,{}),
      request(CLOUD,`/rest/v1/bil_entitlements?owner_id=eq.${owner}&select=entitlement_id,active,starts_at,expires_at&limit=100`,authHeaders),
    ]);
    result.access=summarizeAccess({subscription:rows?.[0],grant:grants,closedTest:closed?.[0],usage,owner:user.id});
    result.activeStoreEntitlementCount=Array.isArray(entitlements)?entitlements.filter(e=>e.active===true&&finiteDate(e.starts_at)<=Date.now()&&(e.expires_at==null||finiteDate(e.expires_at)>Date.now())).length:null;
    result.result=result.access.premiumAccessCandidate && result.access.aiCreditsPositive ? 'SERVER_ACCESS_PREFLIGHT_PASS' : 'REVIEWER_ACCESS_GAP';
    result.stage='complete';
  } catch(error) {
    result.failure={code:error instanceof AuditFailure?error.message:'preflight_internal_error',httpStatus:error instanceof AuditFailure?error.status:null};
  } finally {
    if(accessToken) {
      try {
        await request(CLOUD,'/auth/v1/logout?scope=local',{apikey:apiKey,Authorization:`Bearer ${accessToken}`},undefined,'POST');
        result.sessionCleanup='CURRENT_SESSION_SIGNED_OUT';
      } catch { result.sessionCleanup='FAILED'; result.result='NOT_VERIFIED'; }
    }
    fs.writeFileSync(path.join(outputDir,'reviewer-access.json'),JSON.stringify(result,null,2)+'\n');
    console.log(JSON.stringify({result:result.result,stage:result.stage,sessionCleanup:result.sessionCleanup}));
  }
  return result.result==='SERVER_ACCESS_PREFLIGHT_PASS';
}
if(process.argv[1] && import.meta.url===pathToFileURL(path.resolve(process.argv[1])).href) {
  const output=process.argv[2];
  if(!output) throw new Error('An output directory is required');
  if(!(await run(path.resolve(output)))) process.exitCode=1;
}
