import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';

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
    `Local PostgreSQL fixture failed with exit ${result.status}`,
  );
}

function findDatabaseContainer() {
  const result = spawnSync(
    'docker',
    ['ps', '--format', '{{.Names}}'],
    { encoding: 'utf8', windowsHide: true },
  );
  assert.equal(result.status, 0, 'Docker must list the isolated database');
  const container = result.stdout
    .split(/\r?\n/)
    .find((name) => /^supabase_db_[a-z0-9_-]+$/.test(name));
  assert.ok(container, 'The local Supabase PostgreSQL container must be running');
  return container;
}

async function api(path, { token, method = 'GET', body, prefer } = {}) {
  const response = await fetch(new URL(path, baseUrl), {
    method,
    headers: {
      apikey: anonKey,
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...(body ? { 'content-type': 'application/json' } : {}),
      ...(prefer ? { prefer } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
    redirect: 'error',
  });
  return response;
}

async function createUser(label) {
  const response = await fetch(new URL('/auth/v1/signup', baseUrl), {
    method: 'POST',
    headers: {
      apikey: anonKey,
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      email: `bil-ci-${label}-${randomUUID()}@example.invalid`,
      password: `${randomUUID()}Aa9!`,
    }),
    redirect: 'error',
  });
  assert.ok(
    response.status === 200 || response.status === 201,
    `Local Auth signup returned HTTP ${response.status}`,
  );
  const result = await response.json();
  assert.match(result.user?.id ?? '', /^[0-9a-f-]{36}$/i);
  assert.ok(result.access_token, 'Local Auth must issue a session token');
  assert.ok(result.refresh_token, 'Local Auth must issue a refresh token');
  return result;
}

test('isolated Supabase Auth sessions enforce owner-scoped PostgREST RLS', async (t) => {
  assertLocalApi();
  const container = findDatabaseContainer();
  const suffix = randomUUID().replaceAll('-', '');
  const table = `bil_ci_owner_${suffix}`;
  const users = [];
  let fixtureCreated = false;

  try {
    executeLocalSql(
      container,
      `CREATE TABLE public.${table} (
         id uuid PRIMARY KEY,
         owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
         payload text NOT NULL
       );
       ALTER TABLE public.${table} ENABLE ROW LEVEL SECURITY;
       CREATE POLICY ${table}_select ON public.${table}
         FOR SELECT TO authenticated USING (owner_id = auth.uid());
       CREATE POLICY ${table}_insert ON public.${table}
         FOR INSERT TO authenticated WITH CHECK (owner_id = auth.uid());
       CREATE POLICY ${table}_update ON public.${table}
         FOR UPDATE TO authenticated
         USING (owner_id = auth.uid()) WITH CHECK (owner_id = auth.uid());
       GRANT SELECT, INSERT, UPDATE ON public.${table} TO authenticated;`,
    );
    fixtureCreated = true;

    const owner = await createUser('owner');
    users.push(owner.user.id);
    const other = await createUser('other');
    users.push(other.user.id);

    await t.test('issued sessions resolve to their own authenticated identity', async () => {
      for (const session of [owner, other]) {
        const response = await api('/auth/v1/user', { token: session.access_token });
        assert.equal(response.status, 200);
        assert.equal((await response.json()).id, session.user.id);
      }
    });

    const rowId = randomUUID();
    await t.test('owner can create and read their own row', async () => {
      const inserted = await api(`/rest/v1/${table}`, {
        token: owner.access_token,
        method: 'POST',
        prefer: 'return=representation',
        body: { id: rowId, owner_id: owner.user.id, payload: 'synthetic-owner-data' },
      });
      assert.equal(inserted.status, 201);
      const rows = await inserted.json();
      assert.equal(rows.length, 1);
      assert.equal(rows[0].owner_id, owner.user.id);

      const readback = await api(
        `/rest/v1/${table}?id=eq.${rowId}&select=id,owner_id,payload`,
        { token: owner.access_token },
      );
      assert.equal(readback.status, 200);
      assert.equal((await readback.json()).length, 1);
    });

    await t.test('another account and anonymous caller cannot read the row', async () => {
      const path = `/rest/v1/${table}?id=eq.${rowId}&select=id,owner_id`;
      const otherRead = await api(path, { token: other.access_token });
      assert.equal(otherRead.status, 200);
      assert.deepEqual(await otherRead.json(), []);

      const anonymousRead = await api(path);
      assert.ok(anonymousRead.status === 200 || anonymousRead.status === 401);
      if (anonymousRead.status === 200) {
        assert.deepEqual(await anonymousRead.json(), []);
      }
    });

    await t.test('updates remain owner-scoped', async () => {
      const path = `/rest/v1/${table}?id=eq.${rowId}`;
      const ownerUpdate = await api(path, {
        token: owner.access_token,
        method: 'PATCH',
        prefer: 'return=representation',
        body: { payload: 'updated-by-owner' },
      });
      assert.equal(ownerUpdate.status, 200);
      assert.equal((await ownerUpdate.json()).length, 1);

      const otherUpdate = await api(path, {
        token: other.access_token,
        method: 'PATCH',
        prefer: 'return=representation',
        body: { payload: 'cross-account-write-must-not-land' },
      });
      assert.equal(otherUpdate.status, 200);
      assert.deepEqual(await otherUpdate.json(), []);
    });

    await t.test('owner spoofing and invalid JWTs fail closed', async () => {
      const spoof = await api(`/rest/v1/${table}`, {
        token: owner.access_token,
        method: 'POST',
        prefer: 'return=representation',
        body: {
          id: randomUUID(),
          owner_id: other.user.id,
          payload: 'must-be-rejected',
        },
      });
      assert.ok(spoof.status === 401 || spoof.status === 403);

      const invalid = await api(`/rest/v1/${table}?select=id`, {
        token: 'not-a-signed-jwt',
      });
      assert.ok(invalid.status === 401 || invalid.status === 403);
    });

    await t.test('refresh rotates a real local Auth session without changing owner', async () => {
      const response = await fetch(
        new URL('/auth/v1/token?grant_type=refresh_token', baseUrl),
        {
          method: 'POST',
          headers: { apikey: anonKey, 'content-type': 'application/json' },
          body: JSON.stringify({ refresh_token: owner.refresh_token }),
          redirect: 'error',
        },
      );
      assert.equal(response.status, 200);
      const refreshed = await response.json();
      assert.equal(refreshed.user?.id, owner.user.id);
      assert.ok(refreshed.access_token);
      const identity = await api('/auth/v1/user', { token: refreshed.access_token });
      assert.equal(identity.status, 200);
      assert.equal((await identity.json()).id, owner.user.id);
    });
  } finally {
    const deleteUsers = users.length
      ? `DELETE FROM auth.users WHERE id IN (${users.map((id) => `'${id}'`).join(',')});`
      : '';
    if (fixtureCreated || users.length) {
      executeLocalSql(
        container,
        `${fixtureCreated ? `DROP TABLE IF EXISTS public.${table} CASCADE;` : ''}
         ${deleteUsers}`,
      );
    }
  }
});
