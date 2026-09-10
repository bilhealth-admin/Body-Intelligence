import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';

// Isolated PostgreSQL contract: actual repository RPCs, RLS and triggers;
// synthetic accounts only. No Supabase credentials, network or device.
const db = new PGlite();
const read = (name) => readFileSync(`supabase/migrations/${name}.sql`, 'utf8');
const migration = read('20260910090403_community_and_friendships_free');
const foundation = read('202608020002_bil_community_foundation');
const completion = read('202608040002_bil_community_cloud_completion');
const admin = read('20260905160000_admin_community_access_control');
const social = read('20260908013800_bil_community_social_v2');
const uid = (n) => `16000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
let checks = 0;
const value = async (sql, args = []) => (await db.query(sql, args)).rows[0]?.value;
async function check(name, fn) { await fn(); console.log(`PASS ${++checks}: ${name}`); }
function functionSql(source, name) {
  const start = source.search(new RegExp(`create (?:or replace )?function public\\.${name}\\(`, 'i'));
  assert.notEqual(start, -1, `real function ${name} must exist`);
  const rest = source.slice(start);
  const delimiter = rest.match(/\bas\s+(\$(?:[a-z_]+)?\$)/i);
  assert.ok(delimiter, `function delimiter for ${name}`);
  const end = rest.indexOf(`${delimiter[1]};`, delimiter.index + delimiter[0].length);
  assert.notEqual(end, -1, `function terminator for ${name}`);
  return rest.slice(0, end + delimiter[1].length + 1);
}
async function actor(n, role = 'authenticated') {
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claim.sub', $1, false)", [n ? uid(n) : '']);
  if (role !== 'postgres') await db.exec(`set role ${role}`);
}
const request = (n) => value('select public.bil_social_request_friend_v2($1) as value', [uid(n)]);
async function securitySnapshot() {
  return (await db.query(`select c.relname, c.relrowsecurity, c.relacl::text,
    (select jsonb_agg(to_jsonb(p) order by policyname) from pg_policies p
     where p.schemaname='public' and p.tablename=c.relname) policies
    from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind='r' order by c.relname`)).rows;
}

try {
  await db.exec(`create role anon; create role authenticated; create role service_role;
    create schema auth; create schema private;
    create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql stable as
      $$select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid$$;
    grant usage on schema auth, public to anon, authenticated, service_role;
    create table private.bil_community_member_access(user_id uuid primary key, suspended boolean not null);
    create table private.bil_ai_coach_admins(user_id uuid primary key, active boolean not null);
    create table public.bil_entitlements(owner_id uuid, entitlement_id text, active boolean, expires_at timestamptz);
    create table public.bil_subscriptions(owner_id uuid, plan_id text, lifecycle text, grace_period_ends_at timestamptz, expires_at timestamptz);
    create table public.bil_rate_limit_buckets(user_id uuid, action text,
      window_started_at timestamptz, hit_count integer default 1,
      primary key(user_id, action, window_started_at));
  `);
  await db.exec(foundation);
  await db.exec(`alter table public.bil_public_profiles add column allow_friend_requests boolean default true;
    create unique index bil_friendships_unordered_pair_idx on public.bil_friendships
      (least(requester_id,addressee_id),greatest(requester_id,addressee_id));`);
  for (const [source, names] of [
    [completion, ['bil_request_friendship']],
    [read('20260908182300_harden_shared_diary_read_access'), ['bil_consume_rate_limit']],
    [admin, ['bil_can_use_community', 'bil_guard_community_member_access']],
    [social, ['bil_social_member_visible_v2', 'bil_social_request_friend_v2']],
  ]) for (const name of names) await db.exec(functionSql(source, name));
  await db.exec(read('20260822063821_premium_community_friendships'));
  await db.exec(read('20260906110000_admin_community_friendship_access'));
  await db.exec(`create trigger bil_00_friendships_member_access before insert or update of status
    on public.bil_friendships for each row execute function public.bil_guard_community_member_access();
    revoke all on function public.bil_request_friendship(uuid), public.bil_social_request_friend_v2(uuid)
      from public, anon, authenticated;
    grant execute on function public.bil_request_friendship(uuid), public.bil_social_request_friend_v2(uuid)
      to authenticated;`);
  await db.exec(read('20260908182400_harden_friendship_write_contract'));
  for (let n = 1; n <= 32; n++) {
    await db.query('insert into auth.users values($1)', [uid(n)]);
    await db.query('insert into public.bil_public_profiles(user_id,display_name) values($1,$2)', [uid(n), `Test Member ${n}`]);
  }
  await actor(1);
  await check('baseline proves a Free request is rejected by the legacy payment trigger', async () => {
    await assert.rejects(request(2), /premium_required/);
  });
  await actor(null, 'postgres');
  const before = await securitySnapshot();
  await db.exec(migration);
  await check('migration preserves all table grants and row visibility policies', async () => {
    assert.deepEqual(await securitySnapshot(), before);
    assert.equal(await value('select count(*)::int as value from public.bil_entitlements'), 0);
    assert.equal(await value('select count(*)::int as value from public.bil_subscriptions'), 0);
  });
  await check('Free member can request, and duplicates keep the same pending relationship', async () => {
    await actor(1);
    assert.equal(await request(2), 'pending');
    assert.equal(await request(2), 'pending');
    assert.equal(await value('select count(*)::int as value from public.bil_friendships'), 1);
  });
  await check('requester cannot accept their own request', async () => {
    const result = await db.query("update public.bil_friendships set status='accepted', responded_at=now() returning id");
    assert.equal(result.rows.length, 0);
  });
  await check('only the Free recipient can accept, with a server timestamp', async () => {
    await actor(2);
    assert.equal(await request(1), 'incoming');
    const result = await db.query("update public.bil_friendships set status='accepted',responded_at='2000-01-01' returning status,responded_at");
    assert.equal(result.rows[0].status, 'accepted');
    assert.ok(new Date(result.rows[0].responded_at) > new Date('2026-01-01'));
    assert.equal(await request(1), 'accepted');
  });
  await check('a third member cannot read or change a private friendship', async () => {
    await actor(3);
    assert.equal(await value('select count(*)::int as value from public.bil_friendships'), 0);
    assert.equal((await db.query("update public.bil_friendships set status='declined' returning id")).rows.length, 0);
  });
  await check('legacy Free clients can insert pending requests, not impersonate or pre-accept', async () => {
    await actor(3);
    await db.query('insert into public.bil_friendships(requester_id,addressee_id) values($1,$2)', [uid(3), uid(4)]);
    await assert.rejects(db.query('insert into public.bil_friendships(requester_id,addressee_id) values($1,$2)', [uid(4), uid(5)]), /invalid_friendship_request|row-level security/);
    await assert.rejects(db.query("insert into public.bil_friendships(requester_id,addressee_id,status) values($1,$2,'accepted')", [uid(3), uid(5)]), /permission denied/);
  });
  await check('Free recipients can decline and cannot later overwrite that decision', async () => {
    await actor(4);
    const result = await db.query("update public.bil_friendships set status='declined',responded_at=now() returning status");
    assert.equal(result.rows[0].status, 'declined');
    assert.equal((await db.query("update public.bil_friendships set status='accepted' returning id")).rows.length, 0);
  });
  await check('anonymous calls and missing identities remain denied', async () => {
    await actor(null, 'anon');
    await assert.rejects(request(2), /permission denied/);
    await actor(null);
    await assert.rejects(request(2), /relationship_unavailable/);
  });
  await check('blocks in either direction still prevent requests', async () => {
    await actor(null, 'postgres');
    await db.query('insert into public.bil_blocks(blocker_id,blocked_id) values($1,$2)', [uid(5), uid(6)]);
    await actor(5); await assert.rejects(request(6), /relationship_unavailable/);
    await actor(6); await assert.rejects(request(5), /relationship_unavailable/);
  });
  await check('suspension still blocks actor and recipient without a payment exception', async () => {
    await actor(null, 'postgres');
    await db.query('insert into private.bil_community_member_access values($1,true)', [uid(7)]);
    await actor(7); await assert.rejects(request(8), /relationship_unavailable/);
    await actor(8); await assert.rejects(request(7), /relationship_unavailable/);
  });
  await check('recipient opt-out and self-request checks remain enforced', async () => {
    await actor(null, 'postgres');
    await db.query('update public.bil_public_profiles set allow_friend_requests=false where user_id=$1', [uid(9)]);
    await actor(8); await assert.rejects(request(9), /friend requests disabled/);
    await assert.rejects(request(8), /relationship_unavailable/);
  });
  await check('Free requests still consume the real server rate limit', async () => {
    await actor(10);
    for (let n = 11; n <= 30; n++) assert.equal(await request(n), 'pending');
    await assert.rejects(request(31), /rate limit exceeded/);
  });
  await check('reapplying the migration preserves friendships and keeps safety guards', async () => {
    await actor(null, 'postgres');
    const rows = (await db.query('select * from public.bil_friendships order by id')).rows;
    await db.exec(migration);
    assert.deepEqual((await db.query('select * from public.bil_friendships order by id')).rows, rows);
    assert.equal(await value("select count(*)::int as value from pg_trigger where tgrelid='public.bil_friendships'::regclass and tgname in ('bil_000_friendships_write_contract','bil_00_friendships_member_access') and tgenabled='O'"), 2);
    assert.equal(await value("select to_regprocedure('public.bil_require_premium_friendship()') is null as value"), true);
    assert.equal(await value("select public.bil_has_active_premium($1) as value", [uid(1)]), false);
  });
  console.log(`All ${checks} Free Community PostgreSQL checks passed.`);
} finally { await db.close(); }
