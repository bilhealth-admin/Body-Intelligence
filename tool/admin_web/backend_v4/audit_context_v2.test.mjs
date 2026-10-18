import {test} from 'node:test';
import assert from 'node:assert/strict';
import {safeAuditPage,WebAdminError} from './policy.mjs';
const id='11111111-1111-4111-8111-111111111111';
const base={id,actor_id:id,operation:'grant',created_at:'2026-10-18T03:00:00Z',matched:true,changed:true,grant_id:id};
test('audit includes only scope-checked extra fields',()=>{
 const row=safeAuditPage({has_more:false,rows:[{...base,recipient_email:'masked@example.invalid',actor_email:'admin@example.invalid',plan_id:'premium',grant_expires_at:'2026-12-18',grant_reason:'Account support'}]}).rows[0];
 assert.equal(row.recipient_email,'masked@example.invalid');
 assert.equal(row.actor_email,'admin@example.invalid');
 assert.equal(row.plan_id,'premium');
 assert.equal(row.grant_reason,'Account support');
});
test('legacy response remains valid',()=>{
 const row=safeAuditPage({has_more:false,rows:[base]}).rows[0];
 assert.equal(row.grant_id,id);assert.equal(row.recipient_email,null);
});
test('invalid plans and oversized text fail closed',()=>{
 for(const extra of [{plan_id:'unlimited'},{recipient_email:'x'.repeat(255)},{grant_reason:'a'.repeat(190)}]){
  assert.throws(()=>safeAuditPage({has_more:false,rows:[{...base,...extra}]}),WebAdminError);
 }
});
test('invalid command or unmatched receipt rejected',()=>{
 assert.throws(()=>safeAuditPage({has_more:false,rows:[{...base,operation:'other'}]}),WebAdminError);
 assert.throws(()=>safeAuditPage({has_more:false,rows:[{...base,grant_id:null}]}),WebAdminError);
});
