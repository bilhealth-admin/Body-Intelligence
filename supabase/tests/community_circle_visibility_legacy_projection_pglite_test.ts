import { PGlite } from "npm:@electric-sql/pglite@0.3.15";
import assert from "node:assert/strict";

const migrationPath =
  "../migrations/20261020210400_community_circle_visibility_legacy_projection_guard_v1.sql";
const read = (path: string) =>
  Deno.readTextFile(new URL(path, import.meta.url));
const source = (path: string) => read(`../../${path}`);
const uuid = (n: number) =>
  `70000000-0000-4000-8000-${String(n).padStart(12, "0")}`;
const owner = uuid(1), viewer = uuid(2), author = uuid(3);
const pub = uuid(10), priv = uuid(11), pending = uuid(12), builtin = uuid(13);
const publicPost = uuid(20),
  privatePost = uuid(21),
  olderPost = uuid(22),
  friendsPost = uuid(23);
const signatures = [
  "public.bil_list_community_circles_v1()",
  "public.bil_community_circle_post_refs_v1(text,timestamp with time zone,uuid,integer)",
  "public.bil_community_post_reference_metadata_v1(uuid[])",
];

function functionSql(sql: string, name: string): string {
  const escaped = name.replaceAll(".", "\\.");
  const matches = [...sql.matchAll(
    new RegExp(
      `create(?:\\s+or\\s+replace)?\\s+function\\s+${escaped}\\s*\\([\\s\\S]*?\\bas\\s+(\\$[A-Za-z0-9_]*\\$)[\\s\\S]*?\\1\\s*;`,
      "gi",
    ),
  )];
  assert.equal(
    matches.length,
    1,
    `One exact source definition required: ${name}`,
  );
  return matches[0][0];
}

function tableSql(sql: string, name: string): string {
  const matches = [...sql.matchAll(
    new RegExp(
      `create table ${name.replaceAll(".", "\\.")}\\s*\\([\\s\\S]*?\\n\\);`,
      "gi",
    ),
  )];
  assert.equal(matches.length, 1, `One source table required: ${name}`);
  return matches[0][0];
}

Deno.test("legacy circle reads and metadata enforce the current visibility boundary", async (t) => {
  const phase = Deno.env.get("BIL_CIRCLE_VISIBILITY_PHASE") ?? "patched";
  assert.ok(["baseline", "patched"].includes(phase));
  const db = new PGlite(); // Isolated WASM database; no server/network credentials.
  try {
    await db.exec(
      `create role anon; create role authenticated; create role service_role;
      create schema auth; create schema private;
      create table auth.users(id uuid primary key);
      create function auth.uid() returns uuid language sql stable as
      $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
      grant usage on schema auth,public to authenticated,anon,service_role;`,
    );
    const baseline = await source(
      "tool/release/community_atomic_publish_live_baseline.sql",
    );
    // Reuse real table DDL and effective read functions, without loading writes,
    // Storage, production rows, extension shims, or the complete migration chain.
    for (
      const name of [
        "private.bil_ai_coach_admins",
        "private.bil_community_member_access",
        "public.bil_community_moderators",
        "public.bil_blocks",
        "public.bil_friendships",
        "public.bil_public_profiles",
        "public.bil_social_handles_v2",
        "public.bil_community_posts",
        "public.bil_community_topics",
        "public.bil_community_post_topics",
        "public.bil_community_post_hashtags_v1",
        "public.bil_community_post_collaborators_v1",
      ]
    ) await db.exec(tableSql(baseline, name));
    await db.exec("alter table public.bil_community_posts add primary key(id)");
    const foundation = await source(
      "supabase/migrations/20261003091136_community_circles_foundation_v1.sql",
    );
    await db.exec(
      foundation.slice(
        foundation.indexOf("create table public.bil_community_circles"),
        foundation.indexOf("insert into public.bil_community_circles"),
      ),
    );
    const management = await source(
      "supabase/migrations/20261019071841_community_circle_reviewed_management_v1.sql",
    );
    await db.exec(tableSql(management, "public.bil_circle_metadata_v1"));
    await db.exec(tableSql(management, "public.bil_circle_invites_v1"));
    const social = await source(
      "supabase/migrations/20260908013800_bil_community_social_v2.sql",
    );
    const authority = await source(
      "supabase/migrations/20260924223453_community_admin_moderation_visibility.sql",
    );
    for (
      const name of [
        "public.bil_social_member_visible_v2",
        "public.bil_social_profile_visible_v2",
      ]
    ) await db.exec(functionSql(social, name));
    await db.exec(functionSql(authority, "public.bil_social_post_visible_v2"));
    await db.exec(
      functionSql(
        authority,
        "private.bil_resolve_community_moderation_authority",
      ),
    );
    for (
      const name of [
        "private.bil_circle_invite_usable_v1",
        "private.bil_circle_visible_v1",
      ]
    ) {
      await db.exec(functionSql(management, name));
      await db.exec(
        `revoke all on function ${name}(uuid) from public,anon,authenticated,service_role`,
      );
    }
    for (
      const name of [
        "public.bil_list_community_circles_v1",
        "public.bil_community_circle_post_refs_v1",
      ]
    ) await db.exec(functionSql(foundation, name));
    const projection = functionSql(
      await source(
        "supabase/migrations/20261004170806_community_collaborator_projection_privacy_v1.sql",
      ),
      "public.bil_community_post_reference_metadata_v1",
    );
    await db.exec(projection);
    for (const signature of signatures) {
      await db.exec(
        `revoke all on function ${signature} from public,anon,service_role; grant execute on function ${signature} to authenticated`,
      );
    }
    await db.exec(
      `insert into auth.users values ('${owner}'),('${viewer}'),('${author}');
      insert into public.bil_public_profiles(user_id,display_name,profile_visibility) values
      ('${owner}','Circle creator','public'),('${viewer}','Reader','public'),('${author}','Post author','public');
      insert into public.bil_community_circles(id,slug,title_copy_key,description_copy_key,rules_copy_key,access,active,rank_weight) values
      ('${pub}','public-circle','circle_public','circle_description','circle_rules','public',true,20),
      ('${priv}','private-circle','circle_private','circle_description','circle_rules','private',true,10),
      ('${pending}','pending-circle','circle_pending','circle_description','circle_rules','public',false,0),
      ('${builtin}','builtin-circle','circle_builtin','circle_description','circle_rules','public',true,0);
      insert into public.bil_circle_metadata_v1(circle_id,created_by,review_status,display_name) values
      ('${pub}','${owner}','approved','Public circle'),('${priv}','${owner}','approved','Private circle'),('${pending}','${owner}','pending','Pending circle');
      insert into public.bil_community_circle_memberships(circle_id,owner_id,role,status) values
      ('${pub}','${owner}','moderator','active'),('${priv}','${owner}','moderator','active'),('${pending}','${owner}','moderator','active'),('${pub}','${viewer}','member','active');
      insert into public.bil_community_posts(id,author_id,body,title,visibility,moderation_status,created_at) values
      ('${publicPost}','${author}','Public body','Public title','community','approved','2026-01-03T00:00:00Z'),
      ('${privatePost}','${author}','Explicit community post body','Private circle title','community','approved','2026-01-03T00:00:00Z'),
      ('${olderPost}','${author}','Older body','Older title','community','approved','2026-01-02T00:00:00Z'),
      ('${friendsPost}','${author}','Friends-only body','Friends title','friends','approved','2026-01-04T00:00:00Z');
      insert into public.bil_community_post_circles(post_id,circle_id) values ('${publicPost}','${pub}'),('${olderPost}','${pub}'),('${friendsPost}','${pub}'),('${privatePost}','${priv}');
      insert into public.bil_community_topics(id,slug,title_copy_key,description_copy_key,icon_key) values ('${
        uuid(30)
      }','nutrition','topic_nutrition','topic_description','nutrition');
      insert into public.bil_community_post_topics(post_id,topic_id) values ('${publicPost}','${
        uuid(30)
      }');
      insert into public.bil_community_post_hashtags_v1(post_id,hashtag) values ('${publicPost}','sleep'),('${publicPost}','health');
      insert into public.bil_community_post_collaborators_v1(post_id,collaborator_id,status,responded_at) values ('${publicPost}','${owner}','accepted',now());`,
    );
    const admin = async (sql: string, args: unknown[] = []) => {
      await db.exec("reset role");
      return db.query<Record<string, unknown>>(sql, args);
    };
    const actor = async (id: string) => {
      await admin("select set_config('request.jwt.claim.sub',$1,false)", [id]);
      await db.exec("set role authenticated");
    };
    const list = () =>
      db.query<{ slug: string }>(
        "select * from public.bil_list_community_circles_v1()",
      );
    const metadata = (id: string) =>
      db.query<{ circle: { slug: string } | null }>(
        "select * from public.bil_community_post_reference_metadata_v1($1::uuid[])",
        [[id]],
      );
    const refs = (
      slug: string,
      before: string | null = null,
      id: string | null = null,
      limit = 30,
    ) =>
      db.query<{ post_id: string }>(
        "select * from public.bil_community_circle_post_refs_v1($1,$2,$3,$4)",
        [slug, before, id, limit],
      );
    const deniedCircle = async (slug: string) => {
      await assert.rejects(
        () => refs(slug),
        (error: { code?: string; message?: string }) =>
          error.code === "22023" &&
          error.message === "community_circle_not_found",
      );
    };
    const definitions = async () =>
      (await admin(
        "select oid::regprocedure::text signature,pg_get_functiondef(oid) definition,proacl::text acl from pg_proc where oid=any($1::regprocedure[]) order by oid",
        [signatures],
      )).rows;
    await actor(viewer);
    const publicBefore = (await metadata(publicPost)).rows;
    const listBefore = (await list()).rows;
    const refsBefore = (await refs("public-circle")).rows;
    const beforeDefinitions = await definitions();
    const migration = await read(migrationPath);
    if (phase === "patched") {
      // An unknown third function must fail before replacing the first two.
      const changed = projection.replace(
        "where pc.post_id=p.id and cir.active",
        "where pc.post_id=p.id and cir.active and true",
      );
      assert.notEqual(changed, projection);
      await db.exec(changed);
      await assert.rejects(
        () => db.exec(migration),
        (error: { code?: string }) => error.code === "55000",
      );
      await db.exec("rollback");
      const afterRejected = await definitions();
      assert.deepEqual(
        afterRejected.slice(0, 2),
        beforeDefinitions.slice(0, 2),
      );
      await db.exec(projection);
      await db.exec(migration);
      const once = await definitions();
      await db.exec(migration); // Exact reapplication is safe, no duplicate predicate.
      assert.deepEqual(await definitions(), once);
      assert.deepEqual(
        once.map((row) => row.acl),
        beforeDefinitions.map((row) => row.acl),
      );
      console.log(
        "PASS migration rejects drift atomically; exact reapply and ACLs preserved",
      );
    }

    await t.step(
      "private nonmember receives null circle while allowed post metadata remains",
      async () => {
        await actor(viewer);
        const rows = (await metadata(privatePost)).rows;
        assert.equal(rows.length, 1);
        assert.equal(rows[0].circle, null);
      },
    );
    await t.step(
      "allowed public baseline preserves JSON, order, cursors, post privacy and limits",
      async () => {
        await actor(viewer);
        assert.deepEqual((await metadata(publicPost)).rows, publicBefore);
        assert.deepEqual((await list()).rows, listBefore);
        assert.deepEqual((await refs("public-circle")).rows, refsBefore);
        assert.deepEqual(refsBefore.map((row) => row.post_id), [
          publicPost,
          olderPost,
        ]);
        assert.deepEqual(
          (await refs("public-circle", null, null, 1)).rows.map((row) =>
            row.post_id
          ),
          [publicPost],
        );
        assert.deepEqual(
          (await refs("public-circle", "2026-01-03T00:00:00Z", publicPost)).rows
            .map((row) => row.post_id),
          [olderPost],
        );
        await assert.rejects(
          () => refs("public-circle", null, null, 0),
          (e: { code?: string }) => e.code === "22023",
        );
      },
    );
    await t.step(
      "allowed private member and owner keep access; pending legacy behavior stays unchanged",
      async () => {
        await admin(
          "insert into public.bil_community_circle_memberships(circle_id,owner_id) values ($1,$2)",
          [priv, viewer],
        );
        try {
          await actor(viewer);
          assert.equal(
            (await metadata(privatePost)).rows[0].circle?.slug,
            "private-circle",
          );
          assert.deepEqual(
            (await refs("private-circle")).rows.map((row) => row.post_id),
            [privatePost],
          );
          await actor(owner);
          assert.equal(
            (await metadata(privatePost)).rows[0].circle?.slug,
            "private-circle",
          );
          assert.equal(
            (await list()).rows.some((row) => row.slug === "pending-circle"),
            false,
          );
          await deniedCircle("pending-circle");
        } finally {
          await admin(
            "delete from public.bil_community_circle_memberships where circle_id=$1 and owner_id=$2",
            [priv, viewer],
          );
        }
      },
    );
    for (const [blocker, blocked] of [[viewer, owner], [owner, viewer]]) {
      await t.step(
        `creator block ${
          blocker === viewer ? "outgoing" : "incoming"
        } hides circle across legacy paths`,
        async () => {
          await admin(
            "insert into public.bil_blocks(blocker_id,blocked_id) values ($1,$2)",
            [blocker, blocked],
          );
          try {
            await actor(viewer);
            assert.deepEqual((await list()).rows.map((row) => row.slug), [
              "builtin-circle",
            ]);
            assert.equal((await metadata(publicPost)).rows[0].circle, null);
            await deniedCircle("public-circle");
          } finally {
            await admin(
              "delete from public.bil_blocks where blocker_id=$1 and blocked_id=$2",
              [blocker, blocked],
            );
          }
        },
      );
    }
    await t.step(
      "suspended viewer cannot enumerate circles or use legacy feed",
      async () => {
        await admin(
          "insert into private.bil_community_member_access(user_id,suspended,reason) values ($1,true,'Synthetic isolation')",
          [viewer],
        );
        try {
          await actor(viewer);
          assert.deepEqual((await list()).rows, []);
          await deniedCircle("public-circle");
        } finally {
          await admin(
            "delete from private.bil_community_member_access where user_id=$1",
            [viewer],
          );
        }
      },
    );
    await t.step(
      "private helper and direct tables stay inaccessible to authenticated callers",
      async () => {
        await actor(viewer);
        await assert.rejects(
          () => db.query("select private.bil_circle_visible_v1($1)", [pub]),
          (e: { code?: string }) => e.code === "42501",
        );
        await assert.rejects(
          () => db.query("select * from public.bil_community_circles"),
          (e: { code?: string }) => e.code === "42501",
        );
        for (const role of ["anon", "service_role"]) {
          await admin(`set role ${role}`);
          await assert.rejects(
            () => list(),
            (e: { code?: string }) => e.code === "42501",
          );
        }
      },
    );
  } finally {
    await db.close();
  }
});
