import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  assertApplePurchaseLookup,
  assertApplePurchaseReconciliation,
  type VerifiedApplePurchaseIdentity,
} from "./apple_purchase_reconciliation.ts";

const device: VerifiedApplePurchaseIdentity = Object.freeze({
  provider: "apple",
  productId: "bil_premium_monthly",
  originalTransactionId: "original-1",
  transactionId: "historical-1",
  packageOrBundleId: "app.bil.health",
  environment: "sandbox",
});

const canonical: VerifiedApplePurchaseIdentity = Object.freeze({
  ...device,
  productId: "bil_premium_annual",
  transactionId: "latest-2",
});

Deno.test("Apple historical monthly proof accepts canonical annual renewal in same chain", () => {
  assertApplePurchaseLookup("bil_premium_monthly", device);
  assertApplePurchaseReconciliation(device, canonical);
  // The canonical product is not rewritten to the historical/client product.
  assertEquals(canonical.productId, "bil_premium_annual");
  assertEquals(device.productId, "bil_premium_monthly");
});

Deno.test("Apple unchanged product and transaction are valid for first verification", () => {
  assertApplePurchaseLookup(device.productId, device);
  assertApplePurchaseReconciliation(device, device);
});

Deno.test("Apple annual proof accepts canonical monthly renewal in same chain", () => {
  assertApplePurchaseLookup(canonical.productId, canonical);
  assertApplePurchaseReconciliation(canonical, {
    ...device,
    transactionId: "latest-3",
  });
});

Deno.test("Apple request cannot name canonical product using a different historical proof", () => {
  assertThrows(
    () => assertApplePurchaseLookup(canonical.productId, device),
    Error,
    "wrong_product",
  );
});

Deno.test("Apple request rejects absent, coerced or normalized product values", () => {
  for (
    const requested of [
      undefined,
      null,
      "",
      " ",
      1,
      { toString: () => device.productId },
      ` ${device.productId}`,
      `${device.productId} `,
      device.productId.toUpperCase(),
    ]
  ) {
    assertThrows(
      () => assertApplePurchaseLookup(requested, device),
      Error,
      "wrong_product",
    );
  }
});

Deno.test("Apple canonical result from another chain is rejected even with matching product", () => {
  assertThrows(
    () =>
      assertApplePurchaseReconciliation(device, {
        ...device,
        originalTransactionId: "another-original",
      }),
    Error,
    "apple_transaction_mismatch",
  );
});

Deno.test("Apple canonical changed product cannot bypass original transaction binding", () => {
  assertThrows(
    () =>
      assertApplePurchaseReconciliation(device, {
        ...canonical,
        originalTransactionId: "another-original",
      }),
    Error,
    "apple_transaction_mismatch",
  );
});

Deno.test("Apple canonical result cannot cross sandbox and production", () => {
  assertThrows(
    () =>
      assertApplePurchaseReconciliation(device, {
        ...canonical,
        environment: "production",
      }),
    Error,
    "wrong_environment",
  );
});

Deno.test("Apple canonical result cannot cross bundle identifiers", () => {
  assertThrows(
    () =>
      assertApplePurchaseReconciliation(device, {
        ...canonical,
        packageOrBundleId: "app.other.bundle",
      }),
    Error,
    "wrong_bundle",
  );
});

Deno.test("Apple reconciliation never accepts Google proof or canonical result", () => {
  const google = { ...device, provider: "google" };
  assertThrows(
    () => assertApplePurchaseLookup(device.productId, google),
    Error,
    "invalid_store_source",
  );
  assertThrows(
    () => assertApplePurchaseReconciliation(google, canonical),
    Error,
    "invalid_store_source",
  );
  assertThrows(
    () => assertApplePurchaseReconciliation(device, google),
    Error,
    "invalid_store_source",
  );
});

Deno.test("Apple lookup rejects incomplete signed identities before reconciliation", () => {
  for (
    const field of [
      "productId",
      "originalTransactionId",
      "transactionId",
      "packageOrBundleId",
    ]
  ) {
    for (const value of ["", " "]) {
      assertThrows(
        () =>
          assertApplePurchaseLookup(device.productId, {
            ...device,
            [field]: value,
          }),
        Error,
        "incomplete_store_result",
      );
    }
  }
});

Deno.test("Apple reconciliation rejects incomplete canonical identities", () => {
  for (
    const field of [
      "productId",
      "originalTransactionId",
      "transactionId",
      "packageOrBundleId",
    ]
  ) {
    for (const value of ["", " "]) {
      assertThrows(
        () =>
          assertApplePurchaseReconciliation(device, {
            ...canonical,
            [field]: value,
          }),
        Error,
        "incomplete_store_result",
      );
    }
  }
});

Deno.test("Apple original transaction binding is exact, not normalized", () => {
  assertThrows(
    () =>
      assertApplePurchaseReconciliation(device, {
        ...canonical,
        originalTransactionId: `${device.originalTransactionId} `,
      }),
    Error,
    "apple_transaction_mismatch",
  );
});
