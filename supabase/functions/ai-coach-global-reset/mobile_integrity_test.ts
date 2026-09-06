import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { requireMobileIntegrityGrant } from "../_shared/mobile_integrity.ts";
import { handler } from "./server.ts";

type RpcResult = {
  data: unknown;
  error: null | { message: string };
};

type Call = {
  boundary: "auth" | "admin";
  name: string;
  args?: Record<string, unknown>;
};

const ownerId = "00000000-0000-4000-8000-000000000001";
const grantId = "00000000-0000-4000-8000-000000000002";

const failureCases: Array<{
  name: string;
  envelope: Record<string, unknown>;
  result: RpcResult;
  status: number;
  error: string;
  integrityRpcCalls: number;
}> = [
  {
    name: "malformed envelope",
    envelope: { grant_id: "not-a-grant" },
    result: { data: true, error: null },
    status: 403,
    error: "mobile_integrity_grant_required",
    integrityRpcCalls: 0,
  },
  {
    name: "rejected grant",
    envelope: { grant_id: grantId },
    result: { data: false, error: null },
    status: 403,
    error: "mobile_integrity_grant_invalid",
    integrityRpcCalls: 1,
  },
  {
    name: "verifier outage",
    envelope: { grant_id: grantId },
    result: { data: null, error: { message: "database unavailable" } },
    status: 503,
    error: "mobile_integrity_verification_unavailable",
    integrityRpcCalls: 1,
  },
];

const protectedOperations = [
  {
    action: "admin.ai_coach.global_reset",
    body: {
      operation: "global",
      message: "A safe reset message.",
      idempotency_key: "integrity-global-0001",
    },
  },
  {
    action: "admin.ai_coach.individual_reset",
    body: {
      operation: "individual",
      email: "person@example.com",
      message: "A safe reset message.",
      idempotency_key: "integrity-individual-0001",
    },
  },
  {
    action: "admin.ai_coach.notification",
    body: {
      operation: "notification",
      notification_kind: "custom",
      audience: "all",
      message: "A safe notification.",
      idempotency_key: "integrity-notification-0001",
    },
  },
] as const;

function request(body: Record<string, unknown>) {
  return new Request("https://example.test/ai-coach-global-reset", {
    method: "POST",
    headers: {
      authorization: "Bearer admin-jwt",
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });
}

function enforcingGuard(actions: string[]) {
  return (input: Parameters<typeof requireMobileIntegrityGrant>[0]) => {
    actions.push(input.action);
    return requireMobileIntegrityGrant({ ...input, enforcement: "enforce" });
  };
}

for (const protectedOperation of protectedOperations) {
  Deno.test(`${protectedOperation.action} fails closed before rate limit or mutation`, async () => {
    for (const failure of failureCases) {
      const actions: string[] = [];
      const calls: Call[] = [];
      const response = await handler(
        request({
          ...protectedOperation.body,
          _integrity: failure.envelope,
        }),
        {
          clients: (() => ({
            auth: {
              auth: {
                getUser: () =>
                  Promise.resolve({
                    data: { user: { id: ownerId } },
                    error: null,
                  }),
              },
              rpc: (
                name: string,
                args?: Record<string, unknown>,
              ): Promise<RpcResult> => {
                calls.push({ boundary: "auth", name, args });
                if (name === "bil_can_manage_ai_coach") {
                  return Promise.resolve({ data: true, error: null });
                }
                return Promise.reject(
                  new Error(`admin_work_reached_before_guard:${name}`),
                );
              },
            },
            admin: {
              rpc: (
                name: string,
                args?: Record<string, unknown>,
              ): Promise<RpcResult> => {
                calls.push({ boundary: "admin", name, args });
                if (name === "bil_consume_mobile_integrity_grant") {
                  return Promise.resolve(failure.result);
                }
                return Promise.reject(
                  new Error(`admin_work_reached_before_guard:${name}`),
                );
              },
            },
          })) as never,
          requireIntegrity: enforcingGuard(actions),
        },
      );

      assertEquals(response.status, failure.status, failure.name);
      assertEquals((await response.json()).error, failure.error, failure.name);
      assertEquals(actions, [protectedOperation.action], failure.name);
      assertEquals(
        calls.map((call) => `${call.boundary}:${call.name}`),
        failure.integrityRpcCalls === 0 ? ["auth:bil_can_manage_ai_coach"] : [
          "auth:bil_can_manage_ai_coach",
          "admin:bil_consume_mobile_integrity_grant",
        ],
        failure.name,
      );
      if (failure.integrityRpcCalls === 1) {
        assertEquals(calls[1].args?.p_action, protectedOperation.action);
      }
    }
  });
}
