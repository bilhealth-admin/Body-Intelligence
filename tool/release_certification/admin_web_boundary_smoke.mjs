// Read-only public boundary checks. Never signs in or invokes an owner mutation.
import assert from 'node:assert/strict';

const origin = 'https://bilhealth-secure-admin.bilhealth-app.workers.dev';
const api = 'https://tgmanzhqulksykhslrzb.supabase.co/functions/v1/';
const endpoints = ['bil-admin-web-v1', 'bil-admin-web-ops-v1', 'bil-admin-web-review-v1'];
const rows = [];
const get = (url, options = {}) => fetch(url, {
  ...options, signal: AbortSignal.timeout(30000), redirect: 'error',
});
const site = await get(origin);
assert.equal(site.status, 200, 'Published independent admin login must load');
const html = await site.text();
assert.match(html, /<html/);
assert.ok(!html.includes('sb_secret_'), 'No server secret in public HTML');
assert.ok(site.headers.get('content-security-policy'), 'Admin site needs CSP');
rows.push({site: origin, status: site.status});
for (const endpoint of endpoints) {
  const allowed = await get(api + endpoint, {
    method: 'OPTIONS', headers: {Origin: origin, 'Access-Control-Request-Method': 'POST'},
  });
  assert.equal(allowed.status, 204, `${endpoint} legitimate browser preflight`);
  assert.equal(allowed.headers.get('access-control-allow-origin'), origin);
  await allowed.arrayBuffer();
  const denied = await get(api + endpoint, {
    method: 'POST', headers: {Origin: origin, 'Content-Type': 'application/json'},
    body: JSON.stringify({operation: 'status'}),
  });
  assert.equal(denied.status, 401, `${endpoint} requires authenticated owner`);
  await denied.arrayBuffer();
  const hostile = await get(api + endpoint, {
    method: 'OPTIONS', headers: {Origin: 'https://untrusted.invalid', 'Access-Control-Request-Method': 'POST'},
  });
  assert.equal(hostile.status, 403, `${endpoint} rejects untrusted browser origin`);
  assert.equal(hostile.headers.get('access-control-allow-origin'), null);
  await hostile.arrayBuffer();
  rows.push({endpoint, preflight: 204, unauthenticated: 401, untrusted_origin: 403});
}
console.log(JSON.stringify({status: 'PASS', scope: 'Public read-only boundary only; no authenticated operator action or store certification', rows}, null, 2));
