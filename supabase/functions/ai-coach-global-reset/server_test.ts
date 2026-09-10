import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  type GlobalResetHandlerDependencies,
  handler as productionHandler,
} from "./server.ts";

const handler = (
  request: Request,
  dependencies: GlobalResetHandlerDependencies = {},
) =>
  productionHandler(request, {
    // Unit tests exercise authorization, validation, rate limits, and RPC
    // boundaries with deterministic fakes. Production keeps the real mobile
    // integrity verifier unless a test explicitly replaces this dependency.
    requireIntegrity: ({ body }) => Promise.resolve(body),
    ...dependencies,
  });

type RpcResult = {
  data: unknown;
  error: null | { message: string; code?: string };
};
type Call = { name: string; args?: Record<string, unknown> };
const resolvedTargetId = "00000000-0000-4000-8000-000000000099";
const resetMessage = "A 2,500-token gift from BIL for your next coach session.";

function request(body: Record<string, unknown>) {
  return new Request("https://example.test/ai-coach-global-reset", {
    method: "POST",
    headers: {
      authorization: "Bearer user-jwt",
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });
}

const globalBody = {
  operation: "global",
  message: resetMessage,
  idempotency_key: "global-reset-request-0001",
};

function fakeClients({
  allowed,
  calls,
  resolvedTarget = resolvedTargetId,
  rateLimited = false,
  retryableErrors = [],
  moderatorAddError,
}: {
  allowed: boolean;
  calls: Call[];
  resolvedTarget?: string | null;
  rateLimited?: boolean;
  retryableErrors?: string[];
  moderatorAddError?: string;
}) {
  const pendingErrors = [...retryableErrors];
  return () =>
    ({
      auth: {
        auth: {
          getUser: () =>
            Promise.resolve({
              data: { user: { id: "00000000-0000-4000-8000-000000000001" } },
              error: null,
            }),
        },
        rpc: (
          name: string,
          args?: Record<string, unknown>,
        ): Promise<RpcResult> => {
          calls.push({ name, args });
          if (name === "bil_can_manage_ai_coach") {
            return Promise.resolve({ data: allowed, error: null });
          }
          if (name === "bil_consume_rate_limit") {
            return Promise.resolve(
              rateLimited
                ? { data: null, error: { message: "rate limit exceeded" } }
                : { data: null, error: null },
            );
          }
          return Promise.reject(new Error(`unexpected auth rpc: ${name}`));
        },
      },
      admin: {
        rpc: (
          name: string,
          args?: Record<string, unknown>,
        ): Promise<RpcResult> => {
          calls.push({ name, args });
          if (
            name === "bil_resolve_ai_coach_reset_target" ||
            name === "bil_resolve_admin_notification_target"
          ) {
            return Promise.resolve({ data: resolvedTarget, error: null });
          }
          if (name === "bil_list_community_moderators_for_admin") {
            return Promise.resolve({
              data: [{
                user_id: "00000000-0000-4000-8000-000000000002",
                email: "moderator@example.com",
                created_at: "2026-09-05T00:00:00.000Z",
                protected_administrator: false,
                ignored_private_field: "must-not-cross-edge-boundary",
              }],
              error: null,
            });
          }
          if (name === "bil_add_community_moderator_by_email") {
            if (moderatorAddError != null) {
              return Promise.resolve({
                data: null,
                error: { message: moderatorAddError },
              });
            }
            return Promise.resolve({
              data: { matched: true, added: true },
              error: null,
            });
          }
          if (name === "bil_remove_community_moderator") {
            return Promise.resolve({ data: true, error: null });
          }
          if (name === "bil_list_suspended_community_members_for_admin") {
            return Promise.resolve({
              data: [{
                user_id: "00000000-0000-4000-8000-000000000003",
                email: "suspended@example.com",
                reason: "Repeated Community policy violations",
                suspended_at: "2026-09-05T01:02:03.000Z",
                ignored_private_field: "must-not-cross-edge-boundary",
              }],
              error: null,
            });
          }
          if (name === "bil_suspend_community_member_by_email") {
            return Promise.resolve({
              data: {
                matched: true,
                active: true,
                changed: true,
                moderator_removed: false,
              },
              error: null,
            });
          }
          if (name === "bil_reinstate_community_member") {
            return Promise.resolve({ data: { reinstated: true }, error: null });
          }
          if (pendingErrors.length > 0) {
            const code = pendingErrors.shift()!;
            return Promise.resolve({
              data: null,
              error: { message: "retryable concurrency conflict", code },
            });
          }
          return Promise.resolve(
            name === "bil_enqueue_admin_notification" ||
              name === "bil_enqueue_admin_notification_with_message"
              ? {
                data: { duplicate: false, recipients_enqueued: 2 },
                error: null,
              }
              : {
                data: {
                  duplicate: false,
                  reset_id: "00000000-0000-4000-8000-000000000010",
                  usage_rows_reset: 1,
                  monthly_rows_reset: 1,
                  users_notified: 2,
                  boost_tokens_per_recipient: 2500,
                  custom_message_applied: true,
                },
                error: null,
              },
          );
        },
      },
    }) as never;
}

Deno.test("web preflight is handled without invoking auth", async () => {
  const response = await handler(
    new Request("https://example.test/ai-coach-global-reset", {
      method: "OPTIONS",
    }),
  );
  assertEquals(response.status, 204);
  assertEquals(
    response.headers.get("access-control-allow-methods"),
    "POST, OPTIONS",
  );
});

Deno.test("ordinary user is hidden before payload validation or mutation", async () => {
  const calls: Call[] = [];
  const response = await handler(request({ operation: "individual" }), {
    clients: fakeClients({ allowed: false, calls }),
  });
  assertEquals(response.status, 404);
  assertEquals(calls.map((call) => call.name), ["bil_can_manage_ai_coach"]);
});

Deno.test("authorized global reset reaches rate gate then service RPC", async () => {
  const calls: Call[] = [];
  const response = await handler(request(globalBody), {
    clients: fakeClients({ allowed: true, calls }),
  });
  assertEquals(response.status, 200);
  assertEquals(calls.map((call) => call.name), [
    "bil_can_manage_ai_coach",
    "bil_consume_rate_limit",
    "bil_global_reset_ai_coach",
  ]);
  assertEquals((await response.json()).users_notified, 2);
  assertEquals(calls[2].args?.p_message, resetMessage);
});

Deno.test("contended reset makes three bounded attempts with identical args", async () => {
  const calls: Call[] = [];
  const response = await handler(request(globalBody), {
    clients: fakeClients({
      allowed: true,
      calls,
      retryableErrors: ["55P03", "40P01"],
    }),
  });
  assertEquals(response.status, 200);
  assertEquals(calls.map((call) => call.name), [
    "bil_can_manage_ai_coach",
    "bil_consume_rate_limit",
    "bil_global_reset_ai_coach",
    "bil_global_reset_ai_coach",
    "bil_global_reset_ai_coach",
  ]);
  assertEquals(calls[2].args, calls[3].args);
  assertEquals(calls[3].args, calls[4].args);
});

Deno.test("serialization retry stops after three attempts", async () => {
  const calls: Call[] = [];
  const response = await handler(request(globalBody), {
    clients: fakeClients({
      allowed: true,
      calls,
      retryableErrors: ["40001", "40001", "40001", "40001"],
    }),
  });
  assertEquals(response.status, 500);
  assertEquals(
    calls.filter((call) => call.name === "bil_global_reset_ai_coach").length,
    3,
  );
});

Deno.test("invalid idempotency is rejected only after permission", async () => {
  const calls: Call[] = [];
  const response = await handler(
    request({ operation: "global", idempotency_key: "short" }),
    { clients: fakeClients({ allowed: true, calls }) },
  );
  assertEquals(response.status, 400);
  assertEquals(calls.map((call) => call.name), ["bil_can_manage_ai_coach"]);
});

Deno.test("moderator list is permission, integrity, rate, and shape guarded", async () => {
  const calls: Call[] = [];
  let integrityAction = "";
  const response = await handler(
    request({
      operation: "moderator_list",
      idempotency_key: "moderator-list-request-0001",
    }),
    {
      clients: fakeClients({ allowed: true, calls }),
      requireIntegrity: ({ action, body }) => {
        integrityAction = action;
        return Promise.resolve(body);
      },
    },
  );
  assertEquals(response.status, 200);
  assertEquals(integrityAction, "admin.community.moderators.list");
  assertEquals(calls.map((call) => call.name), [
    "bil_can_manage_ai_coach",
    "bil_consume_rate_limit",
    "bil_list_community_moderators_for_admin",
  ]);
  assertEquals(calls[1].args?.p_action, "admin_community_moderator_list");
  assertEquals(calls[2].args, {
    p_actor_id: "00000000-0000-4000-8000-000000000001",
  });
  assertEquals(await response.json(), [{
    user_id: "00000000-0000-4000-8000-000000000002",
    email: "moderator@example.com",
    created_at: "2026-09-05T00:00:00.000Z",
    protected_administrator: false,
  }]);
});

Deno.test("moderator add normalizes email and remains idempotent service-only", async () => {
  const calls: Call[] = [];
  const response = await handler(
    request({
      operation: "moderator_add",
      email: "  Moderator@Example.COM ",
      idempotency_key: "moderator-add-request-0001",
    }),
    { clients: fakeClients({ allowed: true, calls }) },
  );
  assertEquals(response.status, 200);
  assertEquals(await response.json(), { matched: true, added: true });
  assertEquals(calls.map((call) => call.name), [
    "bil_can_manage_ai_coach",
    "bil_consume_rate_limit",
    "bil_add_community_moderator_by_email",
  ]);
  assertEquals(calls[1].args?.p_action, "admin_community_moderator_add");
  assertEquals(calls[2].args, {
    p_actor_id: "00000000-0000-4000-8000-000000000001",
    p_email: "moderator@example.com",
    p_idempotency_key: "moderator-add-request-0001",
  });
});

Deno.test("suspended member cannot be added as a moderator", async () => {
  const calls: Call[] = [];
  const response = await handler(
    request({
      operation: "moderator_add",
      email: "suspended@example.com",
      idempotency_key: "moderator-add-suspended-0001",
    }),
    {
      clients: fakeClients({
        allowed: true,
        calls,
        moderatorAddError: "suspended_member_cannot_be_moderator",
      }),
    },
  );
  assertEquals(response.status, 409);
  assertEquals(await response.json(), { error: "suspended_member" });
});

Deno.test("moderator removal validates UUID and returns no roster PII", async () => {
  const invalidCalls: Call[] = [];
  const invalid = await handler(
    request({
      operation: "moderator_remove",
      user_id: "not-a-uuid",
      idempotency_key: "moderator-remove-request-0001",
    }),
    { clients: fakeClients({ allowed: true, calls: invalidCalls }) },
  );
  assertEquals(invalid.status, 400);
  assertEquals(invalidCalls.map((call) => call.name), [
    "bil_can_manage_ai_coach",
  ]);

  const calls: Call[] = [];
  const response = await handler(
    request({
      operation: "moderator_remove",
      user_id: "00000000-0000-4000-8000-000000000002",
      idempotency_key: "moderator-remove-request-0002",
    }),
    { clients: fakeClients({ allowed: true, calls }) },
  );
  assertEquals(response.status, 200);
  assertEquals(await response.json(), { removed: true });
  assertEquals(calls[2].args, {
    p_actor_id: "00000000-0000-4000-8000-000000000001",
    p_user_id: "00000000-0000-4000-8000-000000000002",
    p_idempotency_key: "moderator-remove-request-0002",
  });
});

Deno.test("suspended member list is admin, integrity, rate, and shape guarded", async () => {
  const calls: Call[] = [];
  let integrityAction = "";
  const response = await handler(
    request({
      operation: "community_member_list",
      idempotency_key: "community-member-list-0001",
    }),
    {
      clients: fakeClients({ allowed: true, calls }),
      requireIntegrity: ({ action, body }) => {
        integrityAction = action;
        return Promise.resolve(body);
      },
    },
  );
  assertEquals(response.status, 200);
  assertEquals(integrityAction, "admin.community.members.list");
  assertEquals(calls.map((call) => call.name), [
    "bil_can_manage_ai_coach",
    "bil_consume_rate_limit",
    "bil_list_suspended_community_members_for_admin",
  ]);
  assertEquals(await response.json(), [{
    user_id: "00000000-0000-4000-8000-000000000003",
    email: "suspended@example.com",
    reason: "Repeated Community policy violations",
    suspended_at: "2026-09-05T01:02:03.000Z",
  }]);
});

Deno.test("member suspension normalizes input and reaches service-only RPC", async () => {
  const calls: Call[] = [];
  const response = await handler(
    request({
      operation: "community_member_suspend",
      email: "  Suspended@Example.COM ",
      reason: "  Repeated Community policy violations  ",
      idempotency_key: "community-member-suspend-0001",
    }),
    { clients: fakeClients({ allowed: true, calls }) },
  );
  assertEquals(response.status, 200);
  assertEquals(await response.json(), {
    matched: true,
    active: true,
    changed: true,
    moderator_removed: false,
  });
  assertEquals(calls.map((call) => call.name), [
    "bil_can_manage_ai_coach",
    "bil_consume_rate_limit",
    "bil_suspend_community_member_by_email",
  ]);
  assertEquals(calls[2].args, {
    p_actor_id: "00000000-0000-4000-8000-000000000001",
    p_email: "suspended@example.com",
    p_reason: "Repeated Community policy violations",
    p_idempotency_key: "community-member-suspend-0001",
  });
});

Deno.test("member reinstatement validates UUID and returns only outcome", async () => {
  const calls: Call[] = [];
  const response = await handler(
    request({
      operation: "community_member_reinstate",
      user_id: "00000000-0000-4000-8000-000000000003",
      idempotency_key: "community-member-reinstate-0001",
    }),
    { clients: fakeClients({ allowed: true, calls }) },
  );
  assertEquals(response.status, 200);
  assertEquals(await response.json(), { reinstated: true });
  assertEquals(calls.map((call) => call.name), [
    "bil_can_manage_ai_coach",
    "bil_consume_rate_limit",
    "bil_reinstate_community_member",
  ]);
  assertEquals(calls[2].args, {
    p_actor_id: "00000000-0000-4000-8000-000000000001",
    p_user_id: "00000000-0000-4000-8000-000000000003",
    p_idempotency_key: "community-member-reinstate-0001",
  });
});

Deno.test("member suspension requires a useful audit reason", async () => {
  const calls: Call[] = [];
  const response = await handler(
    request({
      operation: "community_member_suspend",
      email: "person@example.com",
      reason: "x",
      idempotency_key: "community-member-suspend-0002",
    }),
    { clients: fakeClients({ allowed: true, calls }) },
  );
  assertEquals(response.status, 400);
  assertEquals((await response.json()).error, "invalid_suspension_reason");
  assertEquals(calls.map((call) => call.name), ["bil_can_manage_ai_coach"]);
});

Deno.test("individual email is normalized server-side and target stays private", async () => {
  const calls: Call[] = [];
  const response = await handler(
    request({
      operation: "individual",
      email: "  Person@Example.COM ",
      reason: " compensation ",
      message: `  ${resetMessage}  `,
      idempotency_key: "individual-reset-request-0001",
    }),
    { clients: fakeClients({ allowed: true, calls }) },
  );
  assertEquals(response.status, 200);
  assertEquals(await response.json(), { matched: true });
  assertEquals(calls.map((call) => call.name), [
    "bil_can_manage_ai_coach",
    "bil_consume_rate_limit",
    "bil_resolve_ai_coach_reset_target",
    "bil_individual_reset_ai_coach",
  ]);
  assertEquals(calls[2].args?.p_normalized_email, "person@example.com");
  assertEquals(calls[3].args?.p_reason, "compensation");
  assertEquals(calls[3].args?.p_message, resetMessage);
});

Deno.test("reset success fails closed without the atomic gift receipt", async () => {
  const calls: Call[] = [];
  const response = await handler(request(globalBody), {
    clients: (() => ({
      auth: {
        auth: {
          getUser: () =>
            Promise.resolve({
              data: { user: { id: "00000000-0000-4000-8000-000000000001" } },
              error: null,
            }),
        },
        rpc: (name: string) =>
          Promise.resolve(
            name === "bil_can_manage_ai_coach"
              ? { data: true, error: null }
              : { data: null, error: null },
          ),
      },
      admin: {
        rpc: (name: string, args?: Record<string, unknown>) => {
          calls.push({ name, args });
          return Promise.resolve({
            data: { duplicate: false, users_notified: 2 },
            error: null,
          });
        },
      },
    })) as never,
  });

  assertEquals(response.status, 500);
  assertEquals((await response.json()).error, "reset_failed");
});

Deno.test("admin receives only matched false for an unknown email", async () => {
  const knownCalls: Call[] = [];
  const unknownCalls: Call[] = [];
  const body = {
    operation: "individual",
    email: "nobody@example.com",
    reason: "reward",
    message: resetMessage,
    idempotency_key: "individual-reset-request-0002",
  };
  const known = await handler(request(body), {
    clients: fakeClients({ allowed: true, calls: knownCalls }),
  });
  const unknown = await handler(request(body), {
    clients: fakeClients({
      allowed: true,
      calls: unknownCalls,
      resolvedTarget: null,
    }),
  });
  assertEquals(known.status, 200);
  assertEquals(unknown.status, 200);
  assertEquals(await known.json(), { matched: true });
  assertEquals(await unknown.json(), { matched: false });
  assertEquals(unknownCalls.map((call) => call.name), [
    "bil_can_manage_ai_coach",
    "bil_consume_rate_limit",
    "bil_resolve_ai_coach_reset_target",
  ]);
});

Deno.test("individual reset is rate limited before account resolution", async () => {
  const calls: Call[] = [];
  const response = await handler(
    request({
      operation: "individual",
      email: "person@example.com",
      message: resetMessage,
      idempotency_key: "individual-reset-request-0003",
    }),
    { clients: fakeClients({ allowed: true, calls, rateLimited: true }) },
  );
  assertEquals(response.status, 429);
  assertEquals(calls.map((call) => call.name), [
    "bil_can_manage_ai_coach",
    "bil_consume_rate_limit",
  ]);
});

Deno.test("reset message is mandatory, bounded, and checked before rate use", async () => {
  for (const message of ["", "line one\nline two", "x".repeat(181)]) {
    const calls: Call[] = [];
    const response = await handler(
      request({
        operation: "global",
        message,
        idempotency_key: "global-reset-message-validation-0001",
      }),
      { clients: fakeClients({ allowed: true, calls }) },
    );
    assertEquals(response.status, 400);
    assertEquals(await response.json(), { error: "invalid_reset_message" });
    assertEquals(calls.map((call) => call.name), [
      "bil_can_manage_ai_coach",
    ]);
  }
});

Deno.test("global compensation notice is durable-server fanout only", async () => {
  const calls: Call[] = [];
  const response = await handler(
    request({
      operation: "notification",
      notification_kind: "compensation",
      audience: "all",
      idempotency_key: "admin-notification-request-0001",
    }),
    { clients: fakeClients({ allowed: true, calls }) },
  );
  assertEquals(response.status, 200);
  assertEquals(await response.json(), {
    matched: true,
    duplicate: false,
    recipients_enqueued: 2,
  });
  assertEquals(calls.map((call) => call.name), [
    "bil_can_manage_ai_coach",
    "bil_consume_rate_limit",
    "bil_enqueue_admin_notification",
  ]);
  assertEquals(calls[1].args?.p_action, "admin_notification_all");
  assertEquals(calls[2].args, {
    p_actor_id: "00000000-0000-4000-8000-000000000001",
    p_notification_kind: "compensation",
    p_audience: "all",
    p_target_id: null,
    p_custom_body: null,
    p_idempotency_key: "admin-notification-request-0001",
  });
});

Deno.test("targeted gift normalizes and resolves exact email", async () => {
  const calls: Call[] = [];
  const response = await handler(
    request({
      operation: "notification",
      notification_kind: "gift",
      audience: "email",
      email: "  Person@Example.COM ",
      idempotency_key: "admin-notification-request-0002",
    }),
    { clients: fakeClients({ allowed: true, calls }) },
  );
  assertEquals(response.status, 200);
  assertEquals((await response.json()).matched, true);
  assertEquals(calls.map((call) => call.name), [
    "bil_can_manage_ai_coach",
    "bil_consume_rate_limit",
    "bil_resolve_admin_notification_target",
    "bil_enqueue_admin_notification",
  ]);
  assertEquals(
    calls[2].args?.p_normalized_email,
    "person@example.com",
  );
  assertEquals(calls[3].args?.p_target_id, resolvedTargetId);
  assertEquals(calls[3].args?.p_custom_body, null);
});

Deno.test("unknown targeted notification returns no account data", async () => {
  const calls: Call[] = [];
  const response = await handler(
    request({
      operation: "notification",
      notification_kind: "gift",
      audience: "email",
      email: "nobody@example.com",
      idempotency_key: "admin-notification-request-0003",
    }),
    {
      clients: fakeClients({
        allowed: true,
        calls,
        resolvedTarget: null,
      }),
    },
  );
  assertEquals(response.status, 200);
  assertEquals(await response.json(), {
    matched: false,
    duplicate: false,
    recipients_enqueued: 0,
  });
  assertEquals(calls.map((call) => call.name), [
    "bil_can_manage_ai_coach",
    "bil_consume_rate_limit",
    "bil_resolve_admin_notification_target",
  ]);
});

Deno.test("targeted notification is rate limited before email resolution", async () => {
  const calls: Call[] = [];
  const response = await handler(
    request({
      operation: "notification",
      notification_kind: "gift",
      audience: "email",
      email: "person@example.com",
      idempotency_key: "admin-notification-request-0008",
    }),
    { clients: fakeClients({ allowed: true, calls, rateLimited: true }) },
  );
  assertEquals(response.status, 429);
  assertEquals(calls.map((call) => call.name), [
    "bil_can_manage_ai_coach",
    "bil_consume_rate_limit",
  ]);
  assertEquals(calls[1].args?.p_action, "admin_notification_individual");
});

Deno.test("custom notification requires exact non-empty safe text", async () => {
  for (const message of ["", "   ", "line one\nline two", { text: "no" }]) {
    const calls: Call[] = [];
    const response = await handler(
      request({
        operation: "notification",
        notification_kind: "custom",
        audience: "all",
        message,
        idempotency_key: "admin-notification-request-0004",
      }),
      { clients: fakeClients({ allowed: true, calls }) },
    );
    assertEquals(response.status, 400);
    assertEquals(await response.json(), {
      error: "invalid_notification_message",
    });
    assertEquals(calls.map((call) => call.name), [
      "bil_can_manage_ai_coach",
    ]);
  }

  const calls: Call[] = [];
  const response = await handler(
    request({
      operation: "notification",
      notification_kind: "custom",
      audience: "all",
      message: "  A precise owner-authored notice.  ",
      idempotency_key: "admin-notification-request-0005",
    }),
    { clients: fakeClients({ allowed: true, calls }) },
  );
  assertEquals(response.status, 200);
  assertEquals(
    calls[2].args?.p_custom_body,
    "A precise owner-authored notice.",
  );
});

Deno.test("authored gift keeps exact text for the atomic Boost grant", async () => {
  const calls: Call[] = [];
  const response = await handler(
    request({
      operation: "notification",
      notification_kind: "gift",
      audience: "all",
      message: "  Exact administrator gift message.  ",
      idempotency_key: "admin-notification-request-0006",
    }),
    { clients: fakeClients({ allowed: true, calls }) },
  );
  assertEquals(response.status, 200);
  assertEquals(calls.map((call) => call.name), [
    "bil_can_manage_ai_coach",
    "bil_consume_rate_limit",
    "bil_enqueue_admin_notification_with_message",
  ]);
  assertEquals(calls[2].args?.p_message, "Exact administrator gift message.");
});

Deno.test("broadcast notification rejects a conflicting email target", async () => {
  const calls: Call[] = [];
  const response = await handler(
    request({
      operation: "notification",
      notification_kind: "gift",
      audience: "all",
      email: "person@example.com",
      idempotency_key: "admin-notification-request-0007",
    }),
    { clients: fakeClients({ allowed: true, calls }) },
  );
  assertEquals(response.status, 400);
  assertEquals(calls.map((call) => call.name), ["bil_can_manage_ai_coach"]);
});
