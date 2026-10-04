// Ordinary-role collaborator projection proof in an EMPTY loopback PG17 database.
// No Production URI, network SDK, Flutter, build, or genuine-device claim.
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';

const here = dirname(fileURLToPath(import.meta.url));
if (!['127.0.0.1', 'localhost', '::1'].includes(process.env.PGHOST ?? '') ||
    !/^bil_collab_qa_[a-z0-9_]+$/.test(process.env.PGDATABASE ?? '')) {
  throw new Error('Refusing non-loopback/non-disposable PostgreSQL target');
}
const psql = process.env.BIL_QA_PSQL ?? 'psql';
const args = ['-X', '-qAt', '-v', 'ON_ERROR_STOP=1'];
function read(name) { return readFileSync(resolve(here, name), 'utf8'); }
function run(sql) {
  const result = spawnSync(psql, args, {
    cwd: here, env: process.env, input: sql, encoding: 'utf8', timeout: 30000,
  });
  if (result.error) throw result.error;
  process.stdout.write(result.stderr ?? '');
  if (result.status !== 0) throw new Error('Collaborator SQL failed\n' + result.stderr);
  return result;
}
function exactFunction(file, name) {
  const sql = read('../../supabase/migrations/' + file);
  const qualified = name.includes('.') ? name : 'public.' + name;
  const match = sql.match(new RegExp('create(?:\\s+or\\s+replace)?\\s+function\\s+' +
    qualified.replaceAll('.', '\\.') +
    '\\s*\\([\\s\\S]*?\\bas\\s+(\\$[A-Za-z0-9_]*\\$)[\\s\\S]*?\\1\\s*;', 'i'));
  if (!match) throw new Error('Missing unchanged real function: ' + name);
  return match[0];
}
const version = Number(run("select current_setting('server_version_num');").stdout.trim());
if (version < 170000 || version >= 180000) throw new Error('PostgreSQL17 required');
if (run("select count(*) from pg_tables where schemaname in ('public','private','auth','storage');").stdout.trim() !== '0') {
  throw new Error('Fixture requires an EMPTY disposable database');
}
const baseline = read('community_atomic_publish_live_baseline.sql');
console.log('UNCHANGED_LIVE_BASELINE_SHA256:' + createHash('sha256').update(baseline).digest('hex'));
run(baseline);
run(read('community_atomic_publish_live_moderation.sql'));
run(exactFunction('20260908013800_bil_community_social_v2.sql', 'bil_social_profile_visible_v2') + '\n' +
  exactFunction('20261003211000_community_reference_composer_persistence_v1.sql', 'bil_community_post_reference_metadata_v1') + '\n' +
  exactFunction('20261003212000_community_reference_collaboration_activity_v1.sql', 'bil_respond_community_collaboration_v1') + '\n' +
  exactFunction('20261004073453_community_prebuild_privacy_write_hardening_v1.sql', 'bil_guard_community_member_access') + '\n' +
  'revoke all on function public.bil_social_profile_visible_v2(uuid) from public,anon,authenticated,service_role;\n' +
  'revoke all on function public.bil_community_post_reference_metadata_v1(uuid[]),public.bil_respond_community_collaboration_v1(uuid,boolean) from public,anon,authenticated,service_role;\n' +
  'grant execute on function public.bil_community_post_reference_metadata_v1(uuid[]),public.bil_respond_community_collaboration_v1(uuid,boolean) to authenticated;');
// These fingerprints were read from actual Production pg_get_functiondef on
// 2026-10-04 17:03:37 UTC. Only CRLF normalization is allowed for Git checkout.
const expected = [
  ['public.bil_community_post_reference_metadata_v1(uuid[])', 'f894809c60bbcea757f94db5feeb9ee8'],
  ['public.bil_social_member_visible_v2(uuid)', 'bff4a47d46555d2856374ce5b0f97317'],
  ['public.bil_social_profile_visible_v2(uuid)', '5b8631f8adb24ac5107c6190cb9137e7'],
  ['public.bil_social_post_visible_v2(uuid)', 'a0f4f2fc39c2db661685b8ba27623f18'],
  ['private.bil_resolve_community_moderation_authority(uuid)', 'fa473bfe2a2a2cba6170f782232b189a'],
  ['public.bil_respond_community_collaboration_v1(uuid,boolean)', 'f574fcc3bfb359a040fb1fe00e94b136'],
];
for (const [signature, md5] of expected) {
  const actual = run("select md5(replace(pg_get_functiondef('" + signature + "'::regprocedure),chr(13),''));").stdout.trim();
  if (actual !== md5) throw new Error('Live-definition prerequisite mismatch: ' + signature + ' ' + actual);
  console.log('EXACT_LIVE_FUNCTION_MD5:' + signature + ':' + actual);
}
const preserved = run("select oid::text||':'||proowner::text||':'||proacl::text||':'||proconfig::text " +
  "from pg_proc where oid='public.bil_community_post_reference_metadata_v1(uuid[])'::regprocedure;").stdout.trim();
if (process.env.BIL_COLLAB_BEFORE_ONLY !== '1') {
  const forward = read('../../supabase/migrations/20261004170806_community_collaborator_projection_privacy_v1.sql');
  console.log('COLLABORATOR_PRIVACY_FORWARD_SHA256:' + createHash('sha256').update(forward).digest('hex'));
  run('begin;\n' + forward + '\ncommit;');
  const after = run("select oid::text||':'||proowner::text||':'||proacl::text||':'||proconfig::text " +
    "from pg_proc where oid='public.bil_community_post_reference_metadata_v1(uuid[])'::regprocedure;").stdout.trim();
  if (after !== preserved) throw new Error('Forward changed function identity/owner/ACL/search_path');
  console.log('PASS: function identity, owner, exact ACL, and empty search_path unchanged');
}
const fixture = read('test_community_collaborator_privacy_isolated.sql');
const proof = run(fixture.replace('-- COLLAB_PRIVACY_EXACT_SEED', () => read('test_community_atomic_publish_seed.sql')));
if (!proof.stdout.includes('COLLABORATOR_PRIVACY_ROLE_ASSERTIONS_PASSED')) throw new Error('Missing strict SQL completion marker');
if (run('select count(*) from auth.users;').stdout.trim() !== '0') throw new Error('Synthetic identity residue after rollback');
run("do $$ declare t record; n bigint; begin for t in select schemaname,tablename from pg_tables " +
  "where schemaname in ('public','private','auth','storage') loop execute format('select count(*) from %I.%I',t.schemaname,t.tablename) into n; " +
  "if n<>0 then raise exception 'Fixture residue in %.%: %',t.schemaname,t.tablename,n; end if; end loop; end $$;");
console.log('PASS: zero synthetic rows in every fixture auth/public/private/storage table after rollback');
console.log('ISOLATED_COLLABORATOR_PRIVACY_PASS -- SQL/ordinary roles only; NOT Production/device proof');
