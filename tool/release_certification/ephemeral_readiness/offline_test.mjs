import assert from "node:assert/strict";
import { generateKeyPairSync } from "node:crypto";
import { authorized, appAttestConfiguration, readiness, handler } from "./index.ts";
const pem = (kind) => generateKeyPairSync(kind,
  kind === "ec" ? { namedCurve: "prime256v1" } : { modulusLength: 2048 }
).privateKey.export({format:"pem",type:"pkcs8"}).toString();
const team = "A1B2C3D4E5";
const values = {
 SUPABASE_SERVICE_ROLE_KEY: "synthetic-service-role",
 BIL_APP_ATTEST_APP_ID: team+".com.bilhealth.bodyintelligencelog",
 BIL_APP_ATTEST_ENVIRONMENTS: "development, production",
 BIL_APP_ATTEST_BUNDLE_VERSIONS: "36, 37",
 BIL_APP_ATTEST_ALLOW_LEGACY: "false",
 BIL_APNS_TEAM_ID: team, BIL_APNS_KEY_ID:"K1L2M3N4P5",
 BIL_APNS_BUNDLE_ID:"com.bilhealth.bodyintelligencelog",
 BIL_APNS_AUTH_KEY_P8:pem("ec"),
 BIL_FCM_PROJECT_ID:"synthetic-project",
 BIL_FCM_SERVICE_ACCOUNT_JSON:JSON.stringify({
  client_email:"fixture@synthetic-project.iam.gserviceaccount.com",
  private_key:pem("rsa"),
 }),
};
const env=(name)=>values[name];
const request=(auth="Bearer synthetic-service-role",method="GET")=>
 new Request("https://example.invalid/readiness", {headers:{authorization:auth},method});
assert.equal(authorized(request(),env),true);
const forgedServiceRoleJwt = 'eyJhbGciOiJIUzI1NiJ9.' + Buffer.from(JSON.stringify({role:'service_role'})).toString('base64url') + '.forged';
const ordinaryOwnerJwt = 'eyJhbGciOiJIUzI1NiJ9.' + Buffer.from(JSON.stringify({role:'authenticated',sub:'00000000-0000-4000-8000-000000000001'})).toString('base64url') + '.fixture';
for(const value of [forgedServiceRoleJwt,ordinaryOwnerJwt])assert.equal(handler(request('Bearer '+value),env).status,401);
assert.equal(handler(new Request('https://example.invalid/readiness',{headers:{apikey:values.SUPABASE_SERVICE_ROLE_KEY}}),env).status,401);
assert.equal(handler(request('Bearer anon','POST'),env).status,401);
assert.equal(authorized(request(),()=>undefined),false);
assert.equal(authorized(request('Bearer '+'x'.repeat(8193)),env),false);
assert.equal(authorized(request(),(name)=>name==='SUPABASE_SERVICE_ROLE_KEY'?'x'.repeat(8186):env(name)),false);
for(const token of ["","Bearer anon","Bearer another-service-role","bearer synthetic-service-role","Bearer synthetic-service-role-extra"]){
 assert.equal(authorized(request(token),env),false);
 assert.equal(handler(request(token),env).status,401);
}
assert.equal(handler(request(undefined,"POST"),env).status,405);
const ok=readiness(env,team);
assert.equal(Object.values(ok).every(v=>typeof v==="boolean"),true);
for(const field of ["configValid","appIDMatchesExpected","ios37Allowed","productionAppAttestAllowed","apnsCredentialsWellFormed","fcmCredentialsWellFormed"])
 assert.equal(ok[field],true,field);
assert.equal(ok.allowLegacy,false);
assert.equal(readiness(env).expectedTeamConfigured,false);
for(const [name,bad]of [
 ["BIL_APP_ATTEST_APP_ID","bad"],
 ["BIL_APP_ATTEST_ENVIRONMENTS","production,qa"],
 ["BIL_APP_ATTEST_ENVIRONMENTS",""],
 ["BIL_APP_ATTEST_BUNDLE_VERSIONS",""],
 ["BIL_APP_ATTEST_ALLOW_LEGACY","TRUE"],
]){
 const changed=(key)=>key===name?bad:env(key);
 assert.equal(appAttestConfiguration(changed).configValid,false,name);
 assert.equal(readiness(changed,team).ios37Allowed,false,name);
}
assert.equal(readiness((k)=>k==="BIL_APP_ATTEST_ALLOW_LEGACY"?"true":env(k),team).allowLegacy,true);
assert.equal(readiness((k)=>k==="BIL_APNS_AUTH_KEY_P8"?"malformed":env(k),team).apnsCredentialsWellFormed,false);
assert.equal(readiness((k)=>k==="BIL_APNS_AUTH_KEY_P8"?pem("rsa"):env(k),team).apnsCredentialsWellFormed,false);
assert.equal(readiness((k)=>k==="BIL_FCM_SERVICE_ACCOUNT_JSON"?"{":env(k),team).fcmCredentialsWellFormed,false);
assert.equal(readiness((k)=>k==="BIL_APP_ATTEST_BUNDLE_VERSIONS"?"36":env(k),team).ios37Allowed,false);
assert.equal(readiness((k)=>k==="BIL_APP_ATTEST_ENVIRONMENTS"?"development":env(k),team).productionAppAttestAllowed,false);
const denied=await handler(request("Bearer anon"),env).json();
assert.deepEqual(denied,{authorized:false});
assert.equal(readiness(env,team).integrityGlobalEnforce,true);
assert.equal(readiness((k)=>k==="BIL_MOBILE_INTEGRITY_ENFORCEMENT"?"":env(k),team).integrityGlobalEnforce,false);
assert.equal(readiness((k)=>k==="BIL_MOBILE_INTEGRITY_ENFORCEMENT"?"canary":env(k),team).integrityGlobalEnforce,false);
assert.equal(authorized(request("Bearer synthetic-service-rold"),env),false);
const rsa=pem("rsa");
const play=JSON.stringify({client_email:"fixture@bil-health.iam.gserviceaccount.com",project_id:"bil-health",private_key:rsa});
const withPlay=(k)=>k==="BIL_PLAY_INTEGRITY_SERVICE_ACCOUNT_JSON"?play:env(k);
assert.equal(readiness(withPlay,team).playIntegrityCredentialsWellFormed,true);
assert.equal(readiness(withPlay,team).googleBillingCredentialsWellFormed,true);
assert.equal(readiness((k)=>k==="GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"?"malformed":withPlay(k),team).googleBillingCredentialsWellFormed,false);
assert.equal(readiness((k)=>k==="BIL_PLAY_INTEGRITY_SERVICE_ACCOUNT_JSON"?JSON.stringify({...JSON.parse(play),project_id:'wrong-project'}):env(k),team).playIntegrityCredentialsWellFormed,false);
const apple=(k)=>k==="APPLE_ISSUER_ID"?"00000000-0000-0000-0000-000000000001":k==="APPLE_KEY_ID"?"K1L2M3N4P5":k==="APPLE_PRIVATE_KEY"?env("BIL_APNS_AUTH_KEY_P8"):env(k);
assert.equal(readiness(apple,team).appleBillingCredentialsWellFormed,true);
assert.equal(readiness((k)=>k==="APPLE_PRIVATE_KEY"?"malformed":apple(k),team).appleBillingCredentialsWellFormed,false);
console.log("PASS: authorization, config parity, EC/RSA shape and boolean-only contracts");

