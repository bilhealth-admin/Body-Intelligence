import { PGlite } from "npm:@electric-sql/pglite@0.3.15";

const strangerId = "26100000-0000-4000-8000-000000000001";
const moderatorId = "26100000-0000-4000-8000-000000000002";
const adminId = "26100000-0000-4000-8000-000000000003";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

async function expectSqlState(
  action: () => Promise<unknown>,
  expectedCode: string,
): Promise<void> {
  try {
    await action();
  } catch (error) {
    if ((error as { code?: string }).code === expectedCode) return;
    throw error;
  }
  throw new Error(`Expected SQLSTATE ${expectedCode}`);
}

async function expectPassedAuthority(
  action: () => Promise<unknown>,
  denialMessage: string,
): Promise<void> {
  try {
    await action();
  } catch (error) {
    if ((error as { message?: string }).message?.includes(denialMessage)) {
      throw new Error(`authorized actor was rejected: ${denialMessage}`);
    }
    return;
  }
  throw new Error(
    "Expected the incomplete catalog fixture to stop business logic",
  );
}

Deno.test("community safety review migration preserves RPCs and injects role checks", async () => {
  const db = new PGlite();
  try {
    await db.exec(`
      create role anon;
      create role authenticated;
      create role service_role;
      create role supabase_auth_admin;
      create role dashboard_user;
      create schema auth;
      create schema private;
      create function auth.uid() returns uuid language sql stable as $$
        select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
      $$;
      create function auth.jwt() returns jsonb language sql stable as $$
        select coalesce(
          nullif(current_setting('request.jwt.claims',true),'')::jsonb,
          jsonb_build_object('role',current_setting('request.jwt.claim.role',true))
        )
      $$;
      create table private.bil_ai_coach_admins (user_id uuid primary key, active boolean not null);
      create table public.bil_community_moderators (user_id uuid primary key);
      create table public.bil_social_comment_reports_v2 (
        id uuid primary key, reviewed_at timestamptz, comment_id uuid, reason text
      );
      create table public.bil_social_comments_v2 (
        id uuid primary key, post_id uuid, parent_id uuid, author_id uuid,
        deleted_at timestamptz, removed_at timestamptz, body text
      );
      create table public.bil_community_reports (
        id uuid primary key, status text, target_id uuid, target_kind text, reason text
      );
      create table public.bil_community_posts (
        id uuid primary key, author_id uuid, deleted_at timestamptz, body text,
        created_at timestamptz, visibility text, moderation_status text,
        moderation_visibility text, media_object_path text, media_mime_type text,
        media_bytes bigint, media_width integer, media_height integer
      );
      create table public.bil_community_post_media_v1 (post_id uuid, position integer);
      create table public.bil_community_polls (post_id uuid);
      create table public.bil_community_poll_options (post_id uuid, position integer);
      create table public.bil_messages (
        id uuid primary key, sender_id uuid, recipient_id uuid, body text,
        deleted_by_sender_at timestamptz, deleted_by_recipient_at timestamptz
      );
      create table public.bil_community_food_submissions (
        id uuid primary key, contributor_id uuid, canonical_name text
      );
      create table public.bil_public_profiles (
        user_id uuid primary key, display_name text, bio text
      );
      grant usage on schema auth, private, public to anon, authenticated, service_role;
    `);
    const fixture = new URL(
      "./fixtures/community_safety_authority_baseline/",
      import.meta.url,
    );
    for (const file of ["functions.sql", "contracts.sql"]) {
      await db.exec(await Deno.readTextFile(new URL(file, fixture)));
    }
    await db.exec(`
      create function public.bil_can_use_community() returns boolean
      language sql stable security definer set search_path='' as $$
        select auth.uid() is not null
      $$;
    `);

    const migration = await Deno.readTextFile(
      new URL(
        "../migrations/20261013062221_community_safety_report_review_v1.sql",
        import.meta.url,
      ),
    );
    await db.exec(migration);

    const reportId = "26100000-0000-4000-8000-000000000201";
    const postId = "26100000-0000-4000-8000-000000000202";
    await db.query(
      `insert into public.bil_community_posts(
        id,author_id,body,created_at,visibility,moderation_status,moderation_visibility
      ) values ($1,$2,'Synthetic post for moderator review',clock_timestamp(),'public','approved','visible')`,
      [postId, strangerId],
    );
    await db.query(
      `insert into public.bil_community_reports(id,status,target_id,target_kind,reason)
        values ($1,'open',$2,'post','safety')`,
      [reportId, postId],
    );

    const guardedSignatures = [
      "public.bil_add_community_moderator_by_email(uuid,text,text)",
      "public.bil_remove_community_moderator(uuid,uuid,text)",
      "public.bil_suspend_community_member_by_email(uuid,text,text,text)",
      "public.bil_reinstate_community_member(uuid,uuid,text)",
      "public.bil_moderate_community_post(uuid,text)",
      "public.bil_moderate_published_community_post(uuid,text,text)",
      "public.bil_moderate_community_report(uuid,text,text)",
      "public.bil_social_resolve_comment_report_v2(uuid,boolean)",
    ];
    for (const signature of guardedSignatures) {
      const result = await db.query(
        "select pg_get_functiondef($1::regprocedure) as definition",
        [signature],
      );
      const definition = String(
        (result.rows[0] as Record<string, unknown>).definition,
      );
      const adminOnly = signature.includes("bil_add_community_moderator") ||
        signature.includes("bil_remove_community_moderator") ||
        signature.includes("bil_suspend_community_member") ||
        signature.includes("bil_reinstate_community_member");
      const guard = adminOnly
        ? "bil_lock_community_admin_v1(p_actor_id)"
        : "bil_lock_community_authority_v1()";
      assert(
        definition.includes(guard),
        `required live authority guard missing from ${signature}`,
      );
    }

    await db.query("set role authenticated");
    const setActor = async (id: string, role = "authenticated") => {
      await db.query(
        `select set_config('request.jwt.claim.sub',$1,false),
          set_config('request.jwt.claim.role',$2,false),
          set_config('request.jwt.claims',json_build_object('sub',$1,'role',$2)::text,false)`,
        [id, role],
      );
    };
    await setActor(strangerId);
    await expectSqlState(
      () =>
        db.query(
          "select public.bil_moderate_community_post($1,'approve')",
          ["26100000-0000-4000-8000-000000000101"],
        ),
      "42501",
    );

    await db.query("reset role");
    await db.query(
      "insert into public.bil_community_moderators(user_id) values ($1)",
      [moderatorId],
    );
    await db.query("set role authenticated");
    await setActor(moderatorId);
    const contentRow = (await db.query(
      "select public.bil_community_report_content_v1($1,'community') as content",
      [reportId],
    )).rows[0] as Record<string, unknown>;
    const content = contentRow.content as Record<string, unknown>;
    assert(
      content.body === "Synthetic post for moderator review",
      "moderator cannot read reported content",
    );
    assert(
      content.available === true && content.can_remove === true,
      "open post review flags are wrong",
    );
    assert(
      !("reporter_id" in content) && !("owner_id" in content),
      "report content exposes reporter or owner data",
    );
    await expectPassedAuthority(
      () =>
        db.query(
          "select public.bil_moderate_community_post($1,'approve')",
          ["26100000-0000-4000-8000-000000000101"],
        ),
      "moderator_or_administrator_required",
    );

    await db.query("reset role");
    await db.query(
      "insert into private.bil_ai_coach_admins(user_id,active) values ($1,true)",
      [adminId],
    );
    await db.query("set role service_role");
    await setActor(adminId, "service_role");
    await expectPassedAuthority(
      () =>
        db.query(
          "select public.bil_add_community_moderator_by_email($1,'new@example.invalid','synthetic-idempotency')",
          [adminId],
        ),
      "administrator_required",
    );
    await db.query("reset role");

    const acl = (await db.query(`
      select has_function_privilege('anon',
        'public.bil_community_report_content_v1(uuid,text)','EXECUTE') as anon_can_read,
        has_function_privilege('authenticated',
        'public.bil_community_report_content_v1(uuid,text)','EXECUTE') as user_can_read,
        has_function_privilege('service_role',
        'public.bil_add_community_moderator_by_email(uuid,text,text)','EXECUTE') as service_can_manage
    `)).rows[0] as Record<string, unknown>;
    assert(
      acl.anon_can_read === false,
      "anonymous report-content access is granted",
    );
    assert(
      acl.user_can_read === true,
      "authenticated report-review RPC is inaccessible",
    );
    assert(
      acl.service_can_manage === true,
      "service role cannot call management RPC",
    );
    await db.query("set role authenticated");
    await expectSqlState(
      () => db.query("select * from private.bil_community_report_decisions_v1"),
      "42501",
    );
  } finally {
    await db.close();
  }
});
