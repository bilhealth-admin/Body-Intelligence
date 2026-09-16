import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  appleServerStatusLifecycle,
  appleTransactionLifecycle,
} from "./apple_subscription_lifecycle.ts";
import {
  buildVerifiedPurchaseRpcArgs,
  persistVerified,
} from "./store_backend.ts";

// These synthetic payloads exercise the real lifecycle and persistence adapter
// functions AFTER their caller has verified Apple's JWS. They do not test JWS
// signatures, call Apple/Supabase, or execute the database SQL. In particular,
// the mocked RPC result below is an explicit fixture, not proof of SQL access
// calculation, cancellation processing, or a real refunded transaction.
const ownerId = "00000000-0000-4000-8000-000000000071";
const dayMs = 24 * 60 * 60 * 1000;
const startedMs = Date.parse("2026-09-16T12:00:00.000Z");
const verifiedAt = "2026-09-19T12:00:00.000Z";
const products = [
  { id: "bil_premium", periodDays: 30, aiTrial: false },
  { id: "bil_premium_annual", periodDays: 365, aiTrial: false },
  { id: "bil_premium_ai_coach", periodDays: 30, aiTrial: true },
  { id: "bil_premium_ai_coach_annual", periodDays: 365, aiTrial: true },
] as const;
type Product = typeof products[number];
type Purchase = Parameters<typeof buildVerifiedPurchaseRpcArgs>[1];

function payloadFor(product: Product, trial = false) {
  return {
    productId: product.id,
    purchaseDate: startedMs,
    expiresDate: startedMs + (trial ? 7 : product.periodDays) * dayMs,
    ...(trial ? { offerType: 1, offerDiscountType: "FREE_TRIAL" } : {}),
  };
}

function purchaseFor(
  product: Product,
  payload: ReturnType<typeof payloadFor>,
  lifecycle: Purchase["lifecycle"],
  autoRenews = false,
): Purchase {
  return {
    provider: "apple",
    productId: product.id,
    originalTransactionId: `original-refund-matrix-${product.id}`,
    transactionId: `transaction-refund-matrix-${product.id}`,
    packageOrBundleId: "app.bil.health",
    environment: "sandbox",
    storeCountryCode: "EG",
    lifecycle,
    startedAt: new Date(payload.purchaseDate).toISOString(),
    expiresAt: new Date(payload.expiresDate).toISOString(),
    autoRenews,
  };
}

function serializedArgs(purchase: Purchase) {
  return JSON.parse(JSON.stringify(
    buildVerifiedPurchaseRpcArgs(
      ownerId,
      purchase,
      verifiedAt,
      "synthetic-refund-matrix-fingerprint",
    ),
  ));
}

function mockExistingOwnerRpc(active: boolean) {
  const writes: { name: string; args: Record<string, unknown> }[] = [];
  const reads: unknown[] = [];
  const query = {
    select(fields: string) {
      reads.push(["select", fields]);
      return query;
    },
    eq(field: string, value: string) {
      reads.push([field, value]);
      return query;
    },
    maybeSingle() {
      return Promise.resolve({
        data: { owner_id: ownerId, environment: "sandbox" },
        error: null,
      });
    },
  };
  const admin = {
    from(table: string) {
      reads.push(["from", table]);
      return query;
    },
    rpc(name: string, args: Record<string, unknown>) {
      writes.push({ name, args: JSON.parse(JSON.stringify(args)) });
      return Promise.resolve({
        data: {
          active,
          lifecycle: args.p_lifecycle,
          verified_at: args.p_verified_at,
        },
        error: null,
      });
    },
  } as unknown as Parameters<typeof persistVerified>[0];
  return { admin, reads, writes };
}

for (const product of products) {
  Deno.test(`${product.id}: cancelling auto-renew keeps paid access until the original expiry`, () => {
    const payload = payloadFor(product);
    for (const elapsedDays of [1, 3, 6]) {
      const nowMs = startedMs + elapsedDays * dayMs;
      const lifecycle = appleServerStatusLifecycle(
        1,
        appleTransactionLifecycle(payload, nowMs),
      );
      assertEquals(lifecycle, "active");
      const args = serializedArgs(purchaseFor(product, payload, lifecycle));
      assertEquals(args.p_auto_renews, false);
      assertEquals(args.p_lifecycle, "active");
      assertEquals(args.p_product_id, product.id);
      assertEquals(args.p_started_at, new Date(startedMs).toISOString());
      assertEquals(
        args.p_expires_at,
        new Date(payload.expiresDate).toISOString(),
      );
      assertEquals(args.p_grace_period_ends_at, null);
    }
    assertEquals(
      appleTransactionLifecycle(payload, payload.expiresDate - 1),
      "active",
    );
    assertEquals(
      appleTransactionLifecycle(payload, payload.expiresDate),
      "expired",
    );
  });

  Deno.test(`${product.id}: day-three revocation dominates a future paid or trial expiry`, () => {
    const payload = payloadFor(product, product.aiTrial);
    const revokedMs = startedMs + 3 * dayMs;
    const revokedPayload = { ...payload, revocationDate: revokedMs };
    assertEquals(payload.expiresDate > revokedMs, true);
    for (const nowMs of [revokedMs, startedMs + 6 * dayMs]) {
      const lifecycle = appleTransactionLifecycle(revokedPayload, nowMs);
      assertEquals(lifecycle, "revoked");
      // A stale active/grace status must not revive a signed revocation.
      for (const status of [1, 2, 3, 4, 5]) {
        assertEquals(appleServerStatusLifecycle(status, lifecycle), "revoked");
      }
      const args = serializedArgs(purchaseFor(product, payload, lifecycle));
      assertEquals(args.p_lifecycle, "revoked");
      assertEquals(
        args.p_expires_at,
        new Date(payload.expiresDate).toISOString(),
      );
      assertEquals(args.p_auto_renews, false);
    }
  });

  Deno.test(`${product.id}: server status five is terminal despite future expiry`, () => {
    const payload = payloadFor(product, product.aiTrial);
    const beforeRevocation = appleTransactionLifecycle(
      payload,
      startedMs + 3 * dayMs,
    );
    assertEquals(beforeRevocation, product.aiTrial ? "trial" : "active");
    const revoked = appleServerStatusLifecycle(5, beforeRevocation);
    assertEquals(revoked, "revoked");
    const args = serializedArgs(purchaseFor(product, payload, revoked));
    assertEquals(args.p_lifecycle, "revoked");
    assertEquals(
      args.p_expires_at,
      new Date(payload.expiresDate).toISOString(),
    );
  });

  Deno.test(`${product.id}: persistence forwards terminal payloads and does not promote an inactive RPC result`, async () => {
    const payload = payloadFor(product, product.aiTrial);
    for (const lifecycle of ["expired", "refunded", "revoked"] as const) {
      const fixture = mockExistingOwnerRpc(false);
      const purchase = purchaseFor(product, payload, lifecycle);
      const result = await persistVerified(fixture.admin, ownerId, purchase);
      assertEquals(result.active, false);
      assertEquals(fixture.writes.length, 1);
      const write = fixture.writes[0];
      assertEquals(write.name, "bil_persist_verified_store_purchase");
      assertEquals(write.args.p_owner_id, ownerId);
      assertEquals(write.args.p_product_id, product.id);
      assertEquals(write.args.p_lifecycle, lifecycle);
      assertEquals(write.args.p_started_at, purchase.startedAt);
      assertEquals(write.args.p_expires_at, purchase.expiresAt);
      assertEquals(write.args.p_grace_period_ends_at, null);
      assertEquals(write.args.p_auto_renews, false);
      assertEquals(write.args.p_verified_at, result.verifiedAt);
      assertEquals(write.args.p_environment, "sandbox");
      assertEquals(Object.keys(write.args).length, 16);
      assertEquals(write.args.p_store_signed_at, null);
      assertEquals(result.lifecycle, lifecycle);
      assertEquals(purchase.lifecycle, lifecycle);
      assertEquals(
        purchase.expiresAt,
        new Date(payload.expiresDate).toISOString(),
      );
    }
  });

  if (!product.aiTrial) continue;

  Deno.test(`${product.id}: a cancelled seven-day trial remains a trial on days one three and six without extending expiry`, async () => {
    const payload = payloadFor(product, true);
    const trialExpiresAt = new Date(startedMs + 7 * dayMs).toISOString();
    for (const elapsedDays of [1, 3, 6]) {
      const nowMs = startedMs + elapsedDays * dayMs;
      const lifecycle = appleServerStatusLifecycle(
        1,
        appleTransactionLifecycle(payload, nowMs),
      );
      assertEquals(lifecycle, "trial");
      const purchase = purchaseFor(product, payload, lifecycle, false);
      const args = serializedArgs(purchase);
      assertEquals(args.p_lifecycle, "trial");
      assertEquals(args.p_auto_renews, false);
      assertEquals(args.p_started_at, new Date(startedMs).toISOString());
      assertEquals(args.p_expires_at, trialExpiresAt);
      // This only verifies the adapter returns the supplied RPC response and
      // keeps the boundaries; the mock does not calculate paid access in SQL.
      const fixture = mockExistingOwnerRpc(true);
      const result = await persistVerified(fixture.admin, ownerId, purchase);
      assertEquals(result.active, true);
      assertEquals(fixture.writes.length, 1);
      assertEquals(fixture.writes[0].args.p_lifecycle, "trial");
      assertEquals(fixture.writes[0].args.p_auto_renews, false);
      assertEquals(fixture.writes[0].args.p_expires_at, trialExpiresAt);
    }
  });

  Deno.test(`${product.id}: the exact day-seven boundary expires the original trial`, async () => {
    const payload = payloadFor(product, true);
    assertEquals(
      appleTransactionLifecycle(payload, payload.expiresDate - 1),
      "trial",
    );
    for (const nowMs of [payload.expiresDate, payload.expiresDate + 1]) {
      const transactionLifecycle = appleTransactionLifecycle(payload, nowMs);
      assertEquals(transactionLifecycle, "expired");
      const lifecycle = appleServerStatusLifecycle(2, transactionLifecycle);
      assertEquals(lifecycle, "expired");
      // A stale active status cannot restore an expired trial either.
      assertEquals(
        appleServerStatusLifecycle(1, transactionLifecycle),
        "revoked",
      );
      const fixture = mockExistingOwnerRpc(false);
      const purchase = purchaseFor(product, payload, lifecycle);
      const result = await persistVerified(fixture.admin, ownerId, purchase);
      assertEquals(result.active, false);
      assertEquals(fixture.writes[0].args.p_lifecycle, "expired");
      assertEquals(fixture.writes[0].args.p_expires_at, purchase.expiresAt);
      assertEquals(fixture.writes[0].args.p_auto_renews, false);
    }
  });
}
