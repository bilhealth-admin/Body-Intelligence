import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { requireMobileIntegrityGrant } from "../_shared/mobile_integrity.ts";
import { handler } from "./store_backend.ts";

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

const protectedActions = [
  {
    routeAction: "verify_purchase",
    integrityAction: "store.verify_purchase",
    productId: "bil_premium",
  },
  {
    routeAction: "verify_ai_boost",
    integrityAction: "store.verify_ai_boost",
    productId: "bil_ai_boost",
  },
] as const;

function request(
  routeAction: string,
  productId: string,
  envelope: Record<string, unknown>,
) {
  return new Request("https://example.test/verify-store-purchase", {
    method: "POST",
    headers: {
      authorization: "Bearer user-jwt",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      action: routeAction,
      source: "google_play",
      product_id: productId,
      verification_data: "receipt-token",
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

for (const protectedAction of protectedActions) {
  Deno.test(`${protectedAction.integrityAction} fails closed before store work`, async () => {
    for (const failure of failureCases) {
      const actions: string[] = [];
      const authRpcCalls: string[] = [];
      const adminCalls: Array<{
        name: string;
        args?: Record<string, unknown>;
      }> = [];
      const response = await handler(
        request(
          protectedAction.routeAction,
          protectedAction.productId,
          failure.envelope,
        ),
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
              rpc: (name: string): Promise<RpcResult> => {
                authRpcCalls.push(name);
                return Promise.reject(
                  new Error(`store_work_reached_before_guard:${name}`),
                );
              },
            },
            admin: {
              rpc: (
                name: string,
                args?: Record<string, unknown>,
              ): Promise<RpcResult> => {
                adminCalls.push({ name, args });
                if (name === "bil_consume_mobile_integrity_grant") {
                  return Promise.resolve(failure.result);
                }
                return Promise.reject(
                  new Error(`store_work_reached_before_guard:${name}`),
                );
              },
            },
          })) as never,
          requireIntegrity: enforcingGuard(actions),
        },
      );

      assertEquals(response.status, failure.status, failure.name);
      assertEquals(
        await response.json(),
        {
          error: failure.error,
          verified: false,
          entitlement_active: false,
        },
        failure.name,
      );
      assertEquals(actions, [protectedAction.integrityAction], failure.name);
      assertEquals(authRpcCalls, [], failure.name);
      assertEquals(adminCalls.length, failure.integrityRpcCalls, failure.name);
      if (adminCalls.length === 1) {
        assertEquals(
          adminCalls[0],
          {
            name: "bil_consume_mobile_integrity_grant",
            args: {
              p_grant_id: grantId,
              p_owner_id: ownerId,
              p_action: protectedAction.integrityAction,
              p_payload_digest: adminCalls[0].args?.p_payload_digest,
            },
          },
          failure.name,
        );
      }
    }
  });
}
