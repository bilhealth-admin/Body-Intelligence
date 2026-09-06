import assert from "node:assert/strict";
import { test } from "node:test";
import { decodeJwt, exportPKCS8, generateKeyPair } from "npm:jose@6.1.0";

import {
  appleAccountEventFromClaims,
  type AppleTokenRpcClient,
  type AppleTokenServerConfiguration,
  applyAppleAccountEvent,
  decryptAppleRefreshToken,
  encryptAppleRefreshToken,
  exchangeAppleAuthorizationCode,
  loadAppleTokenServerConfiguration,
  normalizeAppleAuthorizationPayload,
  revokeAppleCredentialForDeletion,
  sha256Hex,
  storeAppleRefreshToken,
} from "./apple_sign_in_token_lifecycle.ts";

function base64(value: string | Uint8Array) {
  const bytes = typeof value === "string"
    ? new TextEncoder().encode(value)
    : value;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

async function configuration(): Promise<AppleTokenServerConfiguration> {
  const { privateKey } = await generateKeyPair("ES256", { extractable: true });
  return {
    teamId: "TESTTEAM01",
    keyId: "TESTKEY001",
    clientId: "com.example.bil",
    privateKeyPem: await exportPKCS8(privateKey),
    encryptionKey: crypto.getRandomValues(new Uint8Array(32)),
  };
}

class FakeAppleRpc implements AppleTokenRpcClient {
  readonly calls: Array<{ name: string; args: Record<string, unknown> }> = [];
  row: Record<string, unknown> | null = null;
  owner: string | null = null;

  rpc(name: string, args: Record<string, unknown>) {
    this.calls.push({ name, args });
    if (name === "bil_store_apple_sign_in_credential") {
      this.row = {
        user_id: args.p_user_id,
        apple_subject_hash: args.p_apple_subject_hash,
        refresh_token_ciphertext: args.p_refresh_token_ciphertext,
        refresh_token_iv: args.p_refresh_token_iv,
        client_id: args.p_client_id,
        encryption_key_version: args.p_encryption_key_version,
      };
      return Promise.resolve({ data: null, error: null });
    }
    if (name === "bil_read_apple_sign_in_credential") {
      return Promise.resolve({ data: this.row ? [this.row] : [], error: null });
    }
    if (name === "bil_read_apple_sign_in_owner_by_subject_hash") {
      return Promise.resolve({ data: this.owner, error: null });
    }
    if (name === "bil_delete_apple_sign_in_credential") {
      this.row = null;
      return Promise.resolve({ data: true, error: null });
    }
    if (name === "bil_queue_apple_account_deletion") {
      return Promise.resolve({
        data: { request_id: "request-a", status: "pending" },
        error: null,
      });
    }
    return Promise.resolve({
      data: null,
      error: { message: "unexpected rpc" },
    });
  }
}

test("authorization payload is bounded and normalized", () => {
  const payload = normalizeAppleAuthorizationPayload({
    authorization_code: "  authorization-code  ",
    identity_token: `header.${"x".repeat(40)}.signature`,
    raw_nonce: "n".repeat(32),
    apple_user_identifier: "  apple-subject  ",
  });
  assert.equal(payload.authorizationCode, "authorization-code");
  assert.equal(payload.appleUserIdentifier, "apple-subject");
  assert.throws(
    () => normalizeAppleAuthorizationPayload({ authorization_code: "short" }),
    /invalid_apple_authorization_payload/,
  );
});

test("server configuration rejects missing or incorrectly sized secrets", async () => {
  const valid = await configuration();
  const environment = new Map<string, string>([
    ["BIL_APPLE_SIGN_IN_TEAM_ID", valid.teamId],
    ["BIL_APPLE_SIGN_IN_KEY_ID", valid.keyId],
    ["BIL_APPLE_SIGN_IN_CLIENT_ID", valid.clientId],
    ["BIL_APPLE_SIGN_IN_PRIVATE_KEY_BASE64", base64(valid.privateKeyPem)],
    ["BIL_APPLE_TOKEN_ENCRYPTION_KEY_BASE64", base64(valid.encryptionKey)],
  ]);
  assert.equal(
    loadAppleTokenServerConfiguration((name) => environment.get(name)).clientId,
    valid.clientId,
  );
  environment.set("BIL_APPLE_TOKEN_ENCRYPTION_KEY_BASE64", base64("too-short"));
  assert.throws(
    () => loadAppleTokenServerConfiguration((name) => environment.get(name)),
    /apple_configuration_invalid_encryption_key/,
  );
});

test("refresh-token envelope is bound to owner and client", async () => {
  const key = crypto.getRandomValues(new Uint8Array(32));
  const encrypted = await encryptAppleRefreshToken(
    "provider-refresh-token",
    key,
    "owner-a",
    "com.example.bil",
  );
  assert.equal(
    await decryptAppleRefreshToken(
      encrypted.ciphertext,
      encrypted.iv,
      key,
      "owner-a",
      "com.example.bil",
    ),
    "provider-refresh-token",
  );
  await assert.rejects(
    () =>
      decryptAppleRefreshToken(
        encrypted.ciphertext,
        encrypted.iv,
        key,
        "owner-b",
        "com.example.bil",
      ),
    /apple_refresh_token_decryption_failed/,
  );
});

test("authorization code is exchanged once without a native redirect_uri", async () => {
  const config = await configuration();
  let requestBody = new URLSearchParams();
  const fakeFetch: typeof fetch = (_input, init) => {
    requestBody = init?.body as URLSearchParams;
    return Promise.resolve(Response.json({
      refresh_token: "refresh-token",
      id_token: "exchanged-identity-token",
    }));
  };
  const result = await exchangeAppleAuthorizationCode(
    "single-use-code",
    config,
    fakeFetch,
  );
  assert.equal(result.refreshToken, "refresh-token");
  assert.equal(requestBody.get("code"), "single-use-code");
  assert.equal(requestBody.get("grant_type"), "authorization_code");
  assert.equal(requestBody.has("redirect_uri"), false);
  assert.equal(
    decodeJwt(requestBody.get("client_secret")!).sub,
    config.clientId,
  );
});

test("stored refresh token is encrypted and revoked before custody removal", async () => {
  const client = new FakeAppleRpc();
  const config = await configuration();
  await storeAppleRefreshToken(client, {
    userId: "owner-a",
    appleSubject: "apple-subject-a",
    refreshToken: "refresh-token-a",
    configuration: config,
  });
  assert.notEqual(client.row?.refresh_token_ciphertext, "refresh-token-a");
  assert.equal(
    client.row?.apple_subject_hash,
    await sha256Hex("apple-subject-a"),
  );

  let revokeBody = new URLSearchParams();
  const fakeFetch: typeof fetch = (_input, init) => {
    revokeBody = init?.body as URLSearchParams;
    return Promise.resolve(new Response(null, { status: 200 }));
  };
  const environment = new Map<string, string>([
    ["BIL_APPLE_SIGN_IN_TEAM_ID", config.teamId],
    ["BIL_APPLE_SIGN_IN_KEY_ID", config.keyId],
    ["BIL_APPLE_SIGN_IN_CLIENT_ID", config.clientId],
    ["BIL_APPLE_SIGN_IN_PRIVATE_KEY_BASE64", base64(config.privateKeyPem)],
    ["BIL_APPLE_TOKEN_ENCRYPTION_KEY_BASE64", base64(config.encryptionKey)],
  ]);
  assert.deepEqual(
    await revokeAppleCredentialForDeletion(client, "owner-a", {
      readEnvironment: (name) => environment.get(name),
      fetchImplementation: fakeFetch,
    }),
    { status: "revoked" },
  );
  assert.equal(revokeBody.get("token"), "refresh-token-a");
  assert.equal(revokeBody.get("token_type_hint"), "refresh_token");
  assert.equal(client.row, null);
  assert.equal(
    client.calls.at(-1)?.name,
    "bil_delete_apple_sign_in_credential",
  );
});

test("failed Apple revocation preserves encrypted custody for retry", async () => {
  const client = new FakeAppleRpc();
  const config = await configuration();
  await storeAppleRefreshToken(client, {
    userId: "owner-a",
    appleSubject: "apple-subject-a",
    refreshToken: "refresh-token-a",
    configuration: config,
  });
  const environment = new Map<string, string>([
    ["BIL_APPLE_SIGN_IN_TEAM_ID", config.teamId],
    ["BIL_APPLE_SIGN_IN_KEY_ID", config.keyId],
    ["BIL_APPLE_SIGN_IN_CLIENT_ID", config.clientId],
    ["BIL_APPLE_SIGN_IN_PRIVATE_KEY_BASE64", base64(config.privateKeyPem)],
    ["BIL_APPLE_TOKEN_ENCRYPTION_KEY_BASE64", base64(config.encryptionKey)],
  ]);
  const unavailable: typeof fetch = () =>
    Promise.resolve(new Response(null, { status: 503 }));
  await assert.rejects(
    () =>
      revokeAppleCredentialForDeletion(client, "owner-a", {
        readEnvironment: (name) => environment.get(name),
        fetchImplementation: unavailable,
      }),
    /apple_token_revocation_failed/,
  );
  assert.notEqual(client.row, null);
  assert.notEqual(
    client.calls.at(-1)?.name,
    "bil_delete_apple_sign_in_credential",
  );
});

test("Apple account-change events normalize current and legacy names", () => {
  assert.deepEqual(
    appleAccountEventFromClaims({
      events: JSON.stringify({
        type: "account-deleted",
        sub: "apple-subject-a",
      }),
    }),
    { type: "account-deleted", subject: "apple-subject-a" },
  );
  assert.deepEqual(
    appleAccountEventFromClaims({
      events: { type: "account-delete", sub: "apple-subject-a" },
    }),
    { type: "account-deleted", subject: "apple-subject-a" },
  );
});

test("verified consent revocation queues deletion before removing mapping", async () => {
  const client = new FakeAppleRpc();
  client.owner = "owner-a";
  const result = await applyAppleAccountEvent(client, {
    type: "consent-revoked",
    subject: "apple-subject-a",
  });
  assert.deepEqual(result, { status: "deletion_queued" });
  const names = client.calls.map((call) => call.name);
  assert.ok(
    names.indexOf("bil_queue_apple_account_deletion") <
      names.indexOf("bil_delete_apple_sign_in_credential"),
  );
});
