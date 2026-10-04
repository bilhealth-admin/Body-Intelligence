// Loopback disposable PG17 only. SQL/database boundaries, not a signed build,
// real Storage HTTP byte upload, device UI, StoreKit, or Production evidence.
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn, spawnSync } from 'node:child_process';
const here = dirname(fileURLToPath(import.meta.url));
if (!['127.0.0.1', 'localhost', '::1'].includes(process.env.PGHOST ?? '') ||
    !/^bil_atomic_qa_[a-z0-9_]+$/.test(process.env.PGDATABASE ?? '')) {
  throw new Error('Refusing non-loopback/non-disposable PostgreSQL target');
}
const psql = process.env.BIL_QA_PSQL ?? 'psql';
const args = ['-X', '-qAt', '-v', 'ON_ERROR_STOP=1'];
function run(sql) {
  const result = spawnSync(psql, args, {
    cwd: here, env: process.env, input: sql, encoding: 'utf8', timeout: 45000,
  });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error('Atomic SQL failed\n' + result.stderr);
  return result;
}
function file(name) { return readFileSync(resolve(here, name), 'utf8'); }
const version = Number(run("select current_setting('server_version_num');").stdout.trim());
if (version < 170000 || version >= 180000) throw new Error('PostgreSQL17 required');
if (run("select count(*) from pg_tables where schemaname in ('public','private','auth','storage');").stdout.trim() !== '0') {
  throw new Error('Fixture requires an EMPTY disposable database');
}
run(file('community_atomic_publish_live_baseline.sql'));
run(file('community_atomic_publish_live_moderation.sql'));
run(file('test_community_atomic_publish_seed.sql'));
const before = run(file('test_community_atomic_publish_storage_before.sql'));
if (!before.stdout.includes('ORIGINAL_STORAGE_REPLACEMENT_DEFECT_REPRODUCED')) throw new Error('Missing baseline proof');
console.log('CONFIRMED: original live owner Storage INSERT/DELETE allows approved-path replacement (SQL/RLS boundary)');
if (process.env.BIL_ATOMIC_BEFORE_ONLY === '1') process.exit(0);
function exactFunction(sql, qualified) {
  const match = sql.match(new RegExp('create(?:\\s+or\\s+replace)?\\s+function\\s+' +
    qualified.replaceAll('.', '\\.') + '\\s*\\([\\s\\S]*?\\bas\\s+(\\$[A-Za-z0-9_]*\\$)[\\s\\S]*?\\1\\s*;', 'i'));
  if (!match) throw new Error('Missing exact candidate helper: ' + qualified);
  return match[0];
}
// Genuine candidate changes on this dependency path, not a fake helper.
const forward = file('../../supabase/migrations/20261004073453_community_prebuild_privacy_write_hardening_v1.sql');
run(exactFunction(forward, 'public.bil_guard_community_member_access') + '\n' +
    exactFunction(forward, 'public.bil_upsert_my_community_post_draft_v1'));
run(file('../../supabase/migrations/20261004074954_community_atomic_publish_operation_v1.sql'));
const assertions = run(file('test_community_atomic_publish_isolated.sql'));
if (!assertions.stdout.includes('ATOMIC_FUNCTION_AND_ROLE_ASSERTIONS_PASSED')) throw new Error('Missing atomic proof');
console.log('PASS: atomic genuine dependency/RPC/privacy/media/draft/receipt/budget assertions');

function connection(name) {
  const child = spawn(psql, args, { cwd: here,
    env: { ...process.env, PGAPPNAME: 'bil-atomic-' + name }, stdio: ['pipe', 'pipe', 'pipe'] });
  let stdout = '', stderr = '';
  child.stdout.on('data', data => { stdout += data.toString(); });
  child.stderr.on('data', data => { stderr += data.toString(); });
  const done = new Promise((resolve, reject) => {
    child.on('error', reject);
    child.on('close', code => code === 0 ? resolve(stdout) : reject(new Error(name + '\n' + stderr)));
  });
  done.catch(() => {});
  return { child, done, output: () => stdout };
}
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
async function waitFor(predicate, label) {
  const deadline = Date.now() + 7000;
  while (!predicate()) {
    if (Date.now() > deadline) throw new Error('Timeout: ' + label);
    await delay(20);
  }
}
const owner = '11111111-1111-4111-8111-111111111111';
const identity = "set local statement_timeout='15s'; set local lock_timeout='12s'; set local role authenticated;" +
  "select set_config('request.jwt.claim.sub','" + owner + "',true);" +
  "select set_config('request.jwt.claims','{\"sub\":\"" + owner + "\",\"role\":\"authenticated\"}',true);";
function identityFor(actor) { return identity.replaceAll(owner, actor); }
async function overlap(kind, firstCall, secondCall, verifySql) {
  const a = connection(kind + '-A'); const b = connection(kind + '-B');
  const timeout = setTimeout(() => { a.child.kill(); b.child.kill(); }, 20000);
  try {
    a.child.stdin.write('begin;' + identity + firstCall + "select 'QA_A_READY';\n");
    await waitFor(() => a.output().includes('QA_A_READY'), kind + ' A ready');
    b.child.stdin.end('begin;' + identity + secondCall + 'commit;\n');
    await waitFor(() => Number(run("select count(*) from pg_locks l join pg_stat_activity a on a.pid=l.pid " +
      "where a.application_name='bil-atomic-" + kind + "-B' and l.locktype='advisory' and not l.granted;").stdout.trim()) > 0,
      kind + ' B really waits on operation/owner lock');
    a.child.stdin.end('commit;\n');
    await Promise.all([a.done, b.done]);
    run(verifySql);
    console.log('PASS: overlapping ' + kind + ' serializes via genuine advisory locks');
  } finally {
    clearTimeout(timeout); if (!a.child.killed) a.child.kill(); if (!b.child.killed) b.child.kill();
  }
}
function prepare(id, media = '[]') {
  run('begin;' + identity + "select public.bil_begin_my_community_publish_operation_v1('" + id +
      "',qa_atomic_payload('" + media + "'::jsonb));commit;");
}
function publish(id) {
  return "select public.bil_publish_community_post_operation_v1('" + id + "',qa_atomic_payload());";
}
function abort(id) { return "select public.bil_abort_my_community_publish_operation_v1('" + id + "');"; }
function state(id, expected, posts) {
  return "select qa_atomic_assert((select status='" + expected + "' from private.bil_community_publish_operations_v1 where operation_id='" + id +
    "') and (select count(*)=" + posts + " from public.bil_community_posts where id='" + id + "'),'" + expected + " operation and exact post count');";
}
const concurrentCommit = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000101';
prepare(concurrentCommit);
await overlap('commit-commit', publish(concurrentCommit), publish(concurrentCommit), state(concurrentCommit, 'committed', 1) +
  "select qa_atomic_assert((select sum(hit_count)=1 from public.bil_rate_limit_buckets where user_id='" + owner + "' and action='post'),'Concurrent retries charge post quota exactly once');");
const abortWins = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000102';
prepare(abortWins);
await overlap('abort-commit', abort(abortWins), publish(abortWins), state(abortWins, 'aborted', 0));
const commitWins = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000103';
prepare(commitWins);
await overlap('commit-abort', publish(commitWins),
  "select qa_atomic_assert(public.bil_abort_my_community_publish_operation_v1('" + commitWins +
  "') @> jsonb_build_object('status','committed','committed',true,'post_id','" + commitWins +
  "','payload',qa_atomic_payload()),'Committed abort has the full immutable payload and post receipt');",
  state(commitWins, 'committed', 1));

function image(id) { return owner + '/' + id + '/bbbbbbbb-bbbb-4bbb-8bbb-000000000001.png'; }
function media(id) { return JSON.stringify([{ object_path: image(id), mime_type: 'image/png', bytes: 100, width: 10, height: 10 }]); }
function upload(id) { return "insert into storage.objects(bucket_id,name,owner_id,metadata) values('community-post-images','" +
  image(id) + "','" + owner + "','{\"size\":100,\"mimetype\":\"image/png\"}');"; }
const uploadWins = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000104';
prepare(uploadWins, media(uploadWins));
await overlap('upload-abort', upload(uploadWins), abort(uploadWins), state(uploadWins, 'aborted', 0) +
  "select qa_atomic_assert((select count(*)=1 from storage.objects where name='" + image(uploadWins) + "'),'Abort serialized AFTER in-flight upload');");
run('begin;' + identity + "select set_config('storage.operation','storage.object.get_authenticated',true);" +
  "select set_config('storage.allow_delete_query','true',true);delete from storage.objects where name='" + image(uploadWins) + "';commit;");
run("select qa_atomic_assert(not exists(select 1 from storage.objects where name='" + image(uploadWins) + "'),'Acknowledged abort media cleanup leaves no object');");
const cancelWins = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000105';
prepare(cancelWins, media(cancelWins));
await overlap('abort-upload', abort(cancelWins),
  "select qa_atomic_error($q$" + upload(cancelWins) + "$q$,'42501');",
  state(cancelWins, 'aborted', 0) + "select qa_atomic_assert(not exists(select 1 from storage.objects where name='" + image(cancelWins) + "'),'Late upload after abort cannot leave orphan');");
const missing = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000106';
await overlap('missing-abort-begin', abort(missing),
  "select qa_atomic_assert(public.bil_begin_my_community_publish_operation_v1('" + missing +
  "',qa_atomic_payload())->>'status'='aborted','Delayed begin reads tombstone');", state(missing, 'aborted', 0));

// Regression for a CONFIRMED original-policy inversion: the original Storage
// RLS locks member_state before its new journal guard, whereas the first draft
// RPC locked owner before member_state. Both sessions below execute REAL calls.
const lockOrderId = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000107';
async function memberBeforeBeginStorage() {
  const a = connection('member-order-A'); const b = connection('member-order-B');
  const timeout = setTimeout(() => { a.child.kill(); b.child.kill(); }, 20000);
  try {
    b.child.stdin.write('begin;' + identity + "select public.bil_can_use_community();select 'QA_MEMBER_READY';\n");
    await waitFor(() => b.output().includes('QA_MEMBER_READY'), 'Original member lock acquired');
    a.child.stdin.end('begin;' + identity + "select public.bil_begin_my_community_publish_operation_v1('" + lockOrderId +
      "',qa_atomic_payload('" + media(lockOrderId) + "'::jsonb));commit;\n");
    await waitFor(() => Number(run("select count(*) from pg_locks l join pg_stat_activity a on a.pid=l.pid " +
      "where a.application_name='bil-atomic-member-order-A' and l.locktype='advisory' and not l.granted;").stdout.trim()) > 0,
      'Real begin RPC waits for original member lock');
    b.child.stdin.end(upload(lockOrderId) + 'commit;\n');
    await Promise.all([a.done, b.done]);
    run(state(lockOrderId, 'prepared', 0) + "select qa_atomic_assert((select count(*)=1 from storage.objects where name='" +
      image(lockOrderId) + "'),'Genuine original RLS Storage insert completes before waiting begin RPC');");
    run('begin;' + identity + "select public.bil_publish_community_post_operation_v1('" + lockOrderId +
      "',qa_atomic_payload('" + media(lockOrderId) + "'::jsonb));commit;");
    run(state(lockOrderId, 'committed', 1));
    console.log('PASS: original member-first Storage RLS / begin RPC overlap has no lock inversion');
  } finally {
    clearTimeout(timeout); if (!a.child.killed) a.child.kill(); if (!b.child.killed) b.child.kill();
  }
}
await memberBeforeBeginStorage();

const deletedDuringReceipt = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000108';
prepare(deletedDuringReceipt);
run('begin;' + identity + publish(deletedDuringReceipt) + 'commit;');
await overlap('delete-receipt',
  "select public.bil_delete_community_post('" + deletedDuringReceipt + "');",
  "select qa_atomic_assert(public.bil_begin_my_community_publish_operation_v1('" + deletedDuringReceipt +
  "',qa_atomic_payload()) @> '{\"status\":\"unavailable\",\"committed\":false,\"cleanup_allowed\":false,\"media_paths\":[]}'::jsonb,'Racing canonical deletion cannot produce a false committed receipt');",
  "select qa_atomic_assert((select status='committed' from private.bil_community_publish_operations_v1 where operation_id='" + deletedDuringReceipt +
  "') and (select deleted_at is not null from public.bil_community_posts where id='" + deletedDuringReceipt +
  "'),'Canonical deletion preserved historical journal without current publication success');");

async function inverseRowMember(kind, id, actor, mutation, after) {
  const a = connection(kind + '-A'); const b = connection(kind + '-B');
  const timeout = setTimeout(() => { a.child.kill(); b.child.kill(); }, 20000);
  try {
    b.child.stdin.write('begin;' + identity + "select public.bil_can_use_community();select 'QA_AUTHOR_MEMBER_READY';\n");
    await waitFor(() => b.output().includes('QA_AUTHOR_MEMBER_READY'), kind + ' author member held');
    a.child.stdin.end('begin;' + identityFor(actor) + mutation + 'commit;\n');
    await waitFor(() => Number(run("select count(*) from pg_locks l join pg_stat_activity a on a.pid=l.pid " +
      "where a.application_name='bil-atomic-" + kind + "-A' and l.locktype='advisory' and not l.granted;").stdout.trim()) > 0,
      kind + ' genuine row mutation waits for author member');
    // While A's canonical mutation is uncommitted, its old row is the TRUE
    // MVCC-visible post. This must read without waiting for A's row lock.
    b.child.stdin.end("select qa_atomic_assert(public.bil_begin_my_community_publish_operation_v1('" + id +
      "',qa_atomic_payload())->>'committed'='true','Single MVCC projection truth before mutation commits');commit;\n");
    await Promise.all([a.done, b.done]);
    run(after);
    console.log('PASS: inverse ' + kind + ' uses truthful MVCC projection, no member/post row deadlock');
  } finally {
    clearTimeout(timeout); if (!a.child.killed) a.child.kill(); if (!b.child.killed) b.child.kill();
  }
}
const inverseDelete = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000109';
prepare(inverseDelete); run('begin;' + identity + publish(inverseDelete) + 'commit;');
await inverseRowMember('canonical-delete-receipt', inverseDelete, owner,
  "select qa_atomic_assert(public.bil_delete_community_post('" + inverseDelete + "'),'Genuine canonical owner deletion');",
  'begin;' + identity + "select qa_atomic_assert(public.bil_begin_my_community_publish_operation_v1('" + inverseDelete +
  "',qa_atomic_payload()) @> '{\"status\":\"unavailable\",\"committed\":false,\"cleanup_allowed\":false,\"media_paths\":[]}'::jsonb,'Deletion committed: no false current committed receipt');commit;");
const inverseModeration = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000110';
prepare(inverseModeration); run('begin;' + identity + publish(inverseModeration) + 'commit;');
await inverseRowMember('moderator-approval-receipt', inverseModeration, '33333333-3333-4333-8333-333333333333',
  "select public.bil_moderate_community_post('" + inverseModeration + "','approved');",
  'begin;' + identity + "select qa_atomic_assert(public.bil_begin_my_community_publish_operation_v1('" + inverseModeration +
  "',qa_atomic_payload())->>'committed'='true','Actual human approval preserves submitted-content receipt');commit;" +
  "select qa_atomic_assert((select moderation_status='approved' from public.bil_community_posts where id='" + inverseModeration +
  "') and (select count(*)=1 from public.bil_community_post_approval_grants where post_id='" + inverseModeration +
  "'),'Genuine approval and server reward receipt commit once');");

for (let i = 1; i <= 7; i++) prepare('cccccccc-cccc-4ccc-8ccc-' + String(i).padStart(12, '0'));
const capA = 'cccccccc-cccc-4ccc-8ccc-000000000008';
const capB = 'cccccccc-cccc-4ccc-8ccc-000000000009';
await overlap('prepared-cap',
  "select public.bil_begin_my_community_publish_operation_v1('" + capA + "',qa_atomic_payload());",
  "select qa_atomic_error($q$select public.bil_begin_my_community_publish_operation_v1('" + capB +
  "',qa_atomic_payload())$q$,'54000','community_publish_prepared_limit');",
  "select qa_atomic_assert((select count(*)=8 from private.bil_community_publish_operations_v1 where owner_id='" + owner +
  "' and status='prepared'),'Concurrent prepared reservations cannot exceed eight');");
console.log('ISOLATED_PG17_ATOMIC_PASS -- NOT Production/device/Storage HTTP/build/store evidence');
