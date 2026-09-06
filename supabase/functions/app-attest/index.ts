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
  const key = await crypto.subtle.importKey(
    "jwk",
    issuerPublicKey as JsonWebKey,
    { name: "ECDSA", namedCurve: curve },
    false,
    ["verify"],
  );
  return await crypto.subtle.verify(
    { name: "ECDSA", hash: signatureHash },
    key,
    rawSignature,
    tbs.encoded as BufferSource,
  );
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
  return { appId, environments, bundleVersions };
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
  now = Date.now(),
}: {
  attestationObject: Uint8Array;
  keyId: string;
  clientDataHash: Uint8Array;
  appId: string;
  allowedEnvironments: Set<string>;
  allowedBundleVersions: Set<string>;
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
  try {
    leaf = new X509Certificate(leafBytes);
    intermediate = new X509Certificate(intermediateBytes);
    root = new X509Certificate(APPLE_APP_ATTEST_ROOT);
    const leafIssuer = intermediate.publicKey.export({
      format: "jwk",
    }) as JsonObject;
    const intermediateIssuer = root.publicKey.export({
      format: "jwk",
    }) as JsonObject;
    certificateChainValid =
      await verifyCertificateSignature(leafBytes, leafIssuer) &&
      await verifyCertificateSignature(intermediateBytes, intermediateIssuer);
  } catch (error) {
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
  const credentialKey = credentialDecoder.read();
  const extensionsDecoder = new CborDecoder(
    authData,
    credentialDecoder.position,
  );
  const extensions = extensionsDecoder.read();
  if (
    extensionsDecoder.position !== authData.length ||
    !(credentialKey instanceof Map) || !(extensions instanceof Map)
  ) {
    throw new AppAttestFailure("invalid_authenticator_extensions", 403);
  }
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
  const validationCategory = mapValue(
    extensions,
    "apple_validation_category_01",
  );
  const validationCategoryValue = validationCategory instanceof Uint8Array &&
      validationCategory.length === 4
    ? new DataView(
      validationCategory.buffer,
      validationCategory.byteOffset,
      validationCategory.byteLength,
    ).getUint32(0, true)
    : validationCategory;
  if (validationCategoryValue !== 1) {
    throw new AppAttestFailure("invalid_validation_category", 403);
  }
  const bundleVersion = mapValue(extensions, "apple_bundle_version_01");
  if (
    typeof bundleVersion !== "string" ||
    !allowedBundleVersions.has(bundleVersion)
  ) {
    throw new AppAttestFailure("bundle_version_mismatch", 403);
  }

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
}: {
  assertion: Uint8Array;
  publicKeyJwk: JsonObject;
  previousCounter: number;
  appId: string;
  clientData: Uint8Array;
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
    authData.length !== 37 || signature.length < 64 || signature.length > 80
  ) {
    throw new AppAttestFailure("invalid_assertion", 403);
  }
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
  try {
    const publicKey = createPublicKey({ key: publicKeyJwk, format: "jwk" });
    if (
      !verifySignature(
        "sha256",
        concatBytes(authData, clientDataHash),
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
    .select("public_key_jwk,sign_count,active")
    .eq("owner_id", ownerId)
    .eq("key_id", keyId)
    .eq("active", true)
    .maybeSingle();
  if (keyError) throw new AppAttestFailure("app_attest_key_lookup_failed", 503);
  if (!key) throw new AppAttestFailure("app_attest_key_not_registered", 403);
  const clientData = encoder.encode(
    `bil-app-attest-v1\n${challenge.id}\n${challenge.action}\n${challenge.payload_digest}\n${challenge.challenge}`,
  );
  const counter = await verifyAssertion({
    assertion,
    publicKeyJwk: key.public_key_jwk as JsonObject,
    previousCounter: Number(key.sign_count),
    appId: config.appId,
    clientData,
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
  try {
    const body = await request.json() as JsonObject;
    const operation = text(body.operation);
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
    return json(
      { allowed: false, trustworthy: false, error: failure.code },
      failure.status,
    );
  }
}

if (import.meta.main) Deno.serve((request) => handler(request));
