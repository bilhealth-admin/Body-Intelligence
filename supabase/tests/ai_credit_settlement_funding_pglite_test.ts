import { PGlite } from "npm:@electric-sql/pglite@0.3.15";
function assert(v: unknown, m: string): asserts v {
  if (!v) throw new Error(m);
}
const month = "2026-10-01";
const week = "2026-10-12";
async function setup() {
  const db = new PGlite();
  await db.exec(`create schema auth; create schema private;
 create function auth.jwt() returns jsonb language sql stable as $$select jsonb_build_object('role',coalesce(current_setting('test.role',true),'service_role'))$$;
 create function public.bil_resolve_ai_allowance_plan(uuid) returns text language sql as $$select 'free'::text$$;
 create function private.bil_current_ai_month_start(uuid,timestamptz) returns date language sql as $$select '2026-10-01'::date$$;
 create table public.bil_ai_credit_config(plan_id text primary key,weekly_limit bigint,monthly_limit bigint);
 insert into public.bil_ai_credit_config values('free',0,0),('premium',500,1000);
 create table public.bil_ai_usage_events(owner_id uuid,request_id text,capability text,state text,
 week_start date,reservation_expires_at timestamptz,credit_reserved bigint,credit_weekly_debit bigint,credit_paid_debit bigint,
 credit_actual bigint,credit_plan_id text,credit_period_start date,created_at timestamptz default now(),
 provider text,model text,input_tokens integer,output_tokens integer,latency_ms integer,cost_usd numeric,completed_at timestamptz,
 primary key(owner_id,request_id,capability));
 create table public.bil_ai_credit_weekly_usage(owner_id uuid,week_start date,used bigint default 0,reserved bigint default 0,updated_at timestamptz,primary key(owner_id,week_start));
 create table public.bil_ai_credit_monthly_usage(owner_id uuid,month_start date,used bigint default 0,reserved bigint default 0,updated_at timestamptz,primary key(owner_id,month_start));
 create table public.bil_ai_credit_balances(owner_id uuid primary key,granted bigint,used bigint default 0,reserved bigint default 0,updated_at timestamptz,check(used>=0 and reserved>=0 and used+reserved<=granted));`);
  await db.exec(
    await Deno.readTextFile(
      new URL(
        "../migrations/20261018013620_ai_usage_actual_funding_allocation_20261018.sql",
        import.meta.url,
      ),
    ),
  );
  await db.exec(
    "create trigger monthly_sync after insert or update on public.bil_ai_usage_events for each row execute function public.bil_sync_ai_monthly_usage_from_event()",
  );
  return db;
}
async function seed(
  db: PGlite,
  plan: string,
  included: number,
  paid: number,
  granted: number,
  monthUsed = 0,
) {
  const owner = "48000000-0000-4000-8000-000000000001";
  await db.query(
    "insert into public.bil_ai_credit_balances(owner_id,granted,reserved) values($1,$2,$3)",
    [owner, granted, paid],
  );
  await db.query(
    "insert into public.bil_ai_credit_weekly_usage(owner_id,week_start,reserved) values($1,$2,$3)",
    [owner, week, included],
  );
  await db.query(
    "insert into public.bil_ai_credit_monthly_usage(owner_id,month_start,used) values($1,$2,$3)",
    [owner, month, monthUsed],
  );
  await db.query(
    "insert into public.bil_ai_usage_events(owner_id,request_id,capability,state,week_start,reservation_expires_at,credit_reserved,credit_weekly_debit,credit_paid_debit,credit_plan_id,credit_period_start) values($1,'fixture-request-0001','text','reserved',$2,now()+interval '15 minutes',100,$3,$4,$5,$6)",
    [owner, week, included, paid, plan, month],
  );
  return owner;
}
async function settle(db: PGlite, owner: string, success = true) {
  return (await db.query(
    "select public.bil_settle_ai_usage_unserialized($1,'fixture-request-0001','text',$2,'gemini','gemini-test',100,200,1000,0.035) as result",
    [owner, success],
  )).rows[0] as Record<string, unknown>;
}
Deno.test("paid-only Free credits settle real cost above reservation without charging zero monthly quota", async () => {
  const db = await setup();
  try {
    const owner = await seed(db, "free", 0, 100, 1000);
    await settle(db, owner);
    const row = (await db.query(
      "select b.used as paid_used,b.reserved,m.used as included_used,e.credit_paid_debit,e.credit_paid_actual,e.credit_included_actual from public.bil_ai_credit_balances b join public.bil_ai_credit_monthly_usage m using(owner_id) join public.bil_ai_usage_events e using(owner_id)",
    )).rows[0] as Record<string, unknown>;
    assert(
      Number(row.paid_used) === 350 && Number(row.reserved) === 0 &&
        Number(row.included_used) === 0,
      "wrong funded allocation",
    );
    assert(
      Number(row.credit_paid_debit) === 100 &&
        Number(row.credit_paid_actual) === 350 &&
        Number(row.credit_included_actual) === 0,
      "initial reservation audit lost",
    );
    await settle(db, owner);
    const balance =
      (await db.query("select used from public.bil_ai_credit_balances"))
        .rows[0] as Record<string, unknown>;
    assert(Number(balance.used) === 350, "duplicate settlement charged twice");
  } finally {
    await db.close();
  }
});
Deno.test("eligible included quota funds actual usage without requiring paid credits", async () => {
  const db = await setup();
  try {
    const owner = await seed(db, "premium", 100, 0, 0);
    await settle(db, owner);
    const rows = (await db.query(
      "select w.used,m.used as monthly,b.used as paid from public.bil_ai_credit_weekly_usage w join public.bil_ai_credit_monthly_usage m using(owner_id) join public.bil_ai_credit_balances b using(owner_id)",
    )).rows[0] as Record<string, unknown>;
    assert(
      Number(rows.used) === 350 && Number(rows.monthly) === 350 &&
        Number(rows.paid) === 0,
      "included quota allocation incorrect",
    );
  } finally {
    await db.close();
  }
});
Deno.test("monthly remaining quota and paid credits split the cost without increasing limits", async () => {
  const db = await setup();
  try {
    const owner = await seed(db, "premium", 50, 50, 1000, 950);
    await settle(db, owner);
    const row = (await db.query(
      "select m.used,b.used as paid from public.bil_ai_credit_monthly_usage m join public.bil_ai_credit_balances b using(owner_id)",
    )).rows[0] as Record<string, unknown>;
    assert(
      Number(row.used) === 1000 && Number(row.paid) === 300,
      "monthly limit or paid split incorrect",
    );
  } finally {
    await db.close();
  }
});
Deno.test("insufficient paid funds fail atomically and the existing refund releases the reservation", async () => {
  const db = await setup();
  try {
    const owner = await seed(db, "free", 0, 100, 100);
    let code = "";
    try {
      await settle(db, owner);
    } catch (e) {
      code = (e as Error).message;
    }
    assert(
      code.includes("ai_usage_exhausted"),
      "unfunded cost must fail closed",
    );
    let row = (await db.query("select state from public.bil_ai_usage_events"))
      .rows[0] as Record<string, unknown>;
    assert(row.state === "reserved", "failed settlement committed");
    await settle(db, owner, false);
    row = (await db.query(
      "select state,b.used,b.reserved from public.bil_ai_usage_events e join public.bil_ai_credit_balances b using(owner_id)",
    )).rows[0] as Record<string, unknown>;
    assert(
      row.state === "refunded" && Number(row.used) === 0 &&
        Number(row.reserved) === 0,
      "refund changed balance or retained reservation",
    );
  } finally {
    await db.close();
  }
});
Deno.test("unprivileged clients still cannot settle AI usage", async () => {
  const db = await setup();
  try {
    const owner = await seed(db, "free", 0, 100, 1000);
    await db.exec("set test.role='authenticated'");
    let denied = false;
    try {
      await settle(db, owner);
    } catch (e) {
      denied = (e as Error).message.includes("service_role_required");
    }
    assert(denied, "service role guard lost");
  } finally {
    await db.close();
  }
});
