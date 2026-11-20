import { PGlite } from "npm:@electric-sql/pglite@0.3.15";
import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";

// Local PostgreSQL/ACL policy verification only; no hosted users or push calls.
const owner = "25110000-0000-4000-8000-000000000001";
let sequence = 10;
async function fixture() {
  const db = new PGlite();
  await db.exec(`
    create role anon; create role authenticated; create role service_role;
    create schema private;
    create schema auth;
    create table auth.users (id uuid primary key);
    insert into auth.users values ('${owner}');
    create table public.bil_push_outbox (
      id uuid primary key, recipient_id uuid not null references auth.users(id) on delete cascade,
      category text not null check (category in ('friend_request','message','community','account','ai_coach')),
      title text not null default 'BIL', body text not null,
      deep_link text constraint bil_push_outbox_deep_link_check check (deep_link is null or deep_link ~ '^bil://(community|settings)(/|$)'),
      source_key text check (source_key is null or char_length(source_key) between 16 and 128),
      copy_key text check (copy_key is null or char_length(copy_key) between 3 and 80),
      dispatched_at timestamptz, failure_code text,
      check (length(title)<=80 and length(body)<=180)
    );
    create table private.review_receipts (id integer primary key, event_key text);
    insert into private.review_receipts values (1,'original-durable-review');
    create table private.owner_roles (owner_id uuid primary key, active boolean);
    insert into private.owner_roles values ('${owner}',true);
    create table public.bil_push_device_tokens (id integer primary key, enabled boolean);
    insert into public.bil_push_device_tokens values (1,true);
    create table public.bil_push_delivery_attempts (id integer primary key, delivered boolean);
    insert into public.bil_push_delivery_attempts values (1,true);
    revoke all on public.bil_push_outbox from public,anon,authenticated,service_role;
    grant select on public.bil_push_outbox to service_role;
  `);
  await db.exec(await Deno.readTextFile(new URL(
    "../migrations/20261120015317_mobile_push_web_only_destination_policy_v1.sql",
    import.meta.url,
  )));
  async function insert(deepLink: string | null, source: string | null = null, category = "community", dispatched: string | null = null) {
    const id = `25110000-0000-4000-8000-${String(++sequence).padStart(12, "0")}`;
    await db.query(`insert into public.bil_push_outbox
      (id,recipient_id,category,title,body,deep_link,source_key,dispatched_at)
      values($1,$2,$3,'BIL','Original protected copy',$4,$5,$6)`,
      [id, owner, category, deepLink, source, dispatched]);
    return id;
  }
  async function suppress(id: string | null) {
    await db.exec("set role service_role");
    try {
      return (await db.query<{ value: boolean }>(
        "select public.bil_suppress_web_only_mobile_push_v1($1) as value", [id],
      )).rows[0].value;
    } finally { await db.exec("reset role"); }
  }
  return { db, insert, suppress };
}

Deno.test("web-only SQL: route/source suppression preserves receipts, owner, devices and outbox", async () => {
  const x = await fixture();
  try {
    for (const [link, source] of [
      ["bil://community/moderation", null],
      ["bil://community/food-review?item=synthetic", null],
      ["bil://community/moderation/queue", null],
      ["bil://community", "post-event:review_requested:synthetic:owner"],
    ]) {
      const id = await x.insert(link, source);
      assertEquals(await x.suppress(id), true);
      const row = (await x.db.query<Record<string, unknown>>(
        "select * from public.bil_push_outbox where id=$1", [id],
      )).rows[0];
      assertEquals(row.recipient_id, owner);
      assertEquals(row.source_key, source);
      assertEquals(row.deep_link, link);
      assertEquals(row.body, "Original protected copy");
      assertEquals(row.failure_code, "web_only_destination");
      assertEquals(row.dispatched_at !== null, true);
      assertEquals(await x.suppress(id), true);
    }
    assertEquals((await x.db.query("select * from private.review_receipts")).rows, [{ id: 1, event_key: "original-durable-review" }]);
    assertEquals((await x.db.query("select * from private.owner_roles")).rows, [{ owner_id: owner, active: true }]);
    assertEquals((await x.db.query("select * from public.bil_push_device_tokens")).rows, [{ id: 1, enabled: true }]);
    assertEquals((await x.db.query("select * from public.bil_push_delivery_attempts")).rows, [{ id: 1, delivered: true }]);
  } finally { await x.db.close(); }
});

Deno.test("web-only SQL: friends, messages, user receipts and account gifts remain pending/deliverable", async () => {
  const x = await fixture();
  try {
    for (const [link, source, category] of [
      ["bil://community/connections", null, "friend_request"],
      [`bil://community/chat/${owner}`, null, "message"],
      ["bil://community/notifications", "friend_accepted:synthetic", "community"],
      ["bil://community", "post-event:post_submitted:synthetic:owner", "community"],
      ["bil://community", "post-event:post_approved:synthetic:owner", "community"],
      ["bil://settings/ai-coach", null, "ai_coach"],
      ["bil://community/moderation-tips", null, "community"],
      ["bil://community/?next=moderation", "post-event:reviewXrequested:synthetic:owner", "community"],
      [null, null, "message"],
    ]) {
      const id = await x.insert(link, source, category!);
      assertEquals(await x.suppress(id), false, `${category}/${link}`);
      const row = (await x.db.query("select dispatched_at,failure_code from public.bil_push_outbox where id=$1", [id])).rows[0];
      assertEquals(row, { dispatched_at: null, failure_code: null });
    }
  } finally { await x.db.close(); }
});

Deno.test("web-only SQL: admin route defense remains ready if the producer allow-list expands", async () => {
  const x = await fixture();
  try {
    // Production currently permits only community/settings links. Expand only
    // this local fixture to exercise the dispatcher policy's future defense.
    await x.db.exec("alter table public.bil_push_outbox drop constraint bil_push_outbox_deep_link_check");
    for (const link of ["bil://admin/ai-coach", "bil:///admin/ai-coach", "BIL://COMMUNITY/MODERATION/queue"]) {
      assertEquals(await x.suppress(await x.insert(link)), true);
    }
  } finally { await x.db.close(); }
});

Deno.test("web-only SQL: already-delivered history stays intact and missing/null IDs cannot mutate rows", async () => {
  const x = await fixture();
  try {
    const id = await x.insert("bil://community/moderation", null, "community", "2026-11-20T01:29:03Z");
    const before = (await x.db.query("select * from public.bil_push_outbox where id=$1", [id])).rows;
    assertEquals(await x.suppress(id), true);
    assertEquals((await x.db.query("select * from public.bil_push_outbox where id=$1", [id])).rows, before);
    assertEquals(await x.suppress("25110000-0000-4000-8000-000000999999"), false);
    await assertRejects(() => x.suppress(null), Error, "push_outbox_id_required");
  } finally { await x.db.close(); }
});

Deno.test("web-only SQL: only service role can execute; direct UPDATE stays forbidden", async () => {
  const x = await fixture();
  try {
    const id = await x.insert("bil://community/moderation");
    for (const role of ["anon", "authenticated"]) {
      await x.db.exec(`set role ${role}`);
      await assertRejects(() => x.db.query("select public.bil_suppress_web_only_mobile_push_v1($1)", [id]), Error, "permission denied");
      await x.db.exec("reset role");
    }
    await x.db.exec("set role service_role");
    await assertRejects(() => x.db.query("update public.bil_push_outbox set failure_code='forged' where id=$1", [id]), Error, "permission denied");
    await x.db.exec("reset role");
    assertEquals(await x.suppress(id), true);
  } finally { await x.db.close(); }
});
