import { PGlite } from "npm:@electric-sql/pglite@0.3.15";

const memberA = "27100000-0000-4000-8000-000000000001";
const memberB = "27100000-0000-4000-8000-000000000002";
const stranger = "27100000-0000-4000-8000-000000000003";
const channelId = "27100000-0000-4000-8000-000000000101";
const clientMessageId = "27100000-0000-4000-8000-000000000201";

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

Deno.test("bil07 channel RPCs enforce policy, idempotency, receipts, RLS and TTL", async () => {
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
    await db.exec(
      "create table public.bil_community_moderators(user_id uuid primary key references auth.users(id))",
    );
    await db.exec(
      await Deno.readTextFile(
        new URL(
          "../migrations/20261018010609_bil07_channels_privacy_reporting_rate_guard_20261018.sql",
          import.meta.url,
        ),
      ),
    );

    const setActor = async (id: string) => {
      await db.query(
        `select set_config('request.jwt.claim.sub', $1, false),
          set_config('request.jwt.claim.role', 'authenticated', false),
          set_config('request.jwt.claims',
            json_build_object('sub',$1,'role','authenticated')::text,false)`,
        [id],
      );
    };

    await db.query(
      `insert into auth.users(id,email) values
        ($1,'member-a@example.invalid'),($2,'member-b@example.invalid'),
        ($3,'stranger@example.invalid')`,
      [memberA, memberB, stranger],
    );
    await db.query(
      `insert into public.bil_public_profiles(user_id,display_name,discoverable)
        values ($1,'Member A',false),($2,'Member B',true),($3,'Stranger',true)`,
      [memberA, memberB, stranger],
    );
    await db.query(
      `insert into public.bil_content_policies(version,locale_code,document_url,effective_at,active)
        values ('bil07-test-v1','en','https://example.invalid/policy',clock_timestamp() - interval '1 day',true)`,
    );
    for (const id of [memberA, memberB, stranger]) {
      await setActor(id);
      await db.query(
        `insert into public.bil_content_policy_acceptances(user_id,policy_version,accepted_at)
          values ($1,'bil07-test-v1',clock_timestamp())`,
        [id],
      );
    }
    await db.query(
      `insert into public.bil07_channels_v1(id,slug,title,description,visibility,enabled)
        values ($1,'general','General','Community discussion','public',true),
          ('27100000-0000-4000-8000-000000000102','members','Members','Members only','members',true)`,
      [channelId],
    );
    await db.query(
      `insert into public.bil07_channel_memberships_v1(channel_id,owner_id,status)
        values ('27100000-0000-4000-8000-000000000102',$1,'active'),
          ('27100000-0000-4000-8000-000000000102',$2,'active')`,
      [memberA, memberB],
    );

    await db.query("set role authenticated");
    await setActor(memberA);
    const capabilityRow = (await db.query(
      "select public.bil07_channel_capabilities_v1() as value",
    )).rows[0] as Record<string, unknown>;
    const capability = capabilityRow.value as Record<string, unknown>;
    assert(capability.contract_version === 1, "wrong contract version");
    assert(capability.max_text_code_points === 2000, "wrong text limit");
    assert(capability.max_page_size === 100, "wrong page limit");
    assert(capability.max_receipt_ids === 100, "wrong receipt limit");
    assert(capability.presence_ttl_seconds === 90, "wrong presence TTL");
    assert(capability.presence_heartbeat_seconds === 30, "wrong heartbeat");
    assert(
      capability.read_receipts === "exact_message_ids_v1",
      "wrong receipt contract",
    );
    assert(
      capability.realtime_available === false,
      "PGlite must not claim realtime",
    );

    const directoryRow = (await db.query(
      "select public.bil07_channel_directory_v1(null, 50) as value",
    )).rows[0] as Record<string, unknown>;
    const directory = directoryRow.value as Record<string, unknown>;
    const channels = directory.channels as Array<Record<string, unknown>>;
    assert(channels.length === 2, "directory omitted an enabled channel");
    const publicChannel = channels.find((row) => row.id === channelId)!;
    const membersChannel = channels.find((row) =>
      row.visibility === "members"
    )!;
    assert(publicChannel.can_read === true, "public channel is not readable");
    assert(publicChannel.can_send === true, "public channel is not writable");
    assert(
      publicChannel.membership === "active",
      "public membership projection changed",
    );
    assert(membersChannel.can_read === true, "active member was denied");

    const firstRow = (await db.query(
      "select public.bil07_channel_send_v1($1,$2,$3) as value",
      [channelId, clientMessageId, "Exact channel text 🌱"],
    )).rows[0] as Record<string, unknown>;
    const first = firstRow.value as Record<string, unknown>;
    const firstMessage = first.message as Record<string, unknown>;
    assert(first.idempotent_replay === false, "first send was marked replay");
    assert(
      firstMessage.text === "Exact channel text 🌱",
      "send changed message text",
    );
    assert(
      firstMessage.client_message_id === clientMessageId,
      "client id missing from owner receipt",
    );

    const retryRow = (await db.query(
      "select public.bil07_channel_send_v1($1,$2,$3) as value",
      [channelId, clientMessageId, "Exact channel text 🌱"],
    )).rows[0] as Record<string, unknown>;
    const retry = retryRow.value as Record<string, unknown>;
    assert(retry.idempotent_replay === true, "retry did not replay receipt");
    assert(
      (retry.message as Record<string, unknown>).id === firstMessage.id,
      "retry duplicated message",
    );
    await expectSqlState(
      () =>
        db.query(
          "select public.bil07_channel_send_v1($1,$2,$3)",
          [channelId, clientMessageId, "Changed content"],
        ),
      "22023",
    );
    await expectSqlState(
      () =>
        db.query(
          "select public.bil07_channel_send_v1($1,$2,$3)",
          [channelId, "27100000-0000-4000-8000-000000000202", " \t\n "],
        ),
      "22023",
    );

    await setActor(memberB);
    const incomingRow = (await db.query(
      "select public.bil07_channel_messages_v1($1,null,null,50) as value",
      [channelId],
    )).rows[0] as Record<string, unknown>;
    const incoming = incomingRow.value as Record<string, unknown>;
    const incomingRows = incoming.messages as Array<Record<string, unknown>>;
    assert(
      incomingRows.length === 1,
      "recipient did not read the inserted message",
    );
    assert(
      incomingRows[0].author_display_name === null,
      "private author name leaked",
    );
    assert(
      incomingRows[0].client_message_id === null,
      "sender idempotency key leaked",
    );
    assert(incomingRows[0].is_read === false, "unread message marked read");

    const messageId = incomingRows[0].id as string;
    await db.query(
      "select public.bil07_channel_read_v1($1,$2::uuid[])",
      [channelId, [messageId]],
    );
    const readbackRow = (await db.query(
      "select public.bil07_channel_readback_v1($1,$2::uuid[]) as value",
      [channelId, [messageId]],
    )).rows[0] as Record<string, unknown>;
    const readback = readbackRow.value as Record<string, unknown>;
    assert(
      (readback.acknowledged_message_ids as string[]).includes(messageId),
      "readback failed to confirm exact id",
    );
    assert(readback.unread_count === 0, "unread count did not update");

    const presenceRow = (await db.query(
      "select public.bil07_channel_presence_v1($1,true) as value",
      [channelId],
    )).rows[0] as Record<string, unknown>;
    const presence = presenceRow.value as Record<string, unknown>;
    const serverTime = Date.parse(presence.server_time as string);
    const expiresAt = Date.parse(presence.expires_at as string);
    const validUntil = Date.parse(presence.valid_until as string);
    assert(
      presence.online_count === 1,
      "presence count did not include the heartbeat",
    );
    assert(
      expiresAt - serverTime === 90_000,
      "presence expiry is not 90 seconds",
    );
    assert(
      validUntil - serverTime === 30_000,
      "presence freshness is not 30 seconds",
    );

    await setActor(stranger);
    const strangerDirectoryRow = (await db.query(
      "select public.bil07_channel_directory_v1(null, 50) as value",
    )).rows[0] as Record<string, unknown>;
    const strangerDirectory = strangerDirectoryRow.value as Record<
      string,
      unknown
    >;
    const strangerRows = strangerDirectory.channels as Array<
      Record<string, unknown>
    >;
    const locked = strangerRows.find((row) => row.visibility === "members");
    assert(
      locked === undefined,
      `members-only channel leaked access: ${JSON.stringify(locked)}`,
    );
    await expectSqlState(
      () =>
        db.query("select public.bil07_channel_messages_v1($1,null,null,50)", [
          membersChannel.id,
        ]),
      "42501",
    );
    await expectSqlState(
      () =>
        db.query(
          "insert into private.bil07_channel_presence_v1 values ($1,$2,now(),now()+interval '1 minute')",
          [channelId, stranger],
        ),
      "42501",
    );
    await expectSqlState(
      () =>
        db.query(
          "insert into public.bil07_channel_messages_v1(channel_id,author_id,client_message_id,text) values ($1,$2,$3,'bypass')",
          [channelId, stranger, "27100000-0000-4000-8000-000000000203"],
        ),
      "42501",
    );
    await db.query("reset role");
    const counts = (await db.query(
      "select count(*) as messages from public.bil07_channel_messages_v1",
    )).rows[0] as Record<string, unknown>;
    assert(
      Number(counts.messages) === 1,
      "idempotent retry wrote duplicate rows",
    );
  } finally {
    await db.close();
  }
});
