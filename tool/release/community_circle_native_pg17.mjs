// BIL-06 actual local PostgreSQL/WASM + TCP loopback authority tests.
// Does not accept database URLs or existing databases. Never imports Supabase config.
// PGlite is one PostgreSQL backend; native multi-session races remain NOT_RUN.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { resolve, dirname, isAbsolute } from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import assert from 'node:assert/strict';

const here=resolve(dirname(fileURLToPath(import.meta.url)),'../qa_parallel/bil06');
const repo=resolve(here,'../../..');
const modules=process.env.BIL06_SQL_NODE_MODULES;
if (!modules || !isAbsolute(modules)) throw new Error('BIL06_SQL_NODE_MODULES must be an explicit scratch runtime path');
const req=createRequire(resolve(modules,'../package.json'));
const {PGlite}=req('@electric-sql/pglite');
const {pgcrypto}=req('@electric-sql/pglite/contrib/pgcrypto');
const {PGLiteSocketServer}=req('@electric-sql/pglite-socket');
const {Client}=req('pg');
const out=process.env.BIL06_SQL_RESULTS ?? resolve(here,'sql/evidence');
mkdirSync(out,{recursive:true});
const records=[]; const sourceHashes={}; const logs=[]; const protocolSamples=[];
function log(line){logs.push(line);console.log(line);}
function file(path){ const body=readFileSync(resolve(here,path),'utf8'); sourceHashes[path]=createHash('sha256').update(body).digest('hex');return body; }
function exactFunction(body,name){
  const pattern=new RegExp('create(?:\\s+or\\s+replace)?\\s+function\\s+'+name.replaceAll('.','\\.')+'\\s*\\([\\s\\S]*?\\bas\\s+(\\$[A-Za-z0-9_]*\\$)[\\s\\S]*?\\1\\s*;','i');
  const m=body.match(pattern);if(!m)throw new Error('Exact BASE function missing: '+name);return m[0];
}
const identities=Object.fromEntries(Array.from({length:7},(_,i)=>{const n=String(i+1);return[n,n.repeat(8)+'-'+n.repeat(4)+'-4'+n.repeat(3)+'-8'+n.repeat(3)+'-'+n.repeat(12)];}));
let counter=1;const requestId=()=> '06000000-0000-4000-8000-'+String(counter++).padStart(12,'0');
let db;let server;let client;let version;let currentActor='';let currentRole='postgres';
async function sql(text,params){return client.query(text,params);}
async function scalar(text,params){const r=await sql(text,params);return r.rows[0]?.value;}
async function actor(n,role='authenticated'){
  await sql('reset role');
  await sql("select set_config('request.jwt.claim.sub',$1,false),set_config('request.jwt.claims',$2,false)",[n?identities[n]:'',JSON.stringify(n?{sub:identities[n],role}:{role})]);
  if(!['authenticated','anon','postgres'].includes(role))throw new Error('Invalid fixture role');
  if(role!=='postgres')await sql('set role '+role);
  currentActor=n;currentRole=role;
}
async function admin(text,params){const role=currentRole;await sql('reset role');try{return await sql(text,params);}finally{if(role!=='postgres')await sql('set role '+role);}}
async function rpc(name,params=[]){const result=await scalar('select public.'+name+'('+params.map((_,i)=>'$'+(i+1)).join(',')+') as value',params);protocolSamples.push({rpc:name,params,actor:currentActor?identities[currentActor]:null,role:currentRole,result});return result;}
async function denied(label,fn,code){let error;try{await fn();}catch(e){error=e;}assert(error,label+' must fail');if(code)assert.equal(error.code,code,label+' SQLSTATE');}
async function test(label,fn){const start=Date.now();try{await fn();records.push({name:label,status:'PASS',duration_ms:Date.now()-start});log('PASS '+label);}catch(e){records.push({name:label,status:'FAIL',duration_ms:Date.now()-start,code:e.code??null,message:e.message});log('FAIL '+label+': '+e.message);throw e;}}
try {
  const fixture=JSON.parse(readFileSync(process.env.BIL06_NATIVE_FIXTURE,'utf8'));
  assert.equal(fixture.host,'127.0.0.1');assert.match(fixture.database,/^bil06_policy_20261019(?:_r[0-9]+)?$/);
  assert.equal(fixture.user,'postgres');const port=fixture.port;
  assert(Number.isInteger(port)&&port>1024&&port<65536);
  client=new Client({...fixture,ssl:false,connectionTimeoutMillis:5000,query_timeout:30000});
  await client.connect();
  version=await scalar('select version() as value');
  log('RUNTIME '+version);assert.match(version,/PostgreSQL 17\./);log('TRANSPORT native PostgreSQL17 loopback:'+port);
  assert.equal(await scalar("select count(*)::int as value from pg_tables where schemaname in ('public','auth','private','storage')"),0,'Disposable database must be empty');
  await sql(file('../../release/community_atomic_publish_live_baseline.sql'));
  const circleBase=file('sql/fixtures/base_circles_foundation.sql');
  const unchangedNames=['bil_list_community_circles_v1','bil_join_community_circle_v1','bil_leave_community_circle_v1','bil_set_my_community_post_circle_v1','bil_community_circle_post_refs_v1'];
  for(const name of unchangedNames){await sql(exactFunction(circleBase,'public.'+name));}
  await sql("revoke all on function public.bil_list_community_circles_v1(),public.bil_join_community_circle_v1(text),public.bil_leave_community_circle_v1(text),public.bil_set_my_community_post_circle_v1(uuid,text),public.bil_community_circle_post_refs_v1(text,timestamptz,uuid,integer) from public,anon,service_role; grant execute on function public.bil_list_community_circles_v1(),public.bil_join_community_circle_v1(text),public.bil_leave_community_circle_v1(text),public.bil_set_my_community_post_circle_v1(uuid,text),public.bil_community_circle_post_refs_v1(text,timestamptz,uuid,integer) to authenticated;");
  await sql(file('sql/fixtures/base_profile_visibility.sql'));
  await sql(file('sql/fixtures/base_public_code_resolver.sql'));
  const unchangedBefore=await scalar("select jsonb_object_agg(proname,md5(pg_get_functiondef(oid))) as value from pg_proc where proname=any($1)",[unchangedNames]);
  await sql(file('sql/circle_management_v1.sql'));
  await sql(file('sql/fixtures/seed.sql'));
  await test('BASE list/join/leave/post functions remain byte-identical',async()=>{
    assert.deepEqual(await scalar("select jsonb_object_agg(proname,md5(pg_get_functiondef(oid))) as value from pg_proc where proname=any($1)",[unchangedNames]),unchangedBefore);
  });
  file('sql_run.mjs');file('sql_tests.mjs');
  const tests=await import(new URL('../qa_parallel/bil06/sql_tests.mjs',import.meta.url));
  await tests.run({sql,scalar,actor,admin,rpc,denied,test,identities,requestId,assert});
  await admin("delete from public.bil_community_circles where slug like 'cap-fixture-%'");
  await test('Native simultaneous retry commits one circle and one receipt',async()=>{
    const connections=[];
    try{
      for(let i=0;i<2;i++){
        const c=new Client({...fixture,ssl:false,connectionTimeoutMillis:5000,query_timeout:10000});
        await c.connect();connections.push(c);
        await c.query("select set_config('request.jwt.claim.sub',$1,false),set_config('request.jwt.claims',$2,false)",[identities['1'],JSON.stringify({sub:identities['1'],role:'authenticated'})]);
        await c.query('set role authenticated');
      }
      const id=requestId();
      const responses=await Promise.all(connections.map(c=>c.query("select public.bil_circle_create_v1($1,'Simultaneous retry','Synthetic description','Respect members','public','open') as value",[id])));
      assert.deepEqual(responses[0].rows[0].value,responses[1].rows[0].value);
      assert.equal(await admin("select count(*)::int as value from public.bil_circle_operations_v1 where owner_id=$1 and request_id=$2",[identities['1'],id]).then(r=>r.rows[0].value),1);
    }finally{for(const c of connections)await c.end();}
  });
  records.push({name:'Supabase Auth/PostgREST/Storage HTTP and actual image bytes',status:'NOT_RUN',reason:'Local PostgreSQL tests execute real SQL/RLS with synthetic JWT GUCs and Storage metadata; no hosted service, byte upload or image decoder.'});
  log('RESULT PASS '+records.filter(x=>x.status==='PASS').length+' test groups; '+records.filter(x=>x.status==='NOT_RUN').length+' explicitly NOT_RUN');
} catch(error){
  process.exitCode=1;log('FATAL '+(error.code??'')+' '+error.message);if(error.where)log('WHERE '+error.where);
} finally {
  try{if(client)await client.end();if(server)await server.stop();if(db)await db.close();}catch(error){process.exitCode=1;log('CLEANUP '+error.message);}
  const report={role_id:'BIL-06',base_sha:'1744788e6bfbdffc3a168bbaf36b3abf3e2c698a',runtime:version??null,node:process.version,platform:process.platform,architecture:process.arch,exit_code:process.exitCode??0,production_deployed:false,connection_scope:'new disposable native PostgreSQL17 via TCP 127.0.0.1 only',source_hashes:sourceHashes,tests:records};
  writeFileSync(resolve(out,'sql_results.json'),JSON.stringify(report,null,2)+'\n');writeFileSync(resolve(out,'sql_run.log'),logs.join('\n')+'\n');
  writeFileSync(resolve(out,'sql_protocol_samples.json'),JSON.stringify({source:'Actual PostgreSQL RPC execution over 127.0.0.1; synthetic rows only',runtime:version,samples:protocolSamples},null,2)+'\n');
}
