// Real BASE account-deletion Storage traversal with the exact proposed one-line
// overlay, run against a synthetic Storage API. This is not HTTP/provider E2E.
import {readFileSync,writeFileSync,mkdirSync,mkdtempSync} from 'node:fs';
import {dirname,resolve} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import assert from 'node:assert/strict';
const here=dirname(fileURLToPath(import.meta.url));
const runtime=process.env.BIL06_SQL_WORK;
if(!runtime?.startsWith('/'))throw new Error('BIL06_SQL_WORK must name a scratch directory');
const output=resolve(here,'sql/evidence');mkdirSync(output,{recursive:true});
const log=[];const records=[];const hash=x=>createHash('sha256').update(x).digest('hex');
const baseline=readFileSync(resolve(here,'sql/fixtures/account_deletion_storage_base.ts'));
assert.equal(hash(baseline),'505fe46b057f9f8ad12b18e5fa89316d32d402dae34edd4752e9876230ee9d84','Exact BASE bytes required');
const scratch=mkdtempSync(resolve(runtime,'deletion-overlay-'));
const relative='supabase/functions/_shared/account_deletion_storage.ts';
const path=resolve(scratch,relative);mkdirSync(dirname(path),{recursive:true});writeFileSync(path,baseline);
const baseModule=await import(pathToFileURL(path).href+'?baseline');
const patchPath=resolve(here,'sql_account_deletion.patch');
for(const args of [['apply','--check',patchPath],['apply',patchPath]]){
  const result=spawnSync('git',args,{cwd:scratch,encoding:'utf8'});assert.equal(result.status,0,result.stderr);
}
const module=await import(pathToFileURL(path).href+'?candidate');
const owner='11111111-1111-4111-8111-111111111111';
const other='33333333-3333-4333-8333-333333333333';
function fixture({retain=false,fail=false}={}){
  const files=new Map([
    ['profile-avatars',new Set([owner+'/avatar.png',other+'/keep.png'])],
    ['community-post-images',new Set([owner+'/post/photo.png',other+'/post/keep.png'])],
    ['community-circle-media',new Set([owner+'/circle/avatar/photo.png',owner+'/circle/cover/photo.png',other+'/circle/cover/keep.png'])],
  ]);
  const calls=[];
  const storage={from(bucket){calls.push(bucket);return {
    async list(prefix,{limit,offset}){
      const entries=new Map();for(const value of files.get(bucket)??[]){
        if(!value.startsWith(prefix+'/'))continue;
        const rest=value.slice(prefix.length+1);const part=rest.split('/')[0];const leaf=!rest.includes('/');
        entries.set(part,{name:part,id:leaf?'synthetic-object-id':null,metadata:leaf?{size:100}:null});
      }
      return {data:[...entries.values()].sort((a,b)=>a.name.localeCompare(b.name)).slice(offset,offset+limit),error:null};
    },
    async remove(paths){if(fail&&bucket==='community-circle-media')return {data:null,error:{message:'fixture failure'}};
      if(!(retain&&bucket==='community-circle-media'))for(const path of paths)files.get(bucket).delete(path);
      return {data:[],error:null};},
  };}};
  return{files,calls,storage};
}
async function test(name,action){await action();records.push({name,status:'PASS'});log.push('PASS '+name);console.log(log.at(-1));}
try{
  await test('BASE omission reproduced: circle objects survive old default cleanup',async()=>{
    const f=fixture();assert.equal(await baseModule.deleteBilUserStorage(f.storage,owner),2);
    assert([...f.files.get('community-circle-media')].some(x=>x.startsWith(owner+'/')));
  });
  await test('Exact one-line overlay visits circle bucket recursively and clears only owner paths',async()=>{
    const f=fixture();assert.deepEqual(module.BIL_USER_STORAGE_BUCKETS,['profile-avatars','community-post-images','community-circle-media']);
    assert.equal(await module.deleteBilUserStorage(f.storage,owner),4);
    for(const paths of f.files.values()){assert(![...paths].some(x=>x.startsWith(owner+'/')));assert([...paths].some(x=>x.startsWith(other+'/')));}
  });
  await test('Circle Storage removal failure is surfaced instead of authorizing completion',async()=>{
    await assert.rejects(module.deleteBilUserStorage(fixture({fail:true}).storage,owner),/storage_remove_failed/);
  });
  await test('Circle removal readback mismatch fails closed',async()=>{
    await assert.rejects(module.deleteBilUserStorage(fixture({retain:true}).storage,owner),/storage_cleanup_incomplete/);
  });
}catch(error){process.exitCode=1;log.push('FAIL '+error.message);records.push({name:'deletion integration test',status:'FAIL',message:error.message});console.error(error.message);}
writeFileSync(resolve(output,'sql_deletion_results.json'),JSON.stringify({base_sha:'1744788e6bfbdffc3a168bbaf36b3abf3e2c698a',base_file:relative,base_blob_sha:'f971edd92360a1cc3d450ea57a4d092948de54a9',base_sha256:hash(baseline),candidate_sha256:hash(readFileSync(path)),proposal_sha256:hash(readFileSync(patchPath)),runner_sha256:hash(readFileSync(fileURLToPath(import.meta.url))),node:process.version,exit_code:process.exitCode??0,tests:records,scope:'real BASE function plus exact patch; synthetic Storage API; no Auth deletion/HTTP calls'},null,2)+'\n');
writeFileSync(resolve(output,'sql_deletion_run.log'),log.join('\n')+'\n');
