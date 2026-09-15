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
  MobileIntegrityFailure,
  requireMobileIntegrityGrant,
} from "../_shared/mobile_integrity.ts";
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

// Production diagnostics must never include the purchase body, receipt, JWT,
// or exception text.  The static route and error code are sufficient to
// distinguish an Apple/Google verification failure from a persistence fault.
const logStoreVerificationFailure = (
  route: "verify_purchase" | "verify_ai_boost" | "unknown",
  code: string,
  errorType = "",
  errorCategory = "",
  errorCode = "",
) => {
  const safeCode = /^[a-z0-9_]+$/.test(code)
    ? code
    : "verification_failed";
  const safeErrorType = /^[A-Za-z0-9_]+$/.test(errorType)
    ? errorType
    : "";
  const safeErrorCategory = /^[A-Za-z0-9_]+$/.test(errorCategory)
    ? errorCategory
    : "";
  const safeErrorCode = /^[A-Za-z0-9_]+$/.test(errorCode)
    ? errorCode
    : "";
  console.error(JSON.stringify({
    event: "store_verification_failure",
    route,
    code: safeCode,
    ...(safeErrorType ? { error_type: safeErrorType } : {}),
    ...(safeErrorCategory ? { error_category: safeErrorCategory } : {}),
    ...(safeErrorCode ? { error_code: safeErrorCode } : {}),
  }));
};

const safeVerificationErrorCategory = (error: unknown) => {
  const text = error instanceof Error
    ? `${error.name} ${error.message}`.toLowerCase()
    : "";
  if (/(jws|signature|compact|jwt)/.test(text)) return "jws";
  if (/(certificate|x509|chain|root|ca)/.test(text)) return "certificate";
  if (/(fetch|network|timeout|socket|connection)/.test(text)) return "network";
  if (/(json|decode|parse|payload)/.test(text)) return "payload";
  return "runtime";
};

const safeVerificationErrorCode = (error: unknown) => {
  const code = error instanceof Error ? error.message : "";
  const allowed = new Set([
    "invalid_apple_certificate_chain",
    "invalid_apple_leaf_certificate",
    "invalid_apple_ca_certificate",
    "apple_certificate_expired",
    "apple_root_pin_missing",
    "apple_root_pin_unsupported",
    "apple_chain_untrusted",
    "apple_jws_invalid",
  ]);
  return allowed.has(code) ? code : "unknown";
};

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

// Apple signs StoreKit JWS values with a leaf and WWDR intermediate.  The
// third x5c entry is not a trust anchor: Apple can change or omit that entry
// (for example when a cross-signed chain is selected).  Trust is therefore
// rooted in these public Apple Root CA certificates, selected only when their
// exact DER SHA-256 pin is configured in APPLE_ROOT_CA_SHA256.
const APPLE_ROOT_CA_DER_BASE64: Readonly<Record<string, string>> = {
  "b0b1730ecbc7ff4505142c49f1295e6eda6bcaed7e2c68c5be91b5a11001f024":
    "MIIEuzCCA6OgAwIBAgIBAjANBgkqhkiG9w0BAQUFADBiMQswCQYDVQQGEwJVUzETMBEGA1UEChMKQXBwbGUgSW5jLjEmMCQGA1UECxMdQXBwbGUgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkxFjAUBgNVBAMTDUFwcGxlIFJvb3QgQ0EwHhcNMDYwNDI1MjE0MDM2WhcNMzUwMjA5MjE0MDM2WjBiMQswCQYDVQQGEwJVUzETMBEGA1UEChMKQXBwbGUgSW5jLjEmMCQGA1UECxMdQXBwbGUgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkxFjAUBgNVBAMTDUFwcGxlIFJvb3QgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDkkakJH5HbHkdQ6wXtXnmELes2oldMVeyLGYne+Uts9QerIjAC6Bg++FAJ039BqJj50cpmnCRrEdCju+QbKsMflZ56DKRHi1vUFjczy8QPTc4UadHJGXL1XQ7Vf1+b8iUDulWPTV0N8WQ1IxVLFVkds5T39pyez1C6wVhQZ48ItCD3y6wsIG9wtj8BMIy3Q88PnT3zK0koGsj+zrW5DtleHNbLPbU6rfQPDgCSC7EhFi501TwN22IWq6NxkkdTVcGvL0Gz+PvjcM3mo0xFfh9Ma1CWQYnEdGILEINBhzOKgbEwWOxaBDKMaLOPHd5lc/9nXmW8Sdh2nzMUZaF3lMktAgMBAAGjggF6MIIBdjAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUK9BpR5R2Cf70a40uQKb3R01/CF4wHwYDVR0jBBgwFoAUK9BpR5R2Cf70a40uQKb3R01/CF4wggERBgNVHSAEggEIMIIBBDCCAQAGCSqGSIb3Y2QFATCB8jAqBggrBgEFBQcCARYeaHR0cHM6Ly93d3cuYXBwbGUuY29tL2FwcGxlY2EvMIHDBggrBgEFBQcCAjCBthqBs1JlbGlhbmNlIG9uIHRoaXMgY2VydGlmaWNhdGUgYnkgYW55IHBhcnR5IGFzc3VtZXMgYWNjZXB0YW5jZSBvZiB0aGUgdGhlbiBhcHBsaWNhYmxlIHN0YW5kYXJkIHRlcm1zIGFuZCBjb25kaXRpb25zIG9mIHVzZSwgY2VydGlmaWNhdGUgcG9saWN5IGFuZCBjZXJ0aWZpY2F0aW9uIHByYWN0aWNlIHN0YXRlbWVudHMuMA0GCSqGSIb3DQEBBQUAA4IBAQBcNplMLXi37Yyb3PN3m/J20ncwT8EfhYOFG5k9RzfyqZtAjizUsZAS2L70c5vu0mQPy3lPNNiiPvl4/2vIB+x9OYOLUyDTOMSxv5pPCmv/K/xZpwUJfBdAVhEedNO3iyM7R6PVbyTi69G3cN8PReEnyvFteO3ntRcXqNx+IjXKJdXZD9Zr1KIkIxH3oayPc4FgxhtbCS+SsvhESPBgOJ4V9T0mZyCKM2r3DYLP3uujL/lTaltkwGMzd/c6ByxW69oPIQ7aunMZT7XZNn/Bh1XZp5m5MkL72NVxnn6hUrcbvZNCJBIqxw8dtk2cXmPIS4AXUKqK1drk/NAJBzewdXUh",
  "c2b9b042dd57830e7d117dac55ac8ae19407d38e41d88f3215bc3a890444a050":
    "MIIFkjCCA3qgAwIBAgIIAeDltYNno+AwDQYJKoZIhvcNAQEMBQAwZzEbMBkGA1UEAwwSQXBwbGUgUm9vdCBDQSAtIEcyMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcNMTQwNDMwMTgxMDA5WhcNMzkwNDMwMTgxMDA5WjBnMRswGQYDVQQDDBJBcHBsZSBSb290IENBIC0gRzIxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBANgREkhI2imKScUcx+xuM23+TfvgHN6sXuI2pyT5f1BrTM65MFQn5bPW7SXmMLYFN14UIhHF6Kob0vuy0gmVOKTvKkmMXT5xZgM4+xb1hYjkWpIMBDLyyED7Ul+f9sDx47pFoFDVEovy3d6RhiPw9bZyLgHaC/YuOQhfGaFjQQscp5TBhsRTL3b2CtcM0YM/GlMZ81fVJ3/8E7j4ko380yhDPLVoACVdJ2LT3VXdRCCQgzWTxb+4Gftr49wIQuavbfqeQMpOhYV4SbHXw8EwOTKrfl+q04tvny0aIWhwZ7Oj8ZhBbZF8+NfbqOdfIRqMM78xdLe40fTgIvS/cjTf94FNcX1RoeKz8NMoFnNvzcytN31O661A4T+B/fc9Cj6i8b0xlilZ3MIZgIxbdMYs0xBTJh0UT8TUgWY8h2czJxQI6bR3hDRSj4n4aJgXv8O7qhOTH11UL6jHfPsNFL4VPSQ08prcdUFmIrQB1guvkJ4M6mL4m1k8COKWNORj3rw31OsMiANDC1CvoDTdUE0V+1ok2Az6DGOeHwOx4e7hqkP0ZmUoNwIx7wHHHtHMn23KVDpA287PT0aLSmWaasZobNfMmRtHsHLDd4/E92GcdB/O/WuhwpyUgquUoue9G7q5cDmVF8Up8zlYNPXEpMZ7YLlmQ1A/bmH8DvmGqmAMQ0uVAgMBAAGjQjBAMB0GA1UdDgQWBBTEmRNsGAPCe8CjoA1/coB6HHcmjTAPBgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB/wQEAwIBBjANBgkqhkiG9w0BAQwFAAOCAgEAUabz4vS4PZO/Lc4Pu1vhVRROTtHlznldgX/+tvCHM/jvlOV+3Gp5pxy+8JS3ptEwnMgNCnWefZKVfhidfsJxaXwU6s+DDuQUQp50DhDNqxq6EWGBeNjxtUVAeKuowM77fWM3aPbn+6/Gw0vsHzYmE1SGlHKy6gLti23kDKaQwFd1z4xCfVzmMX3zybKSaUYOiPjjLUKyOKimGY3xn83uamW8GrAlvacp/fQ+onVJv57byfenHmOZ4VxG/5IFjPoeIPmGlFYl5bRXOJ3riGQUIUkhOb9iZqmxospvPyFgxYnURTbImHy99v6ZSYA7LNKmp4gDBDEZt7Y6YUX6yfIjyGNzv1aJMbDZfGKnexWoiIqrOEDCzBL/FePwN983csvMmOa/orz6JopxVtfnJBtIRD6e/J/JzBrsQzwBvDR4yGn1xuZW7AYJNpDrFEobXsmII9oDMJELuDY++ee1KG++P+w8j2Ud5cAeh6Squpj9kuNsJnfdBrRkBof0Tta6SqoWqPQFZ2aWuuJVecMsXUmPgEkrihLHdoBR37q9ZV0+N0djMenl9MU/S60EinpxLK8JQzcPqOMyT/RFtm2XNuyE9QoB6he7hY1Ck3DDUOUUi78/w0EP3SIEIwiKum1xRKtzCTrJ+VKACd+66eYWyi4uTLLT3OUEVLLUNIAytbwPF+E=",
  "63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179":
    "MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwSQXBwbGUgUm9vdCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcNMTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2WjBnMRswGQYDVQQDDBJBcHBsZSBSb290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqGSM49AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtfTjjTuxxEtX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK517IDvYuVTZXpmkOlEKMaNCMEAwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySrMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMAoGCCqGSM49BAMDA2gAMGUCMQCD6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3meoyhpmvOwgPUnPWTxnS4at+qIxUCMG1mihDK1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkLF1vLUagM6BgD56KyKA==",
};

function configuredAppleRootCertificates(pinnedRoots: ReadonlySet<string>) {
  return Object.entries(APPLE_ROOT_CA_DER_BASE64)
    .filter(([pin]) => pinnedRoots.has(pin))
    .map(([, encoded]) => new X509Certificate(decodeBase64Bytes(encoded)));
}

function verifiedAppleCertificateChain(
  x5c: string[],
  trustedRoots: X509Certificate[],
) {
  if (x5c.length < 2) throw new Error("invalid_apple_certificate_chain");
  const certificates = x5c.slice(0, 2).map((encoded) =>
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
  const intermediate = certificates[1];
  if (!intermediate.ca) throw new Error("invalid_apple_ca_certificate");
  if (
    certificates[0].issuer !== intermediate.subject ||
    !certificates[0].verify(intermediate.publicKey)
  ) {
    throw new Error("invalid_apple_certificate_chain");
  }
  const root = trustedRoots.find((candidate) =>
    intermediate.issuer === candidate.subject &&
    intermediate.verify(candidate.publicKey)
  );
  if (!root) throw new Error("invalid_apple_certificate_chain");
  const rootValidFrom = Date.parse(root.validFrom);
  const rootValidTo = Date.parse(root.validTo);
  if (
    !Number.isFinite(rootValidFrom) || !Number.isFinite(rootValidTo) ||
    now < rootValidFrom || now > rootValidTo
  ) {
    throw new Error("apple_certificate_expired");
  }
  return [certificates[0], intermediate, root];
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

export type StoreBackendHandlerDependencies = {
  clients?: typeof clients;
  requireIntegrity?: typeof requireMobileIntegrityGrant;
};

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
  const pinnedRoots = new Set(
    env("APPLE_ROOT_CA_SHA256")
      .split(",")
      .map((pin) => pin.trim().toLowerCase().replaceAll(":", ""))
      .filter((pin) => /^[0-9a-f]{64}$/.test(pin)),
  );
  if (pinnedRoots.size === 0) throw new Error("apple_root_pin_missing");
  const trustedRoots = configuredAppleRootCertificates(pinnedRoots);
  if (trustedRoots.length === 0) throw new Error("apple_root_pin_unsupported");
  const certificateChain = verifiedAppleCertificateChain(
    header.x5c,
    trustedRoots,
  );
  // Certificate pins are SHA-256 fingerprints of the raw DER certificate,
  // never of a UTF-8 reinterpretation of its binary bytes.  Hash the exact
  // DER bytes of the separately trusted Apple root, not an optional x5c root.
  const rootDigest = await digestBytes(
    new Uint8Array(certificateChain.at(-1)!.raw),
  );
  if (!pinnedRoots.has(rootDigest)) throw new Error("apple_chain_untrusted");
  const key = await importX509(certificateChain[0].toString(), "ES256");
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

async function authenticatedUser(
  request: Request,
  createClients: typeof clients,
) {
  const authorization = request.headers.get("authorization") ?? "";
  if (!authorization) throw new Error("authentication_required");
  const { auth, admin } = createClients(authorization);
  const { data, error } = await auth.auth.getUser();
  if (error || !data.user) throw new Error("invalid_session");
  return { user: data.user, auth, admin };
}

async function verifyPurchase(
  request: Request,
  body: Record<string, unknown>,
  dependencies: StoreBackendHandlerDependencies,
) {
  const { user, auth, admin } = await authenticatedUser(
    request,
    dependencies.clients ?? clients,
  );
  body = await (dependencies.requireIntegrity ?? requireMobileIntegrityGrant)({
    admin: admin as never,
    ownerId: user.id,
    action: "store.verify_purchase",
    body,
  });
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

async function verifyAiBoost(
  request: Request,
  body: Record<string, unknown>,
  dependencies: StoreBackendHandlerDependencies,
) {
  const { user, auth, admin } = await authenticatedUser(
    request,
    dependencies.clients ?? clients,
  );
  body = await (dependencies.requireIntegrity ?? requireMobileIntegrityGrant)({
    admin: admin as never,
    ownerId: user.id,
    action: "store.verify_ai_boost",
    body,
  });
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

export async function handler(
  request: Request,
  dependencies: StoreBackendHandlerDependencies = {},
): Promise<Response> {
  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }
  let route: "verify_purchase" | "verify_ai_boost" | "unknown" = "unknown";
  try {
    const body = await request.json() as Record<string, unknown>;
    if (body.action === "reconcile") return await reconcile(request);
    if (body.signedPayload) return await verifyAppleNotification(body);
    if (body.message) return await verifyGooglePush(request, body);
    if (body.action === "verify_purchase") {
      route = "verify_purchase";
      return await verifyPurchase(request, body, dependencies);
    }
    if (body.action === "verify_ai_boost") {
      route = "verify_ai_boost";
      return await verifyAiBoost(request, body, dependencies);
    }
    return json({ error: "invalid_action" }, 400);
  } catch (error) {
    const code = error instanceof Error ? error.message : "verification_failed";
    const errorType = error instanceof Error ? error.name : typeof error;
    logStoreVerificationFailure(
      route,
      code,
      errorType,
      safeVerificationErrorCategory(error),
      safeVerificationErrorCode(error),
    );
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
      error instanceof MobileIntegrityFailure
        ? error.status
        : code === "authentication_required" || code === "invalid_session"
        ? 401
        : clientCodes.has(code)
        ? 400
        : 503,
    );
  }
}
