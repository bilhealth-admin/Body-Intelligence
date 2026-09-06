import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { generateKeyPairSync, sign } from "node:crypto";
import { handler, verifyAssertion, verifyAttestation } from "./index.ts";

const encoder = new TextEncoder();

// Published by Apple in the current Attestation Object Validation Guide:
// https://developer.apple.com/documentation/devicecheck/attestation-object-validation-guide
const appleAttestationValidationSample = [
  "o2NmbXRvYXBwbGUtYXBwYXR0ZXN0Z2F0dFN0bXSiY3g1Y4JZBCEwggQdMIIDo6ADAgECAgYBnbE/C04wCgYIKoZIzj0EAwIwTzEj",
  "MCEGA1UEAwwaQXBwbGUgQXBwIEF0dGVzdGF0aW9uIENBIDExEzARBgNVBAoMCkFwcGxlIEluYy4xEzARBgNVBAgMCkNhbGlmb3Ju",
  "aWEwHhcNMjYwNDIwMTgxMzEyWhcNMjYwNDIzMTgxMzEyWjCBkTFJMEcGA1UEAwxAY2UwNDk4ZjU4NDgzZmJiNGRhMGQ3YjJjNjNh",
  "NWE1MzhmNTUyZDRhZGNiOWE0ZmE5MTYxOTVjNDk2MTNlNjU1ZDEaMBgGA1UECwwRQUFBIENlcnRpZmljYXRpb24xEzARBgNVBAoM",
  "CkFwcGxlIEluYy4xEzARBgNVBAgMCkNhbGlmb3JuaWEwWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAARDMlRKzzI9t3REPKrzOfVu",
  "fpXHJPrCwUJZ82XiRFZQsrX7KFvPVJvLYFlEEudoKiQn7q2p+1Lf7QsasX7Qn6m9o4ICJjCCAiIwDAYDVR0TAQH/BAIwADAOBgNV",
  "HQ8BAf8EBAMCBPAwFAYDVR0lBA0wCwYJKoZIhvdjZAQYMHoGCSqGSIb3Y2QIBQRtMGukAwIBCr+JMAMCAQC/iTEDAgEAv4kyAwIB",
  "AL+JMwMCAQC/iTQeBBwxMjM0NTY3ODkwLmNvbS5leGFtcGxlLm15YXBwv4k2AwIBBL+JNwMCAQC/iTkDAgEAv4k6AwIBAL+JOwMC",
  "AQCqAwIBADCB4AYJKoZIhvdjZAgHBIHSMIHPv4p4BgQEMjcuML+IUAMCAQK/inkJBAcxLjAuMjE2v4p7CQQHMjRBMzI1Yr+KfAYE",
  "BDI3LjC/in0GBAQyNy4wv4p+AwIBAL+KfwMCAQC/iwADAgEAv4sBAwIBAL+LAgMCAQC/iwMDAgEAv4sEAwIBAb+LBQMCAQC/iwoQ",
  "BA4yNC4xLjMyNS4wLjIsML+LCxAEDjI0LjEuMzI1LjAuMiwwv4sMEAQOMjQuMS4zMjUuMC4yLDC/iAIKBAhpcGhvbmVvc7+IBQoE",
  "CEludGVybmFsMDMGCSqGSIb3Y2QIAgQmMCShIgQgh7fQbZOkKU5G8BHma2zEAPC6sgcpl2xhlYC0KuYL/24wWAYJKoZIhvdjZAgG",
  "BEswSaNHBEUwQwwCMTEwPTAKDANva2ShAwEB/zAJDAJvYaEDAQH/MAsMBG9zZ26hAwEB/zALDARvZGVsoQMBAf8wCgwDb2NroQMB",
  "Af8wCgYIKoZIzj0EAwIDaAAwZQIwIbzHaPbRKcm2sa4JvDWyTX40yz9U2byxFxTho+HIM0HeYwF3HLyA3Nrqv3WDy/UdAjEApOox",
  "L7zeQV0yhvasPe31+c1ZYuEDxEU6rDrheFcVMRZepvV10+hFxgIWVMSpQu09WQJHMIICQzCCAcigAwIBAgIQCbrF4bxAGtnUU5W8",
  "OBoIVDAKBggqhkjOPQQDAzBSMSYwJAYDVQQDDB1BcHBsZSBBcHAgQXR0ZXN0YXRpb24gUm9vdCBDQTETMBEGA1UECgwKQXBwbGUg",
  "SW5jLjETMBEGA1UECAwKQ2FsaWZvcm5pYTAeFw0yMDAzMTgxODM5NTVaFw0zMDAzMTMwMDAwMDBaME8xIzAhBgNVBAMMGkFwcGxl",
  "IEFwcCBBdHRlc3RhdGlvbiBDQSAxMRMwEQYDVQQKDApBcHBsZSBJbmMuMRMwEQYDVQQIDApDYWxpZm9ybmlhMHYwEAYHKoZIzj0C",
  "AQYFK4EEACIDYgAErls3oHdNebI1j0Dn0fImJvHCX+8XgC3qs4JqWYdP+NKtFSV4mqJmBBkSSLY8uWcGnpjTY71eNw+/oI4ynoBz",
  "qYXndG6jWaL2bynbMq9FXiEWWNVnr54mfrJhTcIaZs6Zo2YwZDASBgNVHRMBAf8ECDAGAQH/AgEAMB8GA1UdIwQYMBaAFKyREFMz",
  "vb5oQf+nDKnl+url5YqhMB0GA1UdDgQWBBQ+410cBBmpybQx+IR01uHhV3LjmzAOBgNVHQ8BAf8EBAMCAQYwCgYIKoZIzj0EAwMD",
  "aQAwZgIxALu+iI1zjQUCz7z9Zm0JV1A1vNaHLD+EMEkmKe3R+RToeZkcmui1rvjTqFQz97YNBgIxAKs47dDMge0ApFLDukT5k2Nl",
  "U/7MKX8utN+fXr5aSsq2mVxLgg35BDhveAe7WJQ5t2dyZWNlaXB0WQ+JMIAGCSqGSIb3DQEHAqCAMIACAQExDzANBglghkgBZQME",
  "AgEFADCABgkqhkiG9w0BBwGggCSABIID6DGCBUEwJAIBAgIBAQQcMTIzNDU2Nzg5MC5jb20uZXhhbXBsZS5teWFwcDCCBCsCAQMC",
  "AQEEggQhMIIEHTCCA6OgAwIBAgIGAZ2xPwtOMAoGCCqGSM49BAMCME8xIzAhBgNVBAMMGkFwcGxlIEFwcCBBdHRlc3RhdGlvbiBD",
  "QSAxMRMwEQYDVQQKDApBcHBsZSBJbmMuMRMwEQYDVQQIDApDYWxpZm9ybmlhMB4XDTI2MDQyMDE4MTMxMloXDTI2MDQyMzE4MTMx",
  "MlowgZExSTBHBgNVBAMMQGNlMDQ5OGY1ODQ4M2ZiYjRkYTBkN2IyYzYzYTVhNTM4ZjU1MmQ0YWRjYjlhNGZhOTE2MTk1YzQ5NjEz",
  "ZTY1NWQxGjAYBgNVBAsMEUFBQSBDZXJ0aWZpY2F0aW9uMRMwEQYDVQQKDApBcHBsZSBJbmMuMRMwEQYDVQQIDApDYWxpZm9ybmlh",
  "MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEQzJUSs8yPbd0RDyq8zn1bn6VxyT6wsFCWfNl4kRWULK1+yhbz1Sby2BZRBLnaCok",
  "J+6tqftS3+0LGrF+0J+pvaOCAiYwggIiMAwGA1UdEwEB/wQCMAAwDgYDVR0PAQH/BAQDAgTwMBQGA1UdJQQNMAsGCSqGSIb3Y2QE",
  "GDB6BgkqhkiG92NkCAUEbTBrpAMCAQq/iTADAgEAv4kxAwIBAL+JMgMCAQC/iTMDAgEAv4k0HgQcMTIzNDU2Nzg5MC5jb20uZXhh",
  "bXBsZS5teWFwcL+JNgMCAQS/iTcDAgEAv4k5AwIBAL+JOgMCAQC/iTsDAgEAqgMCAQAwgeAGCSqGSIb3Y2QIBwSB0jCBz7+KeAYE",
  "BDI3LjC/iFADAgECv4p5CQQHMS4wLjIxNr+KewkEBzI0QTMyNWK/inwGBAQyNy4wv4p9BgQEMjcuML+KfgMCAQC/in8DAgEAv4sA",
  "AwIBAL+LAQMCAQC/iwIDAgEAv4sDAwIBAL+LBAMCAQG/iwUDAgEAv4sKEAQOMjQuMS4zMjUuMC4yLDC/iwsQBA4yNC4xLjMyNS4w",
  "LjIsML+LDBAEDjI0LjEuMzI1LjAuMiwwv4gCCgQIaXBob25lb3O/iAUKBAhJbnRlcm5hbDAzBgkqhkiG92NkCAIEJjAkoSIEIIe3",
  "0G2TpClORvAR5mtsxADwurIHKZdsYZWAtCrmC/9uMFgGCSqGSIb3Y2QIBgRLMEmjRwRFMEMMAjExMD0wCgwDb2tkoQMBAf8wCQwC",
  "b2GhAwEB/zALDARvc2duoQMBAf8wCwwEb2RlbKEDAQH/MAoMA29ja6EDAQH/MAoGCCoEggFdhkjOPQQDAgNoADBlAjAhvMdo9tEp",
  "ybaxrgm8NbJNfjTLP1TZvLEXFOGj4cgzQd5jAXccvIDc2uq/dYPL9R0CMQCk6jEvvN5BXTKG9qw97fX5zVli4QPERTqsOuF4VxUx",
  "Fl6m9XXT6EXGAhZUxKlC7T0wIAIBBAIBAQQYZXhhbXBsZV9zZXJ2ZXJfY2hhbGxlbmdlMGACAQUCAQEEWHJia3RNcTg5bXZEcFJD",
  "Sy84bGNQaGRMNGRXUXo5T1hJd0hHZGU1eFFmU3VJS3NOM09qT1dGOHUrdjBVQTRxOHZqQ1JnRUVKVGxjOUJ3aUl6TlNOT0hRPT0w",
  "DgIBBgIBAQQGQVRURVNUMBICAQcCAQEECnByb2R1Y3Rpb24wIAIBDAIBAQQYMjAyNi0wNC0yMVQxODoxMzoxMi4xNTNaMCACARUC",
  "AQEEGDIwMjYtMDctMjBUMTg6MTM6MTIuMTUzWgAAAAAAAKCAMIIDrjCCA1SgAwIBAgIQZgI4gAAUJvddiw4VLF9uQzAKBggqhkjO",
  "PQQDAjB8MTAwLgYDVQQDDCdBcHBsZSBBcHBsaWNhdGlvbiBJbnRlZ3JhdGlvbiBDQSA1IC0gRzExJjAkBgNVBAsMHUFwcGxlIENl",
  "cnRpZmljYXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzAeFw0yNjAxMjAyMDIxMDlaFw0y",
  "NzAyMTgxODU4MzlaMFoxNjA0BgNVBAMMLUFwcGxpY2F0aW9uIEF0dGVzdGF0aW9uIEZyYXVkIFJlY2VpcHQgU2lnbmluZzETMBEG",
  "A1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAAQ7GK7OxRmtilNRtEBEtKMDmVe0",
  "zb1bhR/gGm/t4o3vsPqww2oCpB9EbgBtWA5WimeAiQfzSICRQ4sgzqpMndxWo4IB2DCCAdQwDAYDVR0TAQH/BAIwADAfBgNVHSME",
  "GDAWgBTZF/5LZ5A4S5L0287VV4AUC489yTBDBggrBgEFBQcBAQQ3MDUwMwYIKwYBBQUHMAGGJ2h0dHA6Ly9vY3NwLmFwcGxlLmNv",
  "bS9vY3NwMDMtYWFpY2E1ZzEwMTCCARwGA1UdIASCARMwggEPMIIBCwYJKoZIhvdjZAUBMIH9MIHDBggrBgEFBQcCAjCBtgyBs1Jl",
  "bGlhbmNlIG9uIHRoaXMgY2VydGlmaWNhdGUgYnkgYW55IHBhcnR5IGFzc3VtZXMgYWNjZXB0YW5jZSBvZiB0aGUgdGhlbiBhcHBs",
  "aWNhYmxlIHN0YW5kYXJkIHRlcm1zIGFuZCBjb25kaXRpb25zIG9mIHVzZSwgY2VydGlmaWNhdGUgcG9saWN5IGFuZCBjZXJ0aWZp",
  "Y2F0aW9uIHByYWN0aWNlIHN0YXRlbWVudHMuMDUGCCsGAQUFBwIBFilodHRwOi8vd3d3LmFwcGxlLmNvbS9jZXJ0aWZpY2F0ZWF1",
  "dGhvcml0eTAdBgNVHQ4EFgQUNFWJcHRgDiLSumfPpVtpwiPxyigwDgYDVR0PAQH/BAQDAgeAMA8GCSqGSIb3Y2QMDwQCBQAwCgYI",
  "KoZIzj0EAwIDSAAwRQIgHGeXuYJF0dbccgS3mwI8r/h78u/4k33XIMReiuRlwusCIQD8yFmEzsmhLMKGqdSSdv3w0vYl3HX8fPiH",
  "RWl75h6qtDCCAvkwggJ/oAMCAQICEFb7g9Qr/43DN5kjtVqubr0wCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwSQXBwbGUgUm9vdCBD",
  "QSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UE",
  "BhMCVVMwHhcNMTkwMzIyMTc1MzMzWhcNMzQwMzIyMDAwMDAwWjB8MTAwLgYDVQQDDCdBcHBsZSBBcHBsaWNhdGlvbiBJbnRlZ3Jh",
  "dGlvbiBDQSA1IC0gRzExJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMu",
  "MQswCQYDVQQGEwJVUzBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABJLOY719hrGrKAo7HOGv+wSUgJGs9jHfpssoNW9ES+Eh5Vfd",
  "Eo2NuoJ8lb5J+r4zyq7NBBnxL0Ml+vS+s8uDfrqjgfcwgfQwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBS7sN6hWDOImqSK",
  "md6+veuv2sskqzBGBggrBgEFBQcBAQQ6MDgwNgYIKwYBBQUHMAGGKmh0dHA6Ly9vY3NwLmFwcGxlLmNvbS9vY3NwMDMtYXBwbGVy",
  "b290Y2FnMzA3BgNVHR8EMDAuMCygKqAohiZodHRwOi8vY3JsLmFwcGxlLmNvbS9hcHBsZXJvb3RjYWczLmNybDAdBgNVHQ4EFgQU",
  "2Rf+S2eQOEuS9NvO1VeAFAuPPckwDgYDVR0PAQH/BAQDAgEGMBAGCiqGSIb3Y2QGAgMEAgUAMAoGCCqGSM49BAMDA2gAMGUCMQCN",
  "b6afoeDk7FtOc4qSfz14U5iP9NofWB7DdUr+OKhMKoMaGqoNpmRt4bmT6NFVTO0CMGc7LLTh6DcHd8vV7HaoGjpVOz81asjF5pKw",
  "4WG+gElp5F8rqWzhEQKqzGHZOLdzSjCCAkMwggHJoAMCAQICCC3F/IjSxUuVMAoGCCqGSM49BAMDMGcxGzAZBgNVBAMMEkFwcGxl",
  "IFJvb3QgQ0EgLSBHMzEmMCQGA1UECwwdQXBwbGUgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkxEzARBgNVBAoMCkFwcGxlIEluYy4x",
  "CzAJBgNVBAYTAlVTMB4XDTE0MDQzMDE4MTkwNloXDTM5MDQzMDE4MTkwNlowZzEbMBkGA1UEAwwSQXBwbGUgUm9vdCBDQSAtIEcz",
  "MSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMw",
  "djAQBgcqhkjOPQIBBgUrgQQAIgNiAASY6S89QHKk7ZMicoETHN0QlfHFo05x3BQW2Q7lpgUqd2R7X04407scRLV/9R+2MmJdyemE",
  "W08wTxFaAP1YWAyl9Q8sTQdHE3Xal5eXbzFc7SudeyA72LlU2V6ZpDpRCjGjQjBAMB0GA1UdDgQWBBS7sN6hWDOImqSKmd6+veuv",
  "2sskqzAPBgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB/wQEAwIBBjAKBggqhkjOPQQDAwNoADBlAjEAg+nBxBZeGl00GNnt7/RsDgBG",
  "S7jfskYRxQ/95nqMoaZrzsID1Jz1k8Z0uGrfqiMVAjBtZooQytQN1E/NjUM+tIpjpTNu423aF7dkH8hTJvmIYnQ5Cxdby1GoDOgY",
  "A+eisigAADGB/TCB+gIBATCBkDB8MTAwLgYDVQQDDCdBcHBsZSBBcHBsaWNhdGlvbiBJbnRlZ3JhdGlvbiBDQSA1IC0gRzExJjAk",
  "BgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUwIQZgI4",
  "gAAUJvddiw4VLF9uQzANBglghkgBZQMEAgEFADAKBggqhkjOPQQDAgRHMEUCIFp+GIuJm5vqJhLtDX40gGP90KJtLoPyzcLEuKHY",
  "Mr9zAiEAgPafgwU16p2N6GvCC3Gj4BAb66R38+IP+Arn3QYbD9QAAAAAAABoYXV0aERhdGFY4vRGbWj5HrbBBiDLfmPHKDJEaF7h",
  "1kZ7VBYOdTFyBX8DQAAAAABhcHBhdHRlc3QAAAAAAAAAACDOBJj1hIP7tNoNeyxjpaU49VLUrcuaT6kWGVxJYT5lXaUBAgMmIAEh",
  "WCBDMlRKzzI9t3REPKrzOfVufpXHJPrCwUJZ82XiRFZQsiJYILX7KFvPVJvLYFlEEudoKiQn7q2p+1Lf7QsasX7Qn6m9ondhcHBs",
  "ZV9idW5kbGVfdmVyc2lvbl8wMWExeBxhcHBsZV92YWxpZGF0aW9uX2NhdGVnb3J5XzAxRAEAAAA=",
].join("");

function concat(...values: Uint8Array[]) {
  const result = new Uint8Array(
    values.reduce((sum, value) => sum + value.length, 0),
  );
  let offset = 0;
  for (const value of values) {
    result.set(value, offset);
    offset += value.length;
  }
  return result;
}

function cborText(value: string) {
  const bytes = encoder.encode(value);
  if (bytes.length >= 24) throw new Error("fixture text too long");
  return concat(Uint8Array.of(0x60 + bytes.length), bytes);
}

function cborBytes(value: Uint8Array) {
  if (value.length < 24) {
    return concat(Uint8Array.of(0x40 + value.length), value);
  }
  if (value.length <= 0xff) {
    return concat(Uint8Array.of(0x58, value.length), value);
  }
  throw new Error("fixture bytes too long");
}

function assertionObject(signature: Uint8Array, authData: Uint8Array) {
  return concat(
    Uint8Array.of(0xa2),
    cborText("signature"),
    cborBytes(signature),
    cborText("authenticatorData"),
    cborBytes(authData),
  );
}

Deno.test("Apple's published App Attest object passes the complete trust validation", async () => {
  const attestationObject = Uint8Array.from(
    atob(appleAttestationValidationSample),
    (character) => character.charCodeAt(0),
  );
  const verified = await verifyAttestation({
    attestationObject,
    keyId: "zgSY9YSD+7TaDXssY6WlOPVS1K3Lmk+pFhlcSWE+ZV0=",
    // Apple's sample uses this supplied client-data value directly. The live
    // handler passes SHA256(server challenge), matching the production client.
    clientDataHash: encoder.encode("example_server_challenge"),
    appId: "1234567890.com.example.myapp",
    allowedEnvironments: new Set(["production"]),
    allowedBundleVersions: new Set(["1"]),
    now: Date.parse("2026-04-21T18:13:12Z"),
  });

  assertEquals(verified.environment, "production");
  assertEquals(verified.bundleVersion, "1");
  assertEquals(verified.publicKeyJwk.kty, "EC");
  assertEquals(verified.publicKeyJwk.crv, "P-256");
  assertEquals(verified.receiptBase64.length > 0, true);
});

Deno.test("App Attest assertion verifies request hash and increasing counter", async () => {
  const appId = "1234567890.com.example.bodylog";
  const clientData = encoder.encode(
    "bil-app-attest-v1\n00000000-0000-4000-8000-000000000001\n" +
      "ai_coach.request\n" + "a".repeat(64) + "\nchallenge",
  );
  const authData = new Uint8Array(37);
  authData.set(
    new Uint8Array(
      await crypto.subtle.digest("SHA-256", encoder.encode(appId)),
    ),
    0,
  );
  new DataView(authData.buffer).setUint32(33, 7, false);
  const clientHash = new Uint8Array(
    await crypto.subtle.digest("SHA-256", clientData),
  );
  const { publicKey, privateKey } = generateKeyPairSync("ec", {
    namedCurve: "prime256v1",
  });
  const signature = sign("sha256", concat(authData, clientHash), privateKey);
  const assertion = assertionObject(signature, authData);

  assertEquals(
    await verifyAssertion({
      assertion,
      publicKeyJwk: publicKey.export({ format: "jwk" }) as Record<
        string,
        unknown
      >,
      previousCounter: 6,
      appId,
      clientData,
    }),
    7,
  );
  await assertRejects(
    () =>
      verifyAssertion({
        assertion,
        publicKeyJwk: publicKey.export({ format: "jwk" }) as Record<
          string,
          unknown
        >,
        previousCounter: 7,
        appId,
        clientData,
      }),
    Error,
    "assertion_counter_replay",
  );
});

Deno.test("App Attest assertion rejects a request-binding mismatch", async () => {
  const appId = "1234567890.com.example.bodylog";
  const signedClientData = encoder.encode("signed request");
  const authData = new Uint8Array(37);
  authData.set(
    new Uint8Array(
      await crypto.subtle.digest("SHA-256", encoder.encode(appId)),
    ),
    0,
  );
  new DataView(authData.buffer).setUint32(33, 1, false);
  const signedHash = new Uint8Array(
    await crypto.subtle.digest("SHA-256", signedClientData),
  );
  const { publicKey, privateKey } = generateKeyPairSync("ec", {
    namedCurve: "prime256v1",
  });
  const signature = sign("sha256", concat(authData, signedHash), privateKey);

  await assertRejects(
    () =>
      verifyAssertion({
        assertion: assertionObject(signature, authData),
        publicKeyJwk: publicKey.export({ format: "jwk" }) as Record<
          string,
          unknown
        >,
        previousCounter: 0,
        appId,
        clientData: encoder.encode("different request"),
      }),
    Error,
    "invalid_assertion_signature",
  );
});

Deno.test("App Attest issue limiting rejects before challenge persistence", async () => {
  const environmentNames = [
    "BIL_APP_ATTEST_APP_ID",
    "BIL_APP_ATTEST_ENVIRONMENTS",
    "BIL_APP_ATTEST_BUNDLE_VERSIONS",
  ] as const;
  const previous = new Map(
    environmentNames.map((name) => [name, Deno.env.get(name)]),
  );
  Deno.env.set("BIL_APP_ATTEST_APP_ID", "1234567890.com.example.bodylog");
  Deno.env.set("BIL_APP_ATTEST_ENVIRONMENTS", "production");
  Deno.env.set("BIL_APP_ATTEST_BUNDLE_VERSIONS", "42");

  try {
    for (
      const scenario of [
        {
          message: "rate limit exceeded",
          status: 429,
          code: "rate_limited",
        },
        {
          message: "database unavailable",
          status: 503,
          code: "rate_limit_unavailable",
        },
      ]
    ) {
      const rateCalls: Array<Record<string, unknown>> = [];
      let persistenceCalls = 0;
      const response = await handler(
        new Request("https://example.test/app-attest", {
          method: "POST",
          body: JSON.stringify({
            operation: "challenge",
            action: "ai_coach.request",
            payload_digest: "a".repeat(64),
            key_id: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
          }),
        }),
        {
          authenticate: (() =>
            Promise.resolve({
              ownerId: "00000000-0000-4000-8000-000000000001",
              auth: {
                rpc: (name: string, params: Record<string, unknown>) => {
                  rateCalls.push({ name, ...params });
                  return Promise.resolve({
                    data: null,
                    error: { message: scenario.message },
                  });
                },
              },
              admin: {
                from: () => {
                  persistenceCalls += 1;
                  throw new Error("challenge persistence must not run");
                },
              },
            })) as never,
        },
      );

      assertEquals(response.status, scenario.status);
      assertEquals(await response.json(), {
        allowed: false,
        trustworthy: false,
        error: scenario.code,
      });
      assertEquals(rateCalls, [{
        name: "bil_consume_rate_limit",
        p_action: "app_attest_issue",
        p_limit: 60,
        p_window_seconds: 3600,
      }]);
      assertEquals(persistenceCalls, 0);
    }
  } finally {
    for (const name of environmentNames) {
      const value = previous.get(name);
      if (value == null) Deno.env.delete(name);
      else Deno.env.set(name, value);
    }
  }
});
