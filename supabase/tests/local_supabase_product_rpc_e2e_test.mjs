import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createCipheriv, createDecipheriv, randomBytes, randomUUID } from 'node:crypto';
import { test } from 'node:test';

// Deliberately refuses hosted endpoints. SQL is only fixture setup/cleanup;
// every behavior assertion below goes through real Auth and PostgREST RPCs.
const baseUrl = process.env.API_URL ?? process.env.SUPABASE_URL ?? '';
const anonKey = process.env.ANON_KEY ?? process.env.SUPABASE_ANON_KEY ?? '';

function localDatabase() {
  const url = new URL(baseUrl);
  assert.equal(url.protocol, 'http:');
  assert.ok(['127.0.0.1', 'localhost', '[::1]'].includes(url.hostname));
  assert.ok(anonKey, 'The disposable local anonymous key is required');
  const containers = spawnSync('docker', ['ps', '--format', '{{.Names}}'], {
    encoding: 'utf8', windowsHide: true,
  });
  assert.equal(containers.status, 0, 'Local Docker must be running');
  const container = containers.stdout.split(/\r?\n/)
    .find((name) => /^supabase_db_[a-z0-9_-]+$/.test(name));
  assert.ok(container, 'A disposable Supabase database is required');
  return container;
}

function sql(container, statement) {
  const result = spawnSync('docker', [
    'exec', '-i', container, 'psql', '-X', '-v', 'ON_ERROR_STOP=1',
    '-U', 'postgres', '-d', 'postgres', '-f', '-',
  ], { input: statement, encoding: 'utf8', windowsHide: true });
  assert.equal(result.error, undefined, 'Fixture SQL must start');
  assert.equal(result.status, 0, 'Fixture setup/cleanup SQL must succeed');
}

async function request(path, token, body) {
  return fetch(new URL(path, baseUrl), {
    method: 'POST', redirect: 'error', signal: AbortSignal.timeout(30000),
    headers: {
      apikey: anonKey, 'content-type': 'application/json',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body),
  });
}

async function user() {
  const response = await request('/auth/v1/signup', undefined, {
    email: `bil-product-ci-${randomUUID()}@example.invalid`,
    password: `${randomUUID()}Aa9!`,
  });
  assert.ok(response.status === 200 || response.status === 201,
    `Synthetic signup returned HTTP ${response.status}`);
  const session = await response.json();
  assert.match(session.user?.id ?? '', /^[0-9a-f-]{36}$/i);
  assert.ok(session.access_token, 'Auth must issue a signed session');
  return session;
}

async function rpc(name, session, body = {}, expected = 200) {
  const response = await request(`/rest/v1/rpc/${name}`, session?.access_token, body);
  assert.equal(response.status, expected, `${name}: HTTP ${response.status}`);
  const content = await response.text();
  return content ? JSON.parse(content) : null;
}

function eraseUsers(container, sessions) {
  if (sessions.length) {
    sql(container, `DELETE FROM auth.users WHERE id IN (${
      sessions.map((session) => `'${session.user.id}'`).join(',')});`);
  }
}

test('BIL AI report RPC: signed users, consent, moderator, retry and revocation', async (t) => {
  const container = localDatabase();
  const sessions = [];
  try {
    const owner = await user(); sessions.push(owner);
    const moderator = await user(); sessions.push(moderator);
    const stranger = await user(); sessions.push(stranger);
    sql(container, `INSERT INTO public.bil_community_moderators(user_id)
      VALUES ('${moderator.user.id}');`);
    const submission = {
      p_response_id: `local-rpc-${randomUUID()}`,
      p_answer_text: 'Synthetic answer selected for safety review only.',
      p_reason: 'other', p_locale: 'ar', p_runtime: 'on_device',
      p_user_note: 'Synthetic report note.', p_consent_confirmed: true,
    };
    await t.test('missing consent and unknown cloud answers are rejected', async () => {
      const refused = await rpc('bil_submit_ai_coach_safety_report_v1', owner,
        { ...submission, p_consent_confirmed: false }, 400);
      assert.equal(refused.code, '22023');
      const unknown = await rpc('bil_submit_ai_coach_safety_report_v1', owner,
        { ...submission, p_runtime: 'cloud_personalized' }, 403);
      assert.equal(unknown.code, '42501');
    });
    const receipts = await Promise.all([0, 1].map(() =>
      rpc('bil_submit_ai_coach_safety_report_v1', owner, submission)));
    const reportId = receipts[0].report_id;
    await t.test('concurrent retries return one report without replacing it', () => {
      assert.match(reportId, /^[0-9a-f-]{36}$/i);
      assert.equal(receipts[1].report_id, reportId);
      assert.deepEqual(receipts.map((receipt) => receipt.duplicate).sort(), [false, true]);
    });
    await t.test('ordinary signed users cannot list or review reports', async () => {
      for (const session of [owner, stranger]) {
        const denied = await rpc('bil_list_ai_coach_safety_reports_v1', session, {}, 403);
        assert.equal(denied.code, '42501');
        await rpc('bil_review_ai_coach_safety_report_v1', session, {
          p_report_id: reportId, p_decision: 'no_violation', p_operation_id: randomUUID(),
        }, 403);
      }
    });
    await t.test('authorized queue exposes only the selected answer and review metadata', async () => {
      const queue = await rpc('bil_list_ai_coach_safety_reports_v1', moderator);
      const item = queue.find((entry) => entry.report_id === reportId);
      assert.ok(item, 'The committed report must reach the real review queue');
      assert.equal(item.answer_text, submission.p_answer_text);
      assert.equal(item.user_note, submission.p_user_note);
      for (const key of ['owner_id', 'prompt', 'conversation', 'profile']) {
        assert.equal(Object.hasOwn(item, key), false, `Queue must omit ${key}`);
      }
    });
    await t.test('review retry is idempotent and erases answer and optional note', async () => {
      const review = {
        p_report_id: reportId, p_decision: 'confirmed_safety_issue',
        p_operation_id: randomUUID(),
      };
      const first = await rpc('bil_review_ai_coach_safety_report_v1', moderator, review);
      const retry = await rpc('bil_review_ai_coach_safety_report_v1', moderator, review);
      assert.equal(first.status, 'reviewed');
      assert.equal(retry.duplicate, true);
      const queue = await rpc('bil_list_ai_coach_safety_reports_v1', moderator);
      const item = queue.find((entry) => entry.report_id === reportId);
      assert.equal(item?.decision, 'confirmed_safety_issue');
      assert.equal(item?.answer_text, null);
      assert.equal(item?.user_note, null);
    });
    await t.test('revoking the fixture moderator blocks the existing signed session', async () => {
      sql(container, `DELETE FROM public.bil_community_moderators
        WHERE user_id='${moderator.user.id}';`);
      await rpc('bil_list_ai_coach_safety_reports_v1', moderator, {}, 403);
    });
  } finally {
    eraseUsers(container, sessions);
  }
});

function seal(value, key) {
  const nonce = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', key, nonce);
  const ciphertext = Buffer.concat([
    cipher.update(JSON.stringify(value), 'utf8'), cipher.final(), cipher.getAuthTag(),
  ]);
  return { _bil_cipher_v: 1, alg: 'A256GCM',
    nonce: nonce.toString('base64url'), ciphertext: ciphertext.toString('base64url') };
}

function open(payload, key) {
  const bytes = Buffer.from(payload.ciphertext, 'base64url');
  const decipher = createDecipheriv('aes-256-gcm', key, Buffer.from(payload.nonce, 'base64url'));
  decipher.setAuthTag(bytes.subarray(-16));
  return JSON.parse(Buffer.concat([
    decipher.update(bytes.subarray(0, -16)), decipher.final(),
  ]).toString('utf8'));
}

test('BIL restore V2 RPC: encrypted two-device CAS, pagination, tombstones and isolation', async (t) => {
  const container = localDatabase();
  const sessions = [];
  try {
    const owner = await user(); sessions.push(owner);
    const other = await user(); sessions.push(other);
    const deviceA = `ci-device-a-${randomUUID()}`;
    const deviceB = `ci-device-b-${randomUUID()}`;
    const key = randomBytes(32);
    const snapshot = { name: 'Synthetic partial meal', fraction: 0.375,
      nutrients: { fiberG: null, sugarG: 0, sodiumMg: 57.125 } };
    const operation = {
      operation_id: randomUUID(), record_type: 'meal', record_id: randomUUID(),
      expected_revision: 0, mutation: 'upsert', payload_version: 2,
      payload: seal(snapshot, key),
    };
    const sync = (session, device, operations = [], cursor = 0, expected = 200,
      scope = 'nutrition') =>
      rpc('bil_sync_records_v2', session, {
        p_device_id: device, p_scope: scope, p_operations: operations,
        p_cursor: cursor, p_limit: 1,
      }, expected);
    const consent = async (session) => {
      await rpc('bil_record_consent', session, {
        p_purpose: 'cloud_sync', p_policy_version: '1', p_granted: true,
      }, 204);
      await rpc('bil_record_cloud_restore_consent_v2', session, {
        p_scope: 'nutrition', p_granted: true, p_policy_version: '1',
      });
    };
    await t.test('old base consent alone does not silently enable nutrition', async () => {
      await rpc('bil_record_consent', owner, {
        p_purpose: 'cloud_sync', p_policy_version: '1', p_granted: true,
      }, 204);
      const denied = await sync(owner, deviceA, [operation], 0, 403);
      assert.equal(denied.message, 'cloud_restore_scope_consent_required');
    });
    await consent(owner);
    await consent(other);
    const uploaded = await sync(owner, deviceA, [operation]);
    const revision = uploaded.receipts[0].server_revision;
    assert.equal(uploaded.receipts[0].outcome, 'accepted');
    await t.test('a different device restores exact encrypted values, null and zero', async () => {
      const downloaded = await sync(owner, deviceB);
      assert.equal(downloaded.records.length, 1);
      assert.equal(downloaded.records[0].record_id, operation.record_id);
      assert.deepEqual(open(downloaded.records[0].payload, key), snapshot);
      assert.throws(() => open(downloaded.records[0].payload, randomBytes(32)));
      const tampered = { ...downloaded.records[0].payload };
      const bytes = Buffer.from(tampered.ciphertext, 'base64url'); bytes[0] ^= 1;
      tampered.ciphertext = bytes.toString('base64url');
      assert.throws(() => open(tampered, key));
    });
    await t.test('retry does not duplicate, another account cannot read the record', async () => {
      const retry = await sync(owner, deviceA, [operation]);
      assert.equal(retry.receipts[0].replayed, true);
      assert.equal(retry.records.length, 1);
      assert.deepEqual((await sync(other, deviceB)).records, []);
    });
    await t.test('server revision resolves competing updates without device clocks', async () => {
      const updateA = { ...operation, operation_id: randomUUID(), expected_revision: revision,
        payload: seal({ ...snapshot, fraction: 0.5 }, key) };
      const updateB = { ...operation, operation_id: randomUUID(), expected_revision: revision,
        payload: seal({ ...snapshot, fraction: 0.75 }, key) };
      const results = await Promise.all([
        sync(owner, deviceA, [updateA]), sync(owner, deviceB, [updateB]),
      ]);
      assert.deepEqual(results.map((value) => value.receipts[0].outcome).sort(),
        ['accepted', 'conflict']);
    });
    await t.test('different records paginate without loss', async () => {
      const second = { ...operation, operation_id: randomUUID(), record_id: randomUUID() };
      const firstPage = await sync(owner, deviceA, [second]);
      assert.equal(firstPage.records.length, 1);
      assert.equal(firstPage.has_more, true);
      const secondPage = await sync(owner, deviceB, [], firstPage.cursor);
      assert.equal(secondPage.records.length, 1);
      assert.equal(secondPage.has_more, false);
      assert.notEqual(firstPage.records[0].record_id, secondPage.records[0].record_id);
    });
    await t.test('late upsert cannot resurrect a deleted record even with its revision', async () => {
      const deleted = { ...operation, operation_id: randomUUID(),
        expected_revision: revision + 1, mutation: 'delete' };
      const receipt = (await sync(owner, deviceA, [deleted])).receipts[0];
      assert.equal(receipt.outcome, 'accepted');
      const late = { ...operation, operation_id: randomUUID(),
        expected_revision: receipt.server_revision };
      const conflict = (await sync(owner, deviceB, [late])).receipts[0];
      assert.equal(conflict.outcome, 'conflict');
      assert.equal(conflict.current_record.deleted, true);
    });
    await t.test('goal values and locks transfer atomically under separate explicit consent', async () => {
      const goalsA = { calories: 1800, carbsG: 210, proteinG: 120, fatG: 53.333333,
        locks: { carbs: false, protein: true, fat: false },
        source: 'synthetic_custom_goal', referenceVersion: 'ci-reference-v1' };
      const goalsB = { ...goalsA, calories: 1900, carbsG: 235,
        locks: { carbs: true, protein: false, fat: false } };
      const goalOperation = { ...operation, operation_id: randomUUID(), record_type: 'goals',
        record_id: 'nutrition-goals', payload: seal(goalsA, key) };
      const denied = await sync(owner, deviceB, [goalOperation], 0, 403, 'goals');
      assert.equal(denied.message, 'cloud_restore_scope_consent_required');
      await rpc('bil_record_cloud_restore_consent_v2', owner, {
        p_scope: 'goals', p_granted: true, p_policy_version: '1',
      });
      const initial = await sync(owner, deviceA, [goalOperation], 0, 200, 'goals');
      assert.equal(initial.receipts[0].outcome, 'accepted');
      const updates = await Promise.all([
        sync(owner, deviceA, [{ ...goalOperation, operation_id: randomUUID(),
          expected_revision: 1, payload: seal(goalsA, key) }], 0, 200, 'goals'),
        sync(owner, deviceB, [{ ...goalOperation, operation_id: randomUUID(),
          expected_revision: 1, payload: seal(goalsB, key) }], 0, 200, 'goals'),
      ]);
      assert.deepEqual(updates.map((value) => value.receipts[0].outcome).sort(),
        ['accepted', 'conflict']);
      const pulled = await sync(owner, deviceB, [], 0, 200, 'goals');
      const winner = open(pulled.records[0].payload, key);
      assert.ok([JSON.stringify(goalsA), JSON.stringify(goalsB)].includes(JSON.stringify(winner)),
        'The server must preserve one whole goal/lock version, without mixing fields');
    });
    await t.test('device revocation and scope withdrawal block existing sessions', async () => {
      await rpc('bil_revoke_cloud_restore_device_v2', owner, { p_device_id: deviceA }, 204);
      assert.equal((await sync(owner, deviceA, [], 0, 403)).message, 'device_revoked');
      await rpc('bil_record_cloud_restore_consent_v2', owner, {
        p_scope: 'nutrition', p_granted: false, p_policy_version: '1',
      });
      assert.equal((await sync(owner, deviceB, [], 0, 403)).message,
        'cloud_restore_scope_consent_required');
      assert.equal((await sync(owner, deviceB, [], 0, 200, 'goals')).records.length, 1,
        'Withdrawing nutrition must not silently withdraw an independent goal consent');
    });
  } finally {
    eraseUsers(container, sessions);
  }
});
