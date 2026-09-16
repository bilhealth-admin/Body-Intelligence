import type { StoreEnvironment } from "./store_environment.ts";

/** A service-role lookup of the owner already bound to this subscription chain. */
export type ExistingApplePurchaseOwner = Readonly<{
  ownerId: string;
  environment: StoreEnvironment;
}>;

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function isOwnerId(value: unknown): value is string {
  return typeof value === "string" && value.length > 0 &&
    value.trim() === value;
}

function assertEnvironment(value: unknown): asserts value is StoreEnvironment {
  if (value !== "sandbox" && value !== "production") {
    throw new Error("wrong_environment");
  }
}

/**
 * Exact equivalent of the iOS storeAccountIdentifier in the Flutter client:
 * SHA-256 over UTF-8, first 16 bytes, UUID version/variant bits, lowercase hex.
 * The owner must come from authenticated server identity, never the request.
 */
export async function deriveAppleAppAccountToken(
  ownerId: string,
): Promise<string> {
  if (!isOwnerId(ownerId)) throw new Error("invalid_store_owner");
  const digest = new Uint8Array(
    await crypto.subtle.digest(
      "SHA-256",
      new TextEncoder().encode(`bil-store-account:${ownerId}`),
    ),
  );
  const bytes = digest.slice(0, 16);
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0"))
    .join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${
    hex.slice(16, 20)
  }-${hex.slice(20, 32)}`;
}

/**
 * A valid store receipt is not by itself proof that this BIL user owns it.
 * Tokens must come ONLY from cryptographically verified Apple JWS payloads.
 * Never pass a client-supplied token or copy a token between signed payloads.
 *
 * A missing legacy token can refresh an existing exact owner/environment
 * binding, but cannot create one. Every present signed token must agree with
 * the current BIL owner, including when a legacy database binding exists.
 * This helper grants no entitlement and replaces no store lifecycle checks.
 */
export async function assertApplePurchaseOwnership(
  ownerId: string,
  signedTokens: readonly unknown[],
  existingOwner: ExistingApplePurchaseOwner | null,
  environment: StoreEnvironment,
): Promise<void> {
  if (!isOwnerId(ownerId)) throw new Error("invalid_store_owner");
  assertEnvironment(environment);
  if (existingOwner !== null) {
    if (
      typeof existingOwner !== "object" ||
      !isOwnerId(existingOwner?.ownerId)
    ) {
      throw new Error("purchase_owner_lookup_failed");
    }
    assertEnvironment(existingOwner.environment);
    if (existingOwner.environment !== environment) {
      throw new Error("wrong_environment");
    }
    if (existingOwner.ownerId !== ownerId) {
      throw new Error("purchase_owned_by_another_account");
    }
  }
  if (!Array.isArray(signedTokens)) {
    throw new Error("invalid_apple_account_token");
  }
  const presentTokens = signedTokens.filter((token) =>
    token !== undefined && token !== null
  );
  if (presentTokens.length === 0) {
    if (existingOwner === null) {
      throw new Error("apple_account_binding_required");
    }
    return;
  }
  const expectedToken = await deriveAppleAppAccountToken(ownerId);
  for (const token of presentTokens) {
    if (typeof token !== "string" || !uuidPattern.test(token)) {
      throw new Error("invalid_apple_account_token");
    }
    if (token.toLowerCase() !== expectedToken) {
      throw new Error("purchase_owned_by_another_account");
    }
  }
}
