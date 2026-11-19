import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handler, type StoreBackendHandlerDependencies } from "./store_backend.ts";
import { integrityPayloadDigest, requireMobileIntegrityGrant } from "../_shared/mobile_integrity.ts";

const owner = "00000000-0000-4000-8000-000000000001";
const lease = "00000000-0000-4000-8000-000000000002";
const grant = "00000000-0000-4000-8000-000000000003";
type Options = {
  provider?: "google" | "apple";
  lifecycle?: "active" | "expired" | "grace_period";
  futureStart?: boolean;
  signedMismatch?: boolean;
  invalidSession?: boolean;
  integrityAllowed?: boolean;
  claim?: "claimed" | "not_required" | "busy" | "rate_limited";
  superseded?: boolean;
  storeFailure?: boolean;
};

function fixture(options: Options = {}) {
  const provider = options.provider ?? "google";
  const calls: { name: string; args: Record<string, unknown> }[] = [];
  const storeLookups: unknown[][] = [];
  let consumed = false;
  const expectedDigest = integrityPayloadDigest({ action: "refresh_subscription" });
  const dependencies: StoreBackendHandlerDependencies = {
    clients: (() => ({
      auth: { auth: { getUser: () => Promise.resolve({
        data: { user: options.invalidSession ? null : { id: owner } }, error: null,
      }) } },
      admin: { rpc: async (name: string, args: Record<string, unknown>) => {
        calls.push({ name, args });
        if (name === "bil_consume_mobile_integrity_grant") {
          const allowed = options.integrityAllowed !== false && !consumed &&
            args.p_owner_id === owner && args.p_action === "store.refresh_subscription" &&
            args.p_grant_id === grant && args.p_payload_digest === await expectedDigest;
          consumed = true;
          return Promise.resolve({ data: allowed, error: null });
        }
        if (name === "bil_claim_own_subscription_refresh") return Promise.resolve({
          data: { status: options.claim ?? "claimed", lease_id: lease,
            retry_after_seconds: 10, snapshot: {
              owner_id: owner, provider, original_transaction_id: "synthetic-chain",
              latest_transaction_id: "synthetic-latest", environment: "sandbox",
              revision: 7, package_or_bundle_id: "app.bil.health",
            } }, error: null,
        });
        if (name === "bil_lookup_store_subscription_owner") return Promise.resolve({
          data: { owner_id: owner, environment: "sandbox" }, error: null,
        });
        if (name === "bil_persist_refreshed_store_purchase") return Promise.resolve({
          data: options.superseded ? { superseded: true } : {
            active: options.lifecycle !== "expired" && !options.futureStart,
            lifecycle: options.lifecycle ?? "active",
            verified_at: "2026-11-18T14:37:06Z", superseded: false,
          }, error: null,
        });
        assertEquals(name, "bil_release_own_subscription_refresh");
        return Promise.resolve({ data: null, error: null });
      } },
    })) as unknown as StoreBackendHandlerDependencies["clients"],
    requireIntegrity: (input) => requireMobileIntegrityGrant({ ...input, enforcement: "enforce" }),
    verifyGoogle: (packageName, token) => {
      storeLookups.push([packageName, token]);
      if (options.storeFailure) return Promise.reject(new Error("synthetic store outage"));
      return Promise.resolve(purchase());
    },
    googleVoidedPurchases: () => Promise.resolve([]),
    reconcileApple: (chain, environment) => {
      storeLookups.push([chain, environment]);
      return Promise.resolve(purchase());
    },
  };
  function purchase() {
    return {
      provider, productId: "bil_premium",
      originalTransactionId: options.signedMismatch ? "other-chain" : "synthetic-chain",
      transactionId: provider === "google" ? "synthetic-latest" : "synthetic-renewal",
      packageOrBundleId: "app.bil.health", environment: "sandbox" as const,
      lifecycle: options.lifecycle ?? "active" as const,
      startedAt: options.futureStart ? "2026-11-18T14:38:00Z" : "2026-11-18T14:36:59Z",
      expiresAt: "2026-11-18T14:39:59Z", autoRenews: true,
      gracePeriodEndsAt: options.lifecycle === "grace_period" ? "2026-11-19T14:39:59Z" : undefined,
      signedAt: "2026-11-18T14:37:05Z",
    };
  }
  async function send(extra: Record<string, unknown> = {}, authenticated = true) {
    const response = await handler(new Request("https://example.test/verify-store-purchase", {
      method: "POST", headers: { "content-type": "application/json",
        ...(authenticated ? { authorization: "Bearer synthetic-user-jwt" } : {}) },
      body: JSON.stringify({ action: "refresh_subscription", _integrity: { grant_id: grant }, ...extra }),
    }), dependencies);
    return { response, body: await response.json() };
  }
  return { calls, storeLookups, send };
}

// Baseline compatible: imports and handler arguments already exist before the
// feature. The old handler returns invalid_action, a value failure, not a load
// or compile failure. Only fake Store APIs are invoked by these local tests.
Deno.test("own refresh reconciles only the JWT owner's stored lineage", async () => {
  const h = fixture(); const { response, body } = await h.send();
  assertEquals(response.status, 200);
  assertEquals(body, { refresh_status: "refreshed" });
  assertEquals(h.storeLookups, [["app.bil.health", "synthetic-latest"]]);
  const persist = h.calls.find((call) => call.name === "bil_persist_refreshed_store_purchase")!;
  assertEquals(persist.args.p_owner_id, owner);
  assertEquals(persist.args.p_expected_revision, 7);
  assertEquals(persist.args.p_refresh_lease, lease);
  assertEquals(h.calls.at(-1)?.name, "bil_release_own_subscription_refresh");
});

Deno.test("own refresh rejects caller identities and receipt payloads before work", async () => {
  for (const key of ["owner_id", "provider", "environment", "transaction_id", "verification_data"]) {
    const h = fixture(); const { response } = await h.send({ [key]: "caller-controlled" });
    assertEquals(response.status, 400); assertEquals(h.calls.length, 0);
    assertEquals(h.storeLookups.length, 0);
  }
});

Deno.test("own refresh requires an authenticated current user", async () => {
  for (const invalidSession of [false, true]) {
    const h = fixture({ invalidSession });
    const { response } = await h.send({}, invalidSession);
    assertEquals(response.status, 401); assertEquals(h.calls.length, 0);
  }
});

Deno.test("own refresh consumes a purpose-bound grant once before claiming", async () => {
  const h = fixture(); assertEquals((await h.send()).response.status, 200);
  const second = await h.send(); assertEquals(second.response.status, 403);
  assertEquals(second.body.error, "mobile_integrity_grant_invalid");
  assertEquals(h.storeLookups.length, 1);
  assertEquals(h.calls[0].args.p_action, "store.refresh_subscription");
});

Deno.test("denied integrity never reads a stored purchase or Store API", async () => {
  const h = fixture({ integrityAllowed: false });
  assertEquals((await h.send()).response.status, 403);
  assertEquals(h.calls.map((call) => call.name), ["bil_consume_mobile_integrity_grant"]);
  assertEquals(h.storeLookups.length, 0);
});

for (const claim of ["not_required", "busy", "rate_limited"] as const) {
  Deno.test(`own refresh ${claim} makes no external Store API call`, async () => {
    const h = fixture({ claim }); const result = await h.send();
    assertEquals(result.response.status, 200);
    assertEquals(h.storeLookups.length, 0);
    assertEquals(result.body.refresh_status, claim === "not_required" ? claim : "checking");
    assertEquals("entitlement_active" in result.body, false);
  });
}

for (const lifecycle of ["active", "expired", "grace_period"] as const) {
  Deno.test(`signed Apple ${lifecycle} is persisted without local grace or rights response`, async () => {
    const h = fixture({ provider: "apple", lifecycle }); const result = await h.send();
    assertEquals(result.body, { refresh_status: "refreshed" });
    assertEquals(h.storeLookups, [["synthetic-chain", "sandbox"]]);
    const args = h.calls.find((c) => c.name === "bil_persist_refreshed_store_purchase")!.args;
    assertEquals(args.p_lifecycle, lifecycle);
    assertEquals(args.p_grace_period_ends_at,
      lifecycle === "grace_period" ? "2026-11-19T14:39:59Z" : null);
  });
}

Deno.test("future Apple period is not rewritten or returned as paid proof", async () => {
  const h = fixture({ provider: "apple", futureStart: true });
  const result = await h.send(); assertEquals(result.body, { refresh_status: "refreshed" });
  assertEquals(h.calls.find((c) => c.name === "bil_persist_refreshed_store_purchase")!.args.p_started_at,
    "2026-11-18T14:38:00Z");
});

Deno.test("newer canonical notification supersedes an in-flight refresh", async () => {
  const h = fixture({ superseded: true });
  assertEquals((await h.send()).body, { refresh_status: "superseded" });
});

Deno.test("mismatched signed lineage cannot persist and releases its own lease", async () => {
  const h = fixture({ signedMismatch: true });
  assertEquals((await h.send()).response.status, 503);
  assertEquals(h.calls.some((c) => c.name === "bil_persist_refreshed_store_purchase"), false);
  assertEquals(h.calls.at(-1)?.args, { p_owner_id: owner, p_lease_id: lease });
});

Deno.test("Store API outage never invents paid access or a durable inactive state", async () => {
  const h = fixture({ storeFailure: true });
  assertEquals((await h.send()).response.status, 503);
  assertEquals(h.calls.some((c) => c.name === "bil_persist_refreshed_store_purchase"), false);
});
