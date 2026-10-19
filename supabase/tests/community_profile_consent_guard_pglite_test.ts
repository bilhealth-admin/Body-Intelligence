import { PGlite } from "npm:@electric-sql/pglite@0.3.15";
import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.test("profile UGC consent is enforced in PostgreSQL while privacy controls remain available", async () => {
  const db = new PGlite();
  const a = "51000000-0000-4000-8000-000000000001";
  const b = "51000000-0000-4000-8000-000000000002";
  const c = "51000000-0000-4000-8000-000000000003";
  try {
    await db.exec(
      "create role anon; create role authenticated; create role service_role; create role supabase_auth_admin; create role dashboard_user;",
    );
    for (const file of ["schema.sql", "functions.sql", "contracts.sql"]) {
      await db.exec(
        await Deno.readTextFile(
          new URL(
            `./fixtures/community_message_baseline/${file}`,
            import.meta.url,
          ),
        ),
      );
    }
    await db.exec(`insert into auth.users(id) values ('${a}'),('${b}'),('${c}');
      insert into public.bil_content_policies(version,document_url,effective_at,active)
      values ('policy-test-v1','https://www.bilhealth.com/community-guidelines',now()-interval '1 day',true);
      insert into public.bil_public_profiles(user_id,display_name,bio,avatar_url)
      values ('${a}','Original member','Original bio','https://example.invalid/original'),('${b}','Other member',null,null);`);
    const sql = await Deno.readTextFile(
      new URL(
        "../migrations/20261019083913_community_profile_consent_guard_20261019.sql",
        import.meta.url,
      ),
    );
    await db.exec(sql);
    await db.exec(sql); // safe migration reapplication, no profile rewrites
    const actor = async (id: string) => {
      await db.exec("reset role");
      await db.query("select set_config('request.jwt.claim.sub',$1,false)", [
        id,
      ]);
      await db.exec("set role authenticated");
    };
    const accept = async (id: string, version = "policy-test-v1") => {
      await actor(id);
      await db.query(
        "insert into public.bil_content_policy_acceptances(user_id,policy_version) values ($1,$2)",
        [id, version],
      );
    };
    await actor(a);
    await assertRejects(
      () =>
        db.query(
          "update public.bil_public_profiles set display_name='Changed' where user_id=$1",
          [a],
        ),
      Error,
      "community_policy_acceptance_required",
    );
    await assertRejects(
      () =>
        db.query(
          "update public.bil_public_profiles set avatar_url='https://example.invalid/new' where user_id=$1",
          [a],
        ),
      Error,
      "community_policy_acceptance_required",
    );
    await assertRejects(
      () =>
        db.query(
          "update public.bil_public_profiles set cover_object_path='new-cover' where user_id=$1",
          [a],
        ),
      Error,
      "community_policy_acceptance_required",
    );
    await db.query(
      "update public.bil_public_profiles set discoverable=false, allow_friend_requests=false,bio=null,avatar_url=null where user_id=$1",
      [a],
    );
    await actor(c);
    await assertRejects(
      () =>
        db.query(
          "insert into public.bil_public_profiles(user_id,display_name) values ($1,'Forged owner')",
          [a],
        ),
      Error,
      "community_profile_owner_required",
    );
    await assertRejects(
      () =>
        db.query(
          "insert into public.bil_public_profiles(user_id,display_name) values ($1,'New member')",
          [c],
        ),
      Error,
      "community_policy_acceptance_required",
    );
    await accept(c);
    await actor(c);
    await db.query(
      "insert into public.bil_public_profiles(user_id,display_name) values ($1,'New member')",
      [c],
    );
    await actor(a);
    await assertRejects(
      () =>
        db.query(
          "update public.bil_public_profiles set discoverable=true where user_id=$1",
          [a],
        ),
      Error,
      "community_policy_acceptance_required",
    );
    await db.query(
      "update public.bil_public_profiles set profile_visibility='private' where user_id=$1",
      [a],
    );
    await assertRejects(
      () =>
        db.query(
          "update public.bil_public_profiles set profile_visibility='public' where user_id=$1",
          [a],
        ),
      Error,
      "community_policy_acceptance_required",
    );
    await accept(a);
    await actor(a);
    await db.query(
      "update public.bil_public_profiles set display_name='Changed' where user_id=$1",
      [a],
    );
    await actor(b);
    const cross = await db.query(
      "update public.bil_public_profiles set display_name='Cross owner' where user_id=$1 returning user_id",
      [a],
    );
    assertEquals(cross.rows.length, 0);
    await db.exec("reset role");
    await db.query(
      "insert into private.bil_community_member_access(user_id,suspended,reason) values ($1,true,'fixture')",
      [a],
    );
    await actor(a);
    await assertRejects(
      () =>
        db.query(
          "update public.bil_public_profiles set display_name='Suspended change' where user_id=$1",
          [a],
        ),
      Error,
      "community_access_suspended",
    );
    await db.query(
      "update public.bil_public_profiles set profile_visibility='private',allow_messages_from='nobody' where user_id=$1",
      [a],
    );
    await db.exec("reset role");
    const rows = await db.query<
      { display_name: string; profile_visibility: string }
    >(
      "select display_name,profile_visibility from public.bil_public_profiles where user_id=$1",
      [a],
    );
    assertEquals(rows.rows[0].display_name, "Changed");
    assertEquals(rows.rows[0].profile_visibility, "private");
  } catch (error) {
    const detail = error as { query?: string; where?: string };
    console.error({ query: detail.query, where: detail.where });
    throw error;
  } finally {
    await db.close();
  }
});
