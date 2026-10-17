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
test('moderation workflows use versioned server snapshots and audit confirmations',()=>{
  assert.match(source,/moderation.posts.snapshots/);
  assert.match(source,/moderation.posts.review/);
  assert.match(source,/moderation.reports.content/);
  assert.match(source,/moderation.reports.decide/);
  assert.match(source,/moderation.safety.decide/);
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