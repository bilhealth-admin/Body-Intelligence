// Only the fixed disposable loopback PostgreSQL17 service is accepted.
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import fs from 'node:fs';
import {createRequire} from 'node:module';
import path from 'node:path';

const args=process.argv.slice(2);
assert.equal(args.length, 4, 'Usage: ROOT OUTPUT PG_PACKAGE_JSON EXPECTED_SHA');
const [rootInput, outputInput, packageInput, expectedSha]=args;
assert.match(expectedSha,/^[0-9a-f]{40}$/);
const root=fs.realpathSync(rootInput), output=path.resolve(outputInput), pkg=fs.realpathSync(packageInput);
const outputRelative=path.relative(root,output);
assert.ok(outputRelative.startsWith('..'+path.sep)||path.isAbsolute(outputRelative), 'Output must be outside source');
assert.equal(JSON.parse(fs.readFileSync(pkg,'utf8')).dependencies.pg,'8.23.1');
const require=createRequire(pkg), {Client}=require('pg');
assert.equal(require('pg/package.json').version,'8.23.1');
const actual=spawnSync('git',['-C',root,'rev-parse','HEAD'],{encoding:'utf8'});
assert.equal(actual.status,0);assert.equal(actual.stdout.trim(),expectedSha);
fs.mkdirSync(output,{recursive:false});
const database=`bil_circle_review_20261019_r${Date.now()}`;
assert.match(database,/^bil_circle_review_20261019_r\d+$/);
const config={host:'127.0.0.1',port:55479,user:'postgres',database:'postgres',
  password:process.env.BIL_NATIVE_PG_QA_PASSWORD,
  connectionTimeoutMillis:10000,query_timeout:30000};
assert.ok(config.password,'A synthetic isolated-service password is required');
const admin=new Client(config);
let created=false;
const fixture=path.join(output,'private-fixture.json');
const test=path.join(root,'supabase/tests/community_circle_review_native_test.mjs');
const testHash=createHash('sha256').update(fs.readFileSync(test)).digest('hex');
const report={source_sha:expectedSha,test_sha256:testHash,host:config.host,port:config.port,
  database,status:'STARTED',database_created:false,database_removed:false,
  scope:'Synthetic native PostgreSQL17 assertions, no hosted Auth/Storage bytes or portal UI'};
let code=1;
try {
  await admin.connect();
  const version=(await admin.query('show server_version_num')).rows[0].server_version_num;
  assert.ok(Number(version)>=170000&&Number(version)<180000,'PostgreSQL17 is mandatory');
  report.postgres_version_num=version;
  await admin.query(`create database "${database}" template template0`);
  created=true;report.database_created=true;
  const fresh=new Client({...config,database});
  try {
    await fresh.connect();
    report.empty_public_tables_before=(await fresh.query("select count(*)::int n from pg_tables where schemaname='public'")).rows[0].n;
    assert.equal(report.empty_public_tables_before,0,'Native fixture database must be empty');
  } finally {await fresh.end();}
  fs.writeFileSync(fixture,JSON.stringify({...config,database}));
  const env=Object.fromEntries(['PATH','SystemRoot','WINDIR','COMSPEC','PATHEXT','HOME','USERPROFILE','TMP','TEMP','TMPDIR']
    .filter(key=>process.env[key]).map(key=>[key,process.env[key]]));
  env.BIL_PG_QA_PACKAGE=pkg;env.BIL_CIRCLE_REVIEW_FIXTURE=fixture;
  const result=spawnSync(process.execPath,[test],{cwd:root,env,encoding:'utf8',timeout:180000});
  fs.writeFileSync(path.join(output,'native-assertions.log'),(result.stdout??'')+(result.stderr??''));
  code=result.status??1;report.exit_code=code;
  const marker=result.stdout?.match(/RESULT (\d+) native groups PASS\./);
  assert.equal(code,0,'Existing native assertion suite failed; inspect preserved log');
  assert.ok(marker,'Missing original assertion suite completion marker');
  report.groups_passed=Number(marker[1]);report.status='PASS';
} catch(error) {
  report.status='FAIL';report.error_type=error.constructor.name;
  console.error(error.message);
  code=1;
} finally {
  if(created){
    try {
      await admin.query(`drop database "${database}" with (force)`);
      report.database_removed=(await admin.query('select count(*)::int n from pg_database where datname=$1',[database])).rows[0].n===0;
      assert.equal(report.database_removed,true,'Deleted fixture database must be absent on readback');
    }
    catch(error){report.status='FAIL';report.cleanup_error_type=error.constructor.name;code=1;}
  }
  await admin.end();
  if(fs.existsSync(fixture))fs.unlinkSync(fixture);
  assert.equal(createHash('sha256').update(fs.readFileSync(test)).digest('hex'),testHash);
  fs.writeFileSync(path.join(output,'result.json'),JSON.stringify(report,null,2)+'\n');
}
console.log(JSON.stringify(report));
process.exitCode=code;
