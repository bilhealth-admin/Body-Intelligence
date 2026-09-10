import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { type GlobalResetHandlerDependencies, handler } from "./server.ts";
import {
  safeSubscriptionResponse,
  subscriptionRpcRequest,
} from "./subscription_operations.ts";
const actor = "00000000-0000-4000-8000-000000000001";
Deno.test("unexpected private fields never cross the response boundary", () => {
  assertEquals(
    safeSubscriptionResponse("subscription_grant", {
      matched: true,
      changed: true,
      grant_id: actor,
      secret: "hidden",
    }),
    { matched: true, changed: true, grant_id: actor },
  );
  const row = {
    id: actor,
    email: "a@example.com",
    plan_id: "premium",
    status: "active",
    created_at: "2026-09-10T00:00:00Z",
    expires_at: null,
  };
  assertEquals(
    safeSubscriptionResponse("subscription_list", {
      rows: [{ ...row, receipt: "hidden" }],
      has_more: false,
    }),
    { rows: [row], has_more: false },
  );
  assertThrows(() =>
    safeSubscriptionResponse("subscription_list", {
      rows: [{}],
      has_more: false,
    })
  );
  assertThrows(() =>
    safeSubscriptionResponse("subscription_grant", {
      matched: false,
      changed: true,
      grant_id: null,
    })
  );
});
const gift = "00000000-0000-4000-8000-000000000002";
const base = {
  operation: "subscription_grant",
  email: " User@Example.COM ",
  plan_id: "premium_ai_coach",
  duration_days: null,
  idempotency_key: "subscription-request-00001",
};
Deno.test("grant RPC uses authenticated actor, normalized registered email and chosen duration", () => {
  const rpc = subscriptionRpcRequest({
    ...base,
    p_actor_id: gift,
    owner_id: gift,
  }, actor);
  assertEquals(rpc.args, {
    p_actor_id: actor,
    p_idempotency_key: base.idempotency_key,
    p_operation: "grant",
    p_email: "user@example.com",
    p_plan_id: "premium_ai_coach",
    p_duration_days: null,
    p_reason: "",
  });
});
Deno.test("invalid tiers, email, duration, cursor and revoke id are rejected", () => {
  for (
    const body of [
      { ...base, plan_id: "enterprise" },
      { ...base, email: "not-an-email" },
      { ...base, duration_days: -1 },
      { ...base, duration_days: "30" },
      { ...base, operation: "subscription_list", offset: -1 },
      {
        ...base,
        operation: "subscription_revoke",
        grant_id: "email@example.com",
      },
    ]
  ) {
    assertThrows(() => subscriptionRpcRequest(body, actor));
  }
});
for (
  const operation of [
    "subscription_grant",
    "subscription_revoke",
    "subscription_list",
  ]
) {
  for (const allowed of [true, false]) {
    Deno.test(`${operation} authorizes the server-verified admin before RPC (${allowed})`, async () => {
      const calls: Array<{ name: string; args?: Record<string, unknown> }> = [];
      const actions: string[] = [];
      const response = await handler(
        new Request("https://example.test/admin", {
          method: "POST",
          headers: { authorization: "Bearer session" },
          body: JSON.stringify({
            ...base,
            operation,
            grant_id: gift,
            p_actor_id: gift,
          }),
        }),
        {
          clients: (() => ({
            auth: {
              auth: {
                getUser: () =>
                  Promise.resolve({
                    data: { user: { id: actor } },
                    error: null,
                  }),
              },
              rpc: (name: string, args?: Record<string, unknown>) => {
                calls.push({ name, args });
                return Promise.resolve({
                  data: name === "bil_can_manage_ai_coach" ? allowed : null,
                  error: null,
                });
              },
            },
            admin: {
              rpc: (name: string, args?: Record<string, unknown>) => {
                calls.push({ name, args });
                return Promise.resolve({
                  data: operation === "subscription_list"
                    ? { rows: [], has_more: false }
                    : { matched: true, changed: true, grant_id: gift },
                  error: null,
                });
              },
            },
          })) as unknown as GlobalResetHandlerDependencies["clients"],
          requireIntegrity: ({ action, body }) => {
            actions.push(action);
            return Promise.resolve(body);
          },
        },
      );
      assertEquals(response.status, allowed ? 200 : 404);
      assertEquals(
        actions,
        allowed ? [`admin.subscriptions.${operation.split("_")[1]}`] : [],
      );
      const writes = calls.filter((c) =>
        c.name === "bil_manage_admin_subscription" ||
        c.name === "bil_list_admin_subscriptions"
      );
      assertEquals(writes.length, allowed ? 1 : 0);
      if (allowed) assertEquals(writes[0].args?.p_actor_id, actor);
    });
  }
}
