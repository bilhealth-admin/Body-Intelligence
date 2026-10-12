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
) {
  const token = await deriveAppleAppAccountToken(signedOwner);
  const purchase = {
    provider: "apple" as const,
    productId: "bil_ai_boost",
    transactionId: base.transactionId,
    originalTransactionId: "fixture-original",
    packageOrBundleId: "app.bil.health",
    environment: "sandbox" as const,
    lifecycle: "active" as const,
    appAccountToken: token,
  };
  let writes = 0;
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
          rpc: (name: string, args: Record<string, unknown>) => {
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
  return { status: response.status, body: await response.json(), writes };
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
