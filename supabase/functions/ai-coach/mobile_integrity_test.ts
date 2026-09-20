import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { requireMobileIntegrityGrant } from "../_shared/mobile_integrity.ts";
import { handler } from "./server.ts";

type RpcResult = {
  data: unknown;
  error: null | { message: string };
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

function request(envelope: Record<string, unknown>) {
  return new Request("https://example.test/ai-coach", {
    method: "POST",
    headers: {
      authorization: "Bearer user-jwt",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      request_id: "coach-integrity-request-0001",
      locale: "en",
      messages: [{ role: "user", content: "Give one short sleep tip" }],
      context: {},
      _integrity: envelope,
    }),
  });
}

function enforcingGuard(actions: string[]) {
  return (input: Parameters<typeof requireMobileIntegrityGrant>[0]) => {
    actions.push(input.action);
    return requireMobileIntegrityGrant({ ...input, enforcement: "enforce" });
  };
}

Deno.test("AI Coach fails closed at its integrity guard before any coach work", async () => {
  for (const failure of failureCases) {
    const actions: string[] = [];
    const adminCalls: Array<{
      name: string;
      args: Record<string, unknown>;
    }> = [];
    let providerCalls = 0;
    const response = await handler(request(failure.envelope), {
      clients: (() => ({
        auth: {
          auth: {
            getUser: () =>
              Promise.resolve({
                data: { user: { id: ownerId } },
                error: null,
              }),
          },
        },
        admin: {
          rpc: (name: string, args: Record<string, unknown>) => {
            adminCalls.push({ name, args });
            if (name === "bil_consume_mobile_integrity_grant") {
              return Promise.resolve(failure.result);
            }
            return Promise.reject(
              new Error(`coach_work_reached_before_guard:${name}`),
            );
          },
        },
      })) as never,
      requireIntegrity: enforcingGuard(actions),
      geminiCall: () => {
        providerCalls += 1;
        return Promise.reject(new Error("provider_reached_before_guard"));
      },
    });

    assertEquals(response.status, failure.status, failure.name);
    assertEquals((await response.json()).error, failure.error, failure.name);
    assertEquals(actions, ["ai_coach.request"], failure.name);
    assertEquals(adminCalls.length, failure.integrityRpcCalls, failure.name);
    if (adminCalls.length === 1) {
      assertEquals(
        adminCalls[0],
        {
          name: "bil_consume_mobile_integrity_grant",
          args: {
            p_grant_id: grantId,
            p_owner_id: ownerId,
            p_action: "ai_coach.request",
            p_payload_digest: adminCalls[0].args.p_payload_digest,
          },
        },
        failure.name,
      );
    }
    assertEquals(providerCalls, 0, failure.name);
  }
});
