import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {runInNewContext} from 'node:vm';
const source=readFileSync(new URL('../site/app.mjs',import.meta.url),'utf8');
const match=source.match(/function revokeAvailability\(status,canWrite\)\{[\s\S]*?\n\}/);
assert.ok(match,'Actual grant availability decision is required');
const availability=runInNewContext(match[0]+';revokeAvailability');
test('active grants stay enabled while revoked and expired grants explain their actual state',()=>{
  for(const [status,disabled,titleKey] of [
    ['active',false,'revoke'],['revoked',true,'grantAlreadyRevoked'],
    ['expired',true,'grantAlreadyExpired'],['pending',true,'grantNotActive'],
    [undefined,true,'grantNotActive'],
  ]){
    const result=availability(status,true);
    assert.equal(result.disabled,disabled,String(status));
    assert.equal(result.titleKey,titleKey,String(status));
    assert.notEqual(result.titleKey,'protectedWriteLocked');
  }
  assert.match(source,/revokeAvailability\(row\.status,state\.finance\?\.financial_writes_enabled===true\)/);
});
test('a genuine server write lock keeps every grant state unavailable',()=>{
  for(const status of ['active','revoked','expired',undefined]){
    const result=availability(status,false);
    assert.equal(result.disabled,true);
    assert.equal(result.titleKey,'protectedWriteLocked');
  }
});
