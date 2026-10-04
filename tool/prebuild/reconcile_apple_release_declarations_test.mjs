import test from 'node:test';
import assert from 'node:assert/strict';
import {metadataPath,metadataBody,reconcile,declarationChanges} from './reconcile_apple_release_declarations.mjs';
const id='7dc45a4b-fc74-41ad-aa58-afe4c8591122';
test('metadata destinations and payload are strictly scoped',()=>{
  for(const path of ['https://evil.example/v1/apps/6805349703','/v1/builds/x','https://u:p@api.appstoreconnect.apple.com/v1/apps/x'])assert.throws(()=>metadataPath(path));
  assert.deepEqual(Object.keys(metadataBody(id).data.attributes).sort(),['advertising','ageRatingOverrideV2']);
  assert.throws(()=>metadataBody('../users'));
});
test('read-only plan cannot mutate and successful apply requires readback',async()=>{
  let value={advertising:false,ageRatingOverride:'NONE',ageRatingOverrideV2:'NONE'};
  const methods=[];
  const request=async(method,path,body)=>{
    methods.push(method);
    if(path==='/v1/apps/6805349703')return{data:{attributes:{bundleId:'com.bilhealth.bodyintelligencelog'}}};
    if(path.includes('/appInfos?'))return{data:[{id,attributes:{state:'WAITING_FOR_REVIEW'}}]};
    if(method==='PATCH'){value={...body.data.attributes};return{data:{id,attributes:value}};}
    return{data:{id,attributes:value}};
  };
  assert.equal((await reconcile({request})).results[0].result,'CHANGE_REQUIRED');
  assert.ok(!methods.includes('PATCH'));
  assert.equal((await reconcile({request,apply:true})).results[0].result,'UPDATED_AND_READ_BACK');
  assert.deepEqual(value,declarationChanges);
  const writes=methods.filter(x=>x==='PATCH').length;
  assert.equal((await reconcile({request,apply:true})).results[0].result,'ALREADY_MATCHES');
  assert.equal(methods.filter(x=>x==='PATCH').length,writes);
});
