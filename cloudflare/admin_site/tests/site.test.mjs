import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const source=readFileSync(new URL('../site/app.mjs',import.meta.url),'utf8');
const index=readFileSync(new URL('../site/index.html',import.meta.url),'utf8');
const headers=readFileSync(new URL('../site/_headers',import.meta.url),'utf8');
const config=readFileSync(new URL('../site/config.mjs',import.meta.url),'utf8');
test('Arabic RTL and English language support',()=>{
  assert.match(index, /lang="ar" dir="rtl"/);
  assert.match(source,/const ar =/);
  assert.match(source,/const en =/);
});
test('all nine admin modules are present',()=>{
  for(const name of ['overview','finance','coach','notifications','moderation','moderators','members','audit','security'])
    assert.match(index,new RegExp(`id="${name}-page"`));
});
test('moderation review reads exact snapshots and separates approval from Earn',()=>{
  for(const op of ['posts.queue','posts.detail','posts.review','earn.queue','earn.policy','earn.request','earn.decide','reports.content','reports.decide','safety.decide']){
    assert.ok(source.includes(op),'Missing documented operation '+op);
  }
  assert.match(source,/api\('review',\{operation:'posts.detail'/);
  assert.match(source,/expected_revision/);
  assert.match(source,/media_complete!==true/);
  assert.match(source,/acknowledge_full_content/);
  assert.match(source,/showReviewDecision\(/);
  assert.match(source,/moderation_writes_enabled/);
});
test('owner login uses Supabase OTP, real TOTP challenge, server state',()=>{
  assert.match(source,/auth\.signInWithOtp\(/);
  assert.match(source,/auth\.verifyOtp\(/);
  assert.match(source,/auth\.mfa\.challengeAndVerify\(/);
  assert.match(source,/api\('finance',\{operation:'status'\}\)/);
  assert.match(source,/api\('ops',\{operation:'status'\}\)/);
});
test('all privileged endpoints use authenticated JWT through server edge',()=>{
  assert.match(source,/getSession\(\)/);
  assert.match(source,/Authorization|authorization/);
  assert.match(source,/Bearer \$\{session\.access_token\}/);
  assert.match(source,/functions\/v1\/bil-admin-web-ops-v1/);
  assert.match(source,/functions\/v1\/bil-admin-web-v1/);
  assert.doesNotMatch(source,/service_role|SUPABASE_SERVICE_ROLE_KEY|secretKey/i);
});
test('financial mutations require confirmation and fresh MFA step-up',()=>{
  assert.match(source,/transaction\('finance',p\)/);
  assert.match(source,/showStepUp\(\)/);
  assert.match(source,/confirmEmail|confirm_email/);
  assert.match(source,/operation:'reconcile'/);
  assert.match(source,/idempotency_key:key/);
});
test('administrative writes fail closed according to backend',()=>{
  assert.match(index, /class="primary ops-write" disabled/);
  assert.match(source, /b\.disabled=!lock/);
  assert.match(source, /if\(!state\.ops\?\.writes_enabled\)/);
});
test('safe record rendering uses DOM text, not HTML injection',()=>{
  assert.match(source,/\.textContent=/);
  assert.match(source,/replaceChildren\(/);
  assert.doesNotMatch(source,/innerHTML|outerHTML|insertAdjacentHTML/);
});
test('CSP prohibits inline scripts and frames',()=>{
  assert.match(headers,/script-src 'self';/);
  assert.match(headers,/default-src 'none'/);
  assert.match(headers,/frame-ancestors 'none'/);
  assert.doesNotMatch(headers,/unsafe-inline|unsafe-eval/);
});
test('only publishable key is embedded in client configuration',()=>{
  assert.match(config,/SUPABASE_PUBLISHABLE_KEY/);
  assert.doesNotMatch(config,/service_role|sb_secret_/i);
});
test('no live user data or fabricated grant rows embedded',()=>{
  assert.doesNotMatch(source,/\bmockUsers\b|\bdemoGrants\b|\bfakeSuccess\b/);
});

test('pending financial receipts survive a same-owner tab refresh only',()=>{
  assert.match(source,/sessionStorage\.setItem\(PENDING_STORAGE_KEY/);
  assert.match(source,/sessionStorage\.getItem\(PENDING_STORAGE_KEY/);
  assert.match(source,/stored\?\.owner_id===state\.user\?\.id/);
  assert.match(source,/restorePending\(\)/);
});
test('reconciliation cannot claim success for an unmatched receipt',()=>{
  assert.match(source,/d\.receipt\?\.matched===true/);
  assert.match(source,/d\.receipt\?\.matched===false/);
  assert.match(source,/d\.operation===p\.operation/);
});
test('sign-out in another tab clears cached privileged records',()=>{
  assert.match(source,/onAuthStateChange/);
  assert.match(source,/event==='SIGNED_OUT'/);
  assert.match(source,/function clearPrivateView/);
  assert.match(source,/state\.auditRows=\[\]/);
});

test('owner-only reporter fields render without raw JSON and prepare a draft only',()=>{
  assert.match(source,/function renderRecords\(/);
  assert.match(source,/function renderReporterContact\(/);
  assert.match(source,/reporter_email/);
  assert.match(source,/reporter_user_id/);
  assert.match(source,/function prepareCompensation\(/);
  assert.match(source,/namedItem\('kind'\)\.value='compensation'/);
  assert.match(source,/namedItem\('email'\)\.value=/);
  assert.match(source,/function displayField\(|function reportField\(|function recordField\(|function renderRecords\(/);
  assert.doesNotMatch(source,/JSON\.stringify\(allowed,null,2\)/);
});
test('grant statuses and financial audit have localized labels and safe identifiers',()=>{
  assert.match(source,/function statusLabel\(/);
  assert.match(source,/function badge\(/);
  assert.match(source,/elem\('span',statusLabel\(value\),'pill'\)/);
  assert.match(source,/setAttribute\('data-status',code\)/);
  assert.match(source,/operationGrant/);
  assert.match(source,/operationRevoke/);
  assert.match(source,/resultChanged/);
  assert.match(source,/function identifier\(/);
  assert.match(source,/identifier\(row\.grant_id\)/);
});
test('notifications explain custom, gift and compensation, with all-account confirmation',()=>{
  assert.match(source,/notificationWarning/);
  assert.match(source,/notificationKindHelpCustom/);
  assert.match(source,/notificationKindHelpGift/);
  assert.match(source,/notificationKindHelpCompensation/);
  assert.match(source,/notificationAudienceAll/);
  assert.match(source,/updateNotificationHelp/);
  assert.match(source,/acknowledge_token_grant/);
});
test('global AI coach reset and member scope explain real effects and server lock',()=>{
  assert.match(source,/individualResetHelp/);
  assert.match(source,/globalWarning/);
  assert.match(source,/whyLocked/);
  assert.match(source,/membersHelp/);
  assert.match(index,/data-i18n="whyLocked"/);
  assert.match(index,/data-i18n="membersHelp"/);
});
test('mobile tables collapse into labeled cards and maintain bounded width',()=>{
  const css=readFileSync(new URL('../site/styles.css',import.meta.url),'utf8');
  assert.match(css,/overflow-x:clip/);
  assert.match(css,/white-space:nowrap/);
  assert.match(css,/grid-template-columns:minmax/);
  assert.match(css,/content:attr\(data-label\)/);
  assert.match(css,/\.data-table td\{display:grid/);
  assert.match(source,/td\.dataset\.label/);
  assert.match(source,/container\.classList\.remove\('empty-state'\)/);
  assert.match(source,/function makeTable\(/);
  assert.match(source,/function badge\(/);
});
test('private post images fail closed on errors under exact-origin CSP',()=>{
  const headers=readFileSync(new URL('../site/_headers',import.meta.url),'utf8');
  assert.match(headers,/img-src 'self' data: https:\/\/tgmanzhqulksykhslrzb\.supabase\.co;/);
  assert.match(source,/function validReviewImage\(/);
  assert.match(source,/function reviewPictureGallery\(/);
  assert.match(source,/picture\.addEventListener\('error'/);
  assert.match(source,/row\.media_complete=false/);
  assert.match(source,/media-broken/);
});
test('human moderation receipts disclose exact Earn policy but never preclaim push delivery',()=>{
 assert.match(source,/posts\.detail/);
 assert.match(source,/earn\.queue/);
 assert.match(source,/notificationPreview/);
 assert.match(source,/approvedWithReward/);
 assert.match(source,/approvedWithoutReward/);
 assert.match(source,/showReviewDecision\(/);
 assert.match(source,/require.*TOTP|showStepUp\(/);
});
