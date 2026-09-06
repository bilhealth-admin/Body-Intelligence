import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'bil-ios-plus8-runtime-'));
process.env.BIL_QA_STATE_PATH = path.join(temporary, 'state.json');
process.env.BIL_EVIDENCE_DIR = path.join(temporary, 'evidence');

let captured;
const originalFetch = globalThis.fetch;
globalThis.fetch = async (url, options) => {
  captured = { url: String(url), options };
  return {
    status: 200,
    text: async () => '{"ok":true}',
  };
};

try {
  const runtime = await import('./ios_plus8_canary/runtime.mjs');
  const result = await runtime.request({ route: '/rest/v1/runtime_probe' });
  assert.equal(result.status, 200);
  assert.deepEqual(result.data, { ok: true });
  assert.equal(captured.options.headers.apikey, runtime.supabaseConfig.anon);
  assert.ok(captured.options.headers.apikey.startsWith('sb_publishable_'));
  assert.equal(
    captured.url,
    `${runtime.supabaseConfig.url}/rest/v1/runtime_probe`,
  );
  process.stdout.write('IOS_PLUS8_CANARY_RUNTIME_FETCH_INJECTION=PASS\n');

  process.env.BIL_SUPABASE_SERVICE_ROLE_KEY = 'local-scope-probe-only';
  const serviceRuntime = await import('./ios_plus8_canary/service_runtime.mjs');
  let paginationCalls = 0;
  globalThis.fetch = async () => {
    paginationCalls += 1;
    return {
      status: 200,
      text: async () => JSON.stringify({ users: Array(1000).fill({}) }),
    };
  };
  await assert.rejects(
    serviceRuntime.adminUsersByEmail('absent@example.invalid'),
    /admin_user_scan_page_cap_reached/,
  );
  assert.equal(paginationCalls, 20);
  process.stdout.write('IOS_PLUS8_ADMIN_USER_SCAN_CAP_FAIL_CLOSED=PASS\n');
} finally {
  delete process.env.BIL_SUPABASE_SERVICE_ROLE_KEY;
  globalThis.fetch = originalFetch;
  fs.rmSync(temporary, { recursive: true, force: true });
}
