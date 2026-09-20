// Pure X.509 signature verification for StoreKit's x5c certificates.
//
// Supabase Edge Runtime 1.76.0 is compatible with Deno 2.1.4, where
// node:crypto's X509Certificate.verify, .raw and .toString are explicitly
// unimplemented.  Keep this module independent of X509Certificate so the
// caller can retain the original DER bytes and verify them with WebCrypto.
import { p256, p384, p521 } from "npm:@noble/curves@1.9.7/nist.js";

type JsonObject = Record<string, unknown>;

type DerNode = {
  tag: number;
  value: Uint8Array;
  encoded: Uint8Array;
  children: DerNode[];
  next: number;
};

const ECDSA_SIGNATURE_ALGORITHMS = new Map<string, string>([
  ["2a8648ce3d040302", "SHA-256"],
  ["2a8648ce3d040303", "SHA-384"],
  ["2a8648ce3d040304", "SHA-512"],
]);

// sha{256,384,512}WithRSAEncryption. SHA-1 is intentionally not accepted for
// a non-anchor certificate chain, even though the legacy Apple Root CA's
// *self-signature* uses SHA-1. Trust for a root comes from its configured DER
// SHA-256 pin, not from validating that self-signature.
const RSA_PKCS1_SIGNATURE_ALGORITHMS = new Map<string, string>([
  ["2a864886f70d01010b", "SHA-256"],
  ["2a864886f70d01010c", "SHA-384"],
  ["2a864886f70d01010d", "SHA-512"],
]);

class AppleCertificateVerifierError extends Error {
  constructor(readonly code: string) {
    super(code);
    this.name = "AppleCertificateVerifierError";
  }
}

const concatBytes = (...values: Uint8Array[]) => {
  const result = new Uint8Array(
    values.reduce((total, value) => total + value.length, 0),
  );
  let offset = 0;
  for (const value of values) {
    result.set(value, offset);
    offset += value.length;
  }
  return result;
};

const equalBytes = (left: Uint8Array, right: Uint8Array) =>
  left.length === right.length &&
  left.every((byte, index) => byte === right[index]);

const hex = (bytes: Uint8Array) =>
  Array.from(bytes).map((byte) => byte.toString(16).padStart(2, "0")).join("");

const text = (value: unknown) => typeof value === "string" ? value.trim() : "";

function parseDer(bytes: Uint8Array, offset = 0, depth = 0): DerNode {
  if (depth > 24 || offset + 2 > bytes.length) {
    throw new AppleCertificateVerifierError("invalid_certificate");
  }
  const start = offset;
  const tag = bytes[offset++];
  if (tag === 0) throw new AppleCertificateVerifierError("invalid_certificate");
  let length = bytes[offset++];
  if ((length & 0x80) !== 0) {
    const count = length & 0x7f;
    if (
      count === 0 || count > 4 || offset + count > bytes.length ||
      bytes[offset] === 0
    ) {
      throw new AppleCertificateVerifierError("invalid_certificate");
    }
    length = 0;
    for (let index = 0; index < count; index += 1) {
      length = length * 256 + bytes[offset++];
    }
    // DER requires short-form encoding for lengths below 128.
    if (length < 128) {
      throw new AppleCertificateVerifierError("invalid_certificate");
    }
  }
  const end = offset + length;
  if (end > bytes.length) {
    throw new AppleCertificateVerifierError("invalid_certificate");
  }
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

function fixedDerInteger(node: DerNode, coordinateBytes: number): Uint8Array {
  if (
    node.tag !== 0x02 || node.value.length === 0 || (node.value[0] & 0x80) !== 0
  ) {
    throw new AppleCertificateVerifierError("invalid_certificate_signature");
  }
  let value = node.value;
  if (value.length > 1 && value[0] === 0) {
    if ((value[1] & 0x80) === 0) {
      throw new AppleCertificateVerifierError("invalid_certificate_signature");
    }
    value = value.slice(1);
  }
  if (value.length > 1 && value[0] === 0 || value.length > coordinateBytes) {
    throw new AppleCertificateVerifierError("invalid_certificate_signature");
  }
  const fixed = new Uint8Array(coordinateBytes);
  fixed.set(value, coordinateBytes - value.length);
  return fixed;
}

function fromBase64Url(value: string, expectedLength: number): Uint8Array {
  if (!/^[A-Za-z0-9_-]+$/.test(value)) {
    throw new AppleCertificateVerifierError("invalid_certificate_issuer_key");
  }
  const normalized = value.replaceAll("-", "+").replaceAll("_", "/")
    .padEnd(Math.ceil(value.length / 4) * 4, "=");
  try {
    const bytes = Uint8Array.from(
      atob(normalized),
      (character) => character.charCodeAt(0),
    );
    if (bytes.length !== expectedLength) throw new Error();
    return bytes;
  } catch {
    throw new AppleCertificateVerifierError("invalid_certificate_issuer_key");
  }
}

function requireMatchingAlgorithm(tbs: DerNode, outerAlgorithm: DerNode) {
  const tbsSignatureIndex = tbs.children[0]?.tag === 0xa0 ? 2 : 1;
  const tbsAlgorithm = tbs.children[tbsSignatureIndex];
  if (
    tbs.tag !== 0x30 || tbsAlgorithm?.tag !== 0x30 ||
    !equalBytes(tbsAlgorithm.encoded, outerAlgorithm.encoded)
  ) {
    throw new AppleCertificateVerifierError(
      "certificate_signature_algorithm_mismatch",
    );
  }
}

function signatureAlgorithm(algorithm: DerNode) {
  if (
    algorithm.tag !== 0x30 || algorithm.children.length === 0 ||
    algorithm.children[0].tag !== 0x06
  ) {
    throw new AppleCertificateVerifierError("invalid_certificate_signature");
  }
  const oid = hex(algorithm.children[0].value);
  const ecdsaHash = ECDSA_SIGNATURE_ALGORITHMS.get(oid);
  if (ecdsaHash) {
    if (algorithm.children.length !== 1) {
      throw new AppleCertificateVerifierError("invalid_certificate_signature");
    }
    return { family: "ecdsa" as const, hash: ecdsaHash };
  }
  const rsaHash = RSA_PKCS1_SIGNATURE_ALGORITHMS.get(oid);
  if (rsaHash) {
    // RSA AlgorithmIdentifier conventionally includes DER NULL parameters.
    // Accept an omitted parameter for interoperability, but no alternate one.
    if (
      algorithm.children.length > 2 ||
      (algorithm.children.length === 2 &&
        (algorithm.children[1].tag !== 0x05 ||
          algorithm.children[1].value.length !== 0))
    ) {
      throw new AppleCertificateVerifierError("invalid_certificate_signature");
    }
    return { family: "rsa" as const, hash: rsaHash };
  }
  throw new AppleCertificateVerifierError("unsupported_certificate_signature");
}

async function verifyEcdsaCertificateSignature(
  tbs: Uint8Array,
  signature: Uint8Array,
  signatureHash: string,
  issuerPublicKey: JsonObject,
): Promise<boolean> {
  const curve = text(issuerPublicKey.crv);
  const coordinateBytes = curve === "P-256"
    ? 32
    : curve === "P-384"
    ? 48
    : curve === "P-521"
    ? 66
    : 0;
  if (issuerPublicKey.kty !== "EC" || coordinateBytes === 0) {
    throw new AppleCertificateVerifierError("invalid_certificate_issuer_key");
  }
  const derSignature = parseDer(signature);
  if (
    derSignature.tag !== 0x30 || derSignature.next !== signature.length ||
    derSignature.children.length !== 2
  ) {
    throw new AppleCertificateVerifierError("invalid_certificate_signature");
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
    return await crypto.subtle.verify(
      { name: "ECDSA", hash: signatureHash },
      key,
      rawSignature,
      tbs as BufferSource,
    );
  } catch (error) {
    // Older Deno versions can reject a valid ECDSA curve/hash combination.
    // Never turn that runtime limitation into a trusted certificate.
    const unsupported = error !== null && typeof error === "object" &&
      "name" in error && error.name === "NotSupportedError";
    if (!unsupported) throw error;

    const verifier = curve === "P-256" ? p256 : curve === "P-384" ? p384 : p521;
    const issuerPoint = concatBytes(
      Uint8Array.of(0x04),
      fromBase64Url(text(issuerPublicKey.x), coordinateBytes),
      fromBase64Url(text(issuerPublicKey.y), coordinateBytes),
    );
    const digest = new Uint8Array(
      await crypto.subtle.digest(signatureHash, tbs as BufferSource),
    );
    try {
      return verifier.verify(rawSignature, digest, issuerPoint, {
        prehash: false,
        lowS: false,
        format: "compact",
      }) === true;
    } catch {
      throw new AppleCertificateVerifierError("invalid_certificate_signature");
    }
  }
}

async function verifyRsaCertificateSignature(
  tbs: Uint8Array,
  signature: Uint8Array,
  signatureHash: string,
  issuerPublicKey: JsonObject,
): Promise<boolean> {
  if (issuerPublicKey.kty !== "RSA") {
    throw new AppleCertificateVerifierError("invalid_certificate_issuer_key");
  }
  const key = await crypto.subtle.importKey(
    "jwk",
    issuerPublicKey as JsonWebKey,
    { name: "RSASSA-PKCS1-v1_5", hash: signatureHash },
    false,
    ["verify"],
  );
  return await crypto.subtle.verify(
    { name: "RSASSA-PKCS1-v1_5" },
    key,
    new Uint8Array(signature),
    tbs as BufferSource,
  );
}

/**
 * Verifies the signature inside one DER-encoded X.509 certificate using the
 * issuer public JWK. The caller still owns issuer-DN, CA, time and root-pin
 * validation; this routine only validates the certificate's signed bytes.
 */
export async function verifyCertificateSignature(
  certificateBytes: Uint8Array,
  issuerPublicKey: JsonObject,
): Promise<boolean> {
  const certificate = parseDer(certificateBytes);
  if (
    certificate.next !== certificateBytes.length || certificate.tag !== 0x30 ||
    certificate.children.length !== 3
  ) {
    throw new AppleCertificateVerifierError("invalid_certificate");
  }
  const [tbs, outerAlgorithm, signatureBits] = certificate.children;
  if (
    signatureBits.tag !== 0x03 || signatureBits.value.length < 2 ||
    signatureBits.value[0] !== 0
  ) {
    throw new AppleCertificateVerifierError("invalid_certificate_signature");
  }
  requireMatchingAlgorithm(tbs, outerAlgorithm);
  const algorithm = signatureAlgorithm(outerAlgorithm);
  const signature = signatureBits.value.slice(1);
  return algorithm.family === "ecdsa"
    ? await verifyEcdsaCertificateSignature(
      tbs.encoded,
      signature,
      algorithm.hash,
      issuerPublicKey,
    )
    : await verifyRsaCertificateSignature(
      tbs.encoded,
      signature,
      algorithm.hash,
      issuerPublicKey,
    );
}

/** Converts preserved certificate DER into the PEM expected by jose.importX509. */
export function certificateDerToPem(certificateBytes: Uint8Array): string {
  if (certificateBytes.length === 0) {
    throw new AppleCertificateVerifierError("invalid_certificate");
  }
  let binary = "";
  for (const byte of certificateBytes) binary += String.fromCharCode(byte);
  const base64 = btoa(binary);
  const body = base64.match(/.{1,64}/g)?.join("\n");
  if (!body) throw new AppleCertificateVerifierError("invalid_certificate");
  return `-----BEGIN CERTIFICATE-----\n${body}\n-----END CERTIFICATE-----`;
}
