import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handler } from "./server.ts";

type RpcResult = {
  data: unknown;
  error: null | { message: string; code?: string };
};
type Call = { name: string; args?: Record<string, unknown> };
const resolvedTargetId = "00000000-0000-4000-8000-000000000099";

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
  idempotency_key: "global-reset-request-0001",
};

function fakeClients({
  allowed,
  calls,
  resolvedTarget = resolvedTargetId,
  rateLimited = false,
  retryableErrors = [],
}: {
  allowed: boolean;
  calls: Call[];
  resolvedTarget?: string | null;
  rateLimited?: boolean;
  retryableErrors?: string[];
}) {
  const pendingErrors = [...retryableErrors];
  return () =>
    ({
      auth: {
        auth: {
          // deno-lint-ignore require-await
          getUser: async () => ({
            data: { user: { id: "00000000-0000-4000-8000-000000000001" } },
            error: null,
          }),
        },
        // deno-lint-ignore require-await
        rpc: async (
          name: string,
          args?: Record<string, unknown>,
        ): Promise<RpcResult> => {
          calls.push({ name, args });
          if (name === "bil_can_manage_ai_coach") {
            return { data: allowed, error: null };
          }
          if (name === "bil_consume_rate_limit") {
            return rateLimited
              ? { data: null, error: { message: "rate limit exceeded" } }
              : { data: null, error: null };
          }
          throw new Error(`unexpected auth rpc: ${name}`);
        },
      },
      admin: {
        // deno-lint-ignore require-await
        rpc: async (
          name: string,
          args?: Record<string, unknown>,
        ): Promise<RpcResult> => {
          calls.push({ name, args });
          if (
            name === "bil_resolve_ai_coach_reset_target" ||
            name === "bil_resolve_admin_notification_target"
          ) {
            return { data: resolvedTarget, error: null };
          }
          if (pendingErrors.length > 0) {
            const code = pendingErrors.shift()!;
            return {
              data: null,
              error: { message: "retryable concurrency conflict", code },
            };
          }
          return name === "bil_enqueue_admin_notification"
            ? {
              data: { duplicate: false, recipients_enqueued: 2 },
              error: null,
            }
            : {
              data: { duplicate: false, users_notified: 2 },
              error: null,
            };
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

Deno.test("individual email is normalized server-side and target stays private", async () => {
  const calls: Call[] = [];
  const response = await handler(
    request({
      operation: "individual",
      email: "  Person@Example.COM ",
      reason: " compensation ",
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
});

Deno.test("admin receives only matched false for an unknown email", async () => {
  const knownCalls: Call[] = [];
  const unknownCalls: Call[] = [];
  const body = {
    operation: "individual",
    email: "nobody@example.com",
    reason: "reward",
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

Deno.test("canned notices reject injected text and conflicting targets", async () => {
  for (
    const body of [
      {
        operation: "notification",
        notification_kind: "gift",
        audience: "all",
        message: "override",
        idempotency_key: "admin-notification-request-0006",
      },
      {
        operation: "notification",
        notification_kind: "gift",
        audience: "all",
        email: "person@example.com",
        idempotency_key: "admin-notification-request-0007",
      },
    ]
  ) {
    const calls: Call[] = [];
    const response = await handler(request(body), {
      clients: fakeClients({ allowed: true, calls }),
    });
    assertEquals(response.status, 400);
    assertEquals(calls.map((call) => call.name), [
      "bil_can_manage_ai_coach",
    ]);
  }
});
