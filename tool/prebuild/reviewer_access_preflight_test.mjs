import assert from 'node:assert/strict';
import test from 'node:test';
import {summarizeAccess} from './reviewer_access_preflight.mjs';
const now=Date.parse('2026-10-04T07:20:00Z');
const sub={plan_id:'premium',lifecycle:'active',provider:'apple',verified_at:new Date(now-1000).toISOString(),started_at:new Date(now-10000).toISOString(),expires_at:new Date(now+60000).toISOString()};
const input={owner:'synthetic',subscription:sub,usage:{credits:{total_remaining:25}}};
test('valid store state and cancelled access before expiry remain eligible',()=>{
  assert.equal(summarizeAccess(input,now).storeSubscriptionVerifiedAndActive,true);
  assert.equal(summarizeAccess({...input,subscription:{...sub,lifecycle:'cancelled'}},now).storeSubscriptionVerifiedAndActive,true);
});
test('terminal and unpaid states cannot unlock Premium',()=>{
  for(const lifecycle of ['expired','pending','account_hold','revoked','refunded','billing_retry','paused']) assert.equal(summarizeAccess({...input,subscription:{...sub,lifecycle}},now).premiumAccessCandidate,false);
});
test('credits require a positive finite number',()=>{
  for(const credit of ['25',NaN,Infinity,-1,0,null]) assert.equal(summarizeAccess({...input,usage:{credits:{total_remaining:credit}}},now).aiCreditsPositive,false);
  assert.equal(summarizeAccess(input,now).aiCreditsPositive,true);
});
test('expiry and unknown provider fail closed',()=>{
  assert.equal(summarizeAccess({...input,subscription:{...sub,expires_at:new Date(now).toISOString()}},now).premiumAccessCandidate,false);
  assert.equal(summarizeAccess({...input,subscription:{...sub,provider:'client'}},now).premiumAccessCandidate,false);
});
test('administrative leases are owner scoped and bounded',()=>{
  const grant={owner_id:'synthetic',plan_id:'premium_ai_coach',created_at:new Date(now-10000).toISOString(),access_until:new Date(now+300000).toISOString(),expires_at:null};
  assert.equal(summarizeAccess({owner:'synthetic',grant},now).administrativeLeaseValid,true);
  assert.equal(summarizeAccess({owner:'other',grant},now).administrativeLeaseValid,false);
  assert.equal(summarizeAccess({owner:'synthetic',grant:{...grant,access_until:new Date(now+360001).toISOString()}},now).administrativeLeaseValid,false);
});
test('closed testing grants must still be active',()=>{
  assert.equal(summarizeAccess({owner:'synthetic',closedTest:{active:true,expires_at:new Date(now+10000).toISOString()}},now).closedTestGrantActive,true);
  assert.equal(summarizeAccess({owner:'synthetic',closedTest:{active:true,expires_at:new Date(now).toISOString()}},now).closedTestGrantActive,false);
});
