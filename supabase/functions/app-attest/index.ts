// Assertion interoperability fix: assertion-compat-v2.
// Corrects AT-flag handling and verifies the App Attest nonce signature.
// Keeps cert-runtime-v1, authdata-compat-v1, and the existing legacy policy.
// App Attest authenticator-format compatibility: authdata-compat-v1.
// Cumulative: retains cert-runtime-v1 and all signature, nonce, identity,
// environment, challenge, replay, authentication, quota and grant checks.
// IMPORTANT POLICY CHANGE (explicit opt-in): BIL_APP_ATTEST_ALLOW_LEGACY=true
// permits cryptographically valid legacy attestations with no extension map.
// Such attestations DO NOT prove a bundle version / launch category. Store the
// literal marker "legacy-unreported", never a guessed or client-supplied version.
// Extended attestations still require an allowed version and app category.
// Certificate runtime compatibility patch: cert-runtime-v1.
// Preserve every existing trust check; only replace an unsupported primitive.
import { p256, p384, p521 } from "npm:@noble/curves@1.9.7/nist.js";
import { createClient } from "npm:@supabase/supabase-js@2.112.3";
import {
  createPublicKey,
  verify as verifySignature,
  X509Certificate,
} from "node:crypto";

type JsonObject = Record<string, unknown>;
type CborValue =
  | null
  | boolean
  | number
  | string
  | Uint8Array
  | CborValue[]
  | Map<CborValue, CborValue>;

const APPLE_APP_ATTEST_ROOT = `-----BEGIN CERTIFICATE-----
MIICITCCAaegAwIBAgIQC/O+DvHN0uD7jG5yH2IXmDAKBggqhkjOPQQDAzBSMSYw
JAYDVQQDDB1BcHBsZSBBcHAgQXR0ZXN0YXRpb24gUm9vdCBDQTETMBEGA1UECgwK
QXBwbGUgSW5jLjETMBEGA1UECAwKQ2FsaWZvcm5pYTAeFw0yMDAzMTgxODMyNTNa
Fw00NTAzMTUwMDAwMDBaMFIxJjAkBgNVBAMMHUFwcGxlIEFwcCBBdHRlc3RhdGlv
biBSb290IENBMRMwEQYDVQQKDApBcHBsZSBJbmMuMRMwEQYDVQQIDApDYWxpZm9y
bmlhMHYwEAYHKoZIzj0CAQYFK4EEACIDYgAERTHhmLW07ATaFQIEVwTtT4dyctdh
NbJhFs/Ii2FdCgAHGbpphY3+d8qjuDngIN3WVhQUBHAoMeQ/cLiP1sOUtgjqK9au
Yen1mMEvRq9Sk3Jm5X8U62H+xTD3FE9TgS41o0IwQDAPBgNVHRMBAf8EBTADAQH/
MB0GA1UdDgQWBBSskRBTM72+aEH/pwyp5frq5eWKoTAOBgNVHQ8BAf8EBAMCAQYw
CgYIKoZIzj0EAwMDaAAwZQIwQgFGnByvsiVbpTKwSga0kP0e8EeDS4+sQmTvb7vn
53O5+FRXgeLhpJ06ysC5PrOyAjEAp5U4xDgEgllF7En3VcE3iexZZtKeYnpqtijV
oyFraWVIyd/dganmrduC1bmTBGwD
-----END CERTIFICATE-----`;

const encoder = new TextEncoder();
const decoder = new TextDecoder("utf-8", { fatal: true });
const env = (name: string) => Deno.env.get(name)?.trim() ?? "";
const text = (value: unknown) => typeof value === "string" ? value.trim() : "";
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json",
      "cache-control": "no-store",
    },
  });

class AppAttestFailure extends Error {
  constructor(readonly code: string, readonly status = 403) {
    super(code);
  }
}

class CborDecoder {
  position: number;

  constructor(readonly bytes: Uint8Array, offset = 0) {
    this.position = offset;
  }

  read(depth = 0): CborValue {
    if (depth > 24 || this.position >= this.bytes.length) {
      throw new AppAttestFailure("invalid_cbor", 400);
    }
    const initial = this.bytes[this.position++];
    const major = initial >>> 5;
    const additional = initial & 0x1f;
    const length = this.readLength(additional);

    if (major === 0) return length;
    if (major === 1) return -1 - length;
    if (major === 2) return this.readBytes(length);
    if (major === 3) {
      try {
        return decoder.decode(this.readBytes(length));
      } catch {
        throw new AppAttestFailure("invalid_cbor", 400);
      }
    }
    if (major === 4) {
      if (length > 64) throw new AppAttestFailure("invalid_cbor", 400);
      return Array.from({ length }, () => this.read(depth + 1));
    }
    if (major === 5) {
      if (length > 64) throw new AppAttestFailure("invalid_cbor", 400);
      const result = new Map<CborValue, CborValue>();
      for (let index = 0; index < length; index += 1) {
        const key = this.read(depth + 1);
        if (result.has(key)) {
          throw new AppAttestFailure("duplicate_cbor_key", 400);
        }
        result.set(key, this.read(depth + 1));
      }
      return result;
    }
    if (major === 7 && additional === 20) return false;
    if (major === 7 && additional === 21) return true;
    if (major === 7 && additional === 22) return null;
    throw new AppAttestFailure("unsupported_cbor", 400);
  }

  private readLength(additional: number): number {
    if (additional < 24) return additional;
    if (additional === 24) return this.readUnsigned(1);
    if (additional === 25) return this.readUnsigned(2);
    if (additional === 26) return this.readUnsigned(4);
    if (additional === 27) {
      const high = this.readUnsigned(4);
      const low = this.readUnsigned(4);
      const value = high * 0x1_0000_0000 + low;
      if (!Number.isSafeInteger(value)) {
        throw new AppAttestFailure("invalid_cbor", 400);
      }
      return value;
    }
    // Indefinite-length objects are unnecessary here and create parser
    // ambiguity at a security boundary.
    throw new AppAttestFailure("invalid_cbor", 400);
  }

  private readUnsigned(length: number): number {
    if (this.position + length > this.bytes.length) {
      throw new AppAttestFailure("invalid_cbor", 400);
    }
    let value = 0;
    for (let index = 0; index < length; index += 1) {
      value = value * 256 + this.bytes[this.position++];
    }
    return value;
  }

  private readBytes(length: number): Uint8Array {
    if (length > 300_000 || this.position + length > this.bytes.length) {
      throw new AppAttestFailure("invalid_cbor", 400);
    }
    const value = this.bytes.slice(this.position, this.position + length);
    this.position += length;
    return value;
  }
}

function decodeCbor(bytes: Uint8Array): CborValue {
  const parser = new CborDecoder(bytes);
  const value = parser.read();
  if (parser.position !== bytes.length) {
    throw new AppAttestFailure("trailing_cbor", 400);
  }
  return value;
}

const mapValue = (value: CborValue, key: CborValue): CborValue | undefined =>
  value instanceof Map ? value.get(key) : undefined;
const asBytes = (
  value: CborValue | undefined,
  code = "invalid_attestation",
) => {
  if (!(value instanceof Uint8Array)) throw new AppAttestFailure(code, 400);
  return value;
};
const equalBytes = (left: Uint8Array, right: Uint8Array) =>
  left.length === right.length &&
  left.every((byte, index) => byte === right[index]);
const concatBytes = (...values: Uint8Array[]) => {
  const result = new Uint8Array(
    values.reduce((sum, value) => sum + value.length, 0),
  );
  let offset = 0;
  for (const value of values) {
    result.set(value, offset);
    offset += value.length;
  }
  return result;
};
const sha256 = async (value: Uint8Array) =>
  new Uint8Array(await crypto.subtle.digest("SHA-256", value as BufferSource));

function fromBase64(value: string, maxBytes: number): Uint8Array {
  if (
    !value || value.length > Math.ceil(maxBytes * 4 / 3) + 8 ||
    !/^[A-Za-z0-9+/]*={0,2}$/.test(value)
  ) {
    throw new AppAttestFailure("invalid_base64", 400);
  }
  try {
    const binary = atob(value);
    if (binary.length === 0 || binary.length > maxBytes) throw new Error();
    return Uint8Array.from(binary, (character) => character.charCodeAt(0));
  } catch {
    throw new AppAttestFailure("invalid_base64", 400);
  }
}

function base64(bytes: Uint8Array) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function base64Url(bytes: Uint8Array) {
  return base64(bytes).replaceAll("+", "-").replaceAll("/", "_").replace(
    /=+$/g,
    "",
  );
}

function fromBase64Url(value: string, expectedLength?: number): Uint8Array {
  if (!/^[A-Za-z0-9_-]+$/.test(value)) {
    throw new AppAttestFailure("invalid_challenge", 400);
  }
  const normalized = value.replaceAll("-", "+").replaceAll("_", "/")
    .padEnd(Math.ceil(value.length / 4) * 4, "=");
  const bytes = fromBase64(normalized, 256);
  if (expectedLength != null && bytes.length !== expectedLength) {
    throw new AppAttestFailure("invalid_challenge", 400);
  }
  return bytes;
}

type DerNode = {
  tag: number;
  value: Uint8Array;
  encoded: Uint8Array;
  children: DerNode[];
  next: number;
};

function parseDer(bytes: Uint8Array, offset = 0, depth = 0): DerNode {
  if (depth > 24 || offset + 2 > bytes.length) {
    throw new AppAttestFailure("invalid_der", 400);
  }
  const start = offset;
  const tag = bytes[offset++];
  let length = bytes[offset++];
  if ((length & 0x80) !== 0) {
    const count = length & 0x7f;
    if (count === 0 || count > 4 || offset + count > bytes.length) {
      throw new AppAttestFailure("invalid_der", 400);
    }
    length = 0;
    for (let index = 0; index < count; index += 1) {
      length = length * 256 + bytes[offset++];
    }
  }
  const end = offset + length;
  if (end > bytes.length) throw new AppAttestFailure("invalid_der", 400);
  const value = bytes.slice(offset, end);
  const children: DerNode[] = [];
  if ((tag & 0x20) !== 0) {
    let childOffset = 0;
    while (childOffset < value.length) {
      const child = parseDer(value, childOffset, depth + 1);
      children.push(child);
      childOffset = child.next;
    }
  }
  return { tag, value, encoded: bytes.slice(start, end), children, next: end };
}

const ECDSA_SIGNATURE_ALGORITHMS = new Map<string, string>([
  ["2a8648ce3d040302", "SHA-256"],
  ["2a8648ce3d040303", "SHA-384"],
  ["2a8648ce3d040304", "SHA-512"],
]);

function hex(bytes: Uint8Array) {
  return Array.from(bytes).map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function fixedDerInteger(node: DerNode, coordinateBytes: number): Uint8Array {
  if (
    node.tag !== 0x02 || node.value.length === 0 || (node.value[0] & 0x80) !== 0
  ) {
    throw new AppAttestFailure("invalid_certificate_signature", 403);
  }
  let value = node.value;
  if (value.length > 1 && value[0] === 0) {
    if ((value[1] & 0x80) === 0) {
      throw new AppAttestFailure("invalid_certificate_signature", 403);
    }
    value = value.slice(1);
  }
  if (value.length > coordinateBytes) {
    throw new AppAttestFailure("invalid_certificate_signature", 403);
  }
  const fixed = new Uint8Array(coordinateBytes);
  fixed.set(value, coordinateBytes - value.length);
  return fixed;
}

/** Deno's node:crypto X509Certificate.verify is not implemented in the Edge runtime. */
async function verifyCertificateSignature(
  certificateBytes: Uint8Array,
  issuerPublicKey: JsonObject,
): Promise<boolean> {
  const certificate = parseDer(certificateBytes);
  if (
    certificate.next !== certificateBytes.length || certificate.tag !== 0x30 ||
    certificate.children.length !== 3
  ) {
    throw new AppAttestFailure("invalid_certificate", 403);
  }
  const [tbs, outerAlgorithm, signatureBits] = certificate.children;
  if (
    tbs.tag !== 0x30 || outerAlgorithm.tag !== 0x30 ||
    outerAlgorithm.children.length !== 1 ||
    outerAlgorithm.children[0].tag !== 0x06 ||
    signatureBits.tag !== 0x03 || signatureBits.value[0] !== 0
  ) {
    throw new AppAttestFailure("invalid_certificate_signature", 403);
  }
  const algorithmOid = hex(outerAlgorithm.children[0].value);
  const signatureHash = ECDSA_SIGNATURE_ALGORITHMS.get(algorithmOid);
  if (signatureHash == null) {
    throw new AppAttestFailure("unsupported_certificate_signature", 403);
  }

  const tbsSignatureIndex = tbs.children[0]?.tag === 0xa0 ? 2 : 1;
  const tbsAlgorithm = tbs.children[tbsSignatureIndex];
  if (
    tbsAlgorithm?.tag !== 0x30 || tbsAlgorithm.children.length !== 1 ||
    tbsAlgorithm.children[0].tag !== 0x06 ||
    hex(tbsAlgorithm.children[0].value) !== algorithmOid
  ) {
    throw new AppAttestFailure("certificate_signature_algorithm_mismatch", 403);
  }

  const curve = text(issuerPublicKey.crv);
  const coordinateBytes = curve === "P-256"
    ? 32
    : curve === "P-384"
    ? 48
    : curve === "P-521"
    ? 66
    : 0;
  if (issuerPublicKey.kty !== "EC" || coordinateBytes === 0) {
    throw new AppAttestFailure("invalid_certificate_issuer_key", 403);
  }
  const derSignature = parseDer(signatureBits.value.slice(1));
  if (
    derSignature.tag !== 0x30 ||
    derSignature.next !== signatureBits.value.length - 1 ||
    derSignature.children.length !== 2
  ) {
    throw new AppAttestFailure("invalid_certificate_signature", 403);
  }
  const rawSignature = concatBytes(
    fixedDerInteger(derSignature.children[0], coordinateBytes),
    fixedDerInteger(derSignature.children[1], coordinateBytes),
  );
  try {
    const key = await crypto.subtle.importKey(
      "jwk",
      issuerPublicKey as JsonWebKey,
      { name: "ECDSA", namedCurve: curve },
      false,
      ["verify"],
    );
    // A false signature result remains false. Never retry a failed signature
    // as though it were an unsupported runtime operation.
    return await crypto.subtle.verify(
      { name: "ECDSA", hash: signatureHash },
      key,
      rawSignature,
      tbs.encoded as BufferSource,
    );
  } catch (error) {
    // Some Deno versions reject valid ECDSA curve/hash combinations (for
    // example P-384 with SHA-256) with NotSupportedError. This is a runtime
    // limitation, not permission to skip signature verification.
    const isUnsupported = error !== null && typeof error === "object" &&
      "name" in error && error.name === "NotSupportedError";
    if (!isUnsupported) throw error;

    const verifier = curve === "P-256" ? p256 : curve === "P-384" ? p384 : p521;
    let issuerPoint: Uint8Array;
    try {
      // SEC1 uncompressed public key, with the exact coordinate width.
      issuerPoint = concatBytes(
        Uint8Array.of(0x04),
        fromBase64Url(text(issuerPublicKey.x), coordinateBytes),
        fromBase64Url(text(issuerPublicKey.y), coordinateBytes),
      );
    } catch {
      throw new AppAttestFailure("invalid_certificate_issuer_key", 403);
    }

    // Hash EXACTLY once using the certificate's declared hash, not the
    // default hash of the signing curve. The OID and DER checks above remain.
    const digest = new Uint8Array(
      await crypto.subtle.digest(
        signatureHash,
        tbs.encoded as BufferSource,
      ),
    );
    let valid = false;
    try {
      valid = verifier.verify(rawSignature, digest, issuerPoint, {
        prehash: false,
        lowS: false, // X.509 permits both valid ECDSA S values (like OpenSSL).
        format: "compact",
      }) === true;
    } catch {
      // An invalid point, scalar or signature never becomes a trusted key.
      throw new AppAttestFailure("invalid_certificate_signature", 403);
    }
    try {
      // Public algorithm metadata only. No certificates, keys or requests.
      console.info(
        "BIL_APP_ATTEST_CERT_FALLBACK " + JSON.stringify({
          patch: "cert-runtime-v1",
          verifier: "noble-curves-1.9.7",
          curve,
          hash: signatureHash,
          signature_valid: valid,
        }),
      );
    } catch {
      // Logging must not change the verification result.
    }
    return valid;
  }
}

const APP_ATTEST_NONCE_OID = Uint8Array.from([
  0x2a,
  0x86,
  0x48,
  0x86,
  0xf7,
  0x63,
  0x64,
  0x08,
  0x02,
]);

function nonceExtension(certificate: Uint8Array): Uint8Array {
  const root = parseDer(certificate);
  if (root.next !== certificate.length) {
    throw new AppAttestFailure("invalid_certificate", 400);
  }
  const extensionValues: Uint8Array[] = [];
  const visit = (node: DerNode) => {
    if (
      node.tag === 0x30 && node.children.length >= 2 &&
      node.children[0].tag === 0x06 &&
      equalBytes(node.children[0].value, APP_ATTEST_NONCE_OID)
    ) {
      const candidate = node.children.at(-1)!;
      if (candidate.tag !== 0x04) {
        throw new AppAttestFailure("invalid_nonce_extension", 400);
      }
      extensionValues.push(candidate.value);
    }
    node.children.forEach(visit);
  };
  visit(root);
  if (extensionValues.length === 0) {
    throw new AppAttestFailure("nonce_extension_missing", 403);
  }
  if (extensionValues.length !== 1) {
    throw new AppAttestFailure("invalid_nonce_extension", 400);
  }
  const extensionValue = extensionValues[0];
  const wrapped = parseDer(extensionValue);
  if (wrapped.next !== extensionValue.length) {
    throw new AppAttestFailure("invalid_nonce_extension", 400);
  }
  const octets: Uint8Array[] = [];
  const collect = (node: DerNode) => {
    if (node.tag === 0x04 && node.value.length === 32) octets.push(node.value);
    node.children.forEach(collect);
  };
  collect(wrapped);
  if (octets.length !== 1) {
    throw new AppAttestFailure("invalid_nonce_extension", 403);
  }
  return octets[0];
}

const LEGACY_BUNDLE_VERSION = "legacy-unreported";

function logAuthDataShape(
  operation: "register" | "assert",
  stage: "credential_key" | "extensions",
  authData: Uint8Array,
  offset: number,
  error: unknown,
): void {
  try {
    console.error(
      "BIL_APP_ATTEST_AUTHDATA_DETAIL " + JSON.stringify({
        patch: "authdata-compat-v1",
        operation,
        stage,
        length: authData.length,
        flags: authData.length > 32 ? authData[32] : null,
        offset,
        bytes_remaining: Math.max(0, authData.length - offset),
        code: error instanceof AppAttestFailure
          ? error.code
          : "parse_exception",
      }),
    );
  } catch { /* Logging must never change validation. */ }
}

/**
 * Legacy data ends immediately after the credential key (registration), or
 * after the 37-byte header (assertion). Never read CBOR beyond that end.
 * Apple's published extended example includes a map with ED clear. Therefore
 * parse an actually present, single trailing map as well as ED-marked data.
 * Missing data with ED set, non-map data, duplicates and trailing bytes fail.
 * The complete bytes remain covered by the nonce/signature checks below.
 */
function readAuthenticatorExtensions(
  authData: Uint8Array,
  offset: number,
  operation: "register" | "assert",
): Map<CborValue, CborValue> | null {
  try {
    if (
      !Number.isSafeInteger(offset) || offset < 37 || offset > authData.length
    ) {
      throw new AppAttestFailure("invalid_authenticator_extensions", 403);
    }
    if (offset === authData.length) {
      if ((authData[32] & 0x80) !== 0) {
        throw new AppAttestFailure("authenticator_extensions_missing", 403);
      }
      return null;
    }
    const extensions = decodeCbor(authData.slice(offset));
    if (
      !(extensions instanceof Map) || extensions.size === 0 ||
      [...extensions.keys()].some((key) => typeof key !== "string")
    ) {
      throw new AppAttestFailure("invalid_authenticator_extensions", 403);
    }
    return extensions;
  } catch (error) {
    logAuthDataShape(operation, "extensions", authData, offset, error);
    if (error instanceof AppAttestFailure) throw error;
    throw new AppAttestFailure("invalid_authenticator_extensions", 403);
  }
}

/** Distribution category is NOT a generic pass/fail flag.
 * Apple's categories: 2=TestFlight, 3=development signing, 4=App Store.
 * 1 is an OS executable, not a third-party BIL app. Other categories fail.
 */
function verifyAppExtensions(
  extensions: Map<CborValue, CborValue> | null,
  environment: "development" | "production",
  allowedBundleVersions: Set<string>,
  allowLegacy: boolean,
  requireExtensions = false,
): { bundleVersion: string; validationCategory: number | null } {
  if (extensions === null) {
    if (requireExtensions) {
      throw new AppAttestFailure("authenticator_extensions_downgrade", 403);
    }
    if (!allowLegacy) {
      throw new AppAttestFailure("legacy_attestation_not_enabled", 403);
    }
    return { bundleVersion: LEGACY_BUNDLE_VERSION, validationCategory: null };
  }
  const value = extensions.get("apple_validation_category_01");
  const category = value instanceof Uint8Array && value.length === 4
    ? new DataView(value.buffer, value.byteOffset, value.byteLength).getUint32(
      0,
      true,
    )
    : value;
  const allowedCategories = environment === "production" ? [2, 4] : [3];
  if (
    typeof category !== "number" || !Number.isInteger(category) ||
    !allowedCategories.includes(category)
  ) {
    throw new AppAttestFailure("invalid_validation_category", 403);
  }
  const bundleVersion = extensions.get("apple_bundle_version_01");
  if (
    typeof bundleVersion !== "string" || bundleVersion.length === 0 ||
    bundleVersion === LEGACY_BUNDLE_VERSION ||
    !allowedBundleVersions.has(bundleVersion)
  ) {
    throw new AppAttestFailure("bundle_version_mismatch", 403);
  }
  return { bundleVersion, validationCategory: category };
}

function logVerifiedAuthData(
  operation: "register" | "assert",
  legacy: boolean,
): void {
  try {
    console.info(
      "BIL_APP_ATTEST_AUTHDATA_VERIFIED " + JSON.stringify({
        patch: "authdata-compat-v1",
        operation,
        format: legacy ? "legacy_without_extensions" : "with_extensions",
        // This describes the proof, not a supplied version or a successful DB write.
        extension_checks_available: !legacy,
      }),
    );
  } catch { /* Never alter a verification result for logging. */ }
}

function configuration() {
  const appId = env("BIL_APP_ATTEST_APP_ID");
  const environments = new Set(
    env("BIL_APP_ATTEST_ENVIRONMENTS").split(",").map((value) => value.trim())
      .filter(Boolean),
  );
  const bundleVersions = new Set(
    env("BIL_APP_ATTEST_BUNDLE_VERSIONS").split(",").map((value) =>
      value.trim()
    ).filter(Boolean),
  );
  if (
    !/^[A-Z0-9]{10}\.[A-Za-z0-9.-]{3,200}$/.test(appId) ||
    environments.size === 0 ||
    [...environments].some((value) =>
      value !== "development" && value !== "production"
    ) ||
    bundleVersions.size === 0
  ) {
    throw new AppAttestFailure("app_attest_server_not_configured", 503);
  }
  const legacySetting = env("BIL_APP_ATTEST_ALLOW_LEGACY");
  if (
    legacySetting !== "" && legacySetting !== "true" &&
    legacySetting !== "false"
  ) {
    throw new AppAttestFailure("invalid_legacy_attestation_configuration", 503);
  }
  return {
    appId,
    environments,
    bundleVersions,
    allowLegacy: legacySetting === "true",
  };
}

// Diagnostic v2: bounded, allow-listed metadata only. Never log a raw error,
// certificate, public/private key, request, header, token, user ID, or secret.
function logCertificateDiagnostic(stage: string, error: unknown): void {
  try {
    const value = error as
      | { name?: unknown; code?: unknown; message?: unknown }
      | null;
    const allowedNames = new Set([
      "Error",
      "TypeError",
      "RangeError",
      "SyntaxError",
      "DataError",
      "InvalidAccessError",
      "NotSupportedError",
      "OperationError",
      "InvalidCharacterError",
      "NotImplemented",
    ]);
    const allowedCodes = new Set([
      "ERR_NOT_IMPLEMENTED",
      "ERR_METHOD_NOT_IMPLEMENTED",
      "ERR_INVALID_ARG_TYPE",
      "ERR_INVALID_ARG_VALUE",
      "ERR_CRYPTO_INVALID_JWK",
      "ERR_CRYPTO_UNSUPPORTED_OPERATION",
      "ERR_CRYPTO_INVALID_KEY_OBJECT_TYPE",
      "ERR_CRYPTO_INVALID_KEYTYPE",
      "ERR_OSSL_UNSUPPORTED",
      "ERR_OSSL_EVP_UNSUPPORTED",
      "ERR_OSSL_ASN1_TOO_LONG",
      "ERR_OSSL_ASN1_HEADER_TOO_LONG",
      "ERR_OSSL_ASN1_NESTED_ASN1_ERROR",
      "ERR_OSSL_ASN1_WRONG_TAG",
      "ERR_OSSL_ASN1_NOT_ENOUGH_DATA",
      "ERR_OSSL_PEM_NO_START_LINE",
      "invalid_certificate",
      "invalid_der",
      "invalid_certificate_signature",
      "unsupported_certificate_signature",
      "invalid_certificate_issuer_key",
      "certificate_signature_algorithm_mismatch",
    ]);
    const name = typeof value?.name === "string" ? value.name : "";
    const nativeCode = typeof value?.code === "string" ? value.code : "";
    // Read the message only to classify it. Never emit the message itself.
    const message = typeof value?.message === "string"
      ? value.message.toLowerCase()
      : "";
    let reason = "unclassified_exception";
    if (error instanceof AppAttestFailure) {
      reason = "verification_rule_rejected";
    } else if (/not implemented|not supported|unsupported/.test(message)) {
      reason = "runtime_unsupported_operation";
    } else if (/jwk|key_ops|extractable|invalid key/.test(message)) {
      reason = "key_format_or_usage_error";
    } else if (
      /asn1|asn\.1|pem|der|x509|x\.509|certificate|parsing|parse|decode/.test(
        message,
      )
    ) {
      reason = "certificate_or_encoding_error";
    } else if (/curve|elliptic|ecdsa/.test(message)) {
      reason = "elliptic_curve_error";
    }
    const runtimeVersion = typeof Deno !== "undefined" &&
        typeof Deno.version?.deno === "string" &&
        /^[0-9A-Za-z.+-]{1,40}$/.test(Deno.version.deno)
      ? Deno.version.deno
      : "unknown";
    console.error(
      "BIL_APP_ATTEST_CERT_DETAIL " + JSON.stringify({
        diagnostic_version: 2,
        stage,
        error_name: allowedNames.has(name) ? name : "Other",
        native_code: allowedCodes.has(nativeCode) ? nativeCode : "unlisted",
        reason,
        deno_version: runtimeVersion,
      }),
    );
  } catch {
    // A logging error must never change the original verification outcome.
  }
}

function certificateIsCurrent(certificate: X509Certificate, now: number) {
  return Date.parse(certificate.validFrom) <= now &&
    now <= Date.parse(certificate.validTo);
}

type VerifiedAttestation = {
  publicKeyJwk: JsonObject;
  receiptBase64: string;
  environment: "development" | "production";
  bundleVersion: string;
};

export async function verifyAttestation({
  attestationObject,
  keyId,
  clientDataHash,
  appId,
  allowedEnvironments,
  allowedBundleVersions,
  allowLegacy = false,
  now = Date.now(),
}: {
  attestationObject: Uint8Array;
  keyId: string;
  clientDataHash: Uint8Array;
  appId: string;
  allowedEnvironments: Set<string>;
  allowedBundleVersions: Set<string>;
  allowLegacy?: boolean;
  now?: number;
}): Promise<VerifiedAttestation> {
  const decoded = decodeCbor(attestationObject);
  if (mapValue(decoded, "fmt") !== "apple-appattest") {
    throw new AppAttestFailure("invalid_attestation_format", 403);
  }
  const statement = mapValue(decoded, "attStmt");
  const chain = mapValue(statement as CborValue, "x5c");
  const receipt = asBytes(mapValue(statement as CborValue, "receipt"));
  const authData = asBytes(mapValue(decoded, "authData"));
  if (!Array.isArray(chain) || chain.length !== 2 || receipt.length > 196_608) {
    throw new AppAttestFailure("invalid_attestation_statement", 403);
  }
  const leafBytes = asBytes(chain[0]);
  const intermediateBytes = asBytes(chain[1]);

  let leaf: X509Certificate;
  let intermediate: X509Certificate;
  let root: X509Certificate;
  let certificateChainValid = false;
  let certificateStage = "parse_leaf_certificate";
  try {
    leaf = new X509Certificate(leafBytes);
    certificateStage = "parse_intermediate_certificate";
    intermediate = new X509Certificate(intermediateBytes);
    certificateStage = "parse_root_certificate";
    root = new X509Certificate(APPLE_APP_ATTEST_ROOT);
    certificateStage = "read_intermediate_public_key";
    const leafIssuerKey = intermediate.publicKey;
    certificateStage = "export_intermediate_public_key";
    const leafIssuer = leafIssuerKey.export({
      format: "jwk",
    }) as JsonObject;
    certificateStage = "read_root_public_key";
    const intermediateIssuerKey = root.publicKey;
    certificateStage = "export_root_public_key";
    const intermediateIssuer = intermediateIssuerKey.export({
      format: "jwk",
    }) as JsonObject;
    certificateStage = "verify_leaf_signature";
    certificateChainValid = await verifyCertificateSignature(
      leafBytes,
      leafIssuer,
    );
    // Preserve the original short-circuit: do not verify the intermediate if
    // the leaf signature is false.
    if (certificateChainValid) {
      certificateStage = "verify_intermediate_signature";
      certificateChainValid = await verifyCertificateSignature(
        intermediateBytes,
        intermediateIssuer,
      );
    }
  } catch (error) {
    logCertificateDiagnostic(certificateStage, error);
    if (error instanceof AppAttestFailure) throw error;
    throw new AppAttestFailure("invalid_certificate", 403);
  }
  if (
    leaf.ca || !intermediate.ca || !root.ca ||
    !certificateChainValid ||
    !certificateIsCurrent(leaf, now) ||
    !certificateIsCurrent(intermediate, now) ||
    !certificateIsCurrent(root, now)
  ) {
    throw new AppAttestFailure("untrusted_certificate_chain", 403);
  }

  if (authData.length < 56) {
    throw new AppAttestFailure("invalid_authenticator_data", 403);
  }
  const expectedRpId = await sha256(encoder.encode(appId));
  if (!equalBytes(authData.slice(0, 32), expectedRpId)) {
    throw new AppAttestFailure("app_id_mismatch", 403);
  }
  const flags = authData[32];
  if ((flags & 0x40) === 0) {
    throw new AppAttestFailure("attested_credential_data_missing", 403);
  }
  const counter = new DataView(authData.buffer, authData.byteOffset + 33, 4)
    .getUint32(0, false);
  if (counter !== 0) {
    throw new AppAttestFailure("invalid_attestation_counter", 403);
  }

  const aaguid = authData.slice(37, 53);
  const productionAaguid = concatBytes(
    encoder.encode("appattest"),
    new Uint8Array(7),
  );
  const developmentAaguid = encoder.encode("appattestdevelop");
  const environment = equalBytes(aaguid, productionAaguid)
    ? "production"
    : equalBytes(aaguid, developmentAaguid)
    ? "development"
    : null;
  if (environment == null || !allowedEnvironments.has(environment)) {
    throw new AppAttestFailure("app_attest_environment_mismatch", 403);
  }

  const credentialLength = new DataView(
    authData.buffer,
    authData.byteOffset + 53,
    2,
  ).getUint16(0, false);
  const credentialStart = 55;
  const credentialEnd = credentialStart + credentialLength;
  if (credentialLength !== 32 || credentialEnd >= authData.length) {
    throw new AppAttestFailure("invalid_credential_id", 403);
  }
  const keyIdBytes = fromBase64(keyId, 64);
  if (
    keyIdBytes.length !== 32 ||
    !equalBytes(authData.slice(credentialStart, credentialEnd), keyIdBytes)
  ) {
    throw new AppAttestFailure("credential_id_mismatch", 403);
  }

  const credentialDecoder = new CborDecoder(authData, credentialEnd);
  let credentialKey: CborValue;
  try {
    credentialKey = credentialDecoder.read();
    if (!(credentialKey instanceof Map)) {
      throw new AppAttestFailure("invalid_credential_public_key", 403);
    }
  } catch (error) {
    logAuthDataShape(
      "register",
      "credential_key",
      authData,
      credentialEnd,
      error,
    );
    throw error;
  }
  const extensions = readAuthenticatorExtensions(
    authData,
    credentialDecoder.position,
    "register",
  );
  if (
    mapValue(credentialKey, 1) !== 2 || mapValue(credentialKey, 3) !== -7 ||
    mapValue(credentialKey, -1) !== 1
  ) {
    throw new AppAttestFailure("invalid_credential_public_key", 403);
  }
  const coseX = asBytes(mapValue(credentialKey, -2));
  const coseY = asBytes(mapValue(credentialKey, -3));
  if (coseX.length !== 32 || coseY.length !== 32) {
    throw new AppAttestFailure("invalid_credential_public_key", 403);
  }
  const { bundleVersion } = verifyAppExtensions(
    extensions,
    environment,
    allowedBundleVersions,
    allowLegacy,
  );

  const expectedNonce = await sha256(concatBytes(authData, clientDataHash));
  if (!equalBytes(nonceExtension(leafBytes), expectedNonce)) {
    throw new AppAttestFailure("attestation_nonce_mismatch", 403);
  }

  let publicKeyJwk: JsonObject;
  try {
    publicKeyJwk = leaf.publicKey.export({ format: "jwk" }) as JsonObject;
  } catch {
    throw new AppAttestFailure("invalid_credential_public_key", 403);
  }
  const x = text(publicKeyJwk.x);
  const y = text(publicKeyJwk.y);
  if (publicKeyJwk.kty !== "EC" || publicKeyJwk.crv !== "P-256" || !x || !y) {
    throw new AppAttestFailure("invalid_credential_public_key", 403);
  }
  const xBytes = fromBase64Url(x, 32);
  const yBytes = fromBase64Url(y, 32);
  if (!equalBytes(xBytes, coseX) || !equalBytes(yBytes, coseY)) {
    throw new AppAttestFailure("credential_public_key_mismatch", 403);
  }
  const publicKeyHash = await sha256(
    concatBytes(Uint8Array.of(0x04), xBytes, yBytes),
  );
  if (!equalBytes(publicKeyHash, keyIdBytes)) {
    throw new AppAttestFailure("key_id_mismatch", 403);
  }

  logVerifiedAuthData("register", extensions === null);
  return {
    publicKeyJwk,
    receiptBase64: base64(receipt),
    environment,
    bundleVersion,
  };
}

export async function verifyAssertion({
  assertion,
  publicKeyJwk,
  previousCounter,
  appId,
  clientData,
  environment = "production",
  allowedBundleVersions = new Set<string>(),
  allowLegacy = false,
  requireExtensions = false,
}: {
  assertion: Uint8Array;
  publicKeyJwk: JsonObject;
  previousCounter: number;
  appId: string;
  clientData: Uint8Array;
  environment?: "development" | "production";
  allowedBundleVersions?: Set<string>;
  allowLegacy?: boolean;
  requireExtensions?: boolean;
}): Promise<number> {
  const decoded = decodeCbor(assertion);
  const signature = asBytes(
    mapValue(decoded, "signature"),
    "invalid_assertion",
  );
  const authData = asBytes(
    mapValue(decoded, "authenticatorData"),
    "invalid_assertion",
  );
  if (
    authData.length < 37 || authData.length > 12_288 ||
    signature.length < 64 || signature.length > 80
  ) {
    throw new AppAttestFailure("invalid_assertion", 403);
  }
  // App Attest assertions use a 37-byte header, optionally followed by Apple's
  // extension map. Actual Apple assertions may retain AT (0x40) with no
  // attested-credential section. Do NOT reject or skip bytes because of AT.
  // readAuthenticatorExtensions below still rejects malformed/trailing data;
  // the signature covers the complete ORIGINAL bytes, including the flags.
  const extensions = readAuthenticatorExtensions(authData, 37, "assert");
  verifyAppExtensions(
    extensions,
    environment,
    allowedBundleVersions,
    allowLegacy,
    requireExtensions,
  );
  if (!equalBytes(authData.slice(0, 32), await sha256(encoder.encode(appId)))) {
    throw new AppAttestFailure("app_id_mismatch", 403);
  }
  const counter = new DataView(authData.buffer, authData.byteOffset + 33, 4)
    .getUint32(0, false);
  if (
    !Number.isSafeInteger(previousCounter) || counter <= previousCounter ||
    counter === 0
  ) {
    throw new AppAttestFailure("assertion_counter_replay", 403);
  }
  const clientDataHash = await sha256(clientData);
  // Apple signs the nonce as an ECDSA/SHA-256 message. First reconstruct nonce
  // = SHA256(authenticatorData || SHA256(clientData)), then verify the signature
  // over that nonce. node:crypto.verify("sha256", ...) applies the signing hash.
  // Do not accept the old single-hash construction as an alternate scheme.
  const nonce = await sha256(concatBytes(authData, clientDataHash));
  try {
    const publicKey = createPublicKey({ key: publicKeyJwk, format: "jwk" });
    if (
      !verifySignature(
        "sha256",
        nonce,
        publicKey,
        signature,
      )
    ) {
      throw new AppAttestFailure("invalid_assertion_signature", 403);
    }
  } catch (error) {
    if (error instanceof AppAttestFailure) throw error;
    throw new AppAttestFailure("invalid_assertion_public_key", 403);
  }
  logVerifiedAuthData("assert", extensions === null);
  try {
    // Proof verification only, not a database-commit or AI-provider success log.
    // Structural metadata only; no request, key, signature, token or user ID.
    console.info(
      "BIL_APP_ATTEST_ASSERTION_VERIFIED " + JSON.stringify({
        patch: "assertion-compat-v2",
        auth_data_bytes: authData.length,
        flags: authData[32],
        extensions_present: extensions !== null,
        signed_message: "nonce",
      }),
    );
  } catch { /* Logging must not change the verification outcome. */ }
  return counter;
}

function clients(authorization: string) {
  const url = env("SUPABASE_URL");
  const anon = env("SUPABASE_ANON_KEY");
  const service = env("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anon || !service) {
    throw new AppAttestFailure("server_not_configured", 503);
  }
  return {
    auth: createClient(url, anon, {
      global: { headers: { Authorization: authorization } },
    }),
    admin: createClient(url, service),
  };
}

const APP_ATTEST_ISSUE_LIMIT = 60;
const INTEGRITY_ISSUE_WINDOW_SECONDS = 3600;

async function consumeAppAttestIssueRateLimit(
  auth: ReturnType<typeof clients>["auth"],
) {
  const { error } = await auth.rpc("bil_consume_rate_limit", {
    p_action: "app_attest_issue",
    p_limit: APP_ATTEST_ISSUE_LIMIT,
    p_window_seconds: INTEGRITY_ISSUE_WINDOW_SECONDS,
  });
  if (!error) return;
  const limited = String(error.message ?? "").toLowerCase().includes(
    "rate limit exceeded",
  );
  throw new AppAttestFailure(
    limited ? "rate_limited" : "rate_limit_unavailable",
    limited ? 429 : 503,
  );
}

async function authenticated(request: Request) {
  const authorization = request.headers.get("authorization") ?? "";
  if (!authorization) {
    throw new AppAttestFailure("authentication_required", 401);
  }
  const values = clients(authorization);
  const { data, error } = await values.auth.auth.getUser();
  if (error || !data.user) throw new AppAttestFailure("invalid_session", 401);
  return { ...values, ownerId: data.user.id };
}

export type AppAttestHandlerDependencies = {
  authenticate?: typeof authenticated;
};

function validAction(value: unknown) {
  const action = text(value);
  if (!/^[a-z][a-z0-9_.:-]{1,79}$/.test(action)) {
    throw new AppAttestFailure("invalid_action", 400);
  }
  return action;
}

function validDigest(value: unknown) {
  const digest = text(value).toLowerCase();
  if (!/^[0-9a-f]{64}$/.test(digest)) {
    throw new AppAttestFailure("invalid_payload_digest", 400);
  }
  return digest;
}

function validKeyId(value: unknown) {
  const keyId = text(value);
  const bytes = fromBase64(keyId, 64);
  if (bytes.length !== 32) throw new AppAttestFailure("invalid_key_id", 400);
  return keyId;
}

async function issueGrant(
  admin: ReturnType<typeof clients>["admin"],
  ownerId: string,
  challenge: JsonObject,
) {
  const { data, error } = await admin.from("bil_mobile_integrity_grants")
    .upsert({
      owner_id: ownerId,
      platform: "ios",
      source_id: challenge.id,
      action: challenge.action,
      payload_digest: challenge.payload_digest,
      key_id: challenge.key_id,
    }, { onConflict: "owner_id,platform,source_id" }).select(
      "id,expires_at,consumed_at",
    ).single();
  if (error || !data || data.consumed_at != null) {
    throw new AppAttestFailure("integrity_grant_issue_failed", 503);
  }
  return { id: data.id, expires_at: data.expires_at };
}

async function claimChallenge(
  admin: ReturnType<typeof clients>["admin"],
  ownerId: string,
  challengeId: string,
  purpose: "registration" | "assertion",
) {
  if (!/^[0-9a-f-]{36}$/i.test(challengeId)) {
    throw new AppAttestFailure("invalid_challenge_id", 400);
  }
  const now = new Date().toISOString();
  const { data, error } = await admin.from("bil_mobile_integrity_challenges")
    .update({ consumed_at: now })
    .eq("id", challengeId)
    .eq("owner_id", ownerId)
    .eq("purpose", purpose)
    .is("consumed_at", null)
    .gt("expires_at", now)
    .select("id,action,payload_digest,key_id,challenge")
    .maybeSingle();
  if (error) throw new AppAttestFailure("challenge_claim_failed", 503);
  if (!data) throw new AppAttestFailure("challenge_expired_or_consumed", 403);
  return data as JsonObject;
}

async function challengeOperation(
  body: JsonObject,
  request: Request,
  authenticate: typeof authenticated,
) {
  const { auth, admin, ownerId } = await authenticate(request);
  configuration();
  // Bound authenticated challenge creation before any persistent row is
  // written. A limiter outage fails closed so it cannot become a quota bypass.
  await consumeAppAttestIssueRateLimit(auth);
  const action = validAction(body.action);
  const payloadDigest = validDigest(body.payload_digest);
  const keyId = validKeyId(body.key_id);
  const { data: existing, error: keyError } = await admin.from(
    "bil_app_attest_keys",
  )
    .select("key_id")
    .eq("owner_id", ownerId)
    .eq("key_id", keyId)
    .eq("active", true)
    .maybeSingle();
  if (keyError) throw new AppAttestFailure("app_attest_key_lookup_failed", 503);
  const registrationRequired = !existing;
  const challenge = base64Url(crypto.getRandomValues(new Uint8Array(32)));
  const { data, error } = await admin.from("bil_mobile_integrity_challenges")
    .insert({
      owner_id: ownerId,
      platform: "ios",
      purpose: registrationRequired ? "registration" : "assertion",
      action,
      payload_digest: payloadDigest,
      key_id: keyId,
      challenge,
    }).select("id,expires_at").single();
  if (error || !data) throw new AppAttestFailure("challenge_issue_failed", 503);
  return json({
    challenge_id: data.id,
    challenge,
    expires_at: data.expires_at,
    registration_required: registrationRequired,
  });
}

async function registerOperation(
  body: JsonObject,
  request: Request,
  authenticate: typeof authenticated,
) {
  const { admin, ownerId } = await authenticate(request);
  const config = configuration();
  const challengeId = text(body.challenge_id);
  const keyId = validKeyId(body.key_id);
  const attestationObject = fromBase64(text(body.attestation_object), 262_144);
  const challenge = await claimChallenge(
    admin,
    ownerId,
    challengeId,
    "registration",
  );
  if (challenge.key_id !== keyId) {
    throw new AppAttestFailure("challenge_key_mismatch", 403);
  }
  const verified = await verifyAttestation({
    attestationObject,
    keyId,
    clientDataHash: await sha256(
      fromBase64Url(String(challenge.challenge), 32),
    ),
    appId: config.appId,
    allowedEnvironments: config.environments,
    allowedBundleVersions: config.bundleVersions,
    allowLegacy: config.allowLegacy,
  });
  const { error } = await admin.from("bil_app_attest_keys").insert({
    owner_id: ownerId,
    key_id: keyId,
    public_key_jwk: verified.publicKeyJwk,
    receipt_base64: verified.receiptBase64,
    environment: verified.environment,
    bundle_version: verified.bundleVersion,
    sign_count: 0,
  });
  if (error) {
    throw new AppAttestFailure("app_attest_key_registration_failed", 403);
  }
  const grant = await issueGrant(admin, ownerId, challenge);
  return json({
    allowed: true,
    trustworthy: true,
    reason: "app_attest_registered",
    grant,
  });
}

async function assertionOperation(
  body: JsonObject,
  request: Request,
  authenticate: typeof authenticated,
) {
  const { admin, ownerId } = await authenticate(request);
  const config = configuration();
  const challengeId = text(body.challenge_id);
  const keyId = validKeyId(body.key_id);
  const assertion = fromBase64(text(body.assertion), 16_384);
  const challenge = await claimChallenge(
    admin,
    ownerId,
    challengeId,
    "assertion",
  );
  if (challenge.key_id !== keyId) {
    throw new AppAttestFailure("challenge_key_mismatch", 403);
  }
  const { data: key, error: keyError } = await admin.from("bil_app_attest_keys")
    .select("public_key_jwk,sign_count,active,bundle_version,environment")
    .eq("owner_id", ownerId)
    .eq("key_id", keyId)
    .eq("active", true)
    .maybeSingle();
  if (keyError) throw new AppAttestFailure("app_attest_key_lookup_failed", 503);
  if (!key) throw new AppAttestFailure("app_attest_key_not_registered", 403);
  const keyEnvironment = key.environment;
  if (
    (keyEnvironment !== "production" && keyEnvironment !== "development") ||
    !config.environments.has(keyEnvironment)
  ) {
    throw new AppAttestFailure("app_attest_environment_mismatch", 403);
  }
  // Only a key explicitly recorded as legacy may issue extension-less assertions.
  const keyRequiresExtensions = key.bundle_version !== LEGACY_BUNDLE_VERSION;
  const clientData = encoder.encode(
    `bil-app-attest-v1\n${challenge.id}\n${challenge.action}\n${challenge.payload_digest}\n${challenge.challenge}`,
  );
  const counter = await verifyAssertion({
    assertion,
    publicKeyJwk: key.public_key_jwk as JsonObject,
    previousCounter: Number(key.sign_count),
    appId: config.appId,
    clientData,
    environment: keyEnvironment,
    allowedBundleVersions: config.bundleVersions,
    allowLegacy: config.allowLegacy,
    requireExtensions: keyRequiresExtensions,
  });
  const { data: updated, error: updateError } = await admin.from(
    "bil_app_attest_keys",
  )
    .update({ sign_count: counter, last_used_at: new Date().toISOString() })
    .eq("owner_id", ownerId)
    .eq("key_id", keyId)
    .eq("active", true)
    .lt("sign_count", counter)
    .select("key_id")
    .maybeSingle();
  if (updateError) {
    throw new AppAttestFailure("assertion_counter_update_failed", 503);
  }
  if (!updated) throw new AppAttestFailure("assertion_counter_replay", 403);
  const grant = await issueGrant(admin, ownerId, challenge);
  return json({
    allowed: true,
    trustworthy: true,
    reason: "app_attest_assertion_valid",
    grant,
  });
}

export async function handler(
  request: Request,
  dependencies: AppAttestHandlerDependencies = {},
): Promise<Response> {
  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }
  let diagnosticOperation = "unparsed";
  try {
    const body = await request.json() as JsonObject;
    const operation = text(body.operation);
    diagnosticOperation =
      operation === "challenge" || operation === "register" ||
        operation === "assert"
        ? operation
        : "invalid";
    const authenticate = dependencies.authenticate ?? authenticated;
    if (operation === "challenge") {
      return await challengeOperation(body, request, authenticate);
    }
    if (operation === "register") {
      return await registerOperation(body, request, authenticate);
    }
    if (operation === "assert") {
      return await assertionOperation(body, request, authenticate);
    }
    return json({ error: "invalid_operation" }, 400);
  } catch (error) {
    const failure = error instanceof AppAttestFailure
      ? error
      : new AppAttestFailure("app_attest_verification_failed", 403);
    // Diagnostic only: log static error codes and an allow-listed operation.
    // Never log request bodies, headers, tokens, keys, or raw exceptions.
    try {
      console.error(
        "BIL_APP_ATTEST_FAILURE " + JSON.stringify({
          operation: diagnosticOperation,
          code: failure.code,
          status: failure.status,
        }),
      );
    } catch {
      // A logging failure must not change the original verification response.
    }
    return json(
      { allowed: false, trustworthy: false, error: failure.code },
      failure.status,
    );
  }
}

if (import.meta.main) Deno.serve((request) => handler(request));
