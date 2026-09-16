import { X509Certificate } from "node:crypto";
import { importPKCS8, SignJWT } from "npm:jose@6.1.0";
import {
  certificateDerToPem,
  verifyCertificateSignature,
} from "./apple_certificate_verifier.ts";
import {
  APPLE_ROOT_CA_DER_BASE64,
  appleCertificateFromTrustedDer,
  verifyAppleJwsWithTrustedRoots,
} from "./store_backend.ts";

const APPLE_ROOT_CA_G2 =
  "c2b9b042dd57830e7d117dac55ac8ae19407d38e41d88f3215bc3a890444a050";
const APPLE_ROOT_CA_G3 =
  "63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179";

// Synthetic, test-only P-384 root/intermediate with SHA-256 certificate
// signatures and a P-256 leaf for an ES256 StoreKit JWS. No production key,
// Apple receipt, or configured root is present here.
const TEST_ROOT =
  "MIIBkjCCARigAwIBAgIIMWKvi18glGEwCgYIKoZIzj0EAwIwHjEcMBoGA1UEAxMTQklMIFN0b3JlIFRlc3QgUm9vdDAeFw0yNjA5MTUwMTEzMTNaFw0zMTA5MTYwMTEzMTNaMB4xHDAaBgNVBAMTE0JJTCBTdG9yZSBUZXN0IFJvb3QwdjAQBgcqhkjOPQIBBgUrgQQAIgNiAAR4SjMJFmNTbo8BsSjhMH4S7JSSFSS79fP2K8rCpkYvJt9emMzEWVJAevHkIKJyjXLp06jwZBHKNlQZIcbXP5ibN0AS2FB6dnoTU/YIEe4vSSm7XC/ykpQ3ABlaky5triSjIzAhMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgIEMAoGCCqGSM49BAMCA2gAMGUCMCkIGDa/qpyZZIjhoi/cCU8ir5XjnAonWbvuz7wWu3TTTv3hOiSTQb5CFPOWy/k4/QIxAPTFaX0S2nm0N6Bze1xK+7NeFXbKV3fRJV0bCBY0NsQC5Vma1lVUOxHxAZOeZ39Kyw==";
const TEST_INTERMEDIATE =
  "MIIBmzCCASCgAwIBAgIIAgMEBQYHCAkwCgYIKoZIzj0EAwIwHjEcMBoGA1UEAxMTQklMIFN0b3JlIFRlc3QgUm9vdDAeFw0yNjA5MTUwMTEzMTNaFw0zMTA5MTYwMTEzMTNaMCYxJDAiBgNVBAMTG0JJTCBTdG9yZSBUZXN0IEludGVybWVkaWF0ZTB2MBAGByqGSM49AgEGBSuBBAAiA2IABL0WgXtffdgwCDPXOmsuEPZjA5mjGBLdRogCpF+L9NZh6N/5cCcozXrz1X+H7b5Eq+2EXwwnoloQ74kzg+/28B2kwtdwfYesGkrZiK/21m+bUq97PGnLSqVthzjWOerXLKMjMCEwDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMCAgQwCgYIKoZIzj0EAwIDaQAwZgIxAPvcK2FCAg1souZIAt7noqyOZ/O/6pOoPDIdkAeTH7gid2ayP8LS+F493jwjbVup5AIxANKuwJa09zaKFHn6FbaqdLoL9Qdr4bo33vcl+JhzKOkhowGyy5CGbhFnuZ+ePQ8aDw==";
const TEST_LEAF =
  "MIIBeTCCAQCgAwIBAgIICgsMDQ4PEBEwCgYIKoZIzj0EAwIwJjEkMCIGA1UEAxMbQklMIFN0b3JlIFRlc3QgSW50ZXJtZWRpYXRlMB4XDTI2MDkxNTAxMTMxM1oXDTMxMDkxNjAxMTMxM1owHjEcMBoGA1UEAxMTQklMIFN0b3JlIFRlc3QgTGVhZjBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABEjANLw/9jV3ZmfZZY4q0NEUJhXnoEhNcb+mtg9JipziJeAi75Q7XGnZWnrvfPa5My+vuLL7KsU1dCiwr33Kt0qjIDAeMAwGA1UdEwEB/wQCMAAwDgYDVR0PAQH/BAQDAgeAMAoGCCqGSM49BAMCA2cAMGQCMHM94IOR03XvuVTWX6DA5LL3NiYxLQrg9sBKuol4iCWWfPPeOlgSj2ChP0pWLUBifwIwf7NEQuUD8YnXATabguJZPgf7wLl3Dp0iJEoNa/6RZ8qdOOPXwC1fooNd8ipgElzS";
const TEST_LEAF_PKCS8 =
  "MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgFHv2mhcOvRpRD5bVtV3c/Q0IRYGZcGmgw+YqvMKQtpKhRANCAARIwDS8P/Y1d2Zn2WWOKtDRFCYV56BITXG/prYPSYqc4iXgIu+UO1xp2Vp673z2uTMvr7iy+yrFNXQosK99yrdK";

const der = (encoded: string) =>
  Uint8Array.from(atob(encoded), (character) => character.charCodeAt(0));

const assertEquals = <T>(actual: T, expected: T) => {
  if (actual !== expected) {
    throw new Error(`expected ${String(expected)}, got ${String(actual)}`);
  }
};

const base64 = (value: Uint8Array) => {
  let binary = "";
  for (const byte of value) binary += String.fromCharCode(byte);
  return btoa(binary);
};

const pemPrivateKey = (encoded: string) =>
  `-----BEGIN PRIVATE KEY-----\n${
    encoded.match(/.{1,64}/g)?.join("\n")
  }\n-----END PRIVATE KEY-----`;

const sha256 = async (value: Uint8Array) =>
  Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256", value)))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");

async function signedTestJws(intermediate = TEST_INTERMEDIATE) {
  const key = await importPKCS8(pemPrivateKey(TEST_LEAF_PKCS8), "ES256");
  return await new SignJWT({ fixture: "verified" })
    .setProtectedHeader({
      alg: "ES256",
      x5c: [TEST_LEAF, intermediate],
    })
    .setIssuedAt()
    .setExpirationTime("5m")
    .sign(key);
}

async function assertRejects(operation: () => Promise<unknown>) {
  let rejected = false;
  try {
    await operation();
  } catch {
    rejected = true;
  }
  if (!rejected) throw new Error("expected_rejection");
}

async function withUnavailableX509Methods(
  operation: () => void | Promise<void>,
) {
  const prototype = X509Certificate.prototype;
  const verify = Object.getOwnPropertyDescriptor(prototype, "verify");
  const raw = Object.getOwnPropertyDescriptor(prototype, "raw");
  const toString = Object.getOwnPropertyDescriptor(prototype, "toString");
  if (!verify || !raw || !toString) throw new Error("x509_test_setup_failed");
  const unsupported = (name: string) => () => {
    throw new Error(`unsupported_x509_${name}`);
  };
  try {
    Object.defineProperties(prototype, {
      verify: { configurable: true, value: unsupported("verify") },
      raw: { configurable: true, get: unsupported("raw") },
      toString: { configurable: true, value: unsupported("to_string") },
    });
    await operation();
  } finally {
    Object.defineProperties(prototype, { verify, raw, toString });
  }
}

Deno.test(
  "StoreKit certificate verifier keeps every configured Apple root DER independent of unavailable X509 methods",
  async () => {
    await withUnavailableX509Methods(() => {
      for (const encoded of Object.values(APPLE_ROOT_CA_DER_BASE64)) {
        const certificateDer = der(encoded);
        const certificate = new X509Certificate(certificateDer);
        const publicKey = certificate.publicKey.export({ format: "jwk" });
        if (!publicKey || typeof publicKey !== "object") {
          throw new Error("apple_root_public_key_unavailable");
        }
        const pem = certificateDerToPem(certificateDer);
        if (
          !pem.startsWith("-----BEGIN CERTIFICATE-----\n") ||
          !pem.endsWith("\n-----END CERTIFICATE-----")
        ) {
          throw new Error("apple_root_pem_conversion_failed");
        }
      }
    });
  },
);

Deno.test(
  "StoreKit JWS verifies a complete leaf-intermediate-root chain when native X509 methods are unavailable",
  async () => {
    const rootDer = der(TEST_ROOT);
    const rootPin = await sha256(rootDer);
    await withUnavailableX509Methods(async () => {
      const jws = await signedTestJws();
      const verified = await verifyAppleJwsWithTrustedRoots(
        jws,
        new Set([rootPin]),
        [appleCertificateFromTrustedDer(rootDer)],
      );
      assertEquals(verified.fixture, "verified");

      await assertRejects(() =>
        verifyAppleJwsWithTrustedRoots(
          jws,
          new Set(["0".repeat(64)]),
          [appleCertificateFromTrustedDer(rootDer)],
        )
      );

      const jwsParts = jws.split(".");
      jwsParts[2] = `${jwsParts[2][0] === "A" ? "B" : "A"}${
        jwsParts[2].slice(1)
      }`;
      await assertRejects(() =>
        verifyAppleJwsWithTrustedRoots(
          jwsParts.join("."),
          new Set([rootPin]),
          [appleCertificateFromTrustedDer(rootDer)],
        )
      );

      const tamperedIntermediate = der(TEST_INTERMEDIATE);
      // Serial-number byte: certificate remains parseable, but its signature
      // no longer verifies against the pinned test root.
      tamperedIntermediate[12] ^= 0x01;
      await assertRejects(() =>
        signedTestJws(base64(tamperedIntermediate)).then((jws) =>
          verifyAppleJwsWithTrustedRoots(
            jws,
            new Set([rootPin]),
            [appleCertificateFromTrustedDer(rootDer)],
          )
        )
      );
    });
  },
);

Deno.test(
  "StoreKit certificate verifier validates public Apple RSA and EC roots and rejects tampering without X509 verify",
  async () => {
    await withUnavailableX509Methods(async () => {
      for (const pin of [APPLE_ROOT_CA_G2, APPLE_ROOT_CA_G3]) {
        const certificateDer = der(APPLE_ROOT_CA_DER_BASE64[pin]);
        const certificate = new X509Certificate(certificateDer);
        const publicKey = certificate.publicKey.export({
          format: "jwk",
        }) as Record<
          string,
          unknown
        >;
        assertEquals(
          await verifyCertificateSignature(certificateDer, publicKey),
          true,
        );

        // This is the X.509 version byte inside tbsCertificate: it remains
        // well-formed DER but invalidates the signature.
        const tampered = new Uint8Array(certificateDer);
        tampered[12] ^= 0x01;
        assertEquals(
          await verifyCertificateSignature(tampered, publicKey),
          false,
        );
      }
    });
  },
);
