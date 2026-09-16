// Executes the real notification-claim function in local, in-memory PostgreSQL.
// No Supabase client, credentials, network connection, or persisted database.
// PGlite serializes queries; this does not prove independent-session concurrency.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';

const latestMigration = '20260916103000_retryable_store_notification_leases.sql';
// Execute the complete actual migration: the legacy four-argument RPC now
// delegates to the five-argument lease implementation and needs its schema.
const migrationSql = readFileSync(new URL(`../migrations/${latestMigration}`, import.meta.url), 'utf8');

const db = new PGlite();
const payloadDigest = 'a'.repeat(64);
let checks = 0;
const claim = async (notificationId) => {
  const result = await db.query(
    'select public.bil_claim_store_notification($1,$2,$3,$4) as claimed',
    ['apple', notificationId, payloadDigest, 'sandbox'],
  );
  return result.rows[0].claimed;
};
async function check(name, run) {
  await run();
  console.log(`PASS ${++checks}: ${name}`);
}

try {
  await db.exec(`
    create role anon;
    create role authenticated;
    create role service_role;
    create schema auth;
    create function auth.jwt() returns jsonb language sql stable as $$
      select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb
    $$;
    select set_config('request.jwt.claims','{"role":"service_role"}',false);
    create table public.bil_store_notification_inbox (
      provider text not null check (provider in ('google','apple')),
      notification_id text not null,
      payload_digest text not null,
      environment text,
      status text not null default 'received'
        check (status in ('received','processed','rejected','error')),
      received_at timestamptz not null default now(),
      processed_at timestamptz,
      primary key (provider, notification_id)
    );
  `);
  const baseline = readFileSync(new URL('../migrations/202608040004_bil_store_entitlement_truth.sql', import.meta.url), 'utf8');
  const originalClaim = baseline.match(/create or replace function public\.bil_claim_store_notification\([\s\S]*?\bas\s+(\$[a-zA-Z0-9_]*\$)[\s\S]*?\1\s*;/i);
  assert.ok(originalClaim, 'actual legacy claim definition required for drift guard');
  await db.exec(originalClaim[0]);
  await db.exec(migrationSql);
  console.log(`Loaded actual claim function from ${latestMigration}`);

  await check('first Apple notification delivery is claimed', async () => {
    assert.equal(await claim('first-delivery'), true);
    const { rows } = await db.query(
      'select status from public.bil_store_notification_inbox where provider=$1 and notification_id=$2',
      ['apple', 'first-delivery'],
    );
    assert.equal(rows.length, 1);
    assert.equal(rows[0].status, 'received');
  });

  await check('successfully processed Apple notification is not claimed twice', async () => {
    const id = 'already-processed-delivery';
    assert.equal(await claim(id), true);
    await db.query(
      "update public.bil_store_notification_inbox set status='processed', processed_at=now() where provider=$1 and notification_id=$2",
      ['apple', id],
    );
    assert.equal(await claim(id), false);
  });

  await check('failed processing permits a retry with the same Apple notification UUID', async () => {
    const id = 'failed-then-retried-delivery';
    assert.equal(await claim(id), true);
    // Mirrors markStoreNotification(..., 'error') after a transient verifier
    // failure. Apple's redelivery retains exactly the same notification UUID.
    await db.query(
      "update public.bil_store_notification_inbox set status='error', processed_at=now() where provider=$1 and notification_id=$2",
      ['apple', id],
    );
    assert.equal(
      await claim(id),
      true,
      'An errored Apple notification must be retryable, not acknowledged as a completed duplicate',
    );
  });

  console.log(`PASS: ${checks} Apple notification retry PostgreSQL regression checks`);
} finally {
  await db.close();
}
