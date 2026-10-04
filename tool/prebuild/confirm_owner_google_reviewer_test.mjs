import assert from 'node:assert/strict';
import test from 'node:test';
import {confirmReviewer,validateReviewerTarget} from './confirm_owner_google_reviewer.mjs';
const id='c1b11121-18eb-444c-aaea-b78e05bdfcc9';
const email='google-play-review-20261004@bilhealth.com';
const acknowledgement='OWNER_APPROVED_GOOGLE_REVIEWER_CONFIRMATION';
test('owner acknowledgment and dedicated namespace mandatory',()=>{
 for(const input of [{id,email,acknowledgement:''},{id:'not-uuid',email,acknowledgement},{id,email:'apple@bilhealth.com',acknowledgement}]) assert.throws(()=>validateReviewerTarget(input.id,input.email,input.acknowledgement));
});
test('confirmation performs only bounded idempotent admin email-confirm and readback',async()=>{
 const calls=[];let confirmed=false;
 const result=await confirmReviewer({id,email,acknowledgement,key:'server-only-fixture-key-that-is-not-real',fetcher:async(url,options)=>{
  calls.push({url,method:options.method,body:options.body});
  if(options.method==='PUT'){assert.deepEqual(JSON.parse(options.body),{email_confirm:true});confirmed=true;}
  return new Response(JSON.stringify({id,email,email_confirmed_at:confirmed?'2026-10-04T07:00:00Z':null}),{status:200});
 }});
 assert.deepEqual(calls.map(x=>x.method),['GET','PUT','GET']);assert.equal(result.confirmed,true);assert.equal(result.passwordChanged,false);
});
test('wrong identity performs no update',async()=>{
 let writes=0;
 await assert.rejects(confirmReviewer({id,email,acknowledgement,key:'server-only-fixture-key-that-is-not-real',fetcher:async(_url,options)=>{if(options.method!=='GET')writes++;return new Response(JSON.stringify({id:'other',email}),{status:200});}}));
 assert.equal(writes,0);
});

