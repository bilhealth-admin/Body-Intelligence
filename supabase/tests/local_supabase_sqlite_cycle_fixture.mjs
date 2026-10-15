import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { findLocalDatabase } from './local_supabase_test_support.mjs';

const [mode, configFile] = process.argv.slice(2);
assert.ok(configFile, 'A private fixture path is required');
const url = new URL(process.env.API_URL ?? '');
assert.equal(url.protocol, 'http:');
assert.equal(url.hostname, '127.0.0.1', 'Hosted projects are forbidden');
const container = findLocalDatabase();

if (mode === 'prepare') {
  assert.equal(fs.existsSync(configFile), false, 'Never replace an existing fixture');
  const anonKey = process.env.ANON_KEY;
  assert.ok(anonKey, 'A local anonymous key is required');
  const email = `bil-sqlite-cycle-${randomUUID()}@example.invalid`;
  const response = await fetch(new URL('/auth/v1/signup', url), {
    method: 'POST', redirect: 'error', signal: AbortSignal.timeout(30000),
    headers: { apikey: anonKey, 'content-type': 'application/json' },
    body: JSON.stringify({ email, password: `${randomUUID()}Aa9!` }),
  });
  assert.ok(response.status === 200 || response.status === 201,
    `Synthetic Auth signup returned HTTP ${response.status}`);
  const session = await response.json();
  assert.match(session.user?.id ?? '', /^[0-9a-f-]{36}$/i);
  assert.ok(session.access_token && session.refresh_token);
  fs.mkdirSync(path.dirname(configFile), { recursive: true });
  fs.writeFileSync(configFile, JSON.stringify({
    mode: 'supabase_local', url: url.toString(), anon_key: anonKey,
    owner_a: session.user.id, email, auth_session: session,
  }), { flag: 'wx', mode: 0o600 });
  console.log('Prepared one synthetic signed Auth session; credentials remain private.');
} else if (mode === 'cleanup') {
  const config = JSON.parse(fs.readFileSync(configFile, 'utf8'));
  assert.equal(config.mode, 'supabase_local');
  assert.match(config.owner_a, /^[0-9a-f-]{36}$/i);
  assert.match(config.email, /^bil-sqlite-cycle-[0-9a-f-]{36}@example\.invalid$/);
  const result = spawnSync('docker', [
    'exec', '-i', container, 'psql', '-X', '-v', 'ON_ERROR_STOP=1',
    '-U', 'postgres', '-d', 'postgres', '-f', '-',
  ], { encoding: 'utf8', windowsHide: true,
    input: `DELETE FROM auth.users WHERE id='${config.owner_a}' AND email='${config.email}';` });
  assert.equal(result.status, 0, 'Delete only the exact synthetic cycle identity');
  fs.unlinkSync(configFile);
  console.log('Removed the synthetic cycle identity and private session fixture.');
} else {
  throw new Error('Use prepare or cleanup');
}
