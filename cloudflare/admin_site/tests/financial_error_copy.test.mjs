import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {runInNewContext} from 'node:vm';
const source=readFileSync(new URL('../site/app.mjs',import.meta.url),'utf8');
const match=source.match(/function explainBackendError\(code,scope\)\{[\s\S]*?\n\}/);
assert.ok(match);
const explain=runInNewContext(match[0]+';explainBackendError',{tr:key=>key});
test('financial cooldown and consumed MFA have precise guidance without weakening server protection',()=>{
  assert.equal(explain('financial_cooldown_active','finance'),'financialCooldown');
  assert.equal(explain('fresh_step_up_already_used','finance'),'freshCodeRequired');
  assert.equal(explain('fresh_mfa_required','finance'),'freshCodeRequired');
  assert.equal(explain('financial_writes_locked','finance'),'protectedWriteLocked');
  assert.match(source,/two-minute protection period/);
});
test('conflicting grants and receipts explain the required review while unknown provider errors remain private',()=>{
  assert.equal(explain('existing_grant_conflict','finance'),'existingGrantConflict');
  assert.equal(explain('idempotency_conflict','finance'),'commandConflict');
  assert.equal(explain('reconciliation_mismatch','finance'),'commandConflict');
  assert.equal(explain('private SQL error: account@example.invalid','finance'),'unknownError');
});
