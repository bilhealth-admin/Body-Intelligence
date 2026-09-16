import type { StoreEnvironment } from "./store_environment.ts";

/**
 * Identity extracted only after verifying an Apple transaction JWS. This
 * helper does not verify signatures and must never receive request-body
 * transaction identifiers, bundle identifiers or environment values.
 */
export type VerifiedApplePurchaseIdentity = Readonly<{
  provider: string;
  productId: string;
  originalTransactionId: string;
  transactionId: string;
  packageOrBundleId: string;
  environment: StoreEnvironment;
}>;

function assertCompleteAppleIdentity(
  transaction: VerifiedApplePurchaseIdentity,
): void {
  if (transaction.provider !== "apple") {
    throw new Error("invalid_store_source");
  }
  if (
    !transaction.productId.trim() ||
    !transaction.originalTransactionId.trim() ||
    !transaction.transactionId.trim() ||
    !transaction.packageOrBundleId.trim()
  ) {
    throw new Error("incomplete_store_result");
  }
  if (
    transaction.environment !== "sandbox" &&
    transaction.environment !== "production"
  ) {
    throw new Error("wrong_environment");
  }
}

/**
 * Bind the untrusted request product to the signed device transaction BEFORE
 * using that transaction as the Server API lookup proof. Do not compare this
 * product to a later renewal: a subscription can change products in its chain.
 */
export function assertApplePurchaseLookup(
  requestedProductId: unknown,
  signedDeviceTransaction: VerifiedApplePurchaseIdentity,
): void {
  assertCompleteAppleIdentity(signedDeviceTransaction);
  if (
    typeof requestedProductId !== "string" ||
    requestedProductId !== signedDeviceTransaction.productId
  ) {
    throw new Error("wrong_product");
  }
}

/**
 * Bind the freshly verified Server API transaction to the verified lookup
 * proof. A changed product or transaction ID is legitimate within the same
 * subscription chain. Persistence must use the canonical transaction's product
 * and still enforce the enabled product catalog; this grants no entitlement.
 */
export function assertApplePurchaseReconciliation(
  signedDeviceTransaction: VerifiedApplePurchaseIdentity,
  signedCanonicalTransaction: VerifiedApplePurchaseIdentity,
): void {
  assertCompleteAppleIdentity(signedDeviceTransaction);
  assertCompleteAppleIdentity(signedCanonicalTransaction);
  if (
    signedCanonicalTransaction.originalTransactionId !==
      signedDeviceTransaction.originalTransactionId
  ) {
    throw new Error("apple_transaction_mismatch");
  }
  if (
    signedCanonicalTransaction.environment !==
      signedDeviceTransaction.environment
  ) {
    throw new Error("wrong_environment");
  }
  if (
    signedCanonicalTransaction.packageOrBundleId !==
      signedDeviceTransaction.packageOrBundleId
  ) {
    throw new Error("wrong_bundle");
  }
}
