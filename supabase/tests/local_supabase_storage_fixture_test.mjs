import assert from 'node:assert/strict';
import { test } from 'node:test';
import { removeStorageFixture, storageFixture } from './local_supabase_storage_fixture.mjs';

test('SQL fixture identities remain unique, bounded, and safe PostgreSQL identifiers', () => {
  const one = storageFixture('a'.repeat(32));
  const two = storageFixture('b'.repeat(32));
  assert.notEqual(one.table, two.table);
  assert.notEqual(one.bucket, two.bucket);
  assert.throws(() => storageFixture("x'; DROP TABLE auth.users;"));
  for (const match of one.setup.matchAll(/CREATE POLICY (\S+)/g)) {
    assert.match(match[1], /^[a-z_][a-z0-9_]*$/);
    assert.ok(match[1].length <= 63, 'PostgreSQL must not silently truncate policy identities');
  }
});

test('cleanup uses Storage lifecycle APIs for the exact fixture bucket', async () => {
  const calls = [];
  const bucket = storageFixture('a'.repeat(32)).bucket;
  await removeStorageFixture('http://127.0.0.1:54321', 'ephemeral-fixture-role', bucket,
    async (url, options) => { calls.push([url.toString(), options]); return { status: 200 }; });
  assert.deepEqual(calls.map(([url, options]) => [url, options.method]), [
    [`http://127.0.0.1:54321/storage/v1/bucket/${bucket}/empty`, 'POST'],
    [`http://127.0.0.1:54321/storage/v1/bucket/${bucket}`, 'DELETE'],
  ]);
  assert.ok(calls.every(([, options]) => options.redirect === 'error'));
  assert.ok(calls.every(([, options]) => options.headers['content-type'] === 'application/json'));
  assert.ok(calls.every(([, options]) => options.body === '{}'));
});

test('cleanup rejects remote services or unrelated buckets before any request', async () => {
  let requests = 0;
  const network = async () => { requests++; return { status: 200 }; };
  await assert.rejects(removeStorageFixture('https://example.invalid', 'fixture',
    storageFixture('a'.repeat(32)).bucket, network));
  await assert.rejects(removeStorageFixture('http://127.0.0.1:54321', 'fixture',
    'profile-avatars', network));
  assert.equal(requests, 0);
});
