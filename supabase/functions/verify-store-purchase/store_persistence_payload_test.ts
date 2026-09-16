import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { buildVerifiedPurchaseRpcArgs } from "./store_backend.ts";

const ownerId = "00000000-0000-4000-8000-000000000001";
const verifiedAt = "2026-09-16T02:00:00.000Z";
const transactionFingerprint = "test-transaction-fingerprint";
const purchase = {
  provider: "apple" as const,
  productId: "bil_premium_annual",
  originalTransactionId: "original-1",
  transactionId: "latest-2",
  packageOrBundleId: "app.bil.health",
  environment: "sandbox" as const,
  lifecycle: "active" as const,
};

function serializedArgs(
  value: Parameters<typeof buildVerifiedPurchaseRpcArgs>[1],
) {
  return JSON.parse(JSON.stringify(
    buildVerifiedPurchaseRpcArgs(
      ownerId,
      value,
      verifiedAt,
      transactionFingerprint,
    ),
  ));
}

Deno.test("purchase RPC JSON retains all 15 required arguments when optional values are absent", () => {
  assertEquals(serializedArgs(purchase), {
    p_owner_id: ownerId,
    p_provider: "apple",
    p_product_id: "bil_premium_annual",
    p_package_or_bundle_id: "app.bil.health",
    p_lifecycle: "active",
    p_original_transaction_id: "original-1",
    p_latest_transaction_id: "latest-2",
    p_environment: "sandbox",
    p_store_country_code: null,
    p_started_at: null,
    p_expires_at: null,
    p_grace_period_ends_at: null,
    p_auto_renews: null,
    p_verified_at: verifiedAt,
    p_transaction_fingerprint: transactionFingerprint,
  });
});

Deno.test("ordinary Apple active receipt keeps the grace argument and preserves auto-renew false", () => {
  const startedAt = "2026-09-15T00:00:00.000Z";
  const expiresAt = "2027-09-15T00:00:00.000Z";
  const args = serializedArgs({
    ...purchase,
    storeCountryCode: "EG",
    startedAt,
    expiresAt,
    gracePeriodEndsAt: undefined,
    autoRenews: false,
  });
  assertEquals(Object.keys(args).length, 15);
  assertEquals(args.p_store_country_code, "EG");
  assertEquals(args.p_started_at, startedAt);
  assertEquals(args.p_expires_at, expiresAt);
  assertEquals(args.p_grace_period_ends_at, null);
  assertEquals(args.p_auto_renews, false);
});

Deno.test("purchase RPC preserves verified grace period and auto-renew true", () => {
  const gracePeriodEndsAt = "2026-09-17T00:00:00.000Z";
  const args = serializedArgs({
    ...purchase,
    lifecycle: "grace_period",
    gracePeriodEndsAt,
    autoRenews: true,
  });
  assertEquals(Object.keys(args).length, 15);
  assertEquals(args.p_lifecycle, "grace_period");
  assertEquals(args.p_grace_period_ends_at, gracePeriodEndsAt);
  assertEquals(args.p_auto_renews, true);
});

Deno.test("Google persistence uses the same complete nullable RPC signature", () => {
  const args = serializedArgs({
    ...purchase,
    provider: "google",
    environment: "production",
    lifecycle: "expired",
    storeCountryCode: "US",
    autoRenews: false,
  });
  assertEquals(Object.keys(args).length, 15);
  assertEquals(args.p_provider, "google");
  assertEquals(args.p_environment, "production");
  assertEquals(args.p_lifecycle, "expired");
  assertEquals(args.p_auto_renews, false);
  assertEquals(args.p_grace_period_ends_at, null);
});
