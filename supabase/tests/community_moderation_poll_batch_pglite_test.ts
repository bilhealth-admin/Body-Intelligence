import { PGlite } from "npm:@electric-sql/pglite@0.3.15";
import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.test("moderation poll batch requires current authority and exposes no voter identities", async () => {
  const db = new PGlite();
  const moderator = "61000000-0000-4000-8000-000000000001";
  const member = "61000000-0000-4000-8000-000000000002";
  const post = "62000000-0000-4000-8000-000000000001";
  const deleted = "62000000-0000-4000-8000-000000000002";
  const option = "63000000-0000-4000-8000-000000000001";
  try {
    // Identity and post scaffolds; poll tables/resolver use repository DDL.
    await db.exec(
      `create role anon; create role authenticated; create role service_role;
      create schema auth; create schema private;
      create table auth.users(id uuid primary key);
      create function auth.uid() returns uuid language sql stable as
        $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
      create table public.bil_community_posts(id uuid primary key, deleted_at timestamptz);
      create table private.bil_ai_coach_admins(user_id uuid primary key,active boolean not null);
      create table public.bil_community_moderators(user_id uuid primary key);
      grant usage on schema public,auth to authenticated,anon,service_role;`,
    );
    const foundation = await Deno.readTextFile(
      new URL(
        "../migrations/20261003095405_community_polls_foundation_v1.sql",
        import.meta.url,
      ),
    );
    await db.exec(
      foundation.slice(
        foundation.indexOf("create table public.bil_community_polls"),
        foundation.indexOf(
          "create or replace function public.bil_create_my_community_poll_v1",
        ),
      ),
    );
    const authority = await Deno.readTextFile(
      new URL(
        "../migrations/20260924223453_community_admin_moderation_visibility.sql",
        import.meta.url,
      ),
    );
    await db.exec(
      authority.slice(
        authority.indexOf(
          "create or replace function private.bil_resolve_community_moderation_authority",
        ),
        authority.indexOf(
          "create or replace function public.bil_is_community_moderator",
        ),
      ),
    );
    const migration = await Deno.readTextFile(
      new URL(
        "../migrations/20261019040842_community_moderation_poll_batch_20261019.sql",
        import.meta.url,
      ),
    );
    await db.exec(migration);
    await db.exec(migration);
    await db.exec(`insert into auth.users values ('${moderator}'),('${member}');
      insert into public.bil_community_posts values ('${post}',null),('${deleted}',now());
      insert into public.bil_community_polls(post_id,question) values ('${post}','Pending question'),('${deleted}','Deleted question');
      insert into public.bil_community_poll_options(id,post_id,position,option_text) values ('${option}','${post}',0,'Pending option');
      insert into public.bil_community_poll_votes(post_id,option_id,voter_id) values ('${post}','${option}','${member}');
      insert into public.bil_community_moderators values ('${moderator}');`);
    const actor = async (id: string, role = "authenticated") => {
      await db.exec("reset role");
      await db.query("select set_config('request.jwt.claim.sub',$1,false)", [
        id,
      ]);
      await db.exec(`set role ${role}`);
    };
    const load = (ids: (string | null)[] | null) =>
      db.query<{ post_id: string; poll: Record<string, unknown> }>(
        "select * from public.bil_community_moderation_polls_v1($1::uuid[])",
        [ids],
      );
    await actor(member);
    await assertRejects(
      () => load([post]),
      Error,
      "community_moderator_required",
    );
    await actor("");
    await assertRejects(() => load([post]), Error, "authentication_required");
    await actor(moderator, "anon");
    await assertRejects(() => load([post]), Error, "permission denied");
    await actor(moderator);
    for (const ids of [null, [], [post, post], [null], Array(101).fill(post)]) {
      await assertRejects(
        () => load(ids),
        Error,
        "invalid_community_poll_batch",
      );
    }
    const result = await load([post, deleted]);
    assertEquals(result.rows.length, 1);
    assertEquals(result.rows[0].poll.question, "Pending question");
    assertEquals(result.rows[0].poll.total_votes, 1);
    assertEquals(result.rows[0].poll.options, [{
      id: option,
      position: 0,
      text: "Pending option",
      vote_count: 1,
      selected: false,
    }]);
    assertEquals(JSON.stringify(result.rows).includes(member), false);
    await db.exec("reset role");
    await db.exec(
      `delete from public.bil_community_moderators where user_id='${moderator}'`,
    );
    await actor(moderator);
    await assertRejects(
      () => load([post]),
      Error,
      "community_moderator_required",
    );
    await db.exec("reset role");
    await db.exec(
      `insert into private.bil_ai_coach_admins values ('${moderator}',true)`,
    );
    await actor(moderator);
    assertEquals((await load([post])).rows.length, 1);
    await db.exec("reset role");
    await db.exec(`update private.bil_ai_coach_admins set active=false`);
    await actor(moderator);
    await assertRejects(
      () => load([post]),
      Error,
      "community_moderator_required",
    );
    await assertRejects(
      () => db.query("select * from public.bil_community_poll_votes"),
      Error,
      "permission denied",
    );
  } finally {
    await db.close();
  }
});
