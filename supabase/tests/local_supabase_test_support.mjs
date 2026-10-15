import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';

const databaseName = /^supabase_db_[A-Za-z0-9_.-]+$/;

export function selectLocalDatabase(names, expectedName) {
  if (expectedName) {
    assert.match(expectedName, databaseName, 'The selected fixture must be a Supabase database');
    assert.ok(names.includes(expectedName), 'The selected local fixture database must be running');
    return expectedName;
  }
  const candidates = names.filter((name) => databaseName.test(name));
  assert.equal(candidates.length, 1, 'Require one local database or an explicit fixture selection');
  return candidates[0];
}

export function findLocalDatabase() {
  const result = spawnSync('docker', ['ps', '--format', '{{.Names}}'], {
    encoding: 'utf8', windowsHide: true,
  });
  assert.equal(result.error, undefined, 'Docker must start');
  assert.equal(result.status, 0, 'Docker must list the isolated database');
  return selectLocalDatabase(result.stdout.split(/\r?\n/).filter(Boolean),
    process.env.BIL_LOCAL_DB_CONTAINER);
}
