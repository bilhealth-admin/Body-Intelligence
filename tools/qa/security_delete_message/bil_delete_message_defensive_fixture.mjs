// Bounded synthetic behavior checks only. Never imports the blocked exploit fixture.
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import fs from 'node:fs';
import {createRequire} from 'node:module';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

assert.equal(process.argv.length, 6, 'Usage: ROOT OUTPUT PG_PACKAGE_JSON EXPECTED_SHA');
const [rootArg, outputArg, packageArg, expectedSha] = process.argv.slice(2);
assert.match(expectedSha, /^[0-9a-f]{40}$/);
const root = fs.realpathSync(rootArg), output = path.resolve(outputArg);
const relative = path.relative(root, output);
assert.ok(relative.startsWith('..' + path.sep) || path.isAbsolute(relative), 'Output must be outside source');
const git = spawnSync('git', ['-C', root, 'rev-parse', 'HEAD'], {encoding: 'utf8'});
assert.equal(git.status, 0); assert.equal(git.stdout.trim(), expectedSha);
const pkg = fs.realpathSync(packageArg), require = createRequire(pkg);
assert.equal(JSON.parse(fs.readFileSync(pkg, 'utf8')).dependencies.pg, '8.23.1');
assert.equal(require('pg/package.json').version, '8.23.1');
const {Client} = require('pg');
const sqlPath = path.join(path.dirname(fileURLToPath(import.meta.url)), 'bil_delete_message.hardening.sql');
const sql = fs.readFileSync(sqlPath, 'utf8');
const sqlHash = createHash('sha256').update(sql).digest('hex');
const fixtureId = `bil_qa_dm_${Date.now()}`;
assert.match(fixtureId, /^bil_qa_dm_\d+$/);
const database = fixtureId, owner = fixtureId + '_owner', authenticated = fixtureId + '_auth', anonymous = fixtureId + '_anon';
const config = {host: '127.0.0.1', port: 55479, user: 'postgres', database: 'postgres',
  password: process.env.BIL_NATIVE_PG_QA_PASSWORD, connectionTimeoutMillis: 10000, query_timeout: 10000};
assert.ok(config.password, 'Synthetic local-service password required');
fs.mkdirSync(output, {recursive: false});
const report = {schema: 'bil.delete-message.defensive-fixture.v1', source_sha: expectedSha,
  patch_sha256: sqlHash, status: 'STARTED', database, host: config.host, port: config.port,
  scope: 'Synthetic owner, recipient, unrelated actor, anonymous, repeat timestamp, ACL preservation only',
  excluded: ['temp shadow tables', 'triggers', 'privilege escalation', 'exploit baseline', 'Production access'],
  prior_exploit_status: 'BLOCKED_NOT_REPRODUCED', checks: [], database_removed: false, roles_removed: false};
const admin = new Client(config);
let db, created = false, code = 1;
const rolesCreated = [];
const pass = (name) => {report.checks.push({name, status: 'PASS'}); console.log(`PASS ${name}`);};
const actors = {sender: '00000000-0000-4000-8000-000000000001', recipient: '00000000-0000-4000-8000-000000000002', unrelated: '00000000-0000-4000-8000-000000000003'};
const ids = ['10000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000003'];
async function asRole(role, actor, query, params = []) {
  assert.ok([authenticated, anonymous].includes(role));
  await db.query('begin');
  try {
    await db.query(`set local role "${role}"`);
    await db.query("select pg_catalog.set_config('request.jwt.claim.sub', $1, true)", [actor ?? '']);
    const result = await db.query(query, params);
    await db.query('commit');
    return result;
  } catch (error) { await db.query('rollback'); throw error; }
}
async function rows() {return (await db.query('select id, sender_id, recipient_id, deleted_by_sender_at::text, deleted_by_recipient_at::text from public.bil_messages order by id')).rows;}
async function acl() {return (await db.query("select p.proowner::regrole::text owner, p.proacl::text acl, p.proconfig, p.prosecdef, has_function_privilege($1, p.oid, 'EXECUTE') authenticated_execute, has_function_privilege($2, p.oid, 'EXECUTE') anonymous_execute from pg_catalog.pg_proc p where p.oid = 'public.bil_delete_message(uuid)'::regprocedure", [authenticated, anonymous])).rows[0];}
async function deletion(role, actor, message) {return asRole(role, actor, 'select public.bil_delete_message($1::uuid)', [message]);}
try {
  await admin.connect();
  report.postgres_version_num = (await admin.query('show server_version_num')).rows[0].server_version_num;
  assert.ok(+report.postgres_version_num >= 170000 && +report.postgres_version_num < 180000);
  await admin.query(`create database "${database}" template template0`); created = true;
  db = new Client({...config, database}); await db.connect();
  await db.query("set statement_timeout = '5s'; set lock_timeout = '2s'");
  report.empty_public_tables_before = (await db.query("select count(*)::int n from pg_catalog.pg_tables where schemaname='public'")).rows[0].n;
  assert.equal(report.empty_public_tables_before, 0);
  for (const role of [owner, authenticated, anonymous]) {
    await admin.query(`create role "${role}" nologin nosuperuser nocreatedb nocreaterole noinherit nobypassrls`);
    rolesCreated.push(role);
  }
  pass('PostgreSQL17 fresh isolated database');
  await db.query(`
    create schema auth;
    create function auth.uid() returns uuid language sql stable as
      'select nullif(pg_catalog.current_setting(''request.jwt.claim.sub'', true), '''')::uuid';
    create table public.bil_messages (
      id uuid primary key, sender_id uuid not null, recipient_id uuid not null,
      deleted_by_sender_at timestamptz, deleted_by_recipient_at timestamptz);
    revoke all on public.bil_messages from public;
    grant usage on schema public, auth to "${owner}";
    grant execute on function auth.uid() to "${owner}";
    grant select, update on public.bil_messages to "${owner}";
    grant usage on schema public to "${authenticated}", "${anonymous}";
  `);
  await db.query('insert into public.bil_messages(id,sender_id,recipient_id) values ($1,$2,$3),($4,$3,$5),($6,$2,$2)', [ids[0], actors.sender, actors.recipient, ids[1], actors.unrelated, ids[2]]);
  // Establish the hardened function directly; no vulnerable baseline is executed.
  await db.query(sql);
  await db.query(`grant create on schema public to "${owner}"; alter function public.bil_delete_message(uuid) owner to "${owner}"; revoke create on schema public from "${owner}"; revoke all on function public.bil_delete_message(uuid) from public; grant execute on function public.bil_delete_message(uuid) to "${authenticated}"`);
  const beforeAcl = await acl();
  await db.query(sql);
  const afterAcl = await acl();
  assert.deepEqual(afterAcl, beforeAcl);
  assert.equal(afterAcl.owner, owner); assert.equal(afterAcl.authenticated_execute, true);
  assert.equal(afterAcl.anonymous_execute, false); assert.equal(afterAcl.prosecdef, true);
  assert.deepEqual(afterAcl.proconfig, ['search_path=""']);
  report.acl_preserved = true;
  pass('CREATE OR REPLACE preserves limited owner and existing authenticated-only ACL');
  for (const role of [authenticated, anonymous]) {
    await assert.rejects(asRole(role, null, 'select * from public.bil_messages'), {code: '42501'});
  }
  pass('Client roles cannot directly read message table');
  const original = await rows();
  await deletion(authenticated, actors.sender, ids[0]);
  let current = await rows();
  assert.ok(current[0].deleted_by_sender_at); assert.equal(current[0].deleted_by_recipient_at, null);
  assert.deepEqual(current.slice(1), original.slice(1));
  pass('Sender deletes only their own view');
  await deletion(authenticated, actors.recipient, ids[0]);
  let recipientState = await rows();
  assert.equal(recipientState[0].deleted_by_sender_at, current[0].deleted_by_sender_at);
  assert.ok(recipientState[0].deleted_by_recipient_at);
  assert.deepEqual(recipientState.slice(1), original.slice(1));
  pass('Recipient deletes only their own view');
  await deletion(authenticated, actors.unrelated, ids[0]);
  assert.deepEqual(await rows(), recipientState);
  pass('Unrelated authenticated actor cannot change any message view');
  await assert.rejects(deletion(anonymous, null, ids[0]), {code: '42501'});
  assert.deepEqual(await rows(), recipientState);
  pass('Anonymous execution denied and rows unchanged');
  const firstTimestamp = recipientState[0].deleted_by_sender_at;
  await deletion(authenticated, actors.sender, ids[0]);
  current = await rows();
  assert.ok(Date.parse(current[0].deleted_by_sender_at) >= Date.parse(firstTimestamp));
  assert.equal(current[0].deleted_by_recipient_at, recipientState[0].deleted_by_recipient_at);
  assert.deepEqual(current.slice(1), original.slice(1));
  pass('Repeat preserves soft-delete state and existing refresh-now timestamp semantics');
  await deletion(authenticated, actors.sender, ids[2]);
  current = await rows();
  assert.ok(current[2].deleted_by_sender_at); assert.ok(current[2].deleted_by_recipient_at);
  assert.deepEqual(current[1], original[1]);
  pass('Self-addressed message retains both legitimate ownership predicates');
  await deletion(authenticated, actors.sender, '10000000-0000-4000-8000-000000000099');
  assert.deepEqual(await rows(), current);
  pass('Absent message leaves existing records unchanged');
  assert.deepEqual(await acl(), afterAcl);
  assert.equal(createHash('sha256').update(fs.readFileSync(sqlPath)).digest('hex'), sqlHash);
  report.status = 'PASS'; code = 0;
} catch (error) {
  report.status = 'FAIL'; report.error_type = error.constructor.name;
  if (error.code) report.error_code = String(error.code);
  console.error(JSON.stringify({status: 'FAIL', error_type: report.error_type, error_code: report.error_code}));
} finally {
  if (db) await db.end();
  if (created) {
    try {await admin.query(`drop database "${database}" with (force)`); report.database_removed = (await admin.query('select count(*)::int n from pg_catalog.pg_database where datname=$1', [database])).rows[0].n === 0;}
    catch (error) {report.cleanup_error_type = error.constructor.name; code = 1;}
  }
  for (const role of rolesCreated.reverse()) {
    try {await admin.query(`drop role "${role}"`);} catch (error) {report.cleanup_error_type = error.constructor.name; code = 1;}
  }
  if (rolesCreated.length) report.roles_removed = (await admin.query('select count(*)::int n from pg_catalog.pg_roles where rolname = any($1::text[])', [rolesCreated])).rows[0].n === 0;
  await admin.end();
  if (!report.database_removed || !report.roles_removed) code = 1;
  if (code) report.status = 'FAIL';
  report.groups_passed = report.checks.filter(x => x.status === 'PASS').length;
  fs.writeFileSync(path.join(output, 'result.json'), JSON.stringify(report, null, 2) + '\n');
}
console.log(JSON.stringify(report));
process.exitCode = code;
