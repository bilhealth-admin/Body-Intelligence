import { PGlite } from "@electric-sql/pglite";
import { pg_trgm } from "@electric-sql/pglite/contrib/pg_trgm";

// Synthetic users/foods only; this suite never opens a network database.
type SqlRow = Record<string, unknown>;
const uuid = (n: number) =>
  `46000000-0000-4000-8000-${n.toString().padStart(12, "0")}`;
const A = uuid(1);
const B = uuid(2);
const patchUrl = new URL(
  "../migrations/20261116051214_community_private_food_explicit_publication_guard_v1.sql",
  import.meta.url,
);
const sources = {
  base: "202608020002_bil_community_foundation.sql",
  trust: "202608030001_bil_product_review_trust.sql",
  live: "20260821054046_community_food_live_search.sql",
  repairs: "20260924071037_community_current_build_backend_repairs.sql",
  official: "20260928112237_seed_sfda_arabic_food_catalog.sql",
  profile: "20261003210000_community_reference_profile_creator_v1.sql",
};

function assert(value: unknown, label: string): asserts value {
  if (!value) throw new Error(label);
}
function equal(actual: unknown, expected: unknown, label: string) {
  assert(
    JSON.stringify(actual) === JSON.stringify(expected),
    `${label}: expected ${JSON.stringify(expected)}, got ${
      JSON.stringify(actual)
    }`,
  );
}
async function denied(action: () => Promise<unknown>, message?: string) {
  try {
    await action();
  } catch (error) {
    const e = error as { code?: string; message?: string };
    assert(e.code === "42501", `Expected42501, got ${e.code}: ${e.message}`);
    if (message) {
      assert(e.message === message, `Unexpected rejection: ${e.message}`);
    }
    return;
  }
  throw new Error("Missing SQLSTATE42501 rejection");
}
async function source(name: string) {
  return await Deno.readTextFile(
    new URL(`../migrations/${name}`, import.meta.url),
  );
}
function statement(sql: string, prefix: string) {
  const start = sql.toLowerCase().indexOf(prefix.toLowerCase());
  assert(start >= 0, `Missing source SQL ${prefix}`);
  const end = sql.indexOf(";", start);
  assert(end > start, `Missing statement terminator ${prefix}`);
  return sql.slice(start, end + 1);
}
function functionSql(sql: string, name: string) {
  const prefix = `create or replace function public.${name}(`;
  const start = sql.toLowerCase().indexOf(prefix);
  assert(start >= 0, `Missing source function ${name}`);
  const after = sql.slice(start);
  const body = /\bas\s+(\$[a-zA-Z_0-9]*\$)/i.exec(after);
  assert(body?.index != null, `Missing function body ${name}`);
  const end = after.indexOf(body[1], body.index + body[0].length);
  assert(end >= 0, `Unclosed function ${name}`);
  return after.slice(0, end + body[1].length) + ";";
}
async function actor(
  db: PGlite,
  role: "authenticated" | "anon",
  id: string | null,
) {
  await db.exec("reset role");
  await db.query<SqlRow>(
    "select set_config('request.jwt.claim.sub',$1,false)",
    [
      id ?? "",
    ],
  );
  await db.exec(`set role ${role}`);
}
async function allRows(db: PGlite) {
  await db.exec("reset role");
  return (await db.query<SqlRow>(
    "select to_jsonb(s) as row from public.bil_community_food_submissions s order by s.id",
  )).rows;
}
async function metadata(db: PGlite) {
  await db.exec("reset role");
  return (await db.query<SqlRow>(`select p.oid::text, p.proname,
    p.proacl::text, p.prorettype::regtype::text, p.proargnames,
    p.proargtypes::text, p.proallargtypes::text, p.proargmodes,
    p.proconfig, p.prosecdef, p.provolatile,
    pg_get_function_arguments(p.oid) as arguments
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname in (
      'bil_upsert_community_food_contribution','bil_search_community_foods',
      'bil_withdraw_community_food_contribution','bil_community_profile_reviews_v1')
    order by p.proname`)).rows;
}

async function setup(db: PGlite) {
  const original = Object.fromEntries(
    await Promise.all(
      Object.entries(sources).map(async (
        [key, name],
      ) => [key, await source(name)]),
    ),
  );
  await db.exec(`create role anon; create role authenticated;
    create schema auth; create schema private; create schema extensions;
    create extension pg_trgm with schema extensions;
    create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql stable as $$
      select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    create table public.bil_public_profiles(
      user_id uuid primary key references auth.users(id), show_posts boolean not null default true);
    create function public.bil_social_profile_visible_v2(uuid) returns boolean language sql stable as $$
      select coalesce(current_setting('fixture.profile_visible',true),'true')<>'false' $$;
    create function public.bil_can_use_community() returns boolean language sql stable as $$
      select auth.uid() is not null $$;
    create function private.bil_assert_current_community_policy() returns text language plpgsql as $$
      begin if coalesce(current_setting('fixture.policy_accepted',true),'yes')<>'yes'
      then raise exception 'community_policy_acceptance_required' using errcode='42501'; end if;
      return 'synthetic-policy'; end $$;`);
  // Exact relevant DDL/policies/function bodies from accepted migrations; no
  // replacement RLS or weakened role grants to make an assertion pass.
  await db.exec(
    statement(
      original.base,
      "create table if not exists public.bil_community_food_submissions",
    ),
  );
  await db.exec(
    statement(
      original.trust,
      "alter table public.bil_community_food_submissions",
    ),
  );
  await db.exec(
    statement(
      original.live,
      "alter table public.bil_community_food_submissions",
    ),
  );
  await db.exec(
    statement(
      original.live,
      "create unique index if not exists bil_food_contributor_client_id_uq",
    ),
  );
  await db.exec(
    statement(
      original.official,
      "create table if not exists public.bil_official_food_catalog",
    ),
  );
  await db.exec(
    `alter table public.bil_community_food_submissions enable row level security`,
  );
  for (
    const policy of [
      "bil_food_read",
      "bil_food_submit",
      "bil_food_update_pending_own",
    ]
  ) {
    await db.exec(statement(original.base, `create policy ${policy} `));
  }
  for (
    const [sql, name] of [
      [original.repairs, "bil_upsert_community_food_contribution"],
      [original.live, "bil_withdraw_community_food_contribution"],
      [original.official, "bil_search_community_foods"],
      [original.profile, "bil_community_profile_reviews_v1"],
    ]
  ) await db.exec(functionSql(sql, name));
  await db.exec(`grant usage on schema public,auth to authenticated,anon;
    grant select,insert,update on public.bil_community_food_submissions to authenticated;
    revoke all on function public.bil_upsert_community_food_contribution(jsonb) from public,anon;
    revoke all on function public.bil_withdraw_community_food_contribution(text) from public,anon;
    revoke all on function public.bil_search_community_foods(text,integer) from public,anon;
    revoke all on function public.bil_community_profile_reviews_v1(uuid,timestamptz,uuid,integer) from public,anon;
    grant execute on function public.bil_upsert_community_food_contribution(jsonb),
      public.bil_withdraw_community_food_contribution(text),
      public.bil_search_community_foods(text,integer),
      public.bil_community_profile_reviews_v1(uuid,timestamptz,uuid,integer) to authenticated;`);
  await db.query<SqlRow>("insert into auth.users(id) values($1),($2)", [A, B]);
  await db.query<SqlRow>(
    "insert into public.bil_public_profiles(user_id) values($1),($2)",
    [A, B],
  );
  const rows: [number, string, string, string, boolean][] = [
    [101, A, "user_created_food", "pending", false],
    [102, A, "user_created_food", "approved", false],
    [103, A, "user_submission", "pending", false],
    [104, A, "user_submission", "approved", false],
    [105, A, "user_submission", "approved", true],
    [106, A, "unknown_future_source", "approved", false],
    [107, B, "user_created_food", "approved", false],
    [108, B, "user_submission", "approved", false],
    [109, A, "user_submission", "approved", false],
  ];
  for (const [id, owner, origin, status, withdrawn] of rows) {
    await db.query<SqlRow>(
      `insert into public.bil_community_food_submissions
      (id,contributor_id,client_food_id,canonical_name,submission_source,status,
       serving_amount,serving_unit,serving_grams,calories_kcal,created_at,withdrawn_at)
      values($1,$2,$3,$4,$5,$6,100,'g',100,120,$7,$8)`,
      [
        uuid(id),
        owner,
        uuid(id + 100),
        `Fixture ${id}`,
        origin,
        status,
        `2026-11-01T00:00:${(id - 100).toString().padStart(2, "0")}Z`,
        withdrawn ? "2026-11-02T00:00:00Z" : null,
      ],
    );
  }
  await db.query<SqlRow>(
    `insert into public.bil_official_food_catalog
    (id,source_id,source_name,source_url,canonical_name,country_code,serving_amount,
     serving_unit,calories_kcal,protein_g,carbohydrate_g,fat_g,nutrient_evidence_mask,published_at)
    values($1,'official-fixture','Synthetic official source','https://example.invalid/source',
      'Fixture official','JO',100,'g',120,10,15,2,15,'2026-11-01')`,
    [uuid(900)],
  );
}

Deno.test("private food publication guards execute on real PostgreSQL roles without production access", async (t) => {
  const db = new PGlite({ extensions: { pg_trgm } });
  try {
    await setup(db);
    await t.step(
      "control reproduces the old privacy defects using synthetic rows then rolls back",
      async () => {
        const rows = await allRows(db);
        await db.exec("begin");
        try {
          await actor(db, "authenticated", A);
          const created = await db.query<SqlRow>(
            "select public.bil_upsert_community_food_contribution($1::jsonb) as id",
            [JSON.stringify({
              client_food_id: uuid(999),
              canonical_name: "Private old fixture",
              serving_amount: 100,
              serving_unit: "g",
            })],
          );
          assert(
            typeof created.rows[0].id === "string",
            "Old auto RPC was not exercised",
          );
          await actor(db, "authenticated", B);
          const rest = (await db.query<SqlRow>(
            "select id from public.bil_community_food_submissions where id=$1",
            [uuid(102)],
          )).rows;
          assert(
            rest.length === 1,
            "Old approved auto-source RLS exposure not reproduced",
          );
          const search = (await db.query<SqlRow>(
            "select id from public.bil_search_community_foods('Fixture',20)",
          )).rows;
          assert(
            search.some((r) => r.id === uuid(101)),
            "Old pending search exposure not reproduced",
          );
          const profile = (await db.query<SqlRow>(
            "select review_id from public.bil_community_profile_reviews_v1($1,null,null,24)",
            [A],
          )).rows;
          assert(
            profile.some((r) => r.review_id === uuid(102)),
            "Old auto-source profile exposure not reproduced",
          );
        } finally {
          await db.exec("reset role; rollback");
        }
        equal(await allRows(db), rows, "Control fixture did not roll back");
      },
    );
    const beforeRows = await allRows(db);
    const beforeMetadata = await metadata(db);
    const beforeWithdraw = (await db.query<SqlRow>(
      "select pg_get_functiondef('public.bil_withdraw_community_food_contribution(text)'::regprocedure) as definition",
    )).rows;
    const beforeWritePolicies =
      (await db.query<SqlRow>(`select policyname,roles,cmd,qual,with_check
      from pg_policies where schemaname='public' and tablename='bil_community_food_submissions'
      and cmd<>'SELECT' order by policyname`)).rows;
    const patch = await Deno.readTextFile(patchUrl);
    if (patch.trim()) await db.exec(patch);

    await t.step(
      "migration preserves rows, signatures, ACL, RLS, write policies and withdrawal definition",
      async () => {
        equal(
          await allRows(db),
          beforeRows,
          "Migration changed user food rows",
        );
        equal(
          await metadata(db),
          beforeMetadata,
          "Function signature/ACL/config drift",
        );
        equal(
          (await db.query<SqlRow>(
            "select pg_get_functiondef('public.bil_withdraw_community_food_contribution(text)'::regprocedure) as definition",
          )).rows,
          beforeWithdraw,
          "Withdrawal changed",
        );
        equal(
          (await db.query<SqlRow>(
            `select policyname,roles,cmd,qual,with_check from pg_policies
        where schemaname='public' and tablename='bil_community_food_submissions' and cmd<>'SELECT'
        order by policyname`,
          )).rows,
          beforeWritePolicies,
          "Write RLS drift",
        );
        assert(
          (await db.query<SqlRow>(
            "select relrowsecurity as enabled from pg_class where oid='public.bil_community_food_submissions'::regclass",
          )).rows[0].enabled,
          "RLS disabled",
        );
      },
    );
    await t.step(
      "legacy RPC rejects ordinary and fabricated-consent payloads for both users without row writes",
      async () => {
        const rows = await allRows(db);
        for (const owner of [A, B]) {
          await actor(db, "authenticated", owner);
          for (
            const extra of [{}, {
              explicit_consent: true,
              submission_source: "user_submission",
              status: "approved",
            }]
          ) {
            await denied(
              () =>
                db.query<SqlRow>(
                  "select public.bil_upsert_community_food_contribution($1::jsonb)",
                  [JSON.stringify({
                    client_food_id: uuid(999),
                    canonical_name: "Private new fixture",
                    serving_amount: 100,
                    serving_unit: "g",
                    ...extra,
                  })],
                ),
              "explicit_community_submission_required",
            );
          }
        }
        equal(await allRows(db), rows, "Rejected RPC changed rows");
      },
    );
    await t.step(
      "REST SELECT hides other owners private, legacy-approved, unknown and withdrawn food but preserves own rows",
      async () => {
        await actor(db, "authenticated", B);
        const ids = (await db.query<SqlRow>(
          "select id from public.bil_community_food_submissions order by id",
        )).rows.map((r) => r.id);
        equal(
          ids,
          [104, 107, 108, 109].map(uuid),
          "Public RLS leaked private contribution",
        );
        await actor(db, "authenticated", A);
        const own = (await db.query<SqlRow>(
          "select id from public.bil_community_food_submissions where contributor_id=$1 order by id",
          [A],
        )).rows.map((r) => r.id);
        equal(
          own,
          [101, 102, 103, 104, 105, 106, 109].map(uuid),
          "Owner lost private retained rows",
        );
      },
    );
    await t.step(
      "search exposes approved explicit food plus unchanged official catalog only",
      async () => {
        for (const owner of [A, B]) {
          await actor(db, "authenticated", owner);
          const rows = (await db.query<SqlRow>(
            "select * from public.bil_search_community_foods('Fixture',20)",
          )).rows;
          equal(
            rows.map((r) => r.id).sort(),
            [104, 108, 109, 900].map(uuid).sort(),
            "Search leaked private/pending/withdrawn food",
          );
          assert(
            rows.every((r) => r.status === "approved" && r.verified === true),
            "Approved verification drift",
          );
        }
      },
    );
    await t.step(
      "profile reviews hide legacy/unknown sources and preserve visibility and pagination",
      async () => {
        await actor(db, "authenticated", B);
        const first = (await db.query<SqlRow>(
          "select * from public.bil_community_profile_reviews_v1($1,null,null,1)",
          [A],
        )).rows;
        equal(
          first.map((r) => r.review_id),
          [uuid(109)],
          "Profile exposed wrong first review",
        );
        const next = (await db.query<SqlRow>(
          "select * from public.bil_community_profile_reviews_v1($1,$2,$3,24)",
          [A, first[0].created_at, first[0].review_id],
        )).rows;
        equal(
          next.map((r) => r.review_id),
          [uuid(104)],
          "Profile exposed legacy food or lost cursor",
        );
        await db.query<SqlRow>(
          "select set_config('fixture.profile_visible','false',false)",
        );
        equal(
          (await db.query<SqlRow>(
            "select * from public.bil_community_profile_reviews_v1($1,null,null,24)",
            [A],
          )).rows,
          [],
          "Profile visibility bypassed",
        );
        await db.query<SqlRow>(
          "select set_config('fixture.profile_visible','true',false)",
        );
      },
    );
    await t.step(
      "anonymous retains permission denied without adding execute or table grants",
      async () => {
        await actor(db, "anon", null);
        await denied(() =>
          db.query<SqlRow>(
            "select public.bil_upsert_community_food_contribution('{}'::jsonb)",
          )
        );
        await denied(() =>
          db.query<SqlRow>(
            "select * from public.bil_search_community_foods('Fixture',20)",
          )
        );
        await denied(() =>
          db.query<SqlRow>(
            "select * from public.bil_community_profile_reviews_v1($1,null,null,24)",
            [A],
          )
        );
        await denied(() =>
          db.query<SqlRow>(
            "select * from public.bil_community_food_submissions",
          )
        );
        await denied(() =>
          db.query<SqlRow>(
            "select public.bil_withdraw_community_food_contribution($1)",
            [uuid(201)],
          )
        );
      },
    );
    await t.step(
      "explicit pending insert remains available, cannot impersonate or self-approve, and owner withdrawal stays idempotent",
      async () => {
        await actor(db, "authenticated", A);
        await db.query<SqlRow>(
          `insert into public.bil_community_food_submissions
        (id,contributor_id,client_food_id,canonical_name,submission_source,status,serving_grams)
        values($1,$2,$3,'Explicit fixture','user_submission','pending',100)`,
          [uuid(111), A, uuid(211)],
        );
        await denied(() =>
          db.query<SqlRow>(
            "update public.bil_community_food_submissions set status='approved' where id=$1",
            [uuid(111)],
          )
        );
        await denied(() =>
          db.query<SqlRow>(
            `insert into public.bil_community_food_submissions
        (contributor_id,canonical_name,submission_source,status) values($1,'Impersonated fixture','user_submission','pending')`,
            [B],
          )
        );
        await actor(db, "authenticated", B);
        equal(
          (await db.query<SqlRow>(
            "select id from public.bil_community_food_submissions where id=$1",
            [uuid(111)],
          )).rows,
          [],
          "Pending direct submission public",
        );
        equal(
          (await db.query<SqlRow>(
            "select public.bil_withdraw_community_food_contribution($1) as removed",
            [uuid(211)],
          )).rows[0].removed,
          false,
          "Other owner withdrew row",
        );
        await actor(db, "authenticated", A);
        equal(
          (await db.query<SqlRow>(
            "select public.bil_withdraw_community_food_contribution($1) as removed",
            [uuid(211)],
          )).rows[0].removed,
          true,
          "Owner withdrawal broken",
        );
        equal(
          (await db.query<SqlRow>(
            "select public.bil_withdraw_community_food_contribution($1) as removed",
            [uuid(211)],
          )).rows[0].removed,
          false,
          "Withdrawal repeated a side effect",
        );
      },
    );
    await t.step(
      "reapplying migration is idempotent without changing existing rows or permissions",
      async () => {
        const rows = await allRows(db);
        const permissions = await metadata(db);
        if (patch.trim()) await db.exec(patch);
        equal(await allRows(db), rows, "Migration replay changed row content");
        equal(
          await metadata(db),
          permissions,
          "Migration replay changed ACL/signatures",
        );
      },
    );
  } finally {
    await db.close();
  }
});
