// LOCAL ONLY: exact LIVE SQL -> same failing regression -> exact forward SQL.
// No Flutter/build, provider HTTP, credentials, personal rows or Production target.
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync, spawn } from 'node:child_process';
import { createHash } from 'node:crypto';

const here = dirname(fileURLToPath(import.meta.url));
if (!['127.0.0.1', 'localhost', '::1'].includes(process.env.PGHOST ?? '') ||
    !/^bil_notification_qa_[a-z0-9_]+$/.test(process.env.PGDATABASE ?? '')) {
  throw new Error('Refusing non-loopback/non-disposable notification fixture target');
}
const psql = process.env.BIL_QA_PSQL ?? 'psql';
const args = ['-X', '-qAt', '-v', 'ON_ERROR_STOP=1'];
function run(sql, variables = [], expectedFailure = false) {
  const result = spawnSync(psql, [...args, ...variables.flatMap(([key, value]) => ['-v', key + '=' + value])], {
    cwd: here, env: process.env, input: sql, encoding: 'utf8', timeout: 30000,
  });
  if (result.error) throw new Error('psql process failed: ' + result.error.message);
  if (!expectedFailure && result.status !== 0) throw new Error('isolated SQL failed\n' + result.stderr);
  return result;
}
const version = Number(run("select current_setting('server_version_num');").stdout.trim());
if (version < 170000 || version >= 180000) throw new Error('PostgreSQL17 required');
if (run("select count(*) from pg_tables where schemaname in ('public','private','auth');").stdout.trim() !== '0') {
  throw new Error('Fixture requires an empty disposable database; never overwrites another run');
}
const baseline = readFileSync(resolve(here, 'community_push_preferences_live_baseline.sql'));
const provenance = JSON.parse(readFileSync(resolve(here, 'community_push_preferences_live_provenance.json'), 'utf8'));
const baselineHash = createHash('sha256').update(baseline).digest('hex');
if (baselineHash !== provenance.baseline_sha256) throw new Error('Exact LIVE baseline/provenance bytes disagree');
console.log('LIVE_FUNCTION_BASELINE_SHA256:' + baselineHash);
const seed = readFileSync(resolve(here, 'test_notification_delivery_preferences_seed.sql'), 'utf8');
if (!seed.includes('-- EXACT_LIVE_FUNCTION_BASELINE')) throw new Error('Missing exact baseline marker');
run(seed.replace('-- EXACT_LIVE_FUNCTION_BASELINE', () => baseline.toString('utf8')));
for (const evidence of provenance.functions) {
  const observed = run("select md5(pg_get_functiondef('" + evidence.signature + "'::regprocedure));").stdout.trim();
  if (observed !== evidence.definition_md5) throw new Error('LIVE function body identity mismatch: ' + evidence.signature);
}
console.log('PASS: all 10 verbatim LIVE function identities match the read-only metadata snapshot');
const retry = readFileSync(resolve(here, 'test_notification_delivery_preferences_retry.sql'), 'utf8');
const categories = [
  ['message', 'message_fixture_v1'],
  ['friend_request', 'friend_request_fixture_v1'],
  ['community', 'friend_accepted_v1'],
];
for (const [category, copy] of categories) {
  const result = run(retry, [['category', category], ['copy_key', copy]], true);
  if (result.status === 0 || !result.stderr.includes('QA_ASSERTION: retry must honor committed category opt-out')) {
    throw new Error('Baseline did not reproduce the EXACT product defect for ' + category + '\n' + result.stderr);
  }
  console.log('EXPECTED_PRODUCT_FAILURE: ' + category + ' existing retry remains claimable after real owner opt-out');
  process.stdout.write(result.stderr);
}
if (process.argv.includes('--baseline-only')) {
  console.log('BASELINE_REPRODUCTION_COMPLETE; forward repair NOT tested');
  process.exit(0);
}
const migrationNames = readdirSync(resolve(here, '../../supabase/migrations'))
  .filter(name => /^\d+_notification_delivery_preferences_authority_v1\.sql$/.test(name));
if (migrationNames.length !== 1) throw new Error('Expected exactly one notification authority forward migration');
const migration = readFileSync(resolve(here, '../../supabase/migrations', migrationNames[0]));
console.log('AUDITED_MIGRATION:' + migrationNames[0]);
console.log('AUDITED_MIGRATION_SHA256:' + createHash('sha256').update(migration).digest('hex'));
// Real legacy registration creates divergent active devices before migration.
// Inactive-only and zero-token owners must NOT acquire inferred durable opt-in.
run(`begin; set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select public.bil_register_push_token_v2('fixture-only-divergent-device-one','fcm','UTC',false,true,false,false);
select public.bil_register_push_token_v2('fixture-only-divergent-device-two','apns','UTC',false,false,true,false);
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select public.bil_register_push_token_v2('fixture-only-inactive-device-one','fcm','UTC',false,false,false,false);
select public.bil_disable_push_tokens(); commit;`);
run(migration.toString('utf8'));
for (const [category, copy] of categories) {
  const result = run(retry, [['category', category], ['copy_key', copy]]);
  if (!result.stdout.includes('RETRY_CATEGORY_OPT_OUT_ASSERTIONS_PASS')) throw new Error('Missing post-repair completion');
  console.log('PASS: same exact queued-' + category + ' opt-out regression');
}
const assertions = run(readFileSync(resolve(here, 'test_notification_delivery_preferences_isolated.sql'), 'utf8'));
if (!assertions.stdout.includes('AUTHORITATIVE_OWNER_PREFERENCE_ASSERTIONS_PASS')) throw new Error('Missing strict SQL completion');
console.log('PASS: 28 strict ordinary-role/readback/security assertions');

const owner = '11111111-1111-4111-8111-111111111111';
const identity = "set local role authenticated; select set_config('request.jwt.claim.sub','" + owner + "',true);";
function connection(name) {
  const child = spawn(psql, args, {
    cwd: here, env: { ...process.env, PGAPPNAME: 'bil-notification-' + name },
    stdio: ['pipe', 'pipe', 'pipe'],
  });
  let stdout = '', stderr = '';
  child.stdout.on('data', chunk => { stdout += chunk.toString(); });
  child.stderr.on('data', chunk => { stderr += chunk.toString(); });
  const done = new Promise((resolve, reject) => {
    child.on('error', reject);
    child.on('close', code => code === 0 ? resolve(stdout) : reject(new Error(stderr)));
  });
  done.catch(() => {});
  return { child, done, output: () => stdout, errors: () => stderr };
}
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
async function waitFor(predicate, label) {
  const deadline = Date.now() + 5000;
  while (!predicate()) {
    if (Date.now() > deadline) throw new Error('Timeout: ' + label);
    await delay(20);
  }
}
async function overlapping(name, first, second, expectedConflict = false) {
  const a = connection(name + '-A');
  const b = connection(name + '-B');
  const deadline = setTimeout(() => { a.child.kill(); b.child.kill(); }, 15000);
  try {
    // A holds the lock through the ACTUAL RPC. B must observably wait at that
    // same owner guard; no manual advisory lock or guessed pg_sleep barrier.
    a.child.stdin.write("begin; set local statement_timeout='10s'; " + identity + first + "select 'QA_A_READY';\n");
    await waitFor(() => a.output().includes('QA_A_READY'), name + ' first RPC completed');
    b.child.stdin.end("\\set VERBOSITY verbose\nbegin; set local statement_timeout='10s'; " + second + 'commit;\n');
    await waitFor(() => Number(run("select count(*) from pg_locks lock join pg_stat_activity activity on activity.pid=lock.pid " +
      "where activity.application_name='bil-notification-" + name + "-B' and lock.locktype='advisory' and not lock.granted;").stdout.trim()) > 0,
    name + ' second real RPC waits');
    a.child.stdin.end('commit;\n');
    await a.done;
    let conflict = false;
    try { await b.done; } catch (error) {
      if (!expectedConflict || !b.errors().includes('40001: push_delivery_preferences_conflict')) throw error;
      conflict = true;
    }
    if (conflict !== expectedConflict) throw new Error('Unexpected CAS conflict outcome: ' + name);
    return b.output();
  } finally {
    clearTimeout(deadline);
    if (a.child.exitCode === null) a.child.kill();
    if (b.child.exitCode === null) b.child.kill();
  }
}
function assertOwner(envelope, label) {
  run('begin; ' + identity + "select public.qa_push_assert(public.bil_get_my_push_delivery_categories_v1() @> '" +
    JSON.stringify({ owner_id: owner, initialized: true, synchronized: true, ...envelope }) +
    "'::jsonb,'" + label + "'); rollback;");
}
await overlapping('cas',
  'select public.bil_set_my_push_delivery_categories_v1(false,true,false,1);',
  identity + 'select public.bil_set_my_push_delivery_categories_v1(true,false,false,1);', true);
assertOwner({ revision: 2, message_enabled: false, friend_request_enabled: true, friend_accepted_enabled: false },
  'stale device CAS does not reset first committed category opt-out');
console.log('PASS: actual same-owner overlapping device writes commit once; stale snapshot rejects40001');

await overlapping('register',
  'select public.bil_set_my_push_delivery_categories_v1(false,false,false,2);',
  identity + "select public.bil_register_push_token_v2('fixture-only-concurrent-rotated-device','fcm','UTC',false,true,true,true);");
assertOwner({ revision: 3, message_enabled: false, friend_request_enabled: false, friend_accepted_enabled: false,
  effective_message_enabled: false, effective_friend_request_enabled: false, effective_friend_accepted_enabled: false },
  'waiting token rotation uses the committed owner opt-out rather than stale client defaults');
console.log('PASS: actual overlapping opt-out/registration preserves durable OFF and revision');

run('begin; ' + identity + 'select public.bil_set_my_push_delivery_categories_v1(true,true,true,3); commit;');
run("begin; insert into public.bil_push_outbox(id,recipient_id,category,copy_key) " +
  "values('cccccccc-cccc-4ccc-8ccc-ccccccccccc1','" + owner + "','message','message_fixture_v1'); " +
  "set local role service_role; do $claim$ declare row record; count_claimed integer:=0; begin " +
  "for row in select * from public.bil_claim_push_deliveries('cccccccc-cccc-4ccc-8ccc-ccccccccccc1',60) loop " +
  "count_claimed:=count_claimed+1; perform public.bil_record_push_delivery_result('cccccccc-cccc-4ccc-8ccc-ccccccccccc1'," +
  "row.device_token_id,false,'fixture_network_failure',false); end loop; " +
  "perform public.qa_push_assert(count_claimed=3,'all three actual registered devices created failed retry attempts'); end $claim$; " +
  "reset role; update public.bil_push_delivery_attempts set next_attempt_at=clock_timestamp() " +
  "where outbox_id='cccccccc-cccc-4ccc-8ccc-ccccccccccc1'; commit;");
const claimOutput = await overlapping('claim',
  'select public.bil_set_my_push_delivery_categories_v1(false,false,false,4);',
  "set local role service_role; select 'CLAIM_COUNT:'||count(*) from public.bil_claim_push_deliveries('cccccccc-cccc-4ccc-8ccc-ccccccccccc1',60);");
if (!claimOutput.includes('CLAIM_COUNT:0')) throw new Error('Waiting retry ignored committed opt-out');
assertOwner({ revision: 5, message_enabled: false, friend_request_enabled: false, friend_accepted_enabled: false },
  'waiting service claim observes the committed opt-out revision');
run("select public.qa_push_assert((select count(*)=3 and bool_and(attempt_count=1) from public.bil_push_delivery_attempts " +
  "where outbox_id='cccccccc-cccc-4ccc-8ccc-ccccccccccc1'),'waiting opt-out retries consume no extra attempts');");
console.log('PASS: actual overlapping opt-out/service retry serializes and claims zero devices');
console.log('ISOLATED_NOTIFICATION_DELIVERY_AUTHORITY_PASS; NO Production/provider/device delivery tested');

