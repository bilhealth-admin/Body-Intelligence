import { PGlite } from "npm:@electric-sql/pglite@0.3.15";

const ownerId = "15100000-0000-4000-8000-000000000001";
const moderatorId = "15100000-0000-4000-8000-000000000002";
const strangerId = "15100000-0000-4000-8000-000000000003";

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

Deno.test("AI Coach report goes through PostgreSQL submit, moderation, and review", async () => {
  const db = new PGlite();
  try {
    await db.exec(`
      create role anon;
      create role authenticated;
      create role service_role;
      create schema auth;
      create schema private;
      create table auth.users (id uuid primary key);
      create table public.bil_community_moderators (user_id uuid primary key);
      create table private.bil_ai_coach_admins (
        user_id uuid primary key,
        active boolean not null
      );
      create table public.bil_ai_usage_events (
        owner_id uuid not null,
        request_id text not null,
        capability text not null,
        state text not null
      );
      create function auth.uid() returns uuid
      language sql stable as $$
        select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
      $$;
      create function public.bil_can_use_community() returns boolean
      language sql stable security definer set search_path = '' as $$
        select auth.uid() is not null
      $$;
      create function private.bil_lock_community_authority_v1()
      returns text language plpgsql security definer set search_path = '' as $$
      declare v_actor uuid := auth.uid();
      begin
        if v_actor is null or not public.bil_can_use_community() then
          raise exception 'moderator_or_administrator_required'
            using errcode = '42501';
        end if;
        if exists (
          select 1 from public.bil_community_moderators m
          where m.user_id = v_actor
        ) then return 'moderator'; end if;
        if exists (
          select 1 from private.bil_ai_coach_admins a
          where a.user_id = v_actor and a.active
        ) then return 'admin'; end if;
        raise exception 'moderator_or_administrator_required'
          using errcode = '42501';
      end $$;
    `);
    await db.query("insert into auth.users(id) values ($1), ($2), ($3)", [
      ownerId,
      moderatorId,
      strangerId,
    ]);
    await db.query(
      "insert into public.bil_community_moderators(user_id) values ($1)",
      [moderatorId],
    );

    const migration = await Deno.readTextFile(
      new URL(
        "../migrations/20261014100000_ai_coach_safety_reports_v1.sql",
        import.meta.url,
      ),
    );
    await db.exec(migration);

    const setActor = async (id: string) => {
      await db.query(
        `select set_config('request.jwt.claim.sub', $1, false),
                set_config('request.jwt.claim.role', 'authenticated', false),
                set_config('request.jwt.claims',
                  json_build_object('sub', $1, 'role', 'authenticated')::text,
                  false)`,
        [id],
      );
    };

    await db.query("set role authenticated");
    await setActor(ownerId);
    await expectSqlState(
      () =>
        db.query(
          `select public.bil_submit_ai_coach_safety_report_v1(
          $1, $2, 'privacy', 'en', 'on_device', null, true
        )`,
          ["coach-response-unsupported-reason", "Synthetic answer."],
        ),
      "22023",
    );
    await expectSqlState(
      () =>
        db.query(
          `select public.bil_submit_ai_coach_safety_report_v1(
          $1, $2, 'unsafe', 'en', 'on_device', null, false
        )`,
          ["coach-response-missing-consent", "Synthetic answer."],
        ),
      "22023",
    );
    const firstRow = (await db.query(
      `select public.bil_submit_ai_coach_safety_report_v1(
        $1, $2, 'other', 'en-US', 'on_device', $3, true
      ) as receipt`,
      [
        "coach-response-pglite-01",
        "Exact answer only; no prompt or profile.",
        "Please review the displayed health claim.",
      ],
    )).rows[0] as Record<string, unknown>;
    const first = firstRow.receipt as Record<string, unknown>;
    assert(
      first.status === "open" && first.duplicate === false,
      "first report did not open",
    );

    const duplicateRow = (await db.query(
      `select public.bil_submit_ai_coach_safety_report_v1(
        $1, $2, 'unsafe', 'fr', 'local_fallback', null, true
      ) as receipt`,
      [
        "coach-response-pglite-01",
        "A retry must not overwrite the original answer.",
      ],
    )).rows[0] as Record<string, unknown>;
    const duplicate = duplicateRow.receipt as Record<string, unknown>;
    assert(
      duplicate.report_id === first.report_id && duplicate.duplicate === true,
      "submission retry created another report",
    );
    await expectSqlState(
      () => db.query("select * from private.bil_ai_coach_safety_reports_v1"),
      "42501",
    );
    await db.query("reset role");

    await db.query(
      `insert into private.bil_ai_coach_safety_reports_v1(
        owner_id, response_id, answer_text, reason, locale, runtime
      ) values ($1, $2, $3, 'privacy', 'en', 'on_device')`,
      [
        ownerId,
        "legacy-coach-response-01",
        "Historical privacy report remains reviewable.",
      ],
    );
    const storedConsent = (await db.query(
      `select consented_at, user_note
       from private.bil_ai_coach_safety_reports_v1
       where owner_id = $1 and response_id = $2`,
      [ownerId, "coach-response-pglite-01"],
    )).rows[0] as Record<string, unknown>;
    assert(
      storedConsent.consented_at != null,
      "explicit consent was not recorded",
    );
    assert(
      storedConsent.user_note === "Please review the displayed health claim.",
      "optional note was not stored with the report",
    );

    await db.query("set role authenticated");
    await setActor(strangerId);
    await expectSqlState(
      () =>
        db.query("select * from public.bil_list_ai_coach_safety_reports_v1()"),
      "42501",
    );
    await db.query("reset role");

    await db.query("set role authenticated");
    await setActor(moderatorId);
    const queueRows = (await db.query(
      "select report_entry from public.bil_list_ai_coach_safety_reports_v1() as q(report_entry)",
    )).rows as Record<string, unknown>[];
    const queueEntries = queueRows.map(
      (row) => row.report_entry as Record<string, unknown>,
    );
    const queue = queueEntries.find(
      (entry) => entry.report_id === first.report_id,
    );
    assert(queue != null, "new report was missing from moderator queue");
    assert(
      queue.answer_text === "Exact answer only; no prompt or profile.",
      "reviewer did not receive answer",
    );
    assert(
      queue.user_note === "Please review the displayed health claim.",
      "reviewer did not receive the optional note",
    );
    assert(
      !("owner_id" in queue) && !("prompt" in queue),
      "reviewer received excess user data",
    );
    const legacyPrivacy = queueEntries.find(
      (entry) => entry.reason === "privacy",
    );
    assert(
      legacyPrivacy?.answer_text ===
        "Historical privacy report remains reviewable.",
      "historical privacy report was not preserved in the moderator queue",
    );

    const operationId = "15100000-0000-4000-8000-000000000098";
    const reviewedRow = (await db.query(
      `select public.bil_review_ai_coach_safety_report_v1($1, $2, $3) as receipt`,
      [first.report_id, "confirmed_safety_issue", operationId],
    )).rows[0] as Record<string, unknown>;
    const reviewed = reviewedRow.receipt as Record<string, unknown>;
    const retriedRow = (await db.query(
      `select public.bil_review_ai_coach_safety_report_v1($1, $2, $3) as receipt`,
      [first.report_id, "confirmed_safety_issue", operationId],
    )).rows[0] as Record<string, unknown>;
    const retried = retriedRow.receipt as Record<string, unknown>;
    assert(reviewed.status === "reviewed", "review did not commit");
    assert(retried.duplicate === true, "review retry was not idempotent");

    const afterRow = (await db.query(
      `select report_entry from public.bil_list_ai_coach_safety_reports_v1() as q(report_entry)
       where report_entry->>'report_id' = $1`,
      [first.report_id],
    )).rows[0] as Record<string, unknown>;
    const after = afterRow.report_entry as Record<string, unknown>;
    assert(
      after.answer_text === null,
      "reviewed health-related answer was retained",
    );
    assert(after.user_note === null, "reviewed optional note was retained");
    assert(
      after.decision === "confirmed_safety_issue",
      "review decision is missing",
    );
    await db.query("reset role");
  } finally {
    await db.close();
  }
});
