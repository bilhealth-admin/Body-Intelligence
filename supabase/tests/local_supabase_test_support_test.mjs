import assert from 'node:assert/strict';
import { test } from 'node:test';
import { selectLocalDatabase } from './local_supabase_test_support.mjs';

test('the actual GitHub repository project name selects its running database', () => {
  assert.equal(selectLocalDatabase(['supabase_db_Body-Intelligence', 'supabase_auth_Body-Intelligence'],
    'supabase_db_Body-Intelligence'), 'supabase_db_Body-Intelligence');
});

test('a single lowercase fixture works without an environment override', () => {
  assert.equal(selectLocalDatabase(['supabase_db_bil_ci', 'supabase_auth_bil_ci']),
    'supabase_db_bil_ci');
});

test('ambiguous databases require explicit selection instead of picking the first', () => {
  assert.throws(() => selectLocalDatabase(['supabase_db_a', 'supabase_db_b']));
  assert.equal(selectLocalDatabase(['supabase_db_a', 'supabase_db_b'], 'supabase_db_b'),
    'supabase_db_b');
});

test('missing containers fail before any fixture mutation', () => {
  assert.throws(() => selectLocalDatabase([]));
  assert.throws(() => selectLocalDatabase(['supabase_db_other'], 'supabase_db_required'));
});

test('invalid or unrelated Docker names are never accepted as fixture databases', () => {
  for (const name of ['production-postgres', '--privileged', 'supabase_db_x;echo', 'supabase_db_']) {
    assert.throws(() => selectLocalDatabase([name], name));
  }
});
