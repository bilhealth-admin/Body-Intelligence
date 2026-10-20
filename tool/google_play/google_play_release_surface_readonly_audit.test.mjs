import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { Client, runReleaseSurfaceAudit } from './google_play_release_surface_readonly_audit.mjs';

const TOKEN = 'synthetic-access-token';
const EMAIL = 'synthetic-service-account@example.invalid';
const PRIVATE_KEY = '-----BEGIN PRIVATE KEY-----\nsynthetic-private-key\n-----END PRIVATE KEY-----';
const json = (value, status = 200) => new Response(JSON.stringify(value), { status });

async function fixture(work) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'bil-readonly-audit-'));
  const output = path.join(directory, 'google-release.json');
  const read = () => JSON.parse(fs.readFileSync(output, 'utf8'));
  try { await work({ output, read }); } finally { fs.rmSync(directory, { recursive: true, force: true }); }
}

function clientFor(handler) {
  const calls = [];
  const client = new Client(TOKEN, async (url, options) => {
    calls.push({ url, method: options.method });
    return handler(url, options);
  }, [EMAIL, PRIVATE_KEY]);
  return { client, calls };
}

function standardHandler(url, options) {
  if (options.method === 'POST') return json({ id: 'synthetic-edit', expiryTimeSeconds: '42' });
  if (options.method === 'DELETE') return new Response(null, { status: 204 });
  if (url.endsWith('/listings')) return json({ listings: [] });
  if (url.endsWith('/tracks')) return json({ tracks: [] });
  return json({});
}

test('CLI failure remains nonzero and prints only a safe structured diagnostic', () => {
  const result = spawnSync(process.execPath, [fileURLToPath(new URL('./google_play_release_surface_readonly_audit.mjs', import.meta.url))], { encoding: 'utf8' });
  assert.equal(result.status, 1);
  assert.equal(result.stdout, '');
  assert.deepEqual(JSON.parse(result.stderr), { stage: 'ARGUMENTS_REQUIRED', httpStatus: null, error: null });
});

test('403 edit insertion persists only bounded sanitized Google diagnostics and fails', async () => {
  await fixture(async ({ output, read }) => {
    const { client, calls } = clientFor(() => json({
      error: {
        code: 403, status: 'PERMISSION_DENIED',
        message: `Denied\nBearer ${TOKEN} access_token=other-secret ${EMAIL} ${PRIVATE_KEY} ${'x'.repeat(500)}`,
        details: [{ token: 'forbidden-detail' }],
      },
      headers: { Authorization: 'forbidden-header' },
    }, 403));
    await assert.rejects(runReleaseSurfaceAudit({ output, clientFactory: async () => client }), /EDIT_INSERT_FAILED:403:PERMISSION_DENIED/);
    const report = read();
    assert.equal(report.failure.stage, 'EDIT_INSERT');
    assert.equal(report.failure.httpStatus, 403);
    assert.deepEqual(Object.keys(report.failure.error).sort(), ['code', 'message', 'status']);
    assert.equal(report.failure.error.code, 403);
    assert.equal(report.failure.error.status, 'PERMISSION_DENIED');
    assert.equal(report.failure.error.message.length, 400);
    assert.equal(report.transientEdit.committed, false);
    assert.equal(calls.length, 1);
    assert.equal(calls[0].method, 'POST');
    const evidence = JSON.stringify(report);
    for (const secret of [TOKEN, EMAIL, 'synthetic-private-key', 'other-secret', 'forbidden-detail', 'forbidden-header']) {
      assert.equal(evidence.includes(secret), false, secret);
    }
  });
});

test('non-JSON 403 response persists a constant diagnostic without the raw body', async () => {
  await fixture(async ({ output, read }) => {
    const { client } = clientFor(() => new Response('<html>raw-secret-response</html>', { status: 403 }));
    await assert.rejects(runReleaseSurfaceAudit({ output, clientFactory: async () => client }));
    assert.deepEqual(read().failure.error, { code: 403, status: null, message: 'Google API returned a non-JSON response.' });
    assert.equal(JSON.stringify(read()).includes('raw-secret-response'), false);
  });
});

test('unexpected Google error field types and quoted credentials cannot enter evidence', async () => {
  await fixture(async ({ output, read }) => {
    const { client } = clientFor(() => json({ error: {
      code: { secret: 'unsafe-code' }, status: 'unsafe status with secret',
      message: 'Denied "refresh_token": "quoted-secret" assertion=assertion-secret eyJhbGciOiJSUzI1NiJ9.payload.signature',
    } }, 403));
    await assert.rejects(runReleaseSurfaceAudit({ output, clientFactory: async () => client }));
    const diagnostic = read().failure.error;
    assert.equal(diagnostic.code, 403);
    assert.equal(diagnostic.status, null);
    for (const secret of ['unsafe-code', 'unsafe status', 'quoted-secret', 'assertion-secret', 'eyJhbGciOiJSUzI1NiJ9']) {
      assert.equal(JSON.stringify(read()).includes(secret), false, secret);
    }
  });
});

test('OAuth or transport exception persists a safe failure before any edit exists', async () => {
  await fixture(async ({ output, read }) => {
    await assert.rejects(runReleaseSurfaceAudit({ output, clientFactory: async () => {
      throw new Error(`Authorization: Bearer ${TOKEN}`);
    } }), /GOOGLE_OAUTH_FAILED/);
    assert.equal(read().failure.stage, 'GOOGLE_OAUTH');
    assert.equal(JSON.stringify(read()).includes(TOKEN), false);
    assert.deepEqual(read().transientEdit, { committed: false });
  });
});

test('read exception still deletes the exact transient edit and retains the primary failure', async () => {
  await fixture(async ({ output, read }) => {
    const { client, calls } = clientFor((url, options) => {
      if (url.endsWith('/details')) throw new Error(`raw-network-secret:${TOKEN}`);
      return standardHandler(url, options);
    });
    await assert.rejects(runReleaseSurfaceAudit({ output, clientFactory: async () => client }), /EDIT_READ_FAILED/);
    assert.equal(read().failure.stage, 'EDIT_READ');
    assert.equal(read().transientEdit.deleted, true);
    assert.deepEqual(calls.filter((call) => call.method === 'DELETE'), [{
      url: 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.bilhealth.bodyintelligencelog/edits/synthetic-edit', method: 'DELETE',
    }]);
    assert.equal(JSON.stringify(read()).includes('raw-network-secret'), false);
  });
});

test('cleanup denial persists diagnostics and remains a failure', async () => {
  await fixture(async ({ output, read }) => {
    const { client } = clientFor((url, options) => options.method === 'DELETE'
      ? json({ error: { code: 403, status: 'PERMISSION_DENIED', message: 'Cleanup denied' } }, 403)
      : standardHandler(url, options));
    await assert.rejects(runReleaseSurfaceAudit({ output, clientFactory: async () => client }), /TRANSIENT_EDIT_DELETE_FAILED:403/);
    assert.equal(read().failure.stage, 'TRANSIENT_EDIT_DELETE');
    assert.equal(read().transientEdit.deleted, false);
  });
});

test('secondary cleanup exception cannot erase the primary read failure', async () => {
  await fixture(async ({ output, read }) => {
    const { client } = clientFor((url, options) => {
      if (url.endsWith('/details') || options.method === 'DELETE') throw new Error(`raw-secret:${TOKEN}`);
      return standardHandler(url, options);
    });
    await assert.rejects(runReleaseSurfaceAudit({ output, clientFactory: async () => client }), /EDIT_READ_FAILED/);
    assert.equal(read().failure.stage, 'EDIT_READ');
    assert.equal(read().cleanupFailure.stage, 'TRANSIENT_EDIT_DELETE');
    assert.equal(read().transientEdit.deleted, false);
    assert.equal(JSON.stringify(read()).includes(TOKEN), false);
  });
});

test('malformed successful read fails safely and still cleans up', async () => {
  await fixture(async ({ output, read }) => {
    const { client } = clientFor((url, options) => url.endsWith('/details')
      ? new Response('raw-malformed-secret', { status: 200 }) : standardHandler(url, options));
    await assert.rejects(runReleaseSurfaceAudit({ output, clientFactory: async () => client }), /GOOGLE_RESPONSE_JSON_FAILED/);
    assert.equal(read().transientEdit.deleted, true);
    assert.equal(JSON.stringify(read()).includes('raw-malformed-secret'), false);
  });
});

test('successful audit writes existing fields, never commits, and retains GET failure semantics', async () => {
  await fixture(async ({ output, read }) => {
    const { client, calls } = clientFor((url, options) => url.endsWith('/bundles')
      ? json({ error: { code: 404, status: 'NOT_FOUND', message: 'No bundles' } }, 404)
      : standardHandler(url, options));
    await runReleaseSurfaceAudit({ output, clientFactory: async () => client });
    const report = read();
    assert.equal(report.failure, undefined);
    assert.equal(report.bundles.ok, false);
    assert.equal(report.bundles.httpStatus, 404);
    assert.equal(report.transientEdit.deleted, true);
    assert.equal(report.transientEdit.committed, false);
    assert.equal(calls.filter((call) => call.method === 'POST').length, 1);
    assert.equal(calls.filter((call) => call.method === 'GET').length, 5);
    assert.equal(calls.some((call) => /commit|validate/.test(call.url)), false);
  });
});
