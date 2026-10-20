import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {execFileSync} from 'node:child_process';
const appSource='5775d082a1b4c7a29e4ed4d6e01693b31923dc31';
const appTree='7ea15defb433ad134ee5066f538d8e790c45f809';
const cloud='https://tgmanzhqulksykhslrzb.supabase.co';
const output=process.env.READINESS_OUT;fs.mkdirSync(output,{recursive:true});
const result={appSource,appTree,sourceCheckoutVerified:false,controllerSource:process.env.GITHUB_SHA,credentialSource:'DEDICATED_GOOGLE_SECRETS',result:'NOT_VERIFIED',consoleInstructionsVerified:false,fullReviewerJourneyVerified:false,entitlementMutationPerformed:false,nativePurchasePerformed:false,sessionCleanup:'NOT_NEEDED'};
let token;let apiKey;
async function req(resource,body,authenticated=false,method=body===undefined?'GET':'POST'){
 const allowed=['/auth/v1/token','/auth/v1/user','/auth/v1/logout','/rest/v1/bil_subscriptions','/rest/v1/bil_ai_closed_test_grants','/rest/v1/rpc/bil_get_my_admin_subscription','/rest/v1/rpc/bil_get_ai_usage_status'];
 const u=new URL(resource,cloud);if(u.origin!==cloud||!allowed.includes(u.pathname))throw new Error('request_not_allowlisted');
 const r=await fetch(u,{method,redirect:'error',signal:AbortSignal.timeout(12000),headers:{'Content-Type':'application/json',apikey:apiKey,...(authenticated?{Authorization:'Bearer '+token}:{})},...(body===undefined?{}:{body:JSON.stringify(body)})});
 if(!r.ok){const e=new Error('http_failure');e.status=r.status;throw e;}
 const t=await r.text();if(t.length>200000)throw new Error('response_too_large');return t?JSON.parse(t):null;
}
try{
 const checkout=process.env.APP_CHECKOUT;
 if(!checkout)throw new Error('source_checkout_not_verified');
 const git=(...args)=>execFileSync('git',['-C',checkout,...args],{encoding:'utf8',timeout:10000,maxBuffer:2048,stdio:['ignore','pipe','pipe']}).trim();
 if(git('rev-parse','HEAD')!==appSource||git('rev-parse','HEAD^{tree}')!==appTree||git('status','--porcelain','--untracked-files=no'))throw new Error('source_checkout_not_verified');
 result.sourceCheckoutVerified=true;
 const email=process.env.BIL_GOOGLE_REVIEWER_EMAIL?.trim();const password=process.env.BIL_GOOGLE_REVIEWER_PASSWORD;
 result.dedicatedEmailPresent=!!email;result.dedicatedPasswordPresent=!!password;
 if(!email||!password)throw new Error('missing_dedicated_google_credentials');
 apiKey=process.env.BIL_SUPABASE_PUBLISHABLE_KEY?.trim();
 if(!apiKey){const src=fs.readFileSync(path.join(process.env.APP_CHECKOUT,'.github/workflows/bil_reviewer_access_preflight.yml'),'utf8');apiKey=src.match(/BIL_SUPABASE_PUBLISHABLE_KEY:\s*(sb_publishable_[^\s]+)/)?.[1];}
 if(!apiKey?.startsWith('sb_publishable_'))throw new Error('publishable_key_unavailable');
 const {summarizeAccess}=await import(pathToFileURL(path.join(process.env.APP_CHECKOUT,'tool/prebuild/reviewer_access_preflight.mjs')).href);
 const session=await req('/auth/v1/token?grant_type=password',{email,password});token=session?.access_token;
 if(!token||!session?.user?.id)throw new Error('login_session_missing');
 const user=await req('/auth/v1/user',undefined,true);
 if(user?.id!==session.user.id||user?.email?.toLowerCase()!==email.toLowerCase())throw new Error('reviewer_identity_mismatch');
 result.normalLoginVerified=true;
 const expectedOwner=process.env.BIL_GOOGLE_REVIEWER_EXPECTED_OWNER_ID?.trim();
 result.expectedOwnerConfigured=!!expectedOwner;
 result.expectedOwnerMatches=expectedOwner?user.id===expectedOwner:null;
 if(expectedOwner&&user.id!==expectedOwner)throw new Error('expected_owner_mismatch');
 const owner=encodeURIComponent(user.id);
 const [subscription,grant,closed,usage]=await Promise.all([
  req('/rest/v1/bil_subscriptions?owner_id=eq.'+owner+'&limit=1&select=plan_id,lifecycle,provider,verified_at,started_at,expires_at,grace_period_ends_at',undefined,true),
  req('/rest/v1/rpc/bil_get_my_admin_subscription',{},true),
  req('/rest/v1/bil_ai_closed_test_grants?owner_id=eq.'+owner+'&limit=1&select=active,expires_at',undefined,true),
  req('/rest/v1/rpc/bil_get_ai_usage_status',{},true)
 ]);
 const access=summarizeAccess({subscription:subscription?.[0],grant,closedTest:closed?.[0],usage,owner:user.id});
 // Export only booleans, never identity, credit balances, dates or grants.
 result.access={storeSubscriptionVerifiedAndActive:access.storeSubscriptionVerifiedAndActive,administrativeLeaseValid:access.administrativeLeaseValid,closedTestGrantActive:access.closedTestGrantActive,premiumAccessCandidate:access.premiumAccessCandidate,aiCreditsPositive:access.aiCreditsPositive};
 const budgetText=process.env.BIL_GOOGLE_REVIEW_MINIMUM_AI_CREDITS?.trim();const budget=budgetText?Number(budgetText):null;
 result.minimumReviewBudgetConfigured=Number.isSafeInteger(budget)&&budget>0;
 result.minimumReviewBudgetSatisfied=result.minimumReviewBudgetConfigured?Number.isFinite(access.aiCreditsRemaining)&&access.aiCreditsRemaining>=budget:null;
 result.result=access.premiumAccessCandidate&&access.aiCreditsPositive?'GOOGLE_SERVER_ACCESS_PREFLIGHT_PASS':'GOOGLE_SERVER_ACCESS_GAP';
}catch(e){result.failure={code:['source_checkout_not_verified','missing_dedicated_google_credentials','publishable_key_unavailable','login_session_missing','reviewer_identity_mismatch','expected_owner_mismatch','request_not_allowlisted','response_too_large','http_failure'].includes(e.message)?e.message:'transport_or_shape_failure',httpStatus:Number.isInteger(e.status)?e.status:null};}
finally{
 if(token){try{await req('/auth/v1/logout?scope=local',undefined,true,'POST');result.sessionCleanup='CURRENT_SESSION_SIGNED_OUT';}catch{result.sessionCleanup='FAILED';result.result='NOT_VERIFIED';}}
 fs.writeFileSync(path.join(output,'google-reviewer-readonly.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify({result:result.result,sessionCleanup:result.sessionCleanup,consoleInstructionsVerified:false,fullReviewerJourneyVerified:false}));
}
process.exitCode=result.result==='GOOGLE_SERVER_ACCESS_PREFLIGHT_PASS'?0:1;

