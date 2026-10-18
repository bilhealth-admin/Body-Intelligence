import { PGlite } from "npm:@electric-sql/pglite@0.3.15";
import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
Deno.test("translation quota executes with real Postgres owner, privilege and fixed limits", async () => {
  const db = new PGlite();
  try {
    await db.exec(`create role anon; create role authenticated;
      create schema auth;
      create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
      create table public.bil_rate_limit_buckets(user_id uuid not null, action text not null, window_started_at timestamptz not null, hit_count int not null, primary key(user_id,action,window_started_at));
      alter table public.bil_rate_limit_buckets enable row level security;
      revoke all on public.bil_rate_limit_buckets from public,anon,authenticated;`);
    await db.exec(
      await Deno.readTextFile(
        new URL(
          "../migrations/20261018030056_community_translation_quota_20261018.sql",
          import.meta.url,
        ),
      ),
    );
    await db.exec("set role anon");
    await assertRejects(
      () => db.query("select public.bil_consume_community_translation_quota()"),
      Error,
      "permission denied",
    );
    await db.exec("set role authenticated");
    await assertRejects(
      () => db.query("select public.bil_consume_community_translation_quota()"),
      Error,
      "authentication_required",
    );
    await db.exec(
      "set request.jwt.claim.sub='49000000-0000-4000-8000-000000000001'",
    );
    for (let i = 0; i < 10; i++) {
      await db.query("select public.bil_consume_community_translation_quota()");
    }
    await assertRejects(
      () => db.query("select public.bil_consume_community_translation_quota()"),
      Error,
      "rate limit exceeded",
    );
    await assertRejects(
      () => db.query("select * from public.bil_rate_limit_buckets"),
      Error,
      "permission denied",
    );
    await db.exec(
      "set request.jwt.claim.sub='49000000-0000-4000-8000-000000000002'",
    );
    await db.query("select public.bil_consume_community_translation_quota()");
    await db.exec("reset role");
    const counts = await db.query<{ user_id: string; hits: number }>(
      "select user_id,sum(hit_count)::int hits from public.bil_rate_limit_buckets group by user_id order by user_id",
    );
    assertEquals(counts.rows.map((r) => r.hits), [20, 2]);
    await db.exec(
      "update public.bil_rate_limit_buckets set hit_count=60 where action='community_translation_hour' and user_id='49000000-0000-4000-8000-000000000002'; set role authenticated",
    );
    await assertRejects(
      () => db.query("select public.bil_consume_community_translation_quota()"),
      Error,
      "rate limit exceeded",
    );
  } finally {
    await db.close();
  }
});
