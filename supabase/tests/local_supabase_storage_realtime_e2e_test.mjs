import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { findLocalDatabase } from './local_supabase_test_support.mjs';
import { removeStorageFixture, storageFixture } from './local_supabase_storage_fixture.mjs';

const baseUrl = process.env.API_URL ?? process.env.SUPABASE_URL ?? '';
const anonKey = process.env.ANON_KEY ?? process.env.SUPABASE_ANON_KEY ?? '';

function assertLocalApi() {
  const url = new URL(baseUrl);
  assert.equal(url.protocol, 'http:', 'The isolated API must use local HTTP');
  assert.ok(
    ['127.0.0.1', 'localhost', '::1'].includes(url.hostname),
    'The isolated API must resolve to loopback; remote endpoints are forbidden',
  );
  assert.ok(anonKey, 'The local anonymous key is required');
}

function executeLocalSql(container, sql) {
  const result = spawnSync(
    'docker',
    [
      'exec',
      '-i',
      container,
      'psql',
      '-U',
      'postgres',
      '-d',
      'postgres',
      '-v',
      'ON_ERROR_STOP=1',
      '-f',
      '-',
    ],
    { encoding: 'utf8', input: sql, windowsHide: true },
  );
  assert.equal(result.error, undefined, 'Local PostgreSQL command must start');
  assert.equal(
    result.status,
    0,
    'Synthetic local SQL failed: ' + result.stderr.split(/\r?\n/)
      .filter((line) => line.includes('ERROR:')).slice(0, 2).join(' ').slice(0, 500),
  );
}

async function request(path, { token, method = 'GET', body, headers = {} } = {}) {
  return fetch(new URL(path, baseUrl), {
    method,
    headers: {
      apikey: anonKey,
      ...(token ? { authorization: 'Bearer ' + token } : {}),
      ...headers,
    },
    ...(body === undefined ? {} : { body }),
    redirect: 'error',
  });
}

async function createUser() {
  const response = await request('/auth/v1/signup', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      email: 'bil-storage-rt-' + randomUUID() + '@example.invalid',
      password: randomUUID() + 'Aa9!',
    }),
  });
  assert.ok(
    response.status === 200 || response.status === 201,
    'Local Auth signup must issue a synthetic test user',
  );
  const value = await response.json();
  assert.match(value.user?.id ?? '', /^[0-9a-f-]{36}$/i);
  assert.ok(value.access_token, 'Local Auth session token is required');
  return value;
}

function timeout(promise, label, milliseconds = 15000) {
  let timer;
  const deadline = new Promise((_, reject) => {
    timer = setTimeout(
      () => reject(new Error(label + ' timed out')),
      milliseconds,
    );
  });
  return Promise.race([promise, deadline]).finally(() => clearTimeout(timer));
}

async function awaitRealtimeInsert({ table, token, rowId, ownerId }) {
  const endpoint = new URL('/realtime/v1/websocket', baseUrl);
  endpoint.protocol = endpoint.protocol === 'https:' ? 'wss:' : 'ws:';
  endpoint.searchParams.set('apikey', anonKey);
  endpoint.searchParams.set('vsn', '1.0.0');

  const topic = 'realtime:bil-ci-' + randomUUID();
  const socket = new WebSocket(endpoint.toString());
  let joinResolve;
  let joinReject;
  let readyResolve;
  let readyReject;
  let subscribedResolve;
  let subscribedReject;
  let changeResolve;
  let changeReject;
  const joined = new Promise((resolve, reject) => {
    joinResolve = resolve;
    joinReject = reject;
  });
  const replicationReady = new Promise((resolve, reject) => {
    readyResolve = resolve;
    readyReject = reject;
  });
  const postgresSubscribed = new Promise((resolve, reject) => {
    subscribedResolve = resolve;
    subscribedReject = reject;
  });
  const changed = new Promise((resolve, reject) => {
    changeResolve = resolve;
    changeReject = reject;
  });

  socket.addEventListener('message', (event) => {
    let message;
    try {
      message = JSON.parse(event.data);
    } catch (error) {
      joinReject(error);
      changeReject(error);
      return;
    }
    if (!message || message.topic !== topic) return;
    if (message.event === 'phx_reply' && message.ref === '1') {
      if (message.payload?.status === 'ok') joinResolve();
      else joinReject(new Error('Realtime subscription was rejected'));
    } else if (
      message.event === 'system' &&
      message.payload?.extension === 'system'
    ) {
      if (message.payload?.status === 'ok') readyResolve();
      else readyReject(new Error('Realtime replication did not become ready'));
    } else if (
      message.event === 'system' &&
      message.payload?.extension === 'postgres_changes'
    ) {
      if (message.payload?.status === 'ok') subscribedResolve();
      else subscribedReject(new Error('PostgreSQL change subscription failed'));
    } else if (message.event === 'phx_error' || message.event === 'phx_close') {
      const error = new Error('Realtime subscription closed before delivery');
      joinReject(error);
      readyReject(error);
      subscribedReject(error);
      changeReject(error);
    } else if (message.event === 'postgres_changes') {
      const record = message.payload?.data?.record ?? message.payload?.data?.new;
      if (record?.id === rowId && record?.owner_id === ownerId) {
        changeResolve(message);
      }
    }
  });
  socket.addEventListener('error', () => {
    const error = new Error('Local Realtime WebSocket failed');
    joinReject(error);
    readyReject(error);
    subscribedReject(error);
    changeReject(error);
  });

  try {
    await timeout(
      new Promise((resolve, reject) => {
        socket.addEventListener('open', resolve, { once: true });
        socket.addEventListener('error', reject, { once: true });
      }),
      'Local Realtime connection',
    );
    socket.send(JSON.stringify({
      topic,
      event: 'phx_join',
      payload: {
        config: {
          broadcast: { ack: false, self: false, replication_ready: true },
          presence: { enabled: false, key: '' },
          postgres_changes: [{
            event: 'INSERT',
            schema: 'public',
            table,
            filter: 'owner_id=eq.' + ownerId,
          }],
          private: false,
        },
        access_token: token,
      },
      ref: '1',
      join_ref: '1',
    }));
    await timeout(joined, 'Local Realtime channel join');
    await timeout(replicationReady, 'Local Realtime replication readiness');
    await timeout(postgresSubscribed, 'Local PostgreSQL change subscription');
    const apiResponse = await request('/rest/v1/' + table, {
      token,
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        prefer: 'return=representation',
      },
      body: JSON.stringify({
        id: rowId,
        owner_id: ownerId,
        payload: 'synthetic-realtime-event',
      }),
    });
    assert.equal(apiResponse.status, 201, 'Owner insert must commit through Data API');
    const inserted = await apiResponse.json();
    assert.equal(inserted.length, 1);
    return await timeout(changed, 'Local Realtime row delivery');
  } finally {
    socket.close();
  }
}

test('isolated Supabase Storage and Realtime enforce scoped authenticated access', async (t) => {
  assertLocalApi();
  const container = findLocalDatabase();
  const suffix = randomUUID().replaceAll('-', '');
  const fixture = storageFixture(suffix);
  const { table, bucket } = fixture;
  const cleanupKey = process.env.BIL_LOCAL_SERVICE_ROLE_KEY;
  assert.ok(cleanupKey, 'Disposable Storage cleanup key is required before fixture creation');
  const users = [];
  let fixtureCreated = false;
  let primaryError;

  try {
    executeLocalSql(container, fixture.setup);
    fixtureCreated = true;

    const owner = await createUser();
    users.push(owner.user.id);
    const other = await createUser();
    users.push(other.user.id);
    const objectPath = owner.user.id + '/nutrition-fixture.txt';

    await t.test('private Storage bucket permits only the owner path', async () => {
      const upload = await request(
        '/storage/v1/object/' + bucket + '/' + objectPath,
        {
          token: owner.access_token,
          method: 'POST',
          headers: {
            'content-type': 'text/plain',
            'x-upsert': 'false',
          },
          body: 'synthetic local nutrition attachment',
        },
      );
      assert.equal(upload.status, 200);

      const ownerRead = await request(
        '/storage/v1/object/' + bucket + '/' + objectPath,
        { token: owner.access_token },
      );
      assert.equal(ownerRead.status, 200);
      assert.equal(await ownerRead.text(), 'synthetic local nutrition attachment');

      const crossAccountRead = await request(
        '/storage/v1/object/' + bucket + '/' + objectPath,
        { token: other.access_token },
      );
      assert.notEqual(crossAccountRead.status, 200);

      const ownerPathSpoof = await request(
        '/storage/v1/object/' + bucket + '/' + owner.user.id + '/spoof.txt',
        {
          token: other.access_token,
          method: 'POST',
          headers: {
            'content-type': 'text/plain',
            'x-upsert': 'false',
          },
          body: 'must not cross account boundary',
        },
      );
      assert.notEqual(ownerPathSpoof.status, 200);

      const anonymousRead = await request(
        '/storage/v1/object/' + bucket + '/' + objectPath,
      );
      assert.notEqual(anonymousRead.status, 200);
    });

    await t.test('Realtime delivers committed owner-scoped PostgreSQL changes', async () => {
      const rowId = randomUUID();
      const event = await awaitRealtimeInsert({
        table,
        token: owner.access_token,
        rowId,
        ownerId: owner.user.id,
      });
      const record = event.payload?.data?.record ?? event.payload?.data?.new;
      assert.equal(record.id, rowId);
      assert.equal(record.owner_id, owner.user.id);
      assert.equal(record.payload, 'synthetic-realtime-event');
    });
  } catch (error) {
    primaryError = error;
    throw error;
  } finally {
    if (fixtureCreated) {
      const deleteUsers = users.length
        ? 'DELETE FROM auth.users WHERE id IN (' +
          users.map((id) => "'" + id + "'").join(',') +
          ');'
        : '';
      try {
        await removeStorageFixture(baseUrl, cleanupKey, bucket);
        executeLocalSql(container, fixture.cleanup + deleteUsers);
      } catch (cleanupError) {
        if (primaryError) throw new AggregateError([primaryError, cleanupError],
          'Preserved both fixture failure and cleanup failure');
        throw cleanupError;
      }
    }
  }
});
