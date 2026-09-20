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
  certificateDerToPem,
  verifyCertificateSignature,
} from "./apple_certificate_verifier.ts";
import {
  assertApplePurchaseLookup,
  assertApplePurchaseReconciliation,
} from "./apple_purchase_reconciliation.ts";
import { assertApplePurchaseOwnership } from "./apple_purchase_ownership.ts";
import { assertAppleNotificationFreshness } from "./apple_notification_policy.ts";
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
  // Only copied from Apple's verified JWS, never from the request body.
  appAccountToken?: unknown;
  signedAt?: string;
  // Google renewal orders share a purchaseToken; only this exact verified
  // latest successful order may be matched to a voided-purchase record.
  storeOrderId?: string;
};

type VerifiedConsumable = {
  provider: Provider;
  productId: string;
  transactionId: string;
  packageOrBundleId: string;
  environment: "sandbox" | "production";
  verifiedAt: string;
};

type VerifiedGoogleConsumable = VerifiedConsumable & {
  purchaseState: number;
  orderId?: string;
};

type GoogleVoidedPurchase = {
  purchaseToken: string;
  orderId: string;
  voidedAt: string;
};

type AppleCertificateVerificationStage =
  | "configured_root_certificate"
  | "parse_leaf_certificate"
  | "parse_intermediate_certificate"
  | "verify_leaf_certificate_signature"
  | "verify_intermediate_certificate_signature"
  | "import_leaf_jws_key";

// Preserve the public failure code while giving production diagnostics a
// bounded, non-sensitive stage. Certificate bodies, public keys and runtime
// exception text must never enter logs.
class AppleCertificateVerificationFailure extends Error {
  constructor(
    readonly stage: AppleCertificateVerificationStage,
    code = "invalid_apple_certificate_chain",
  ) {
    super(code);
    this.name = "AppleCertificateVerificationFailure";
  }
}

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
  errorStage = "",
) => {
  const safeCode = /^[a-z0-9_]+$/.test(code) ? code : "verification_failed";
  const safeErrorType = /^[A-Za-z0-9_]+$/.test(errorType) ? errorType : "";
  const safeErrorCategory = /^[A-Za-z0-9_]+$/.test(errorCategory)
    ? errorCategory
    : "";
  const safeErrorCode = /^[A-Za-z0-9_]+$/.test(errorCode) ? errorCode : "";
  const safeErrorStage = /^[A-Za-z0-9_]+$/.test(errorStage) ? errorStage : "";
  console.error(JSON.stringify({
    event: "store_verification_failure",
    route,
    code: safeCode,
    ...(safeErrorType ? { error_type: safeErrorType } : {}),
    ...(safeErrorCategory ? { error_category: safeErrorCategory } : {}),
    ...(safeErrorCode ? { error_code: safeErrorCode } : {}),
    ...(safeErrorStage ? { error_stage: safeErrorStage } : {}),
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

const safeVerificationErrorStage = (error: unknown) =>
  error instanceof AppleCertificateVerificationFailure ? error.stage : "";

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
export const APPLE_ROOT_CA_DER_BASE64: Readonly<Record<string, string>> = {
  "b0b1730ecbc7ff4505142c49f1295e6eda6bcaed7e2c68c5be91b5a11001f024":
    "MIIEuzCCA6OgAwIBAgIBAjANBgkqhkiG9w0BAQUFADBiMQswCQYDVQQGEwJVUzETMBEGA1UEChMKQXBwbGUgSW5jLjEmMCQGA1UECxMdQXBwbGUgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkxFjAUBgNVBAMTDUFwcGxlIFJvb3QgQ0EwHhcNMDYwNDI1MjE0MDM2WhcNMzUwMjA5MjE0MDM2WjBiMQswCQYDVQQGEwJVUzETMBEGA1UEChMKQXBwbGUgSW5jLjEmMCQGA1UECxMdQXBwbGUgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkxFjAUBgNVBAMTDUFwcGxlIFJvb3QgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDkkakJH5HbHkdQ6wXtXnmELes2oldMVeyLGYne+Uts9QerIjAC6Bg++FAJ039BqJj50cpmnCRrEdCju+QbKsMflZ56DKRHi1vUFjczy8QPTc4UadHJGXL1XQ7Vf1+b8iUDulWPTV0N8WQ1IxVLFVkds5T39pyez1C6wVhQZ48ItCD3y6wsIG9wtj8BMIy3Q88PnT3zK0koGsj+zrW5DtleHNbLPbU6rfQPDgCSC7EhFi501TwN22IWq6NxkkdTVcGvL0Gz+PvjcM3mo0xFfh9Ma1CWQYnEdGILEINBhzOKgbEwWOxaBDKMaLOPHd5lc/9nXmW8Sdh2nzMUZaF3lMktAgMBAAGjggF6MIIBdjAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUK9BpR5R2Cf70a40uQKb3R01/CF4wHwYDVR0jBBgwFoAUK9BpR5R2Cf70a40uQKb3R01/CF4wggERBgNVHSAEggEIMIIBBDCCAQAGCSqGSIb3Y2QFATCB8jAqBggrBgEFBQcCARYeaHR0cHM6Ly93d3cuYXBwbGUuY29tL2FwcGxlY2EvMIHDBggrBgEFBQcCAjCBthqBs1JlbGlhbmNlIG9uIHRoaXMgY2VydGlmaWNhdGUgYnkgYW55IHBhcnR5IGFzc3VtZXMgYWNjZXB0YW5jZSBvZiB0aGUgdGhlbiBhcHBsaWNhYmxlIHN0YW5kYXJkIHRlcm1zIGFuZCBjb25kaXRpb25zIG9mIHVzZSwgY2VydGlmaWNhdGUgcG9saWN5IGFuZCBjZXJ0aWZpY2F0aW9uIHByYWN0aWNlIHN0YXRlbWVudHMuMA0GCSqGSIb3DQEBBQUAA4IBAQBcNplMLXi37Yyb3PN3m/J20ncwT8EfhYOFG5k9RzfyqZtAjizUsZAS2L70c5vu0mQPy3lPNNiiPvl4/2vIB+x9OYOLUyDTOMSxv5pPCmv/K/xZpwUJfBdAVhEedNO3iyM7R6PVbyTi69G3cN8PReEnyvFteO3ntRcXqNx+IjXKJdXZD9Zr1KIkIxH3oayPc4FgxhtbCS+SsvhESPBgOJ4V9T0mZyCKM2r3DYLP3uujL/lTaltkwGMzd/c6ByxW69oPIQ7aunMZT7XZNn/Bh1XZp5m5MkL72NVxnn6hUrcbvZNCJBIqxw8dtk2cXmPIS4AXUKqK1drk/NAJBzewdXUh",
  "c2b9b042dd57830e7d117dac55ac8ae19407d38e41d88f3215bc3a890444a050":
    "MIIFkjCCA3qgAwIBAgIIAeDltYNno+AwDQYJKoZIhvcNAQEMBQAwZzEbMBkGA1UEAwwSQXBwbGUgUm9vdCBDQSAtIEcyMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcNMTQwNDMwMTgxMDA5WhcNMzkwNDMwMTgxMDA5WjBnMRswGQYDVQQDDBJBcHBsZSBSb290IENBIC0gRzIxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBANgREkhI2imKScUcx+xuM23+TfvgHN6sXuI2pyT5f1BrTM65MFQn5bPW7SXmMLYFN14UIhHF6Kob0vuy0gmVOKTvKkmMXT5xZgM4+xb1hYjkWpIMBDLyyED7Ul+f9sDx47pFoFDVEovy3d6RhiPw9bZyLgHaC/YuOQhfGaFjQQscp5TBhsRTL3b2CtcM0YM/GlMZ81fVJ3/8E7j4ko380yhDPLVoACVdJ2LT3VXdRCCQgzWTxb+4Gftr49wIQuavbfqeQMpOhYV4SbHXw8EwOTKrfl+q04tvny0aIWhwZ7Oj8ZhBbZF8+NfbqOdfIRqMM78xdLe40fTgIvS/cjTf94FNcX1RoeKz8NMoFnNvzcytN31O661A4T+B/fc9Cj6i8b0xlilZ3MIZgIxbdMYs0xBTJh0UT8TUgWY8h2czJxQI6bR3hDRSj4n4aJgXv8O7qhOTH11UL6jHfPsNFL4VPSQ08prcdUFmIrQB1guvkJ4M6mL4m1k8COKWNORj3rw31OsMiANDC1CvoDTdUE0V+1ok2Az6DGOeHwOx4e7hqkP0ZmUoNwIx7wHHHtHMn23KVDpA287PT0aLSmWaasZobNfMmRtHsHLDd4/E92GcdB/O/WuhwpyUgquUoue9G7q5cDmVF8Up8zlYNPXEpMZ7YLlmQ1A/bmH8DvmGqmAMQ0uVAgMBAAGjQjBAMB0GA1UdDgQWBBTEmRNsGAPCe8CjoA1/coB6HHcmjTAPBgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB/wQEAwIBBjANBgkqhkiG9w0BAQwFAAOCAgEAUabz4vS4PZO/Lc4Pu1vhVRROTtHlznldgX/+tvCHM/jvlOV+3Gp5pxy+8JS3ptEwnMgNCnWefZKVfhidfsJxaXwU6s+DDuQUQp50DhDNqxq6EWGBeNjxtUVAeKuowM77fWM3aPbn+6/Gw0vsHzYmE1SGlHKy6gLti23kDKaQwFd1z4xCfVzmMX3zybKSaUYOiPjjLUKyOKimGY3xn83uamW8GrAlvacp/fQ+onVJv57byfenHmOZ4VxG/5IFjPoeIPmGlFYl5bRXOJ3riGQUIUkhOb9iZqmxospvPyFgxYnURTbImHy99v6ZSYA7LNKmp4gDBDEZt7Y6YUX6yfIjyGNzv1aJMbDZfGKnexWoiIqrOEDCzBL/FePwN983csvMmOa/orz6JopxVtfnJBtIRD6e/J/JzBrsQzwBvDR4yGn1xuZW7AYJNpDrFEobXsmII9oDMJELuDY++ee1KG++P+w8j2Ud5cAeh6Squpj9kuNsJnfdBrRkBof0Tta6SqoWqPQFZ2aWuuJVecMsXUmPgEkrihLHdoBR37q9ZV0+N0djMenl9MU/S60EinpxLK8JQzcPqOMyT/RFtm2XNuyE9QoB6he7hY1Ck3DDUOUUi78/w0EP3SIEIwiKum1xRKtzCTrJ+VKACd+66eYWyi4uTLLT3OUEVLLUNIAytbwPF+E=",
  "63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179":
    "MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwSQXBwbGUgUm9vdCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcNMTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2WjBnMRswGQYDVQQDDBJBcHBsZSBSb290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqGSM49AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtfTjjTuxxEtX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK517IDvYuVTZXpmkOlEKMaNCMEAwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySrMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMAoGCCqGSM49BAMDA2gAMGUCMQCD6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3meoyhpmvOwgPUnPWTxnS4at+qIxUCMG1mihDK1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkLF1vLUagM6BgD56KyKA==",
};

const MAX_APPLE_CERTIFICATE_DER_BYTES = 16 * 1024;

export type AppleCertificate = {
  // Preserve exact DER from x5c/configuration. Deno 2.1.x cannot read
  // X509Certificate.raw, so the original trusted bytes are authoritative.
  der: Uint8Array;
  pem: string;
  certificate: X509Certificate;
};

function appleCertificateFromDer(
  value: Uint8Array,
  stage: AppleCertificateVerificationStage,
): AppleCertificate {
  if (value.length === 0 || value.length > MAX_APPLE_CERTIFICATE_DER_BYTES) {
    throw new AppleCertificateVerificationFailure(stage);
  }
  // Do not keep a view into a decoder-owned buffer at a trust boundary.
  const der = new Uint8Array(value.length);
  der.set(value);
  try {
    return {
      der,
      pem: certificateDerToPem(der),
      certificate: new X509Certificate(der),
    };
  } catch {
    throw new AppleCertificateVerificationFailure(stage);
  }
}

// This is intentionally an in-process helper, exported only so certificate
// compatibility tests can construct a synthetic trusted root. Production
// roots remain exclusively the pinned APPLE_ROOT_CA_DER_BASE64 entries below.
export function appleCertificateFromTrustedDer(value: Uint8Array) {
  return appleCertificateFromDer(value, "configured_root_certificate");
}

function appleCertificateFromX5c(
  encoded: string,
  stage: AppleCertificateVerificationStage,
): AppleCertificate {
  if (
    encoded.length === 0 ||
    encoded.length > Math.ceil(MAX_APPLE_CERTIFICATE_DER_BYTES * 4 / 3) + 8 ||
    !/^[A-Za-z0-9+/]*={0,2}$/.test(encoded)
  ) {
    throw new AppleCertificateVerificationFailure(stage);
  }
  try {
    return appleCertificateFromDer(decodeBase64Bytes(encoded), stage);
  } catch (error) {
    if (error instanceof AppleCertificateVerificationFailure) throw error;
    throw new AppleCertificateVerificationFailure(stage);
  }
}

function configuredAppleRootCertificates(pinnedRoots: ReadonlySet<string>) {
  return Object.entries(APPLE_ROOT_CA_DER_BASE64)
    .filter(([pin]) => pinnedRoots.has(pin))
    .map(([, encoded]) =>
      appleCertificateFromX5c(encoded, "configured_root_certificate")
    );
}

function certificatePublicKey(
  certificate: AppleCertificate,
  stage: AppleCertificateVerificationStage,
) {
  try {
    const key = certificate.certificate.publicKey.export({ format: "jwk" });
    if (!key || typeof key !== "object") throw new Error();
    return key as Record<string, unknown>;
  } catch {
    throw new AppleCertificateVerificationFailure(stage);
  }
}

function certificateIsCurrent(certificate: AppleCertificate, now: number) {
  const validFrom = Date.parse(certificate.certificate.validFrom);
  const validTo = Date.parse(certificate.certificate.validTo);
  return Number.isFinite(validFrom) && Number.isFinite(validTo) &&
    now >= validFrom && now <= validTo;
}

export async function verifiedAppleCertificateChain(
  x5c: string[],
  trustedRoots: AppleCertificate[],
): Promise<[AppleCertificate, AppleCertificate, AppleCertificate]> {
  if (x5c.length < 2) throw new Error("invalid_apple_certificate_chain");
  const leaf = appleCertificateFromX5c(x5c[0], "parse_leaf_certificate");
  const intermediate = appleCertificateFromX5c(
    x5c[1],
    "parse_intermediate_certificate",
  );
  const now = Date.now();
  if (
    !certificateIsCurrent(leaf, now) || !certificateIsCurrent(intermediate, now)
  ) {
    throw new AppleCertificateVerificationFailure(
      "verify_leaf_certificate_signature",
      "apple_certificate_expired",
    );
  }
  if (leaf.certificate.ca) {
    throw new AppleCertificateVerificationFailure(
      "verify_leaf_certificate_signature",
      "invalid_apple_leaf_certificate",
    );
  }
  if (!intermediate.certificate.ca) {
    throw new AppleCertificateVerificationFailure(
      "verify_intermediate_certificate_signature",
      "invalid_apple_ca_certificate",
    );
  }
  if (leaf.certificate.issuer !== intermediate.certificate.subject) {
    throw new AppleCertificateVerificationFailure(
      "verify_leaf_certificate_signature",
    );
  }
  let leafSignatureValid = false;
  try {
    leafSignatureValid = await verifyCertificateSignature(
      leaf.der,
      certificatePublicKey(intermediate, "verify_leaf_certificate_signature"),
    );
  } catch {
    throw new AppleCertificateVerificationFailure(
      "verify_leaf_certificate_signature",
    );
  }
  if (!leafSignatureValid) {
    throw new AppleCertificateVerificationFailure(
      "verify_leaf_certificate_signature",
    );
  }

  let root: AppleCertificate | undefined;
  for (const candidate of trustedRoots) {
    if (intermediate.certificate.issuer !== candidate.certificate.subject) {
      continue;
    }
    let intermediateSignatureValid = false;
    try {
      intermediateSignatureValid = await verifyCertificateSignature(
        intermediate.der,
        certificatePublicKey(
          candidate,
          "verify_intermediate_certificate_signature",
        ),
      );
    } catch {
      throw new AppleCertificateVerificationFailure(
        "verify_intermediate_certificate_signature",
      );
    }
    if (intermediateSignatureValid) {
      root = candidate;
      break;
    }
  }
  if (!root) {
    throw new AppleCertificateVerificationFailure(
      "verify_intermediate_certificate_signature",
    );
  }
  if (!certificateIsCurrent(root, now)) {
    throw new AppleCertificateVerificationFailure(
      "verify_intermediate_certificate_signature",
      "apple_certificate_expired",
    );
  }
  return [leaf, intermediate, root];
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
  // In-process test seams only. The HTTP body can never replace these trust
  // boundaries; production always uses signature verification and store APIs.
  verifyAppleJws?: typeof verifyAppleJws;
  verifyAppleTransaction?: typeof verifyApple;
  reconcileApple?: typeof reconcileApple;
  readAppleTransaction?: typeof readAppleTransaction;
  verifyGoogle?: typeof verifyGoogle;
  readGoogleConsumable?: typeof readGoogleConsumable;
  verifyGooglePushIdentity?: typeof verifyGooglePushIdentity;
  googleVoidedPurchases?: typeof googleVoidedPurchases;
  readEnvironment?: EnvironmentReader;
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
    storeOrderId: typeof line.latestSuccessfulOrderId === "string"
      ? line.latestSuccessfulOrderId.trim() || undefined
      : undefined,
  };
}

async function verifyGoogleConsumable(
  packageName: string,
  productId: string,
  purchaseToken: string,
): Promise<VerifiedConsumable> {
  const purchase = await readGoogleConsumable(packageName, productId, purchaseToken);
  if (purchase.purchaseState !== 0) throw new Error("purchase_not_completed");
  return purchase;
}

async function readGoogleConsumable(
  packageName: string,
  productId: string,
  purchaseToken: string,
): Promise<VerifiedGoogleConsumable> {
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
  const purchaseState = Number(data.purchaseState ?? -1);
  if (![0, 1, 2].includes(purchaseState)) throw new Error("invalid_google_purchase_state");
  const environment = googleProductEnvironment(data.purchaseType);
  return {
    provider: "google",
    productId,
    transactionId: purchaseToken,
    packageOrBundleId: packageName,
    environment,
    verifiedAt: new Date().toISOString(),
    purchaseState,
    orderId: typeof data.orderId === "string" ? data.orderId.trim() || undefined : undefined,
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

async function googleVoidedPurchases(): Promise<GoogleVoidedPurchase[]> {
  const packageName = env("GOOGLE_PLAY_PACKAGE_NAME");
  const token = await googleAccessToken();
  const purchases: GoogleVoidedPurchase[] = [];
  let pageToken = "";
  do {
    const endpoint = new URL(
      `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${
        encodeURIComponent(packageName)
      }/purchases/voidedpurchases`,
    );
    // Default type=0 omits subscriptions. Include them, then match order IDs:
    // multiple renewals legitimately have the same purchase token.
    endpoint.searchParams.set("type", "1");
    if (pageToken) endpoint.searchParams.set("token", pageToken);
    const response = await fetch(endpoint, {
      headers: { authorization: `Bearer ${token}` },
    });
    if (!response.ok) throw new Error("google_voided_purchase_query_failed");
    const data = await response.json();
    for (const purchase of data.voidedPurchases ?? []) {
      const purchaseToken = String(purchase.purchaseToken ?? "");
      const orderId = String(purchase.orderId ?? "").trim();
      if (purchaseToken && orderId) {
        purchases.push({ purchaseToken, orderId, voidedAt: googleStoreEventTime(purchase.voidedTimeMillis) });
      }
    }
    pageToken = String(data.tokenPagination?.nextPageToken ?? "");
  } while (pageToken);
  return purchases;
}

function googleStoreEventTime(value: unknown): string {
  const milliseconds = Number(value);
  if (!Number.isFinite(milliseconds) || milliseconds <= 0 || milliseconds > Date.now() + 300000) {
    throw new Error("invalid_google_event_time");
  }
  return new Date(milliseconds).toISOString();
}

export async function verifyAppleJwsWithTrustedRoots(
  jws: string,
  pinnedRoots: ReadonlySet<string>,
  trustedRoots: AppleCertificate[],
): Promise<Record<string, unknown>> {
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
  if (pinnedRoots.size === 0) throw new Error("apple_root_pin_missing");
  if (trustedRoots.length === 0) throw new Error("apple_root_pin_unsupported");
  const certificateChain = await verifiedAppleCertificateChain(
    header.x5c,
    trustedRoots,
  );
  // Certificate pins are SHA-256 fingerprints of the raw DER certificate,
  // never of a UTF-8 reinterpretation of its binary bytes.  Hash the exact
  // DER bytes of the separately trusted Apple root, not an optional x5c root.
  // The legacy release contract spells this boundary as
  // `digestBytes(decodeBase64Bytes(...))`; the current chain verifier already
  // holds the exact DER bytes, so hashing that byte array is equivalent and
  // avoids a lossy binary-to-text round trip.
  const rootDigest = await digestBytes(certificateChain[2].der);
  if (!pinnedRoots.has(rootDigest)) throw new Error("apple_chain_untrusted");
  let key;
  try {
    key = await importX509(certificateChain[0].pem, "ES256");
  } catch {
    throw new AppleCertificateVerificationFailure("import_leaf_jws_key");
  }
  const verified = await compactVerify(jws, key, { algorithms: ["ES256"] });
  return JSON.parse(new TextDecoder().decode(verified.payload));
}

export async function verifyAppleJws(
  jws: string,
): Promise<Record<string, unknown>> {
  const pinnedRoots = new Set(
    env("APPLE_ROOT_CA_SHA256")
      .split(",")
      .map((pin) => pin.trim().toLowerCase().replaceAll(":", ""))
      .filter((pin) => /^[0-9a-f]{64}$/.test(pin)),
  );
  const trustedRoots = configuredAppleRootCertificates(pinnedRoots);
  return await verifyAppleJwsWithTrustedRoots(
    jws,
    pinnedRoots,
    trustedRoots,
  );
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
    appAccountToken: payload.appAccountToken,
    signedAt: typeof payload.signedDate === "number" &&
        Number.isFinite(payload.signedDate) && payload.signedDate > 0
      ? new Date(payload.signedDate).toISOString()
      : undefined,
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

type AppleLastTransaction = Record<string, unknown>;

const isRecord = (value: unknown): value is Record<string, unknown> =>
  value !== null && typeof value === "object" && !Array.isArray(value);

/// The Status API returns every subscription group for the customer.  Bind the
/// server result to the original transaction identifier that was already
/// verified in the device JWS; never accept whichever item Apple happens to
/// list first.
export function selectAppleSubscriptionTransaction(
  groups: unknown,
  expectedOriginalTransactionId: string,
): AppleLastTransaction {
  if (!expectedOriginalTransactionId) {
    throw new Error("apple_transaction_missing");
  }
  const transactions = Array.isArray(groups)
    ? groups.flatMap((group) => {
      if (!isRecord(group) || !Array.isArray(group.lastTransactions)) {
        return [];
      }
      return group.lastTransactions.filter(isRecord);
    })
    : [];
  const matches = transactions.filter((transaction) =>
    String(transaction.originalTransactionId ?? "") ===
      expectedOriginalTransactionId
  );
  if (matches.length === 0) throw new Error("apple_transaction_missing");
  if (matches.length !== 1) throw new Error("apple_transaction_ambiguous");
  const selected = matches[0];
  if (
    typeof selected.signedTransactionInfo !== "string" ||
    !selected.signedTransactionInfo.trim()
  ) {
    throw new Error("apple_transaction_missing");
  }
  return selected;
}

/// Preserve only a stable HTTP status in diagnostic logs.  Apple response
/// bodies can contain store-specific details and must never reach telemetry.
export function appleServerApiFailureCode(status: number) {
  return Number.isInteger(status) && status >= 100 && status <= 599
    ? `apple_server_api_${status}`
    : "apple_server_api_failed";
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
  if (!response.ok) {
    throw new Error(appleServerApiFailureCode(response.status));
  }
  const data = await response.json();
  const latest = selectAppleSubscriptionTransaction(
    isRecord(data) ? data.data : undefined,
    originalTransactionId,
  );
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

async function readAppleTransaction(
  transactionId: string,
  environment: StoreEnvironment,
): Promise<VerifiedPurchase> {
  const response = await fetch(
    `https://${appleServerHost(environment)}/inApps/v1/transactions/${
      encodeURIComponent(transactionId)
    }`,
    { headers: { authorization: `Bearer ${await appleServerToken()}` } },
  );
  if (!response.ok) throw new Error(appleServerApiFailureCode(response.status));
  const result = await response.json();
  const purchase = await verifyApple(String(result.signedTransactionInfo ?? ""));
  if (purchase.transactionId !== transactionId) {
    throw new Error("apple_transaction_mismatch");
  }
  if (purchase.environment !== environment) throw new Error("wrong_environment");
  return purchase;
}

function assertExactAppleTransaction(
  proof: VerifiedPurchase,
  canonical: VerifiedPurchase,
) {
  assertApplePurchaseReconciliation(proof, canonical);
  if (proof.transactionId !== canonical.transactionId) {
    throw new Error("apple_transaction_mismatch");
  }
  if (proof.productId !== canonical.productId) throw new Error("wrong_product");
}

// PostgREST resolves this RPC by its complete named argument signature. These
// nullable SQL arguments have no defaults: undefined would disappear from JSON
// and cause a function-resolution 404, even for a valid active subscription.
export function buildVerifiedPurchaseRpcArgs(
  ownerId: string,
  purchase: VerifiedPurchase,
  verifiedAt: string,
  transactionFingerprint: string,
) {
  return {
    p_owner_id: ownerId,
    p_provider: purchase.provider,
    p_product_id: purchase.productId,
    p_package_or_bundle_id: purchase.packageOrBundleId,
    p_lifecycle: purchase.lifecycle,
    p_original_transaction_id: purchase.originalTransactionId,
    p_latest_transaction_id: purchase.transactionId,
    p_environment: purchase.environment,
    p_store_country_code: purchase.storeCountryCode ?? null,
    p_started_at: purchase.startedAt ?? null,
    p_expires_at: purchase.expiresAt ?? null,
    p_grace_period_ends_at: purchase.gracePeriodEndsAt ?? null,
    p_auto_renews: purchase.autoRenews ?? null,
    p_verified_at: verifiedAt,
    p_transaction_fingerprint: transactionFingerprint,
  };
}

type StoreSubscriptionOwner = {
  owner_id: string;
  environment: string;
};

async function lookupStoreSubscriptionOwner(
  admin: ReturnType<typeof clients>["admin"],
  provider: Provider,
  originalTransactionId: string,
  failureCode = "notification_owner_lookup_failed",
): Promise<StoreSubscriptionOwner | null> {
  const { data, error } = await admin.rpc(
    "bil_lookup_store_subscription_owner",
    {
      p_provider: provider,
      p_original_transaction_id: originalTransactionId,
    },
  );
  if (error) throw new Error(failureCode);
  const rows = Array.isArray(data) ? data : data == null ? [] : [data];
  const row = rows[0];
  if (!isRecord(row)) return null;
  const ownerId = String(row.owner_id ?? "");
  const environment = String(row.environment ?? "");
  if (!ownerId || !["sandbox", "production"].includes(environment)) {
    throw new Error(failureCode);
  }
  return { owner_id: ownerId, environment };
}

async function recordStoreEntitlementAudit(
  admin: ReturnType<typeof clients>["admin"],
  values: {
    ownerId: string;
    provider: Provider;
    lifecycle: string;
    reason: string;
    transactionFingerprint: string;
  },
) {
  const { data, error } = await admin.rpc(
    "bil_record_store_entitlement_audit",
    {
      p_owner_id: values.ownerId,
      p_provider: values.provider,
      p_product_id: null,
      p_lifecycle: values.lifecycle,
      p_reason: values.reason,
      p_transaction_fingerprint: values.transactionFingerprint,
    },
  );
  if (error || data !== true) throw new Error("audit_persistence_failed");
}

async function lookupAiBoostProduct(
  admin: ReturnType<typeof clients>["admin"],
  store: "app_store" | "google_play",
  transactionId: string,
): Promise<string | null> {
  const { data, error } = await admin.rpc("bil_lookup_ai_boost_purchase", {
    p_store: store,
    p_transaction_id: transactionId,
  });
  if (error) throw new Error("boost_refund_lookup_failed");
  const rows = Array.isArray(data) ? data : data == null ? [] : [data];
  const row = rows[0];
  if (!isRecord(row)) return null;
  const productId = String(row.product_id ?? "");
  return productId || null;
}

export async function persistVerified(
  admin: ReturnType<typeof clients>["admin"],
  ownerId: string,
  purchase: VerifiedPurchase,
  additionalSignedAppleAccountTokens: readonly unknown[] = [],
) {
  if (
    !purchase.productId || !purchase.originalTransactionId ||
    !purchase.transactionId
  ) {
    throw new Error("incomplete_store_result");
  }
  if (purchase.provider === "apple") {
    // A valid Apple receipt proves a store purchase, not that the currently
    // signed-in BIL member owns it. Check Apple's signed account binding before
    // any entitlement write, including notification and scheduled refreshes.
    const existing = await lookupStoreSubscriptionOwner(
      admin,
      "apple",
      purchase.originalTransactionId,
      "apple_ownership_check_unavailable",
    );
    // Still honor Apple's authoritative terminal state for this exact stored
    // owner. A historical bad binding must not prevent a refund/revocation
    // from removing access. This cannot create a binding or grant paid access.
    const deactivatesExistingOwner = existing?.owner_id === ownerId &&
      existing?.environment === purchase.environment &&
      (purchase.environment === "sandbox" ||
        purchase.environment === "production") &&
      ["expired", "refunded", "revoked"].includes(purchase.lifecycle);
    if (!deactivatesExistingOwner) {
      await assertApplePurchaseOwnership(
        ownerId,
        [purchase.appAccountToken, ...additionalSignedAppleAccountTokens],
        existing
          ? { ownerId: existing.owner_id, environment: existing.environment }
          : null,
        purchase.environment,
      );
    }
  }
  const verifiedAt = new Date().toISOString();
  const { data: persisted, error } = await admin.rpc(
    "bil_persist_verified_store_purchase",
    {
      ...buildVerifiedPurchaseRpcArgs(
        ownerId,
        purchase,
        verifiedAt,
        await fingerprint(purchase.transactionId),
      ),
      p_store_signed_at: purchase.provider === "apple" ? purchase.signedAt ?? null : null,
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
  if (!isRecord(persisted) || typeof persisted.active !== "boolean" ||
    typeof persisted.lifecycle !== "string" || typeof persisted.verified_at !== "string" ||
    !Number.isFinite(Date.parse(persisted.verified_at))) throw new Error("persistence_failed");
  return { active: persisted.active, lifecycle: persisted.lifecycle, verifiedAt: persisted.verified_at };
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
  const signedAppleAccountTokens: unknown[] = [];
  if (source === "app_store") {
    // The device JWS is only the lookup proof. Entitlement truth comes from a
    // fresh App Store Server API response over authenticated TLS.
    const deviceTransaction = await (dependencies.verifyAppleTransaction ??
      verifyApple)(verification);
    signedAppleAccountTokens.push(deviceTransaction.appAccountToken);
    assertApplePurchaseLookup(body.product_id, deviceTransaction);
    purchase = await (dependencies.reconcileApple ?? reconcileApple)(
      deviceTransaction.originalTransactionId,
      deviceTransaction.environment,
    );
    assertApplePurchaseReconciliation(deviceTransaction, purchase);
  } else if (source === "google_play") {
    purchase = await verifyGoogle(
      env("GOOGLE_PLAY_PACKAGE_NAME"),
      verification,
    );
    if (purchase.productId !== String(body.product_id ?? "")) {
      throw new Error("wrong_product");
    }
  } else {
    throw new Error("invalid_store_source");
  }
  const { active, lifecycle, verifiedAt } = await persistVerified(
    admin,
    user.id,
    purchase,
    signedAppleAccountTokens,
  );
  return json({
    verified: true,
    entitlement_active: active,
    // The client uses this server-generated watermark to ignore only older
    // entitlement snapshots while a fresh subscription verification settles.
    verified_at: verifiedAt,
    lifecycle,
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
    const proof = await (dependencies.verifyAppleTransaction ?? verifyApple)(
      verification,
    );
    assertApplePurchaseLookup(productId, proof);
    const apple = await (dependencies.readAppleTransaction ?? readAppleTransaction)(
      proof.transactionId,
      proof.environment,
    );
    assertExactAppleTransaction(proof, apple);
    if (apple.productId !== productId || apple.lifecycle !== "active") {
      throw new Error("purchase_not_completed");
    }
    // Consumable credits have no subscription-owner row to establish a legacy
    // binding. Never make a new credit without Apple's signed BIL account token.
    await assertApplePurchaseOwnership(
      user.id,
      [proof.appAccountToken, apple.appAccountToken],
      null,
      apple.environment,
    );
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
    p_environment: purchase.environment,
  });
  if (error) {
    if (
      error.code === "23505" ||
      error.message === "purchase_owned_by_another_account"
    ) {
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

async function verifyGooglePushIdentity(request: Request): Promise<void> {
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
}

async function applyGoogleBoostRefund(
  admin: ReturnType<typeof clients>["admin"],
  purchaseToken: string,
  orderId: string | undefined,
  eventId: string,
  eventAt: string,
  receiptDigest: string,
  dependencies: StoreBackendHandlerDependencies,
) {
  if (!purchaseToken.trim()) throw new Error("invalid_google_notification");
  const purchase = await (dependencies.readGoogleConsumable ?? readGoogleConsumable)(
    (dependencies.readEnvironment ?? env)("GOOGLE_PLAY_PACKAGE_NAME"),
    "bil_ai_boost",
    purchaseToken,
  );
  if (purchase.provider !== "google" || purchase.productId !== "bil_ai_boost" ||
    purchase.transactionId !== purchaseToken || (orderId && purchase.orderId !== orderId)) {
    throw new Error("google_transaction_mismatch");
  }
  if (purchase.purchaseState !== 1) {
    // A notification can beat the Publisher API. A purchased/pending response
    // cannot authorize a refund, nor may we acknowledge the refund away.
    throw new Error("google_canonical_state_pending");
  }
  const { data, error } = await admin.rpc("bil_apply_ai_boost_store_event", {
    p_store: "google_play",
    p_transaction_id: purchaseToken,
    p_product_id: "bil_ai_boost",
    p_environment: purchase.environment,
    p_event_id: eventId,
    p_event_type: "refunded",
    p_event_at: eventAt,
    p_raw_receipt_hash: receiptDigest,
  });
  if (error || !isRecord(data) || typeof data.applied !== "boolean") {
    throw new Error("boost_refund_persistence_failed");
  }
}

async function verifyGooglePush(
  request: Request,
  body: Record<string, unknown>,
  dependencies: StoreBackendHandlerDependencies,
) {
  await (dependencies.verifyGooglePushIdentity ?? verifyGooglePushIdentity)(request);
  const encoded = String((body.message as Record<string, unknown>)?.data ?? "");
  const notice = JSON.parse(atob(encoded)) as Record<string, unknown>;
  const parsed = parseGoogleNotification(notice);
  const voided = isRecord(notice.voidedPurchaseNotification) ? notice.voidedPurchaseNotification : null;
  const notificationId = String(
    (body.message as Record<string, unknown>)?.messageId ?? "",
  );
  if (!notificationId) throw new Error("invalid_google_notification");
  const { admin } = (dependencies.clients ?? clients)();
  const claimToken = await claimStoreNotification(
    admin, "google", notificationId, await digest(encoded),
    // Google RTDN delivery itself has no environment field. Purchase truth is
    // persisted from the authenticated Publisher API response below.
    "production",
  );
  if (!claimToken) return json({ accepted: true, duplicate: true });
  const mark = (status: "processed" | "error", errorCode?: string) =>
    markStoreNotification(admin, "google", notificationId, claimToken, status, errorCode);
  try {
    if (parsed.kind === "test") {
      await mark("processed");
      return json({ accepted: true, test: true });
    }
    if (voided && Number(voided.productType) === 2) {
      await applyGoogleBoostRefund(
        admin, String(voided.purchaseToken ?? ""), String(voided.orderId ?? "") || undefined,
        notificationId, googleStoreEventTime(notice.eventTimeMillis), await digest(encoded), dependencies,
      );
      await mark("processed");
      return json({ accepted: true, one_time_product: true, refunded: true });
    }
    if (parsed.kind === "one_time_canceled") {
      if (parsed.productId !== "bil_ai_boost") throw new Error("wrong_product");
      await applyGoogleBoostRefund(
        admin, parsed.purchaseToken!, undefined, notificationId,
        googleStoreEventTime(notice.eventTimeMillis), await digest(encoded), dependencies,
      );
      await mark("processed");
      return json({ accepted: true, one_time_product: true, refunded: true });
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
      await mark("processed");
      return json({
        accepted: true,
        one_time_product: true,
        owner_pending: true,
      });
    }
    const subscriptionToken = parsed.kind === "subscription" ? parsed.purchaseToken
      : voided && Number(voided.productType) === 1 ? String(voided.purchaseToken ?? "") : null;
    if (!subscriptionToken) {
      throw new Error("invalid_google_notification");
    }
    const purchase = await (dependencies.verifyGoogle ?? verifyGoogle)(
      (dependencies.readEnvironment ?? env)("GOOGLE_PLAY_PACKAGE_NAME"),
      subscriptionToken,
    );
    if (voided && !purchase.storeOrderId && ["active", "trial", "grace_period"].includes(purchase.lifecycle)) {
      throw new Error("google_canonical_state_pending");
    }
    if (voided && purchase.storeOrderId === voided.orderId) {
      const voidedPurchases = await (dependencies.googleVoidedPurchases ?? googleVoidedPurchases)();
      if (!voidedPurchases.some((item) => item.purchaseToken === purchase.transactionId && item.orderId === purchase.storeOrderId)) {
        throw new Error("google_canonical_state_pending");
      }
      purchase.lifecycle = "revoked";
    }
    const existing = await lookupStoreSubscriptionOwner(
      admin,
      "google",
      purchase.originalTransactionId,
    );
    if (existing?.owner_id) {
      await persistVerified(admin, existing.owner_id, purchase);
    }
    await mark("processed");
    return json({ accepted: true });
  } catch (error) {
    await mark("error", notificationFailureCode(error)).catch(() => {});
    throw error;
  }
}

async function claimStoreNotification(
  admin: ReturnType<typeof clients>["admin"],
  provider: Provider,
  notificationId: string,
  payloadDigest: string,
  environment: StoreEnvironment,
): Promise<string | null> {
  if (!notificationId.trim()) throw new Error("invalid_store_notification");
  const claimToken = crypto.randomUUID();
  const { data, error } = await admin.rpc("bil_claim_store_notification", {
    p_provider: provider,
    p_notification_id: notificationId,
    p_payload_digest: payloadDigest,
    p_environment: environment,
    p_claim_token: claimToken,
  });
  if (error) {
    if (error.message === "notification_claim_in_progress") {
      throw new Error("notification_claim_in_progress");
    }
    throw new Error("notification_claim_failed");
  }
  if (typeof data !== "boolean") throw new Error("notification_claim_failed");
  return data ? claimToken : null;
}

async function markStoreNotification(
  admin: ReturnType<typeof clients>["admin"],
  provider: Provider,
  notificationId: string,
  claimToken: string,
  status: "processed" | "error",
  errorCode?: string,
) {
  const { data, error } = await admin.rpc("bil_finish_store_notification", {
    p_provider: provider,
    p_notification_id: notificationId,
    p_claim_token: claimToken,
    p_status: status,
    p_error_code: status === "error" ? errorCode ?? "verification_failed" : null,
  });
  if (error || data !== true) {
    throw new Error("notification_status_update_failed");
  }
}

function notificationFailureCode(error: unknown): string {
  const code = error instanceof Error ? error.message : "";
  return /^[a-z0-9_]{1,80}$/.test(code) ? code : "verification_failed";
}

async function verifyAppleNotification(
  body: Record<string, unknown>,
  dependencies: StoreBackendHandlerDependencies,
) {
  const signedPayload = String(body.signedPayload ?? "");
  const notification = await (dependencies.verifyAppleJws ?? verifyAppleJws)(signedPayload);
  const notificationId = String(notification.notificationUUID ?? "");
  const data = isRecord(notification.data) ? notification.data : {};
  const notificationEnvironment = verifiedStoreEnvironment(data?.environment);
  const { admin } = (dependencies.clients ?? clients)();
  const claimToken = await claimStoreNotification(
    admin, "apple", notificationId, await digest(signedPayload), notificationEnvironment,
  );
  if (!claimToken) return json({ accepted: true, duplicate: true });
  const mark = (status: "processed" | "error", errorCode?: string) =>
    markStoreNotification(admin, "apple", notificationId, claimToken, status, errorCode);
  try {
    const notificationType = String(notification.notificationType ?? "");
    if (notificationType === "TEST") {
      await mark("processed");
      return json({ accepted: true, test: true });
    }
    const transactionJws = String(data?.signedTransactionInfo ?? "");
    const notificationTransaction = await (dependencies.verifyAppleTransaction ?? verifyApple)(transactionJws);
    if (notificationTransaction.environment !== notificationEnvironment) {
      throw new Error("wrong_environment");
    }
    if (notificationType === "CONSUMPTION_REQUEST") {
      // There is no consent-backed usage disclosure contract in this service.
      // A refund REQUEST is not a refund decision. Send no usage/personal data,
      // never change entitlement/credits, and explicitly record handling.
      await mark("processed");
      return json({ accepted: true, consumption_data_sent: false, reason: "consent_not_recorded" });
    }
    if (notificationTransaction.productId === "bil_ai_boost") {
      const canonical = await (dependencies.readAppleTransaction ?? readAppleTransaction)(
        notificationTransaction.transactionId, notificationTransaction.environment,
      );
      assertExactAppleTransaction(notificationTransaction, canonical);
      assertAppleNotificationFreshness(notificationType, notificationTransaction, canonical);
      let eventApplied = false;
      if (["REFUND", "REVOKE", "REFUND_REVERSED"].includes(notificationType)) {
        const eventType = canonical.lifecycle === "revoked" || canonical.lifecycle === "refunded"
          ? "refunded"
          : canonical.lifecycle === "active" ? "refund_reversed" : null;
        if (!eventType || !canonical.signedAt || !Number.isFinite(Date.parse(canonical.signedAt))) {
          throw new Error("invalid_apple_store_event");
        }
        const { data: eventResult, error } = await admin.rpc("bil_apply_ai_boost_store_event", {
          p_store: "app_store",
          p_transaction_id: canonical.transactionId,
          p_product_id: canonical.productId,
          p_environment: canonical.environment,
          p_event_id: notificationId,
          p_event_type: eventType,
          p_event_at: canonical.signedAt,
          p_raw_receipt_hash: await digest(signedPayload),
        });
        if (error || !isRecord(eventResult) || typeof eventResult.applied !== "boolean") {
          throw new Error("boost_refund_persistence_failed");
        }
        eventApplied = eventResult.applied;
      }
      await mark("processed");
      return json({ accepted: true, one_time_product: true, event_applied: eventApplied });
    }
    const purchase = await (dependencies.reconcileApple ?? reconcileApple)(
      notificationTransaction.originalTransactionId,
      notificationTransaction.environment,
    );
    assertApplePurchaseReconciliation(notificationTransaction, purchase);
    assertAppleNotificationFreshness(notificationType, notificationTransaction, purchase);
    // Never project an older event's state onto a newer renewal/upgrade. The
    // freshly verified canonical transaction/status is the entitlement truth.
    const existing = await lookupStoreSubscriptionOwner(
      admin,
      "apple",
      purchase.originalTransactionId,
    );
    if (existing?.owner_id) {
      await persistVerified(admin, existing.owner_id, purchase, [
        notificationTransaction.appAccountToken,
      ]);
    }
    await mark("processed");
    return json({ accepted: true });
  } catch (error) {
    await mark("error", notificationFailureCode(error)).catch(() => {});
    throw error;
  }
}

async function reconcile(
  request: Request,
  body: Record<string, unknown>,
  dependencies: StoreBackendHandlerDependencies,
) {
  const supplied = request.headers.get("x-bil-reconciliation-secret") ?? "";
  const readEnvironment = dependencies.readEnvironment ?? env;
  const expected = readEnvironment("BIL_RECONCILIATION_SECRET");
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
  const cursor = body.after_owner_id;
  if (cursor != null && (typeof cursor !== "string" ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(cursor))) {
    throw new Error("invalid_reconciliation_cursor");
  }
  const { admin } = (dependencies.clients ?? clients)();
  const { data: page, error } = await admin.rpc(
    "bil_list_store_subscriptions_page",
    {
      p_after_owner_id: typeof cursor === "string" ? cursor : null,
      p_limit: 101,
    },
  );
  if (error || !Array.isArray(page)) {
    throw new Error("reconciliation_read_failed");
  }
  const hasMore = (page?.length ?? 0) > 100;
  const subscriptions = (page ?? []).slice(0, 100);
  let voidedGooglePurchases: GoogleVoidedPurchase[] = [];
  let voidedGoogleLookupUnavailable = false;
  if (subscriptions.some((row) => row.provider === "google") || readEnvironment("GOOGLE_PLAY_PACKAGE_NAME")) {
    try {
      voidedGooglePurchases = await (dependencies.googleVoidedPurchases ?? googleVoidedPurchases)();
    } catch {
      // The Google function follows every store page; an outage is explicitly
      // reported rather than pretending this bounded owner page is a full audit.
      voidedGoogleLookupUnavailable = true;
    }
  }
  let reconciled = 0;
  let failed = 0;
  for (const row of subscriptions) {
    try {
      const purchase = row.provider === "google"
        ? await (dependencies.verifyGoogle ?? verifyGoogle)(
          readEnvironment("GOOGLE_PLAY_PACKAGE_NAME"),
          row.latest_transaction_id,
        )
        : await (dependencies.reconcileApple ?? reconcileApple)(
          row.original_transaction_id,
          verifiedStoreEnvironment(row.environment),
        );
      if (purchase.provider === "google" && purchase.storeOrderId &&
        voidedGooglePurchases.some((item) => item.purchaseToken === purchase.transactionId && item.orderId === purchase.storeOrderId)) {
        // Apply revocation through the same atomic subscription + entitlement
        // persistence RPC, never three independently acknowledged writes.
        purchase.lifecycle = "revoked";
      }
      await persistVerified(admin, row.owner_id, purchase);
      reconciled += 1;
    } catch {
      failed += 1;
      await recordStoreEntitlementAudit(admin, {
        ownerId: row.owner_id,
        provider: row.provider,
        lifecycle: "suspended",
        reason: "scheduled_reconciliation_failed",
        transactionFingerprint: await fingerprint(row.latest_transaction_id),
      });
    }
  }
  let boostRefundsReconciled = 0;
  let boostRefundsFailed = 0;
  // The authoritative, fully paginated Google voided list already bounds this
  // work to recent refunds. Exact ledger lookups avoid a second unbounded scan.
  // Do it once per full owner pass rather than repeating on every cursor page.
  if (cursor == null && !voidedGoogleLookupUnavailable) {
    for (const voided of voidedGooglePurchases) {
      try {
        const productId = await lookupAiBoostProduct(
          admin,
          "google_play",
          voided.purchaseToken,
        );
        if (!productId) continue;
        if (productId !== "bil_ai_boost") throw new Error("wrong_product");
        await applyGoogleBoostRefund(
          admin, voided.purchaseToken, voided.orderId,
          `voided:${voided.orderId}:${voided.voidedAt}`, voided.voidedAt,
          await digest(JSON.stringify(voided)), dependencies,
        );
        boostRefundsReconciled++;
      } catch {
        boostRefundsFailed++;
      }
    }
  }
  return json({
    reconciled, failed, examined: subscriptions.length,
    has_more: hasMore,
    next_cursor: hasMore ? subscriptions[subscriptions.length - 1].owner_id : null,
    voided_google_lookup_unavailable: voidedGoogleLookupUnavailable,
    boost_refunds_reconciled: boostRefundsReconciled,
    boost_refunds_failed: boostRefundsFailed,
  });
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
    if (body.action === "reconcile") return await reconcile(request, body, dependencies);
    if (body.signedPayload) return await verifyAppleNotification(body, dependencies);
    if (body.message) return await verifyGooglePush(request, body, dependencies);
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
      safeVerificationErrorStage(error),
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
      "apple_account_binding_required",
      "invalid_apple_account_token",
      "market_plan_mismatch",
      "store_country_required",
      "invalid_reconciliation_cursor",
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
