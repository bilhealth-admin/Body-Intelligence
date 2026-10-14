import { PGlite } from "npm:@electric-sql/pglite@0.3.15";

const senderId = "25100000-0000-4000-8000-000000000001";
const recipientId = "25100000-0000-4000-8000-000000000002";
const strangerId = "25100000-0000-4000-8000-000000000003";
const requestId = "25100000-0000-4000-8000-000000000101";

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

Deno.test("community message delivery v2 persists once and remains owner scoped", async () => {
  const db = new PGlite();
  try {
    await db.exec(
      `create role anon; create role authenticated; create role service_role;
       create role supabase_auth_admin; create role dashboard_user;`,
    );
    const baseline = new URL(
      "./fixtures/community_message_baseline/",
      import.meta.url,
    );
    for (const file of ["schema.sql", "functions.sql", "contracts.sql"]) {
      await db.exec(await Deno.readTextFile(new URL(file, baseline)));
    }
    const migration = await Deno.readTextFile(
      new URL(
        "../migrations/20261013062209_community_message_delivery_v2.sql",
        import.meta.url,
      ),
    );
    await db.exec(migration);

    const setActor = async (id: string | null) => {
      await db.query(
        `select set_config('request.jwt.claim.sub', coalesce($1,''), false),
          set_config('request.jwt.claim.role', 'authenticated', false),
          set_config('request.jwt.claims',
            json_build_object('sub',$1,'role','authenticated')::text,false)`,
        [id],
      );
    };

    await db.query(
      `insert into auth.users(id,email) values ($1,'sender@example.invalid'),
        ($2,'recipient@example.invalid'),($3,'stranger@example.invalid')`,
      [senderId, recipientId, strangerId],
    );
    await db.query(
      `insert into public.bil_public_profiles(user_id,display_name,allow_messages_from)
        values ($1,'Sender','friends'),($2,'Recipient','friends'),($3,'Stranger','friends')`,
      [senderId, recipientId, strangerId],
    );
    await db.query(
      `insert into public.bil_friendships(requester_id,addressee_id,status,responded_at)
        values ($1,$2,'accepted',clock_timestamp())`,
      [senderId, recipientId],
    );
    await db.query(
      `insert into public.bil_content_policies(version,locale_code,document_url,effective_at,active)
        values ('test-v1','en','https://example.invalid/community-policy',clock_timestamp() - interval '1 day',true)`,
    );
    await setActor(senderId);
    await db.query(
      `insert into public.bil_content_policy_acceptances(user_id,policy_version,accepted_at)
        values ($1,'test-v1',clock_timestamp())`,
      [senderId],
    );
    await setActor(recipientId);
    await db.query(
      `insert into public.bil_content_policy_acceptances(user_id,policy_version,accepted_at)
        values ($1,'test-v1',clock_timestamp())`,
      [recipientId],
    );
    await db.query("set role authenticated");
    await setActor(senderId);

    const firstRow = (await db.query(
      `select public.bil_send_community_message_v2($1,$2,$3) as receipt`,
      [recipientId, "One delivered message", requestId],
    )).rows[0] as Record<string, unknown>;
    const first = firstRow.receipt as Record<string, unknown>;
    assert(first.status === "delivered", "first send did not return delivered");
    assert(first.body === "One delivered message", "first send body changed");
    const messageId = first.message_id as string;
    assert(Boolean(messageId), "delivery receipt missed its message id");

    const retryRow = (await db.query(
      `select public.bil_send_community_message_v2($1,$2,$3) as receipt`,
      [recipientId, "One delivered message", requestId],
    )).rows[0] as Record<string, unknown>;
    const retry = retryRow.receipt as Record<string, unknown>;
    assert(retry.message_id === messageId, "retry created another message");
    assert(retry.status === "delivered", "retry lost the delivery receipt");
    await expectSqlState(
      () =>
        db.query(
          `select public.bil_send_community_message_v2($1,$2,$3)`,
          [recipientId, "Changed content for same request", requestId],
        ),
      "22023",
    );

    await db.query("reset role");
    const counts = (await db.query(
      `select (select count(*) from public.bil_messages) as messages,
        (select count(*) from public.bil_push_outbox where category='message') as pushes,
        (select count(*) from private.bil_community_message_deliveries_v2) as receipts`,
    )).rows[0] as Record<string, unknown>;
    assert(Number(counts.messages) === 1, "retry duplicated the message row");
    assert(Number(counts.pushes) === 1, "retry duplicated the notification");
    assert(
      Number(counts.receipts) === 1,
      "retry duplicated its delivery record",
    );

    await db.query("set role authenticated");
    await setActor(strangerId);
    const crossAccount = (await db.query(
      `select public.bil_get_community_message_delivery_v2($1) as receipt`,
      [requestId],
    )).rows[0] as Record<string, unknown>;
    assert(
      crossAccount.receipt === null,
      "another account read the owner's receipt",
    );
    await expectSqlState(
      () =>
        db.query("select * from private.bil_community_message_deliveries_v2"),
      "42501",
    );
    await db.query("reset role");

    await db.query(
      `update public.bil_messages set deleted_by_sender_at=clock_timestamp() where id=$1`,
      [messageId],
    );
    await db.query("set role authenticated");
    await setActor(senderId);
    const removedRow = (await db.query(
      `select public.bil_get_community_message_delivery_v2($1) as receipt`,
      [requestId],
    )).rows[0] as Record<string, unknown>;
    const removed = removedRow.receipt as Record<string, unknown>;
    assert(removed.status === "removed", "deleted delivery was not tombstoned");
    assert(removed.body === null, "deleted message body remained visible");
  } finally {
    await db.close();
  }
});
