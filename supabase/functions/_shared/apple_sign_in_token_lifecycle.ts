import {
  createRemoteJWKSet,
  importPKCS8,
  type JWTPayload,
  jwtVerify,
  SignJWT,
} from "npm:jose@6.1.0";

const appleIssuer = "https://appleid.apple.com";
const appleTokenEndpoint = `${appleIssuer}/auth/token`;
const appleRevokeEndpoint = `${appleIssuer}/auth/revoke`;
const appleJwks = createRemoteJWKSet(new URL(`${appleIssuer}/auth/keys`));
const encoder = new TextEncoder();
const decoder = new TextDecoder();

export type AppleEnvironmentReader = (name: string) => string | undefined;
export type AppleFetch = typeof fetch;

export interface AppleTokenRpcClient {
  rpc(
    functionName: string,
    args: Record<string, unknown>,
  ): PromiseLike<{
    data: unknown;
    error: { message?: string } | null;
  }>;
}

export interface AppleTokenServerConfiguration {
  teamId: string;
  keyId: string;
  clientId: string;
  privateKeyPem: string;
  encryptionKey: Uint8Array;
}

export interface AppleAuthorizationPayload {
  authorizationCode: string;
  identityToken: string;
  rawNonce: string;
  appleUserIdentifier: string;
}

export interface AppleIdentityClaims {
  subject: string;
  nonce?: string;
  payload: JWTPayload;
}

interface AppleCredentialEnvelope {
  userId: string;
  appleSubjectHash: string;
  refreshTokenCiphertext: string;
  refreshTokenIv: string;
  clientId: string;
  encryptionKeyVersion: number;
}

export type AppleAccountEventType =
  | "email-enabled"
  | "email-disabled"
  | "consent-revoked"
  | "account-deleted";

export interface AppleAccountEvent {
  type: AppleAccountEventType;
  subject: string;
}

function requiredEnvironment(
  readEnvironment: AppleEnvironmentReader,
  name: string,
) {
  const value = readEnvironment(name)?.trim();
  if (!value) throw new Error(`apple_configuration_missing:${name}`);
  return value;
}

export function decodeBase64Secret(value: string) {
  const normalized = value.trim().replace(/\s+/g, "")
    .replace(/-/g, "+").replace(/_/g, "/");
  if (!normalized || !/^[A-Za-z0-9+/]*={0,2}$/.test(normalized)) {
    throw new Error("apple_configuration_invalid_base64");
  }
  let binary: string;
  try {
    binary = atob(normalized);
  } catch (_error) {
    throw new Error("apple_configuration_invalid_base64");
  }
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

export function loadAppleTokenServerConfiguration(
  readEnvironment: AppleEnvironmentReader = (name) => Deno.env.get(name),
): AppleTokenServerConfiguration {
  const privateKeyBytes = decodeBase64Secret(requiredEnvironment(
    readEnvironment,
    "BIL_APPLE_SIGN_IN_PRIVATE_KEY_BASE64",
  ));
  const privateKeyPem = decoder.decode(privateKeyBytes).trim();
  if (
    !privateKeyPem.startsWith("-----BEGIN PRIVATE KEY-----") ||
    !privateKeyPem.endsWith("-----END PRIVATE KEY-----")
  ) {
    throw new Error("apple_configuration_invalid_private_key");
  }
  const encryptionKey = decodeBase64Secret(requiredEnvironment(
    readEnvironment,
    "BIL_APPLE_TOKEN_ENCRYPTION_KEY_BASE64",
  ));
  if (encryptionKey.byteLength !== 32) {
    throw new Error("apple_configuration_invalid_encryption_key");
  }

  const teamId = requiredEnvironment(
    readEnvironment,
    "BIL_APPLE_SIGN_IN_TEAM_ID",
  );
  const keyId = requiredEnvironment(
    readEnvironment,
    "BIL_APPLE_SIGN_IN_KEY_ID",
  );
  const clientId = requiredEnvironment(
    readEnvironment,
    "BIL_APPLE_SIGN_IN_CLIENT_ID",
  );
  if (
    teamId.length > 64 || keyId.length > 64 || clientId.length > 255 ||
    !/^[A-Za-z0-9.-]+$/.test(clientId)
  ) {
    throw new Error("apple_configuration_invalid_identifier");
  }
  return { teamId, keyId, clientId, privateKeyPem, encryptionKey };
}

export function loadAppleClientId(
  readEnvironment: AppleEnvironmentReader = (name) => Deno.env.get(name),
) {
  const clientId = requiredEnvironment(
    readEnvironment,
    "BIL_APPLE_SIGN_IN_CLIENT_ID",
  );
  if (clientId.length > 255 || !/^[A-Za-z0-9.-]+$/.test(clientId)) {
    throw new Error("apple_configuration_invalid_identifier");
  }
  return clientId;
}

export function normalizeAppleAuthorizationPayload(
  value: unknown,
): AppleAuthorizationPayload {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("invalid_apple_authorization_payload");
  }
  const body = value as Record<string, unknown>;
  const authorizationCode = typeof body.authorization_code === "string"
    ? body.authorization_code.trim()
    : "";
  const identityToken = typeof body.identity_token === "string"
    ? body.identity_token.trim()
    : "";
  const rawNonce = typeof body.raw_nonce === "string"
    ? body.raw_nonce.trim()
    : "";
  const appleUserIdentifier = typeof body.apple_user_identifier === "string"
    ? body.apple_user_identifier.trim()
    : "";

  if (
    authorizationCode.length < 8 || authorizationCode.length > 4096 ||
    identityToken.length < 32 || identityToken.length > 16384 ||
    rawNonce.length < 16 || rawNonce.length > 1024 ||
    appleUserIdentifier.length < 3 || appleUserIdentifier.length > 1024
  ) {
    throw new Error("invalid_apple_authorization_payload");
  }
  return {
    authorizationCode,
    identityToken,
    rawNonce,
    appleUserIdentifier,
  };
}

export async function sha256Hex(value: string) {
  const digest = new Uint8Array(
    await crypto.subtle.digest("SHA-256", encoder.encode(value)),
  );
  return [...digest].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function constantTimeEqual(left: string, right: string) {
  const leftBytes = encoder.encode(left);
  const rightBytes = encoder.encode(right);
  let difference = leftBytes.length ^ rightBytes.length;
  const length = Math.max(leftBytes.length, rightBytes.length);
  for (let index = 0; index < length; index += 1) {
    difference |= (leftBytes[index] ?? 0) ^ (rightBytes[index] ?? 0);
  }
  return difference === 0;
}

export async function verifyAppleIdentityToken(
  token: string,
  clientId: string,
): Promise<AppleIdentityClaims> {
  const { payload } = await jwtVerify(token, appleJwks, {
    algorithms: ["RS256"],
    issuer: appleIssuer,
    audience: clientId,
  });
  const subject = payload.sub?.trim() ?? "";
  if (!subject) throw new Error("apple_identity_subject_missing");
  const nonce = typeof payload.nonce === "string"
    ? payload.nonce.trim()
    : undefined;
  return { subject, nonce, payload };
}

export async function verifyAppleNonce(
  claims: AppleIdentityClaims,
  rawNonce: string,
) {
  const expected = await sha256Hex(rawNonce);
  if (!claims.nonce || !constantTimeEqual(claims.nonce, expected)) {
    throw new Error("apple_identity_nonce_mismatch");
  }
}

export async function createAppleClientSecret(
  configuration: AppleTokenServerConfiguration,
  nowSeconds = Math.floor(Date.now() / 1000),
) {
  const privateKey = await importPKCS8(configuration.privateKeyPem, "ES256");
  return new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: configuration.keyId })
    .setIssuer(configuration.teamId)
    .setSubject(configuration.clientId)
    .setAudience(appleIssuer)
    .setIssuedAt(nowSeconds)
    .setExpirationTime(nowSeconds + 300)
    .sign(privateKey);
}

export async function exchangeAppleAuthorizationCode(
  authorizationCode: string,
  configuration: AppleTokenServerConfiguration,
  fetchImplementation: AppleFetch = fetch,
) {
  const body = new URLSearchParams({
    client_id: configuration.clientId,
    client_secret: await createAppleClientSecret(configuration),
    code: authorizationCode,
    grant_type: "authorization_code",
  });
  const response = await fetchImplementation(appleTokenEndpoint, {
    method: "POST",
    headers: {
      accept: "application/json",
      "content-type": "application/x-www-form-urlencoded",
    },
    body,
  });
  if (!response.ok) {
    throw new Error("apple_authorization_code_exchange_failed");
  }
  let result: Record<string, unknown>;
  try {
    result = await response.json() as Record<string, unknown>;
  } catch (_error) {
    throw new Error("apple_authorization_code_exchange_failed");
  }
  const refreshToken = typeof result.refresh_token === "string"
    ? result.refresh_token.trim()
    : "";
  const identityToken = typeof result.id_token === "string"
    ? result.id_token.trim()
    : "";
  if (!refreshToken || !identityToken) {
    throw new Error("apple_authorization_code_exchange_incomplete");
  }
  return { refreshToken, identityToken };
}

function encodeBase64(value: Uint8Array) {
  let binary = "";
  for (const byte of value) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function envelopeAdditionalData(userId: string, clientId: string) {
  return encoder.encode(`bil.apple.refresh.v1\u0000${userId}\u0000${clientId}`);
}

function ownedArrayBuffer(value: Uint8Array) {
  const copy = new Uint8Array(value.byteLength);
  copy.set(value);
  return copy.buffer;
}

export async function encryptAppleRefreshToken(
  refreshToken: string,
  encryptionKey: Uint8Array,
  userId: string,
  clientId: string,
) {
  if (!refreshToken || encryptionKey.byteLength !== 32) {
    throw new Error("invalid_apple_refresh_token_envelope");
  }
  const key = await crypto.subtle.importKey(
    "raw",
    ownedArrayBuffer(encryptionKey),
    "AES-GCM",
    false,
    ["encrypt"],
  );
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ciphertext = new Uint8Array(
    await crypto.subtle.encrypt(
      {
        name: "AES-GCM",
        iv,
        additionalData: envelopeAdditionalData(userId, clientId),
        tagLength: 128,
      },
      key,
      encoder.encode(refreshToken),
    ),
  );
  return {
    ciphertext: encodeBase64(ciphertext),
    iv: encodeBase64(iv),
  };
}

export async function decryptAppleRefreshToken(
  ciphertext: string,
  iv: string,
  encryptionKey: Uint8Array,
  userId: string,
  clientId: string,
) {
  if (encryptionKey.byteLength !== 32) {
    throw new Error("invalid_apple_refresh_token_envelope");
  }
  const key = await crypto.subtle.importKey(
    "raw",
    ownedArrayBuffer(encryptionKey),
    "AES-GCM",
    false,
    ["decrypt"],
  );
  try {
    const plaintext = await crypto.subtle.decrypt(
      {
        name: "AES-GCM",
        iv: decodeBase64Secret(iv),
        additionalData: envelopeAdditionalData(userId, clientId),
        tagLength: 128,
      },
      key,
      decodeBase64Secret(ciphertext),
    );
    const token = decoder.decode(plaintext).trim();
    if (!token) throw new Error("empty");
    return token;
  } catch (_error) {
    throw new Error("apple_refresh_token_decryption_failed");
  }
}

async function rpc(
  client: AppleTokenRpcClient,
  name: string,
  args: Record<string, unknown>,
) {
  const { data, error } = await client.rpc(name, args);
  if (error) throw new Error(`${name}_failed`);
  return data;
}

export async function storeAppleRefreshToken(
  client: AppleTokenRpcClient,
  values: {
    userId: string;
    appleSubject: string;
    refreshToken: string;
    configuration: AppleTokenServerConfiguration;
  },
) {
  const envelope = await encryptAppleRefreshToken(
    values.refreshToken,
    values.configuration.encryptionKey,
    values.userId,
    values.configuration.clientId,
  );
  await rpc(client, "bil_store_apple_sign_in_credential", {
    p_user_id: values.userId,
    p_apple_subject_hash: await sha256Hex(values.appleSubject),
    p_refresh_token_ciphertext: envelope.ciphertext,
    p_refresh_token_iv: envelope.iv,
    p_client_id: values.configuration.clientId,
    p_encryption_key_version: 1,
  });
}

function record(value: unknown) {
  const candidate = Array.isArray(value) ? value[0] : value;
  return candidate && typeof candidate === "object" && !Array.isArray(candidate)
    ? candidate as Record<string, unknown>
    : null;
}

function appleCredentialEnvelope(
  value: unknown,
): AppleCredentialEnvelope | null {
  const row = record(value);
  if (!row) return null;
  const userId = typeof row.user_id === "string" ? row.user_id.trim() : "";
  const appleSubjectHash = typeof row.apple_subject_hash === "string"
    ? row.apple_subject_hash.trim()
    : "";
  const refreshTokenCiphertext =
    typeof row.refresh_token_ciphertext === "string"
      ? row.refresh_token_ciphertext.trim()
      : "";
  const refreshTokenIv = typeof row.refresh_token_iv === "string"
    ? row.refresh_token_iv.trim()
    : "";
  const clientId = typeof row.client_id === "string"
    ? row.client_id.trim()
    : "";
  const encryptionKeyVersion = Number(row.encryption_key_version);
  if (
    !userId || !/^[0-9a-f]{64}$/.test(appleSubjectHash) ||
    !refreshTokenCiphertext || !refreshTokenIv || !clientId ||
    encryptionKeyVersion !== 1
  ) {
    throw new Error("apple_credential_record_invalid");
  }
  return {
    userId,
    appleSubjectHash,
    refreshTokenCiphertext,
    refreshTokenIv,
    clientId,
    encryptionKeyVersion,
  };
}

export async function revokeAppleCredentialForDeletion(
  client: AppleTokenRpcClient,
  userId: string,
  options: {
    readEnvironment?: AppleEnvironmentReader;
    fetchImplementation?: AppleFetch;
  } = {},
) {
  const stored = appleCredentialEnvelope(
    await rpc(
      client,
      "bil_read_apple_sign_in_credential",
      { p_user_id: userId },
    ),
  );
  if (!stored) return { status: "not_available" as const };

  const configuration = loadAppleTokenServerConfiguration(
    options.readEnvironment,
  );
  if (!constantTimeEqual(stored.clientId, configuration.clientId)) {
    throw new Error("apple_credential_client_mismatch");
  }
  const refreshToken = await decryptAppleRefreshToken(
    stored.refreshTokenCiphertext,
    stored.refreshTokenIv,
    configuration.encryptionKey,
    stored.userId,
    stored.clientId,
  );
  await revokeAppleRefreshToken(
    refreshToken,
    configuration,
    options.fetchImplementation,
  );

  await rpc(client, "bil_delete_apple_sign_in_credential", {
    p_user_id: userId,
  });
  return { status: "revoked" as const };
}

export async function revokeAppleRefreshToken(
  refreshToken: string,
  configuration: AppleTokenServerConfiguration,
  fetchImplementation: AppleFetch = fetch,
) {
  const body = new URLSearchParams({
    client_id: configuration.clientId,
    client_secret: await createAppleClientSecret(configuration),
    token: refreshToken,
    token_type_hint: "refresh_token",
  });
  const response = await fetchImplementation(appleRevokeEndpoint, {
    method: "POST",
    headers: {
      accept: "application/json",
      "content-type": "application/x-www-form-urlencoded",
    },
    body,
  });
  if (!response.ok) throw new Error("apple_token_revocation_failed");
}

export function appleAccountEventFromClaims(
  payload: JWTPayload,
): AppleAccountEvent {
  let events: unknown = payload.events;
  if (typeof events === "string") {
    try {
      events = JSON.parse(events);
    } catch (_error) {
      throw new Error("invalid_apple_notification_events");
    }
  }
  const candidate = Array.isArray(events) ? events[0] : events;
  if (!candidate || typeof candidate !== "object" || Array.isArray(candidate)) {
    throw new Error("invalid_apple_notification_events");
  }
  const event = candidate as Record<string, unknown>;
  const rawType = typeof event.type === "string" ? event.type.trim() : "";
  const type = rawType === "account-delete" ? "account-deleted" : rawType;
  const supported = new Set<AppleAccountEventType>([
    "email-enabled",
    "email-disabled",
    "consent-revoked",
    "account-deleted",
  ]);
  const subject = typeof event.sub === "string" ? event.sub.trim() : "";
  if (!supported.has(type as AppleAccountEventType) || !subject) {
    throw new Error("invalid_apple_notification_events");
  }
  return { type: type as AppleAccountEventType, subject };
}

export async function applyAppleAccountEvent(
  client: AppleTokenRpcClient,
  event: AppleAccountEvent,
) {
  if (event.type === "email-enabled" || event.type === "email-disabled") {
    // BIL does not retain or send to Apple's relay address. These verified
    // events therefore require no user-data mutation.
    return { status: "acknowledged" as const };
  }
  const owner = await rpc(
    client,
    "bil_read_apple_sign_in_owner_by_subject_hash",
    { p_apple_subject_hash: await sha256Hex(event.subject) },
  );
  const userId = typeof owner === "string" ? owner.trim() : "";
  if (!userId) return { status: "unknown_subject" as const };

  const reason = event.type === "consent-revoked"
    ? "apple_consent_revoked"
    : "apple_account_deleted";
  // Queue first. If credential cleanup then fails, Apple's retry still finds
  // the owner mapping and the queue's unique active-request guard is idempotent.
  await rpc(client, "bil_queue_apple_account_deletion", {
    p_user_id: userId,
    p_reason: reason,
  });
  await rpc(client, "bil_delete_apple_sign_in_credential", {
    p_user_id: userId,
  });
  return { status: "deletion_queued" as const };
}

export async function verifyAppleNotification(
  signedPayload: string,
  clientId: string,
) {
  const { payload } = await jwtVerify(signedPayload, appleJwks, {
    algorithms: ["RS256"],
    issuer: appleIssuer,
    audience: clientId,
  });
  return appleAccountEventFromClaims(payload);
}
