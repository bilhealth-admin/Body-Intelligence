import { assertEquals, assertNotEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { deriveAppleAppAccountToken } from "./apple_purchase_ownership.ts";
import { handler, persistVerified, type StoreBackendHandlerDependencies } from "./store_backend.ts";

type Purchase = Parameters<typeof persistVerified>[2];
type RpcCall = { name: string; args: Record<string, unknown> };
const ownerId = "00000000-0000-4000-8000-000000000001";
const earlier = "2026-09-15T10:00:00.000Z";
const later = "2026-09-16T10:00:00.000Z";

function transaction(overrides: Partial<Purchase> = {}): Purchase {
  return {
    provider: "apple",
    productId: "bil_premium_yearly",
    originalTransactionId: "chain-1",
    transactionId: "transaction-1",
    packageOrBundleId: "com.example.bil",
    environment: "sandbox",
    lifecycle: "active",
    startedAt: "2026-09-15T00:00:00.000Z",
    expiresAt: "2027-09-15T00:00:00.000Z",
    signedAt: later,
    autoRenews: true,
    ...overrides,
  };
}

function request(body: Record<string, unknown>, headers: Record<string, string> = {}) {
  return new Request("https://example.test/verify-store-purchase", {
    method: "POST",
    headers: { "content-type": "application/json", ...headers },
    body: JSON.stringify(body),
  });
}

/** Exercise the real HTTP handler and persistence/ownership orchestration.
 * Only crypto/network boundaries and the database transport are injected;
 * separate cryptographic and SQL execution tests prove those boundaries.
 * No test makes a network request or reads credentials/environment variables.
 */
function fixture(options: {
  type?: string;
  notice?: Partial<Purchase>;
  canonical?: Partial<Purchase>;
  claimError?: string;
  finishFailure?: boolean;
  ownerLookupFailure?: boolean;
  eventFailure?: boolean;
} = {}) {
  const notice = transaction(options.notice);
  const canonical = transaction(options.canonical);
  const calls: RpcCall[] = [];
  const lookups: string[] = [];
  let lease: string | null = null;
  let status = "new";
  const admin = {
    from: (_table: string) => {
      const query = {
        select: (_columns: string) => query,
        eq: (_column: string, _value: unknown) => query,
        maybeSingle: () => Promise.resolve({
          data: options.ownerLookupFailure ? null : { owner_id: ownerId, environment: "sandbox" },
          error: options.ownerLookupFailure ? { message: "database unavailable" } : null,
        }),
      };
      return query;
    },
    rpc: (name: string, args: Record<string, unknown>) => {
      calls.push({ name, args });
      if (name === "bil_claim_store_notification") {
        if (options.claimError) return Promise.resolve({ data: null, error: { message: options.claimError } });
        if (status === "processed") return Promise.resolve({ data: false, error: null });
        if (status === "processing") return Promise.resolve({ data: null, error: { message: "notification_claim_in_progress" } });
        lease = String(args.p_claim_token);
        status = "processing";
        return Promise.resolve({ data: true, error: null });
      }
      if (name === "bil_finish_store_notification") {
        if (options.finishFailure || args.p_claim_token !== lease) {
          return Promise.resolve({ data: false, error: null });
        }
        status = String(args.p_status);
        return Promise.resolve({ data: true, error: null });
      }
      if (name === "bil_persist_verified_store_purchase") {
        return Promise.resolve({ data: { active: ["active", "trial", "grace_period"].includes(String(args.p_lifecycle)), lifecycle: args.p_lifecycle, verified_at: args.p_verified_at }, error: null });
      }
      if (name === "bil_apply_ai_boost_store_event") {
        return Promise.resolve({ data: { applied: true }, error: options.eventFailure ? { message: "write unavailable" } : null });
      }
      if (name === "bil_credit_ai_boost_verified") return Promise.resolve({ data: { credited: true }, error: null });
      throw new Error(`Unexpected RPC ${name}`);
    },
  };
  const dependencies: StoreBackendHandlerDependencies = {
    clients: (() => ({
      admin,
      auth: {
        auth: { getUser: () => Promise.resolve({ data: { user: { id: ownerId } }, error: null }) },
        rpc: () => Promise.resolve({ data: null, error: null }),
      },
    })) as unknown as StoreBackendHandlerDependencies["clients"],
    requireIntegrity: (input) => Promise.resolve(input.body),
    readEnvironment: () => "",
    verifyAppleJws: () => Promise.resolve({
      notificationUUID: "notification-1",
      notificationType: options.type ?? "DID_RENEW",
      subtype: "AUTO_RENEW_DISABLED",
      data: { environment: "Sandbox", signedTransactionInfo: "verified-transaction-fixture" },
    }),
    verifyAppleTransaction: () => Promise.resolve(notice),
    reconcileApple: (id, environment) => {
      lookups.push(`subscription:${id}:${environment}`);
      return Promise.resolve(canonical);
    },
    readAppleTransaction: (id, environment) => {
      lookups.push(`transaction:${id}:${environment}`);
      return Promise.resolve(canonical);
    },
    verifyGooglePushIdentity: () => Promise.resolve(),
    verifyGoogle: () => Promise.resolve(transaction({ provider: "google" })),
  };
  return {
    calls, lookups, dependencies, notice, canonical,
    invoke: () => handler(request({ signedPayload: "verified-notification-fixture" }), dependencies),
    persisted: () => calls.filter((call) => call.name === "bil_persist_verified_store_purchase"),
    events: () => calls.filter((call) => call.name === "bil_apply_ai_boost_store_event"),
    credits: () => calls.filter((call) => call.name === "bil_credit_ai_boost_verified"),
    status: () => status,
  };
}

Deno.test("notification claim outage and active lease return retryable HTTP 503 without processing", async () => {
  for (const claimError of ["database unavailable", "notification_claim_in_progress"]) {
    const test = fixture({ claimError });
    const result = await test.invoke();
    assertEquals(result.status, 503);
    assertEquals((await result.json()).error, claimError === "notification_claim_in_progress" ? claimError : "notification_claim_failed");
    assertEquals(test.lookups.length, 0);
    assertEquals(test.persisted().length, 0);
    assertEquals(test.calls.length, 1);
  }
});

Deno.test("same Apple UUID retries after canonical outage and only processed duplicates are acknowledged", async () => {
  const test = fixture();
  let attempts = 0;
  test.dependencies.reconcileApple = () => ++attempts === 1
    ? Promise.reject(new Error("apple_server_unavailable"))
    : Promise.resolve(test.canonical);
  assertEquals((await test.invoke()).status, 503);
  assertEquals(test.status(), "error");
  assertEquals((await test.invoke()).status, 200);
  assertEquals(test.status(), "processed");
  const duplicate = await test.invoke();
  assertEquals(await duplicate.json(), { accepted: true, duplicate: true });
  assertEquals(test.persisted().length, 1);
  assertEquals(attempts, 2);
  const claims = test.calls.filter((call) => call.name === "bil_claim_store_notification");
  assertNotEquals(claims[0].args.p_claim_token, claims[1].args.p_claim_token);
  const finishes = test.calls.filter((call) => call.name === "bil_finish_store_notification");
  assertEquals(finishes[0].args.p_claim_token, claims[0].args.p_claim_token);
  assertEquals(finishes[1].args.p_claim_token, claims[1].args.p_claim_token);
});

Deno.test("owner read failure and lost finish lease are not acknowledged as successful notifications", async () => {
  for (const options of [{ ownerLookupFailure: true }, { finishFailure: true }]) {
    const test = fixture(options);
    assertEquals((await test.invoke()).status, 503);
    assertNotEquals(test.status(), "processed");
    if (options.ownerLookupFailure) assertEquals(test.persisted().length, 0);
  }
});

for (const type of ["REFUND", "REVOKE", "EXPIRED", "GRACE_PERIOD_EXPIRED"]) {
  Deno.test(`late ${type} for older transaction cannot revoke a newer canonical renewal`, async () => {
    const test = fixture({ type, notice: { lifecycle: "revoked", signedAt: earlier }, canonical: { transactionId: "newer-renewal" } });
    assertEquals((await test.invoke()).status, 200);
    assertEquals(test.persisted()[0].args.p_lifecycle, "active");
    assertEquals(test.persisted()[0].args.p_latest_transaction_id, "newer-renewal");
  });
}

Deno.test("same transaction refund or revoke with lagging active API is retried, not acknowledged away", async () => {
  for (const type of ["REFUND", "REVOKE"]) {
    for (const signedAt of [earlier, later]) {
      const test = fixture({ type, notice: { lifecycle: "revoked", signedAt: later }, canonical: { lifecycle: "active", signedAt } });
      const result = await test.invoke();
      assertEquals(result.status, 503);
      assertEquals((await result.json()).error, "apple_canonical_state_pending");
      assertEquals(test.persisted().length, 0);
      assertEquals(test.status(), "error");
    }
  }
});

Deno.test("verified canonical terminal state removes existing access for REFUND and REVOKE", async () => {
  for (const type of ["REFUND", "REVOKE"]) {
    const test = fixture({ type, notice: { lifecycle: "revoked" }, canonical: { lifecycle: "revoked" } });
    assertEquals((await test.invoke()).status, 200);
    assertEquals(test.persisted()[0].args.p_lifecycle, "revoked");
  }
});

Deno.test("refund reversal uses authoritative fresh state and never reactivates over a newer revocation", async () => {
  for (const lifecycle of ["active", "revoked"] as const) {
    const test = fixture({ type: "REFUND_REVERSED", notice: { lifecycle: "active", signedAt: earlier }, canonical: { lifecycle, signedAt: later } });
    assertEquals((await test.invoke()).status, 200);
    assertEquals(test.persisted()[0].args.p_lifecycle, lifecycle);
  }
  const stale = fixture({ type: "REFUND_REVERSED", canonical: { lifecycle: "revoked", signedAt: earlier } });
  assertEquals((await stale.invoke()).status, 503);
  assertEquals(stale.persisted().length, 0);
});

Deno.test("CONSUMPTION_REQUEST sends no usage data, performs no canonical lookup and changes no balances/access", async () => {
  for (const productId of ["bil_ai_boost", "bil_premium_yearly"]) {
    const test = fixture({ type: "CONSUMPTION_REQUEST", notice: { productId } });
    const result = await test.invoke();
    assertEquals(result.status, 200);
    assertEquals(await result.json(), { accepted: true, consumption_data_sent: false, reason: "consent_not_recorded" });
    assertEquals(test.lookups, []);
    assertEquals(test.persisted(), []);
    assertEquals(test.events(), []);
    assertEquals(test.credits(), []);
    assertEquals(test.status(), "processed");
  }
});

Deno.test("refund decline and renewal cancellation preserve canonical active access until signed expiry", async () => {
  for (const type of ["REFUND_DECLINED", "DID_CHANGE_RENEWAL_STATUS"]) {
    for (const lifecycle of ["active", "trial"] as const) {
      const test = fixture({ type, canonical: { lifecycle, autoRenews: false } });
      assertEquals((await test.invoke()).status, 200);
      const persisted = test.persisted()[0].args;
      assertEquals(persisted.p_lifecycle, lifecycle);
      assertEquals(persisted.p_auto_renews, false);
      assertEquals(persisted.p_expires_at, test.canonical.expiresAt);
    }
  }
});

Deno.test("Boost refund and reversal route exact canonical transactions to idempotent environment-aware event RPC", async () => {
  for (const [type, lifecycle, event] of [["REFUND", "revoked", "refunded"], ["REVOKE", "revoked", "refunded"], ["REFUND_REVERSED", "active", "refund_reversed"]] as const) {
    const test = fixture({ type, notice: { productId: "bil_ai_boost", lifecycle, signedAt: earlier }, canonical: { productId: "bil_ai_boost", lifecycle, signedAt: later } });
    assertEquals((await test.invoke()).status, 200);
    assertEquals(test.lookups, ["transaction:transaction-1:sandbox"]);
    assertEquals(test.persisted().length, 0);
    assertEquals(test.credits().length, 0);
    const applied = test.events()[0].args;
    assertEquals(applied.p_environment, "sandbox");
    assertEquals(applied.p_event_at, later);
    assertEquals(applied.p_event_id, "notification-1");
    assertEquals(applied.p_transaction_id, "transaction-1");
    assertEquals(applied.p_event_type, event);
    assertEquals(test.status(), "processed");
  }
});

Deno.test("Boost event persistence failure preserves retryability", async () => {
  const test = fixture({ type: "REFUND", notice: { productId: "bil_ai_boost", lifecycle: "revoked" }, canonical: { productId: "bil_ai_boost", lifecycle: "revoked" }, eventFailure: true });
  assertEquals((await test.invoke()).status, 503);
  assertEquals(test.status(), "error");
  assertEquals(test.events().length, 1);
});

Deno.test("Boost canonical transaction identity cannot cross transaction, product, bundle or environment", async () => {
  for (const invalid of [{ transactionId: "different-transaction" }, { productId: "different-product" }, { packageOrBundleId: "different.bundle" }, { environment: "production" as const }, { originalTransactionId: "different-chain" }]) {
    const test = fixture({ type: "REFUND", notice: { productId: "bil_ai_boost", lifecycle: "revoked" }, canonical: { productId: "bil_ai_boost", lifecycle: "revoked", ...invalid } });
    assertNotEquals((await test.invoke()).status, 200);
    assertEquals(test.events().length, 0);
    assertEquals(test.status(), "error");
  }
});

Deno.test("client Boost credit rechecks exact canonical state before granting and includes signed environment", async () => {
  const appAccountToken = await deriveAppleAppAccountToken(ownerId);
  for (const lifecycle of ["active", "revoked"] as const) {
    const test = fixture({ notice: { productId: "bil_ai_boost", appAccountToken }, canonical: { productId: "bil_ai_boost", appAccountToken, lifecycle } });
    const result = await handler(request({ action: "verify_ai_boost", source: "app_store", product_id: "bil_ai_boost", verification_data: "verified-fixture" }, { authorization: "Bearer fixture" }), test.dependencies);
    assertEquals(result.status, lifecycle === "active" ? 200 : 503);
    assertEquals(test.credits().length, lifecycle === "active" ? 1 : 0);
    assertEquals(test.lookups, ["transaction:transaction-1:sandbox"]);
    if (lifecycle === "active") assertEquals(test.credits()[0].args.p_environment, "sandbox");
  }
});

Deno.test("client Boost signed token bound to another BIL account cannot credit even after canonical verification", async () => {
  const appAccountToken = await deriveAppleAppAccountToken("another-bil-member");
  const test = fixture({ notice: { productId: "bil_ai_boost", appAccountToken }, canonical: { productId: "bil_ai_boost", appAccountToken } });
  const result = await handler(request({ action: "verify_ai_boost", source: "app_store", product_id: "bil_ai_boost", verification_data: "verified-fixture" }, { authorization: "Bearer fixture" }), test.dependencies);
  assertEquals(result.status, 400);
  assertEquals((await result.json()).error, "purchase_owned_by_another_account");
  assertEquals(test.credits().length, 0);
});

Deno.test("Google notifications share retryable claims and fenced completion without calling Apple paths", async () => {
  const test = fixture();
  let attempts = 0;
  test.dependencies.verifyGoogle = () => ++attempts === 1
    ? Promise.reject(new Error("google_verification_failed"))
    : Promise.resolve(transaction({ provider: "google" }));
  const invoke = () => handler(request({ message: { messageId: "google-notice", data: btoa(JSON.stringify({ subscriptionNotification: { notificationType: 2, purchaseToken: "google-token" } })) } }), test.dependencies);
  assertEquals((await invoke()).status, 503);
  assertEquals(test.status(), "error");
  assertEquals((await invoke()).status, 200);
  assertEquals(test.status(), "processed");
  assertEquals(test.lookups, []);
  assertEquals(test.persisted().length, 1);
  const claims = test.calls.filter((call) => call.name === "bil_claim_store_notification");
  assertEquals(claims[0].args.p_provider, "google");
  assertNotEquals(claims[0].args.p_claim_token, claims[1].args.p_claim_token);
});

Deno.test("reconciliation uses stable 100-owner pages and explicitly reports per-owner failures", async () => {
  const rows = Array.from({ length: 101 }, (_, index) => ({
    owner_id: `00000000-0000-4000-8000-${String(index + 1).padStart(12, "0")}`,
    provider: "apple", original_transaction_id: `chain-${index}`, latest_transaction_id: `tx-${index}`, environment: "sandbox",
  }));
  const filters: Array<[string, unknown]> = [];
  const audited: unknown[] = [];
  let cursor: string | null = null;
  let appleLookups = 0;
  const admin = {
    from: (table: string) => {
      const query = {
        select: () => query,
        in: (column: string, value: unknown) => { filters.push([column, value]); return query; },
        order: (column: string, value: unknown) => { filters.push([column, value]); return query; },
        limit: (value: number) => { filters.push(["limit", value]); return query; },
        gt: (column: string, value: string) => { filters.push([column, value]); cursor = value; return query; },
        insert: (value: unknown) => { assertEquals(table, "bil_store_entitlement_audit"); audited.push(value); return Promise.resolve({ error: null }); },
        then: (resolve: (value: unknown) => unknown) => Promise.resolve({ data: cursor ? rows.filter((row) => row.owner_id > cursor!) : rows, error: null }).then(resolve),
      };
      return query;
    },
  };
  const dependencies: StoreBackendHandlerDependencies = {
    clients: (() => ({ admin, auth: {} })) as unknown as StoreBackendHandlerDependencies["clients"],
    readEnvironment: (name) => name === "BIL_RECONCILIATION_SECRET" ? "fixture-secret" : "",
    reconcileApple: () => { appleLookups++; return Promise.reject(new Error("simulated_store_outage")); },
    googleVoidedPurchases: () => { throw new Error("Apple-only page must not request Google credentials"); },
  };
  const invoke = (after_owner_id?: string) => handler(request({ action: "reconcile", ...(after_owner_id ? { after_owner_id } : {}) }, { "x-bil-reconciliation-secret": "fixture-secret" }), dependencies);
  const first = await invoke();
  assertEquals(first.status, 200);
  assertEquals(await first.json(), { reconciled: 0, failed: 100, examined: 100, has_more: true, next_cursor: rows[99].owner_id, voided_google_lookup_unavailable: false, boost_refunds_reconciled: 0, boost_refunds_failed: 0 });
  const second = await invoke(rows[99].owner_id);
  assertEquals(second.status, 200);
  assertEquals(await second.json(), { reconciled: 0, failed: 1, examined: 1, has_more: false, next_cursor: null, voided_google_lookup_unavailable: false, boost_refunds_reconciled: 0, boost_refunds_failed: 0 });
  assertEquals(appleLookups, 101);
  assertEquals(audited.length, 101);
  assertEquals(filters[0], ["provider", ["apple", "google"]]);
  assertEquals(filters[2], ["limit", 101]);
  const invalid = await invoke("not-a-uuid");
  assertEquals(invalid.status, 400);
  assertEquals((await invalid.json()).error, "invalid_reconciliation_cursor");
});
