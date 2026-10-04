import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

test('retired disclosure generator refuses before reading or writing files', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'bil-disclosure-refusal-'));
  const input = path.join(directory, 'missing-input.csv');
  const output = path.join(directory, 'declaration.csv');
  const script = fileURLToPath(new URL('./patch_play_data_safety_csv.mjs', import.meta.url));
  const result = spawnSync(process.execPath, [script, input, output], { encoding: 'utf8' });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /RETIRED_DATA_SAFETY_GENERATOR/);
  assert.doesNotMatch(result.stderr, /ENOENT/);
  assert.equal(result.stdout, '');
  assert.equal(fs.existsSync(input), false);
  assert.equal(fs.existsSync(output), false);
  assert.deepEqual(fs.readdirSync(directory), []);
  fs.rmdirSync(directory);
});
