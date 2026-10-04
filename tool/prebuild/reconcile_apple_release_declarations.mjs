// Owner-authorized metadata only. Never changes accounts, builds or submissions.
import crypto from 'node:crypto';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';

const origin='https://api.appstoreconnect.apple.com';
const appId='6805349703';
export const declarationChanges=Object.freeze({
  advertising:true,
  ageRatingOverrideV2:'EIGHTEEN_PLUS',
});
export function metadataPath(resource){
  const url=new URL(resource,origin);
  if(url.origin!==origin||url.username||url.password||url.hash||
      !/^\/v1\/(apps|appInfos|ageRatingDeclarations)\//.test(url.pathname))
    throw new Error('Forbidden metadata destination');
  return url;
}
export function metadataBody(id){
  if(!/^[a-f0-9-]{36}$/.test(id))throw new Error('Invalid declaration identity');
  return {data:{type:'ageRatingDeclarations',id,attributes:{...declarationChanges}}};
}
function token(){
  const now=Math.floor(Date.now()/1000);
  const part=x=>Buffer.from(JSON.stringify(x)).toString('base64url');
  const body=part({alg:'ES256',kid:process.env.ASC_KEY_ID,typ:'JWT'})+'.'+part({iss:process.env.ASC_ISSUER_ID,iat:now-5,exp:now+600,aud:'appstoreconnect-v1'});
  return body+'.'+crypto.sign('sha256',Buffer.from(body),{key:fs.readFileSync(process.env.ASC_PRIVATE_KEY_PATH),dsaEncoding:'ieee-p1363'}).toString('base64url');
}
export async function reconcile({request,apply=false}){
  const app=await request('GET',`/v1/apps/${appId}`);
  if(app.data?.attributes?.bundleId!=='com.bilhealth.bodyintelligencelog')throw new Error('App identity mismatch');
  const infos=await request('GET',`/v1/apps/${appId}/appInfos?limit=200`);
  if(infos.links?.next)throw new Error('Unbounded app-info list');
  const results=[];
  for(const info of infos.data??[]){
    if(!/^[a-f0-9-]{36}$/.test(info.id))throw new Error('Invalid app-info identity');
    const resource=`/v1/appInfos/${info.id}/ageRatingDeclaration`;
    const before=await request('GET',resource);
    const id=before.data?.id;
    const body=metadataBody(id);
    const matches=value=>Object.entries(declarationChanges).every(([key,want])=>value?.data?.attributes?.[key]===want);
    const result={appInfoId:info.id,state:info.attributes?.state??info.attributes?.appStoreState,
      before:Object.fromEntries(Object.keys(declarationChanges).map(key=>[key,before.data?.attributes?.[key]])),
      changed:false,result:matches(before)?'ALREADY_MATCHES':'CHANGE_REQUIRED'};
    if(apply&&!matches(before)){
      try{
        await request('PATCH',`/v1/ageRatingDeclarations/${id}`,body);
        const after=await request('GET',resource);
        if(!matches(after))throw new Error('Readback mismatch');
        result.changed=true;result.result='UPDATED_AND_READ_BACK';
      }catch(error){result.result='NOT_UPDATED';result.failure=error.message;}
    }
    results.push(result);
  }
  if(!results.length)throw new Error('No declaration found');
  return {checkedAt:new Date().toISOString(),appId,buildMutation:false,reviewSubmissionMutation:false,
    reviewerAccountMutation:false,requestedAttributes:declarationChanges,results};
}
async function main(){
  const apply=process.argv.includes('--apply');
  if(apply&&process.env.BIL_OWNER_METADATA_ACK!=='OWNER_APPROVED_CURRENT_CODE_METADATA')throw new Error('Explicit owner metadata acknowledgement required');
  const output=process.argv[process.argv.indexOf('--output')+1];
  if(!process.argv.includes('--output')||!output?.startsWith('G:/BIL_Project/audit-work/'))throw new Error('Private evidence output required');
  async function request(method,resource,body){
    if(method!=='GET'&&!(method==='PATCH'&&apply&&/^\/v1\/ageRatingDeclarations\/[^/]+$/.test(resource)))throw new Error('Forbidden metadata mutation');
    const response=await fetch(metadataPath(resource),{method,redirect:'error',signal:AbortSignal.timeout(15000),
      headers:{Authorization:`Bearer ${token()}`,'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined});
    const data=await response.json();
    if(!response.ok)throw new Error(`ASC_${response.status}_`+(data.errors??[]).map(x=>x.code).join(','));
    return data;
  }
  const result=await reconcile({request,apply});
  fs.writeFileSync(output,JSON.stringify(result,null,2));console.log(JSON.stringify(result));
  if(result.results.some(x=>!['ALREADY_MATCHES','UPDATED_AND_READ_BACK'].includes(x.result)))process.exitCode=1;
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href)await main();
