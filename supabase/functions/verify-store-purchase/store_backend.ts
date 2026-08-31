import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  compactVerify,
  decodeProtectedHeader,
  importPKCS8,
  importX509,
  SignJWT,
} from "npm:jose@6.1.0";
import { X509Certificate } from "node:crypto";
import {
  appleServerStatusLifecycle,
  appleTransactionLifecycle,
} from "./apple_subscription_lifecycle.ts";
import { googleLifecycle } from "./google_play_subscription_lifecycle.ts";
import {
  googleGracePeriodEnd,
  parseGoogleNotification,
} from "./google_play_notification.ts";
import {
  appleServerHost,
  googleProductEnvironment,
  googleSubscriptionEnvironment,
  type StoreEnvironment,
  verifiedStoreEnvironment,
} from "./store_environment.ts";

type Provider = "google" | "apple";
type Lifecycle =
  | "pending"
  | "trial"
  | "active"
  | "grace_period"
  | "billing_retry"
  | "account_hold"
  | "paused"
  | "suspended"
  | "deferred"
  | "cancelled"
  | "expired"
  | "refunded"
  | "revoked";

type VerifiedPurchase = {
  provider: Provider;
  productId: string;
  originalTransactionId: string;
  transactionId: string;
  packageOrBundleId: string;
  environment: "sandbox" | "production";
  storeCountryCode?: string;
  lifecycle: Lifecycle;
  startedAt?: string;
  expiresAt?: string;
  gracePeriodEndsAt?: string;
  autoRenews?: boolean;
};

type VerifiedConsumable = {
  provider: Provider;
  productId: string;
  transactionId: string;
  packageOrBundleId: string;
  environment: "sandbox" | "production";
  verifiedAt: string;
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json",
      "cache-control": "no-store",
    },
  });

const env = (name: string) => Deno.env.get(name)?.trim() ?? "";
type EnvironmentReader = (name: string) => string;

/// Keeps the dedicated Play Billing credential authoritative while allowing
/// the already-provisioned Play Integrity service account to be reused when
/// it also has Android Publisher access. Credential values are never logged.
export function googlePlayServiceAccountJson(
  readEnvironment: EnvironmentReader = env,
) {
  const dedicated = readEnvironment("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON").trim();
  if (dedicated) return dedicated;
  const playIntegrity = readEnvironment(
    "BIL_PLAY_INTEGRITY_SERVICE_ACCOUNT_JSON",
  ).trim();
  if (playIntegrity) return playIntegrity;
  throw new Error("google_credentials_missing");
}

const bytesToHex = (value: ArrayBuffer) =>
  [...new Uint8Array(value)].map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
const digest = async (value: string) =>
  bytesToHex(
    await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)),
  );
const digestBytes = async (value: Uint8Array) => {
  // Copy into an ArrayBuffer-backed view so WebCrypto never receives a
  // SharedArrayBuffer-compatible `ArrayBufferLike` under Deno 2's typings.
  const bytes = new Uint8Array(value.byteLength);
  bytes.set(value);
  return bytesToHex(await crypto.subtle.digest("SHA-256", bytes.buffer));
};
const fingerprint = async (value: string) => (await digest(value)).slice(0, 24);

const decodeBase64Bytes = (value: string) =>
  Uint8Array.from(atob(value), (character) => character.charCodeAt(0));

function verifiedAppleCertificateChain(x5c: string[]) {
  if (x5c.length < 2) throw new Error("invalid_apple_certificate_chain");
  const certificates = x5c.map((encoded) =>
    new X509Certificate(decodeBase64Bytes(encoded))
  );
  const now = Date.now();
  for (const certificate of certificates) {
    const validFrom = Date.parse(certificate.validFrom);
    const validTo = Date.parse(certificate.validTo);
    if (
      !Number.isFinite(validFrom) || !Number.isFinite(validTo) ||
      now < validFrom || now > validTo
    ) {
      throw new Error("apple_certificate_expired");
    }
  }
  if (certificates[0].ca) throw new Error("invalid_apple_leaf_certificate");
  for (let index = 1; index < certificates.length; index += 1) {
    if (!certificates[index].ca) {
      throw new Error("invalid_apple_ca_certificate");
    }
    if (!certificates[index - 1].verify(certificates[index].publicKey)) {
      throw new Error("invalid_apple_certificate_chain");
    }
  }
  const root = certificates.at(-1)!;
  if (!root.verify(root.publicKey)) {
    throw new Error("invalid_apple_root_certificate");
  }
  return certificates;
}

function clients(authorization?: string) {
  const url = env("SUPABASE_URL");
  const anon = env("SUPABASE_ANON_KEY");
  const service = env("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anon || !service) throw new Error("server_not_configured");
  return {
    auth: createClient(
      url,
      anon,
      authorization
        ? { global: { headers: { Authorization: authorization } } }
        : undefined,
    ),
    admin: createClient(url, service),
  };
}

async function googleAccessToken() {
  const raw = googlePlayServiceAccountJson();
  const account = JSON.parse(raw);
  const key = await importPKCS8(account.private_key, "RS256");
  const assertion = await new SignJWT({
    scope: "https://www.googleapis.com/auth/androidpublisher",
  }).setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(account.client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt().setExpirationTime("5m").sign(key);
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) throw new Error("google_oauth_failed");
  return String((await response.json()).access_token ?? "");
}

async function verifyGoogle(
  packageName: string,
  purchaseToken: string,
): Promise<VerifiedPurchase> {
  if (packageName !== env("GOOGLE_PLAY_PACKAGE_NAME")) {
    throw new Error("wrong_package");
  }
  const token = await googleAccessToken();
  const endpoint =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${
      encodeURIComponent(packageName)
    }/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`;
  const response = await fetch(endpoint, {
    headers: { authorization: `Bearer ${token}` },
  });
  if (!response.ok) throw new Error("google_verification_failed");
  const data = await response.json();
  const line = data.lineItems?.[0] ?? {};
  // Google, not the client, is authoritative for test-vs-production state.
  const environment = googleSubscriptionEnvironment(data.testPurchase);
  const lifecycle = googleLifecycle(
    String(data.subscriptionState ?? ""),
    line,
    new Date(),
    data.startTime,
  );
  return {
    provider: "google",
    productId: String(line.productId ?? ""),
    originalTransactionId: String(data.linkedPurchaseToken ?? purchaseToken),
    transactionId: purchaseToken,
    packageOrBundleId: packageName,
    environment,
    storeCountryCode: String(data.regionCode ?? "").trim().toUpperCase() ||
      undefined,
    lifecycle,
    startedAt: data.startTime,
    expiresAt: line.expiryTime,
    gracePeriodEndsAt: googleGracePeriodEnd(lifecycle, line.expiryTime),
    autoRenews: Boolean(line.autoRenewingPlan?.autoRenewEnabled),
  };
}

async function verifyGoogleConsumable(
  packageName: string,
  productId: string,
  purchaseToken: string,
): Promise<VerifiedConsumable> {
  if (packageName !== env("GOOGLE_PLAY_PACKAGE_NAME")) {
    throw new Error("wrong_package");
  }
  if (productId !== "bil_ai_boost") throw new Error("wrong_product");
  const token = await googleAccessToken();
  const endpoint =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${
      encodeURIComponent(packageName)
    }/purchases/products/${encodeURIComponent(productId)}/tokens/${
      encodeURIComponent(purchaseToken)
    }`;
  const response = await fetch(endpoint, {
    headers: { authorization: `Bearer ${token}` },
  });
  if (!response.ok) throw new Error("google_verification_failed");
  const data = await response.json() as Record<string, unknown>;
  if (Number(data.purchaseState ?? -1) !== 0) {
    throw new Error("purchase_not_completed");
  }
  const environment = googleProductEnvironment(data.purchaseType);
  return {
    provider: "google",
    productId,
    transactionId: purchaseToken,
    packageOrBundleId: packageName,
    environment,
    verifiedAt: new Date().toISOString(),
  };
}

async function consumeGoogleConsumable(
  packageName: string,
  productId: string,
  purchaseToken: string,
) {
  const token = await googleAccessToken();
  const endpoint =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${
      encodeURIComponent(packageName)
    }/purchases/products/${encodeURIComponent(productId)}/tokens/${
      encodeURIComponent(purchaseToken)
    }:consume`;
  const response = await fetch(endpoint, {
    method: "POST",
    headers: { authorization: `Bearer ${token}` },
  });
  // A retry can observe an already-consumed purchase after the idempotent
  // credit committed. Google reports 409 in that case and no second grant is
  // possible because the transaction ledger is unique.
  if (!response.ok && response.status !== 409) {
    throw new Error("google_consume_failed");
  }
}

async function googleVoidedPurchaseTokens(): Promise<Set<string>> {
  const packageName = env("GOOGLE_PLAY_PACKAGE_NAME");
  const token = await googleAccessToken();
  const tokens = new Set<string>();
  let pageToken = "";
  do {
    const endpoint = new URL(
      `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${
        encodeURIComponent(packageName)
      }/purchases/voidedpurchases`,
    );
    if (pageToken) endpoint.searchParams.set("token", pageToken);
    const response = await fetch(endpoint, {
      headers: { authorization: `Bearer ${token}` },
    });
    if (!response.ok) throw new Error("google_voided_purchase_query_failed");
    const data = await response.json();
    for (const purchase of data.voidedPurchases ?? []) {
      const purchaseToken = String(purchase.purchaseToken ?? "");
      if (purchaseToken) tokens.add(purchaseToken);
    }
    pageToken = String(data.tokenPagination?.nextPageToken ?? "");
  } while (pageToken);
  return tokens;
}

async function verifyAppleJws(jws: string): Promise<Record<string, unknown>> {
  const header = decodeProtectedHeader(jws);
  if (
    header.alg !== "ES256" || !Array.isArray(header.x5c) ||
    header.x5c.length < 2
  ) {
    throw new Error("invalid_apple_jws_header");
  }
  if (
    !header.x5c.every((certificate): certificate is string =>
      typeof certificate === "string" && certificate.length > 0
    )
  ) {
    throw new Error("invalid_apple_jws_header");
  }
  verifiedAppleCertificateChain(header.x5c);
  const pinnedRoots = new Set(
    env("APPLE_ROOT_CA_SHA256")
      .split(",")
      .map((pin) => pin.trim().toLowerCase().replaceAll(":", ""))
      .filter((pin) => /^[0-9a-f]{64}$/.test(pin)),
  );
  if (pinnedRoots.size === 0) throw new Error("apple_root_pin_missing");
  // Certificate pins are SHA-256 fingerprints of the raw DER certificate,
  // never of a UTF-8 reinterpretation of its binary bytes.
  // Hash the exact DER bytes carried in the signed x5c header after the same
  // bytes have passed full X509 path validation above.
  const rootDigest = await digestBytes(decodeBase64Bytes(header.x5c.at(-1)!));
  if (!pinnedRoots.has(rootDigest)) throw new Error("apple_chain_untrusted");
  const leaf = `-----BEGIN CERTIFICATE-----\n${
    header.x5c[0]
  }\n-----END CERTIFICATE-----`;
  const key = await importX509(leaf, "ES256");
  const verified = await compactVerify(jws, key, { algorithms: ["ES256"] });
  return JSON.parse(new TextDecoder().decode(verified.payload));
}

async function verifyApple(transactionJws: string): Promise<VerifiedPurchase> {
  const payload = await verifyAppleJws(transactionJws);
  const bundleId = String(payload.bundleId ?? "");
  if (bundleId !== env("APPLE_BUNDLE_ID")) throw new Error("wrong_bundle");
  // The environment is inside Apple's verified JWS and cannot be supplied by
  // the mobile client independently.
  const environment = verifiedStoreEnvironment(payload.environment);
  return {
    provider: "apple",
    productId: String(payload.productId ?? ""),
    originalTransactionId: String(payload.originalTransactionId ?? ""),
    transactionId: String(payload.transactionId ?? ""),
    packageOrBundleId: bundleId,
    environment,
    storeCountryCode: String(payload.storefront ?? "").trim().toUpperCase() ||
      undefined,
    lifecycle: appleTransactionLifecycle(payload),
    startedAt: payload.purchaseDate
      ? new Date(Number(payload.purchaseDate)).toISOString()
      : undefined,
    expiresAt: payload.expiresDate
      ? new Date(Number(payload.expiresDate)).toISOString()
      : undefined,
  };
}

async function appleServerToken() {
  const issuer = env("APPLE_ISSUER_ID");
  const keyId = env("APPLE_KEY_ID");
  const privateKey = env("APPLE_PRIVATE_KEY").replaceAll("\\n", "\n");
  const bundleId = env("APPLE_BUNDLE_ID");
  if (!issuer || !keyId || !privateKey || !bundleId) {
    throw new Error("apple_server_credentials_missing");
  }
  const key = await importPKCS8(privateKey, "ES256");
  return new SignJWT({ bid: bundleId })
    .setProtectedHeader({ alg: "ES256", kid: keyId, typ: "JWT" })
    .setIssuer(issuer).setAudience("appstoreconnect-v1")
    .setIssuedAt().setExpirationTime("5m").sign(key);
}

async function reconcileApple(
  originalTransactionId: string,
  environment: StoreEnvironment,
) {
  const host = appleServerHost(environment);
  const response = await fetch(
    `https://${host}/inApps/v1/subscriptions/${
      encodeURIComponent(originalTransactionId)
    }`,
    { headers: { authorization: `Bearer ${await appleServerToken()}` } },
  );
  if (!response.ok) throw new Error("apple_server_api_failed");
  const data = await response.json();
  const groups = data.data ?? [];
  const transactions = groups.flatMap((group: Record<string, unknown>) =>
    (group.lastTransactions as Array<Record<string, unknown>> | undefined) ?? []
  );
  const latest = transactions[0];
  if (!latest?.signedTransactionInfo) {
    throw new Error("apple_transaction_missing");
  }
  const purchase = await verifyApple(String(latest.signedTransactionInfo));
  purchase.lifecycle = appleServerStatusLifecycle(
    Number(latest.status ?? 0),
    purchase.lifecycle,
  );
  if (latest.signedRenewalInfo) {
    const renewal = await verifyAppleJws(String(latest.signedRenewalInfo));
    const graceEnds = Number(renewal.gracePeriodExpiresDate ?? 0);
    purchase.gracePeriodEndsAt = graceEnds > 0
      ? new Date(graceEnds).toISOString()
      : undefined;
    purchase.autoRenews = Number(renewal.autoRenewStatus ?? 0) === 1;
  }
  return purchase;
}

async function persistVerified(
  admin: ReturnType<typeof clients>["admin"],
  ownerId: string,
  purchase: VerifiedPurchase,
) {
  if (
    !purchase.productId || !purchase.originalTransactionId ||
    !purchase.transactionId
  ) {
    throw new Error("incomplete_store_result");
  }
  const verifiedAt = new Date().toISOString();
  const { data: active, error } = await admin.rpc(
    "bil_persist_verified_store_purchase",
    {
      p_owner_id: ownerId,
      p_provider: purchase.provider,
      p_product_id: purchase.productId,
      p_package_or_bundle_id: purchase.packageOrBundleId,
      p_lifecycle: purchase.lifecycle,
      p_original_transaction_id: purchase.originalTransactionId,
      p_latest_transaction_id: purchase.transactionId,
      p_environment: purchase.environment,
      p_store_country_code: purchase.storeCountryCode,
      p_started_at: purchase.startedAt,
      p_expires_at: purchase.expiresAt,
      p_grace_period_ends_at: purchase.gracePeriodEndsAt,
      p_auto_renews: purchase.autoRenews,
      p_verified_at: verifiedAt,
      p_transaction_fingerprint: await fingerprint(purchase.transactionId),
    },
  );
  if (error) {
    if (error.code === "23505") {
      throw new Error("purchase_owned_by_another_account");
    }
    if (error.message?.includes("product_not_enabled")) {
      throw new Error("product_not_enabled");
    }
    if (error.message?.includes("market_plan_mismatch")) {
      throw new Error("market_plan_mismatch");
    }
    if (error.message?.includes("store_country_required")) {
      throw new Error("store_country_required");
    }
    throw new Error("persistence_failed");
  }
  if (typeof active !== "boolean") throw new Error("persistence_failed");
  return active;
}

async function authenticatedUser(request: Request) {
  const authorization = request.headers.get("authorization") ?? "";
  if (!authorization) throw new Error("authentication_required");
  const { auth, admin } = clients(authorization);
  const { data, error } = await auth.auth.getUser();
  if (error || !data.user) throw new Error("invalid_session");
  return { user: data.user, auth, admin };
}

async function verifyPurchase(request: Request, body: Record<string, unknown>) {
  const { user, auth, admin } = await authenticatedUser(request);
  const { error: rateError } = await auth.rpc("bil_consume_rate_limit", {
    p_action: "store_purchase_verification",
    p_limit: 20,
    p_window_seconds: 3600,
  });
  if (rateError) throw new Error("rate_limited");
  const source = String(body.source ?? "");
  const verification = String(body.verification_data ?? "");
  if (!verification) throw new Error("invalid_receipt_payload");
  let purchase: VerifiedPurchase;
  if (source === "app_store") {
    // The device JWS is only the lookup proof. Entitlement truth comes from a
    // fresh App Store Server API response over authenticated TLS.
    const deviceTransaction = await verifyApple(verification);
    purchase = await reconcileApple(
      deviceTransaction.originalTransactionId,
      deviceTransaction.environment,
    );
    if (
      purchase.originalTransactionId !== deviceTransaction.originalTransactionId
    ) {
      throw new Error("apple_transaction_mismatch");
    }
  } else if (source === "google_play") {
    purchase = await verifyGoogle(
      env("GOOGLE_PLAY_PACKAGE_NAME"),
      verification,
    );
  } else {
    throw new Error("invalid_store_source");
  }
  if (purchase.productId !== String(body.product_id ?? "")) {
    throw new Error("wrong_product");
  }
  const active = await persistVerified(admin, user.id, purchase);
  return json({
    verified: true,
    entitlement_active: active,
    lifecycle: purchase.lifecycle,
    store_country_code: purchase.storeCountryCode,
  });
}

async function verifyAiBoost(request: Request, body: Record<string, unknown>) {
  const { user, auth, admin } = await authenticatedUser(request);
  const { error: rateError } = await auth.rpc("bil_consume_rate_limit", {
    p_action: "ai_boost_purchase_verification",
    p_limit: 20,
    p_window_seconds: 3600,
  });
  if (rateError) throw new Error("rate_limited");
  const source = String(body.source ?? "");
  const productId = String(body.product_id ?? "");
  const verification = String(body.verification_data ?? "");
  if (productId !== "bil_ai_boost") throw new Error("wrong_product");
  if (!verification) throw new Error("invalid_receipt_payload");
  let purchase: VerifiedConsumable;
  if (source === "google_play") {
    purchase = await verifyGoogleConsumable(
      env("GOOGLE_PLAY_PACKAGE_NAME"),
      productId,
      verification,
    );
  } else if (source === "app_store") {
    const apple = await verifyApple(verification);
    if (apple.productId !== productId || apple.lifecycle !== "active") {
      throw new Error("purchase_not_completed");
    }
    purchase = {
      provider: "apple",
      productId,
      transactionId: apple.transactionId,
      packageOrBundleId: apple.packageOrBundleId,
      environment: apple.environment,
      verifiedAt: new Date().toISOString(),
    };
  } else {
    throw new Error("invalid_store_source");
  }
  const store = purchase.provider === "google" ? "google_play" : "app_store";
  const { data, error } = await admin.rpc("bil_credit_ai_boost_verified", {
    p_owner_id: user.id,
    p_store: store,
    p_transaction_id: purchase.transactionId,
    p_product_id: productId,
    p_verified_at: purchase.verifiedAt,
    p_raw_receipt_hash: await digest(verification),
  });
  if (error) {
    if (error.code === "23505") {
      throw new Error("purchase_owned_by_another_account");
    }
    throw new Error("persistence_failed");
  }
  if (purchase.provider === "google") {
    await consumeGoogleConsumable(
      purchase.packageOrBundleId,
      productId,
      purchase.transactionId,
    );
  }
  return json({
    verified: true,
    product_id: productId,
    credited: Boolean((data as Record<string, unknown> | null)?.credited),
  });
}

async function verifyGooglePush(
  request: Request,
  body: Record<string, unknown>,
) {
  const bearer =
    request.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  const tokenInfo = await fetch(
    `https://oauth2.googleapis.com/tokeninfo?id_token=${
      encodeURIComponent(bearer)
    }`,
  );
  if (!tokenInfo.ok) throw new Error("invalid_pubsub_identity");
  const identity = await tokenInfo.json();
  if (
    identity.aud !== env("GOOGLE_PUBSUB_AUDIENCE") ||
    identity.email !== env("GOOGLE_PUBSUB_SERVICE_ACCOUNT")
  ) {
    throw new Error("invalid_pubsub_identity");
  }
  const encoded = String((body.message as Record<string, unknown>)?.data ?? "");
  const notice = JSON.parse(atob(encoded)) as Record<string, unknown>;
  const parsed = parseGoogleNotification(notice);
  const notificationId = String(
    (body.message as Record<string, unknown>)?.messageId ?? "",
  );
  if (!notificationId) throw new Error("invalid_google_notification");
  const { admin } = clients();
  const { data: claimed } = await admin.rpc("bil_claim_store_notification", {
    p_provider: "google",
    p_notification_id: notificationId,
    // Google RTDN delivery itself has no environment field. Purchase truth is
    // persisted from the authenticated Publisher API response below.
    p_payload_digest: await digest(encoded),
    p_environment: "production",
  });
  if (!claimed) return json({ accepted: true, duplicate: true });
  try {
    if (parsed.kind === "test") {
      await markStoreNotification(admin, "google", notificationId, "processed");
      return json({ accepted: true, test: true });
    }
    if (parsed.kind === "one_time_canceled") {
      if (parsed.productId !== "bil_ai_boost") throw new Error("wrong_product");
      await markStoreNotification(admin, "google", notificationId, "processed");
      return json({ accepted: true, one_time_product: true, cancelled: true });
    }
    if (parsed.kind === "one_time_purchased") {
      await verifyGoogleConsumable(
        env("GOOGLE_PLAY_PACKAGE_NAME"),
        parsed.productId!,
        parsed.purchaseToken!,
      );
      // RTDN has no authenticated BIL owner. The signed-in client performs the
      // idempotent credit and consume flow; this notification only validates
      // the purchase and records delivery without guessing account ownership.
      await markStoreNotification(admin, "google", notificationId, "processed");
      return json({
        accepted: true,
        one_time_product: true,
        owner_pending: true,
      });
    }
    if (parsed.kind !== "subscription") {
      throw new Error("invalid_google_notification");
    }
    const purchase = await verifyGoogle(
      env("GOOGLE_PLAY_PACKAGE_NAME"),
      parsed.purchaseToken!,
    );
    const existing = await admin.from("bil_subscriptions").select("owner_id")
      .eq("provider", "google").eq(
        "original_transaction_id",
        purchase.originalTransactionId,
      ).maybeSingle();
    if (existing.data?.owner_id) {
      await persistVerified(admin, existing.data.owner_id, purchase);
    }
    await markStoreNotification(admin, "google", notificationId, "processed");
    return json({ accepted: true });
  } catch (error) {
    await markStoreNotification(admin, "google", notificationId, "error").catch(
      () => {},
    );
    throw error;
  }
}

async function markStoreNotification(
  admin: ReturnType<typeof clients>["admin"],
  provider: Provider,
  notificationId: string,
  status: "processed" | "error",
) {
  const { error } = await admin.from("bil_store_notification_inbox").update({
    status,
    processed_at: new Date().toISOString(),
  }).eq("provider", provider).eq("notification_id", notificationId);
  if (error) throw new Error("notification_status_update_failed");
}

async function verifyAppleNotification(body: Record<string, unknown>) {
  const signedPayload = String(body.signedPayload ?? "");
  const notification = await verifyAppleJws(signedPayload);
  const notificationId = String(notification.notificationUUID ?? "");
  const data = notification.data as Record<string, unknown>;
  const notificationEnvironment = verifiedStoreEnvironment(data?.environment);
  const { admin } = clients();
  const { data: claimed } = await admin.rpc("bil_claim_store_notification", {
    p_provider: "apple",
    p_notification_id: notificationId,
    p_payload_digest: await digest(signedPayload),
    p_environment: notificationEnvironment,
  });
  if (!claimed) return json({ accepted: true, duplicate: true });
  try {
    if (String(notification.notificationType ?? "") === "TEST") {
      await markStoreNotification(admin, "apple", notificationId, "processed");
      return json({ accepted: true, test: true });
    }
    const transactionJws = String(data?.signedTransactionInfo ?? "");
    const notificationTransaction = await verifyApple(transactionJws);
    const purchase = await reconcileApple(
      notificationTransaction.originalTransactionId,
      notificationTransaction.environment,
    );
    if (
      purchase.originalTransactionId !==
        notificationTransaction.originalTransactionId
    ) {
      throw new Error("apple_transaction_mismatch");
    }
    const notificationType = String(notification.notificationType ?? "");
    const subtype = String(notification.subtype ?? "");
    purchase.lifecycle = appleNotificationLifecycle(
      notificationType,
      subtype,
      purchase.lifecycle,
    );
    const existing = await admin.from("bil_subscriptions").select("owner_id")
      .eq("provider", "apple").eq(
        "original_transaction_id",
        purchase.originalTransactionId,
      ).maybeSingle();
    if (existing.data?.owner_id) {
      await persistVerified(admin, existing.data.owner_id, purchase);
    }
    await markStoreNotification(admin, "apple", notificationId, "processed");
    return json({ accepted: true });
  } catch (error) {
    await markStoreNotification(admin, "apple", notificationId, "error").catch(
      () => {},
    );
    throw error;
  }
}

function appleNotificationLifecycle(
  notificationType: string,
  subtype: string,
  verifiedLifecycle: Lifecycle,
): Lifecycle {
  if (notificationType === "REFUND") return "refunded";
  if (notificationType === "REVOKE") return "revoked";
  if (
    notificationType === "EXPIRED" ||
    notificationType === "GRACE_PERIOD_EXPIRED"
  ) {
    return "expired";
  }
  if (notificationType === "DID_FAIL_TO_RENEW") {
    return subtype === "GRACE_PERIOD" ? "grace_period" : "billing_retry";
  }
  return verifiedLifecycle;
}

async function reconcile(request: Request) {
  const supplied = request.headers.get("x-bil-reconciliation-secret") ?? "";
  const expected = env("BIL_RECONCILIATION_SECRET");
  if (!expected || supplied.length !== expected.length) {
    throw new Error("reconciliation_forbidden");
  }
  const left = new TextEncoder().encode(supplied);
  const right = new TextEncoder().encode(expected);
  let mismatch = 0;
  for (let index = 0; index < left.length; index += 1) {
    mismatch |= left[index] ^ right[index];
  }
  if (mismatch !== 0) throw new Error("reconciliation_forbidden");
  const { admin } = clients();
  const { data: subscriptions, error } = await admin.from("bil_subscriptions")
    .select(
      "owner_id,provider,original_transaction_id,latest_transaction_id,environment",
    )
    .limit(500);
  if (error) throw new Error("reconciliation_read_failed");
  let voidedGoogleTokens = new Set<string>();
  try {
    voidedGoogleTokens = await googleVoidedPurchaseTokens();
  } catch {
    // Normal per-subscription verification still runs. The failure is visible
    // in reconciliation audit rather than silently granting new access.
  }
  let reconciled = 0;
  for (const row of subscriptions ?? []) {
    try {
      if (
        row.provider === "google" &&
        voidedGoogleTokens.has(row.latest_transaction_id)
      ) {
        await admin.from("bil_subscriptions").update({
          lifecycle: "revoked",
          verified_at: new Date().toISOString(),
        }).eq("owner_id", row.owner_id);
        await admin.from("bil_entitlements").update({
          active: false,
          server_updated_at: new Date().toISOString(),
        }).eq("owner_id", row.owner_id).like("entitlement_id", "plan:%");
        await admin.from("bil_store_entitlement_audit").insert({
          owner_id: row.owner_id,
          provider: "google",
          lifecycle: "revoked",
          reason: "google_voided_purchase",
          transaction_fingerprint: await fingerprint(row.latest_transaction_id),
        });
        reconciled += 1;
        continue;
      }
      const purchase = row.provider === "google"
        ? await verifyGoogle(
          env("GOOGLE_PLAY_PACKAGE_NAME"),
          row.latest_transaction_id,
        )
        : await reconcileApple(
          row.original_transaction_id,
          verifiedStoreEnvironment(row.environment),
        );
      await persistVerified(admin, row.owner_id, purchase);
      reconciled += 1;
    } catch {
      await admin.from("bil_store_entitlement_audit").insert({
        owner_id: row.owner_id,
        provider: row.provider,
        lifecycle: "suspended",
        reason: "scheduled_reconciliation_failed",
        transaction_fingerprint: await fingerprint(row.latest_transaction_id),
      });
    }
  }
  return json({ reconciled, examined: subscriptions?.length ?? 0 });
}

export async function handler(request: Request): Promise<Response> {
  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }
  try {
    const body = await request.json() as Record<string, unknown>;
    if (body.action === "reconcile") return await reconcile(request);
    if (body.signedPayload) return await verifyAppleNotification(body);
    if (body.message) return await verifyGooglePush(request, body);
    if (body.action === "verify_purchase") {
      return await verifyPurchase(request, body);
    }
    if (body.action === "verify_ai_boost") {
      return await verifyAiBoost(request, body);
    }
    return json({ error: "invalid_action" }, 400);
  } catch (error) {
    const code = error instanceof Error ? error.message : "verification_failed";
    const clientCodes = new Set([
      "authentication_required",
      "invalid_session",
      "invalid_receipt_payload",
      "wrong_product",
      "wrong_package",
      "wrong_bundle",
      "wrong_environment",
      "purchase_owned_by_another_account",
      "market_plan_mismatch",
      "store_country_required",
    ]);
    return json(
      { error: code, verified: false, entitlement_active: false },
      code === "authentication_required" || code === "invalid_session"
        ? 401
        : clientCodes.has(code)
        ? 400
        : 503,
    );
  }
}
