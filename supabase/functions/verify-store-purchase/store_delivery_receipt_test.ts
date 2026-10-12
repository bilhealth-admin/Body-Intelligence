import {
  assertEquals,
  assertNotEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  boostCreditOutcome,
  deliveryReceipt,
} from "./store_delivery_receipt.ts";
import { handler } from "./store_backend.ts";
import { deriveAppleAppAccountToken } from "./apple_purchase_ownership.ts";

const owner = "00000000-0000-4000-8000-000000000001";
const base = {
  ownerId: owner,
  store: "app_store" as const,
  environment: "sandbox" as const,
  transactionId: "fixture-transaction-1",
  productId: "bil_ai_boost",
  verifiedAt: "2026-10-11T20:00:00Z",
  kind: "boost" as const,
  active: true,
  quantity: 730,
};

Deno.test("delivery key binds owner, environment and transaction, not product or receipt", async () => {
  const first = await deliveryReceipt(base);
  assertEquals(first.quantity, 730);
  assertEquals(
    first.event_key,
    (await deliveryReceipt({ ...base, creditedNow: false })).event_key,
  );
  for (
    const changed of [
      { ownerId: "another-owner" },
      { environment: "production" as const },
      { transactionId: "fixture-transaction-2" },
    ]
  ) {
    assertNotEquals(
      first.event_key,
      (await deliveryReceipt({ ...base, ...changed })).event_key,
    );
  }
  assertEquals(JSON.stringify(first).includes(base.transactionId), false);
});

Deno.test("credit proof distinguishes replay, refund and unknown policy quantity", async () => {
  assertEquals(boostCreditOutcome({ credited: true, tokens_granted: 730 }), {
    active: true,
    quantity: 730,
    credited: true,
  });
  assertEquals(
    boostCreditOutcome({
      credited: false,
      tokens_granted: 0,
      tokens_per_boost: 730,
    }),
    { active: true, quantity: 730, credited: false },
  );
  assertEquals(boostCreditOutcome({ credited: false, refunded: true }), {
    active: false,
    quantity: 0,
    credited: false,
  });
  await assertRejects(
    async () => boostCreditOutcome({ credited: true }),
    Error,
    "delivery_receipt_unavailable",
  );
});

// Execute the actual HTTP handler, authentication/integrity/rate-limit and
// account binding. Signature/store and RPC boundaries are controlled here;
// this is not an Apple transaction or a deployed cloud test.
async function verify(
  version: number | undefined,
  credit: Record<string, unknown>,
  signedOwner = owner,
  lifecycle: "active" | "refunded" | "revoked" = "active",
  settlementFails = false,
) {
  const token = await deriveAppleAppAccountToken(signedOwner);
  const purchase = {
    provider: "apple" as const,
    productId: "bil_ai_boost",
    transactionId: base.transactionId,
    originalTransactionId: "fixture-original",
    packageOrBundleId: "app.bil.health",
    environment: "sandbox" as const,
    lifecycle,
    signedAt: "2026-10-12T12:00:00Z",
    appAccountToken: token,
  };
  let writes = 0, refundEvents = 0;
  const response = await handler(
    new Request("https://fixture.invalid/verify", {
      method: "POST",
      headers: { authorization: "Bearer fixture" },
      body: JSON.stringify({
        action: "verify_ai_boost",
        source: "app_store",
        product_id: "bil_ai_boost",
        verification_data: "fixture-signed-boundary",
        delivery_version: version,
        // Hostile client fields must not affect the committed server proof.
        owner_id: "attacker",
        quantity: 900000,
        environment: "production",
      }),
    }),
    {
      clients: () => ({
        auth: {
          auth: {
            getUser: () =>
              Promise.resolve({ data: { user: { id: owner } }, error: null }),
          },
          rpc: () => Promise.resolve({ error: null }),
        } as never,
        admin: {
          from: (name: string) => {
            assertEquals(name, "bil_ai_boost_store_state");
            const filters: Record<string, unknown> = {};
            const query = {
              select: () => query,
              eq: (key: string, value: unknown) => {
                filters[key] = value;
                return query;
              },
              maybeSingle: () => {
                assertEquals(filters, {
                  store: "app_store",
                  transaction_id: base.transactionId,
                  product_id: "bil_ai_boost",
                  environment: "sandbox",
                });
                return Promise.resolve({
                  data: settlementFails ? null : {
                    ...filters,
                    owner_id: owner,
                    purchase_credited: true,
                    state: "refunded",
                  },
                  error: null,
                });
              },
            };
            return query;
          },
          rpc: (name: string, args: Record<string, unknown>) => {
            if (name === "bil_apply_ai_boost_store_event") {
              refundEvents++;
              assertEquals(args.p_store, "app_store");
              assertEquals(args.p_transaction_id, base.transactionId);
              assertEquals(args.p_environment, "sandbox");
              assertEquals(args.p_event_type, "refunded");
              assertEquals(args.p_event_at, purchase.signedAt);
              assertEquals(typeof args.p_event_id, "string");
              return Promise.resolve({
                data: settlementFails ? null : { applied: true },
                error: settlementFails
                  ? { message: "fixture storage failure" }
                  : null,
              });
            }
            assertEquals(name, "bil_credit_ai_boost_verified");
            assertEquals(args.p_owner_id, owner);
            assertEquals(args.p_environment, "sandbox");
            writes++;
            return Promise.resolve({ data: credit, error: null });
          },
        } as never,
      }),
      requireIntegrity: (input) => Promise.resolve(input.body),
      verifyAppleTransaction: () => Promise.resolve(purchase),
      readAppleTransaction: () => Promise.resolve(purchase),
    },
  );
  return {
    status: response.status,
    body: await response.json(),
    writes,
    refundEvents,
  };
}

Deno.test("32/35 legacy Boost response remains exact; v2 uses committed quantity", async () => {
  const credit = { credited: true, tokens_granted: 730, tokens_per_boost: 730 };
  const legacy = await verify(undefined, credit);
  assertEquals(legacy.body, {
    verified: true,
    product_id: "bil_ai_boost",
    credited: true,
  });
  const current = await verify(2, credit);
  assertEquals(current.status, 200);
  assertEquals(current.writes, 1);
  assertEquals(current.body.delivery.quantity, 730);
  assertEquals(current.body.delivery.owner_id, owner);
  assertEquals(current.body.delivery.environment, "sandbox");
});

Deno.test("refunded canonical Boost has no delivered quantity; foreign owner cannot write", async () => {
  const refunded = await verify(2, { credited: false, refunded: true });
  assertEquals(refunded.body.delivery.active, false);
  assertEquals(refunded.body.delivery.quantity, 0);
  const foreign = await verify(
    2,
    { credited: true, tokens_granted: 730 },
    "00000000-0000-4000-8000-000000000002",
  );
  assertEquals(foreign.writes, 0);
  assertEquals(foreign.body.error, "purchase_owned_by_another_account");
});

for (const lifecycle of ["refunded", "revoked"] as const) {
  Deno.test(`actual canonical Apple ${lifecycle} settles v2 without credit and preserves legacy`, async () => {
    const result = await verify(2, {}, owner, lifecycle);
    assertEquals(result.status, 200);
    assertEquals(result.body.verified, true);
    assertEquals(result.body.credited, false);
    assertEquals(result.body.delivery.active, false);
    assertEquals(result.body.delivery.quantity, 0);
    assertEquals(result.body.delivery.finish_pending, false);
    assertEquals(result.writes, 0);
    assertEquals(result.refundEvents, 1);
    const legacy = await verify(undefined, {}, owner, lifecycle);
    assertEquals(legacy.body.error, "purchase_not_completed");
    assertEquals(legacy.writes, 0);
    assertEquals(legacy.refundEvents, 0);
    const foreign = await verify(
      2,
      {},
      "00000000-0000-4000-8000-000000000002",
      lifecycle,
    );
    assertEquals(foreign.body.error, "purchase_owned_by_another_account");
    assertEquals(foreign.writes, 0);
    assertEquals(foreign.refundEvents, 0);
    const failed = await verify(2, {}, owner, lifecycle, true);
    assertEquals(failed.body.error, "boost_refund_persistence_failed");
    assertEquals(failed.body.delivery, undefined);
    assertEquals(failed.writes, 0);
  });
}

Deno.test("Google v2 delivers a committed credit before consumption; failed finish can retry without recredit", async () => {
  const hash = Array.from(
    new Uint8Array(
      await crypto.subtle.digest("SHA-256", new TextEncoder().encode(owner)),
    ),
    (v) => v.toString(16).padStart(2, "0"),
  ).join("");
  let grants = 0, consumes = 0;
  const credited = new Set<string>();
  let consumeFails = true;
  const dependencies = {
    clients: () => ({
      auth: {
        auth: {
          getUser: () =>
            Promise.resolve({ data: { user: { id: owner } }, error: null }),
        },
        rpc: () => Promise.resolve({ error: null }),
      } as never,
      admin: {
        rpc: (name: string, args: Record<string, unknown>) => {
          if (name === "bil_lookup_ai_boost_owner") {
            assertEquals(args.p_store, "google_play");
            assertEquals(args.p_transaction_id, "fixture-token");
            return Promise.resolve({
              data: [],
              error: null,
            });
          }
          assertEquals(name, "bil_credit_ai_boost_verified");
          assertEquals(args.p_environment, "sandbox");
          const fresh = !credited.has(String(args.p_transaction_id));
          credited.add(String(args.p_transaction_id));
          if (fresh) grants++;
          return Promise.resolve({
            data: {
              credited: fresh,
              tokens_granted: fresh ? 730 : 0,
              tokens_per_boost: 730,
            },
            error: null,
          });
        },
      } as never,
    }),
    requireIntegrity: (input: { body: Record<string, unknown> }) =>
      Promise.resolve(input.body),
    readEnvironment: () => "fixture.package",
    verifyGoogleConsumable: () =>
      Promise.resolve({
        provider: "google" as const,
        productId: "bil_ai_boost",
        transactionId: "fixture-token",
        packageOrBundleId: "fixture.package",
        environment: "sandbox" as const,
        verifiedAt: base.verifiedAt,
        purchaseState: 0,
        googleObfuscatedAccountId: hash,
      }),
    consumeGoogleConsumable: () => {
      consumes++;
      return consumeFails
        ? Promise.reject(new Error("fixture-consume-offline"))
        : Promise.resolve();
    },
  };
  const request = (finish: boolean) =>
    new Request("https://fixture.invalid/verify", {
      method: "POST",
      headers: { authorization: "Bearer fixture" },
      body: JSON.stringify({
        action: "verify_ai_boost",
        source: "google_play",
        product_id: "bil_ai_boost",
        verification_data: "fixture-token",
        delivery_version: 2,
        finish_store: finish,
      }),
    });
  const delivered = await (await handler(request(false), dependencies)).json();
  assertEquals(delivered.delivery.active, true);
  assertEquals(delivered.delivery.finish_pending, true);
  assertEquals(delivered.delivery.quantity, 730);
  assertEquals(grants, 1);
  assertEquals(consumes, 0);
  const failedFinish = await (await handler(request(true), dependencies))
    .json();
  assertEquals(failedFinish.delivery.event_key, delivered.delivery.event_key);
  assertEquals(failedFinish.delivery.finish_pending, true);
  assertEquals(grants, 1);
  assertEquals(consumes, 1);
  consumeFails = false;
  const finished = await (await handler(request(true), dependencies)).json();
  assertEquals(finished.delivery.finish_pending, false);
  assertEquals(grants, 1);
  assertEquals(consumes, 2);
});

// Actual handler and explicit database/API boundaries. These are synthetic
// authentication/store responses, not a live Play or deployed RLS exercise.
async function googleTerminalFixture(options: {
  state?: number;
  version?: number;
  foreignBinding?: boolean;
  storedOwner?: string | null;
  packageName?: string;
  productId?: string;
  token?: string;
  environment?: "sandbox" | "production";
  existingState?: "refunded" | "refund_reversed";
  stateOwner?: string | null;
  noVoidedRecord?: boolean;
  wrongVoidedOrder?: boolean;
  persistenceFails?: boolean;
  tombstoneReadFails?: boolean;
  reversalWins?: boolean;
} = {}) {
  const state = options.state ?? 1;
  const version = options.version;
  const account = options.foreignBinding
    ? "00000000-0000-4000-8000-000000000002"
    : owner;
  const accountHash = Array.from(
    new Uint8Array(
      await crypto.subtle.digest(
        "SHA-256",
        new TextEncoder().encode(account),
      ),
    ),
    (v) => v.toString(16).padStart(2, "0"),
  ).join("");
  let tombstone = options.existingState ?? null;
  let credits = 0,
    events = 0,
    consumes = 0,
    canonicalReads = 0,
    legacyReads = 0,
    voidedReads = 0;
  const purchase = {
    provider: "google" as const,
    productId: options.productId ?? "bil_ai_boost",
    transactionId: options.token ?? "fixture-canceled-token",
    packageOrBundleId: options.packageName ?? "fixture.package",
    environment: options.environment ?? "sandbox" as const,
    verifiedAt: new Date().toISOString(),
    purchaseState: state,
    orderId: "fixture-canceled-order",
    googleObfuscatedAccountId: accountHash,
  };
  const dependencies = {
    clients: () => ({
      auth: {
        auth: {
          getUser: () =>
            Promise.resolve({ data: { user: { id: owner } }, error: null }),
        },
        rpc: () => Promise.resolve({ error: null }),
      } as never,
      admin: {
        from: (name: string) => {
          assertEquals(name, "bil_ai_boost_store_state");
          const filters: Record<string, unknown> = {};
          const query = {
            select: () => query,
            eq: (key: string, value: unknown) => {
              filters[key] = value;
              return query;
            },
            maybeSingle: () => {
              assertEquals(filters, {
                store: "google_play",
                transaction_id: purchase.transactionId,
                product_id: "bil_ai_boost",
                environment: purchase.environment,
              });
              return Promise.resolve({
                data: tombstone
                  ? {
                    ...filters,
                    owner_id: options.stateOwner === undefined
                      ? owner
                      : options.stateOwner,
                    purchase_credited: options.stateOwner !== null,
                    state: tombstone,
                  }
                  : null,
                error: options.tombstoneReadFails
                  ? { message: "fixture unreadable" }
                  : null,
              });
            },
          };
          return query;
        },
        rpc: (name: string, args: Record<string, unknown>) => {
          if (name === "bil_lookup_ai_boost_owner") {
            assertEquals(args.p_store, "google_play");
            assertEquals(args.p_transaction_id, purchase.transactionId);
            return Promise.resolve({
              data: options.storedOwner
                ? [{ owner_id: options.storedOwner }]
                : [],
              error: null,
            });
          }
          if (name === "bil_credit_ai_boost_verified") {
            credits++;
            return Promise.resolve({
              data: { credited: true, tokens_granted: 730 },
              error: null,
            });
          }
          assertEquals(name, "bil_apply_ai_boost_store_event");
          events++;
          assertEquals(args.p_store, "google_play");
          assertEquals(args.p_environment, "sandbox");
          assertEquals(args.p_transaction_id, purchase.transactionId);
          assertEquals(args.p_product_id, "bil_ai_boost");
          assertEquals(args.p_event_type, "refunded");
          assertEquals(args.p_event_at, "2026-10-11T12:00:00Z");
          assertEquals(
            args.p_event_id,
            "voided:fixture-canceled-order:2026-10-11T12:00:00Z",
          );
          if (!options.persistenceFails) {
            tombstone = options.reversalWins ? "refund_reversed" : "refunded";
          }
          return Promise.resolve({
            data: {
              applied: !options.persistenceFails && !options.reversalWins,
            },
            error: options.persistenceFails
              ? { message: "fixture write failure" }
              : null,
          });
        },
      } as never,
    }),
    requireIntegrity: (input: { body: Record<string, unknown> }) =>
      Promise.resolve(input.body),
    readEnvironment: () => "fixture.package",
    readGoogleConsumable: () => {
      canonicalReads++;
      return Promise.resolve(purchase);
    },
    verifyGoogleConsumable: () => {
      legacyReads++;
      return state === 0
        ? Promise.resolve(purchase)
        : Promise.reject(new Error("purchase_not_completed"));
    },
    googleVoidedPurchases: () => {
      voidedReads++;
      return Promise.resolve(
        options.noVoidedRecord ? [] : [{
          purchaseToken: "fixture-canceled-token",
          orderId: options.wrongVoidedOrder
            ? "different-order"
            : "fixture-canceled-order",
          voidedAt: "2026-10-11T12:00:00Z",
        }],
      );
    },
    consumeGoogleConsumable: () => {
      consumes++;
      return Promise.resolve();
    },
  };
  const send = async () => {
    const response = await handler(
      new Request("https://fixture.invalid/verify", {
        method: "POST",
        headers: { authorization: "Bearer fixture" },
        body: JSON.stringify({
          action: "verify_ai_boost",
          source: "google_play",
          product_id: "bil_ai_boost",
          verification_data: "fixture-canceled-token",
          delivery_version: version,
          finish_store: true,
          owner_id: "attacker",
          quantity: 900000,
          environment: "production",
        }),
      }),
      dependencies,
    );
    return { status: response.status, body: await response.json() };
  };
  return {
    send,
    stats: () => ({
      credits,
      events,
      consumes,
      canonicalReads,
      legacyReads,
      voidedReads,
    }),
  };
}

Deno.test("canonical Google canceled Boost settles v2 exactly once, without credit or consumption", async () => {
  const fixture = await googleTerminalFixture({ version: 2 });
  const first = await fixture.send();
  assertEquals(first.status, 200);
  assertEquals(first.body.verified, true);
  assertEquals(first.body.credited, false);
  assertEquals(first.body.delivery.active, false);
  assertEquals(first.body.delivery.quantity, 0);
  assertEquals(first.body.delivery.finish_pending, false);
  assertEquals(first.body.delivery.owner_id, owner);
  assertEquals(first.body.delivery.environment, "sandbox");
  const repeated = await fixture.send();
  assertEquals(repeated.body.delivery.event_key, first.body.delivery.event_key);
  assertEquals(fixture.stats(), {
    credits: 0,
    events: 1,
    consumes: 0,
    canonicalReads: 2,
    legacyReads: 0,
    voidedReads: 1,
  });
});

Deno.test("Google pending, unknown and legacy canceled receipts cannot settle or credit", async () => {
  for (
    const options of [{ state: 2, version: 2 }, { state: 99, version: 2 }, {
      state: 1,
    }]
  ) {
    const fixture = await googleTerminalFixture(options);
    const result = await fixture.send();
    assertEquals(result.body.error, "purchase_not_completed");
    assertEquals(result.body.delivery, undefined);
    assertEquals(fixture.stats().credits, 0);
    assertEquals(fixture.stats().events, 0);
    assertEquals(fixture.stats().consumes, 0);
  }
});

Deno.test("Google canceled ownership and exact canonical identity are enforced before any refund write", async () => {
  const cases = [
    { foreignBinding: true, expected: "purchase_owned_by_another_account" },
    {
      storedOwner: "00000000-0000-4000-8000-000000000002",
      expected: "purchase_owned_by_another_account",
    },
    {
      stateOwner: "00000000-0000-4000-8000-000000000002",
      existingState: "refunded" as const,
      expected: "purchase_owned_by_another_account",
    },
    { packageName: "foreign.package", expected: "google_transaction_mismatch" },
    { productId: "foreign-product", expected: "google_transaction_mismatch" },
    { token: "foreign-token", expected: "google_transaction_mismatch" },
  ];
  for (const options of cases) {
    const fixture = await googleTerminalFixture({ ...options, version: 2 });
    const result = await fixture.send();
    assertEquals(
      result.status,
      options.expected === "purchase_owned_by_another_account" ? 400 : 503,
    );
    assertEquals(result.body.error, options.expected);
    assertEquals(result.body.delivery, undefined);
    assertEquals(fixture.stats().credits, 0);
    assertEquals(fixture.stats().events, 0);
    assertEquals(fixture.stats().consumes, 0);
  }
  // Existing ownership for the same account still permits truthful terminal
  // settlement. The conflict guard must not reject every durable owner row.
  const matched = await googleTerminalFixture({
    version: 2,
    storedOwner: owner,
  });
  const accepted = await matched.send();
  assertEquals(accepted.status, 200);
  assertEquals(accepted.body.delivery.active, false);
  assertEquals(accepted.body.delivery.quantity, 0);
  assertEquals(matched.stats().credits, 0);
  assertEquals(matched.stats().events, 1);
  assertEquals(matched.stats().consumes, 0);
});

Deno.test("Google active Boost matching signed hash cannot override a foreign persisted transaction owner", async () => {
  const fixture = await googleTerminalFixture({
    version: 2,
    state: 0,
    storedOwner: "00000000-0000-4000-8000-000000000002",
  });
  const result = await fixture.send();
  assertEquals(result.status, 400);
  assertEquals(result.body.error, "purchase_owned_by_another_account");
  assertEquals(result.body.verified, false);
  assertEquals(result.body.entitlement_active, false);
  assertEquals(result.body.delivery, undefined);
  assertEquals(fixture.stats().credits, 0);
  assertEquals(fixture.stats().events, 0);
  assertEquals(fixture.stats().consumes, 0);
  assertEquals(fixture.stats().voidedReads, 0);
});

Deno.test("Google canceled old refund tombstone settles without querying an expired voided window", async () => {
  const fixture = await googleTerminalFixture({
    version: 2,
    existingState: "refunded",
    noVoidedRecord: true,
  });
  const result = await fixture.send();
  assertEquals(result.status, 200);
  assertEquals(result.body.delivery.active, false);
  assertEquals(fixture.stats().voidedReads, 0);
  assertEquals(fixture.stats().events, 0);
  assertEquals(fixture.stats().credits, 0);
});

Deno.test("Google canceled missing proof, storage failure or newer reversal remains unavailable with no fake success", async () => {
  const cases = [
    {
      noVoidedRecord: true,
      expected: "google_canceled_reconciliation_unavailable",
    },
    {
      wrongVoidedOrder: true,
      expected: "google_canceled_reconciliation_unavailable",
    },
    { tombstoneReadFails: true, expected: "boost_refund_check_unavailable" },
    { persistenceFails: true, expected: "boost_refund_persistence_failed" },
    { reversalWins: true, expected: "boost_refund_persistence_failed" },
  ];
  for (const options of cases) {
    const fixture = await googleTerminalFixture({ ...options, version: 2 });
    const result = await fixture.send();
    assertEquals(result.body.error, options.expected);
    assertEquals(result.body.delivery, undefined);
    assertEquals(fixture.stats().credits, 0);
    assertEquals(fixture.stats().consumes, 0);
  }
});
