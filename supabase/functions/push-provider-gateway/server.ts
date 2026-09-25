import { timingSafeEqual } from "node:crypto";

export type PushGatewayDependencies = {
  env?: (name: string) => string | undefined;
  fetch?: typeof fetch;
  now?: () => number;
};

type GatewayPayload = {
  token: string;
  title: string;
  body: string;
  deep_link: string | null;
  idempotency_key: string;
  data?: Record<string, unknown>;
};

const encoder = new TextEncoder();
const providerTimeoutMs = 10_000;
const maxBodyBytes = 8_192;

const json = (status: number, body: unknown, invalid = false) =>
  Response.json(body, {
    status,
    headers: invalid ? { "x-bil-token-status": "invalid" } : undefined,
  });

async function secretMatches(provided: string, expected: string) {
  const [left, right] = await Promise.all([
    crypto.subtle.digest("SHA-256", encoder.encode(provided)),
    crypto.subtle.digest("SHA-256", encoder.encode(expected)),
  ]);
  return timingSafeEqual(new Uint8Array(left), new Uint8Array(right));
}

const base64Url = (bytes: Uint8Array) =>
  btoa(String.fromCharCode(...bytes))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replace(/=+$/, "");

const encodeJson = (value: unknown) => base64Url(encoder.encode(JSON.stringify(value)));

function pemBytes(pem: string): Uint8Array {
  const body = pem.replace(/-----BEGIN [^-]+-----|-----END [^-]+-----|\s/g, "");
  if (!body) throw new Error("empty_private_key");
  return Uint8Array.from(atob(body), (character) => character.charCodeAt(0));
}

async function signedJwt(options: {
  algorithm: "RS256" | "ES256";
  privateKey: string;
  header: Record<string, unknown>;
  claims: Record<string, unknown>;
}) {
  const header = encodeJson({ alg: options.algorithm, typ: "JWT", ...options.header });
  const claims = encodeJson(options.claims);
  const input = `${header}.${claims}`;
  const rsa = options.algorithm === "RS256";
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemBytes(options.privateKey).slice().buffer as ArrayBuffer,
    rsa
      ? { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }
      : { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(await crypto.subtle.sign(
    rsa
      ? { name: "RSASSA-PKCS1-v1_5" }
      : { name: "ECDSA", hash: "SHA-256" },
    key,
    encoder.encode(input),
  ));
  return `${input}.${base64Url(signature)}`;
}

function boundedText(value: unknown, maximum: number): string | null {
  if (typeof value !== "string") return null;
  const result = value.trim();
  return result && result.length <= maximum ? result : null;
}

function parsePayload(value: unknown): GatewayPayload | null {
  if (!value || typeof value !== "object") return null;
  const raw = value as Record<string, unknown>;
  const token = boundedText(raw.token, 4_096);
  const title = boundedText(raw.title, 180);
  const body = boundedText(raw.body, 512);
  const idempotencyKey = boundedText(raw.idempotency_key, 512);
  const deepLink = raw.deep_link == null ? null : boundedText(raw.deep_link, 512);
  if (!token || !title || !body || !idempotencyKey) return null;
  if (deepLink != null && !deepLink.startsWith("bil://")) return null;
  const data = raw.data && typeof raw.data === "object"
    ? raw.data as Record<string, unknown>
    : undefined;
  return { token, title, body, deep_link: deepLink, idempotency_key: idempotencyKey, data };
}

async function readRequest(request: Request): Promise<GatewayPayload | null> {
  const length = Number(request.headers.get("content-length") ?? "0");
  if (Number.isFinite(length) && length > maxBodyBytes) return null;
  const text = await request.text();
  if (encoder.encode(text).byteLength > maxBodyBytes) return null;
  try {
    return parsePayload(JSON.parse(text));
  } catch {
    return null;
  }
}

async function fcmAccessToken(
  serviceAccount: Record<string, unknown>,
  runtimeFetch: typeof fetch,
  now: number,
) {
  const clientEmail = boundedText(serviceAccount.client_email, 512);
  const privateKey = boundedText(serviceAccount.private_key, 16_384);
  const tokenUri = boundedText(serviceAccount.token_uri, 1_024) ??
    "https://oauth2.googleapis.com/token";
  if (!clientEmail || !privateKey || tokenUri !== "https://oauth2.googleapis.com/token") {
    throw new Error("invalid_service_account");
  }
  const issuedAt = Math.floor(now / 1_000);
  const assertion = await signedJwt({
    algorithm: "RS256",
    privateKey,
    header: {},
    claims: {
      iss: clientEmail,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: tokenUri,
      iat: issuedAt,
      exp: issuedAt + 3_000,
    },
  });
  const response = await runtimeFetch(tokenUri, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) throw new Error("fcm_oauth_failed");
  const result = await response.json() as Record<string, unknown>;
  const accessToken = boundedText(result.access_token, 8_192);
  if (!accessToken) throw new Error("fcm_oauth_failed");
  return accessToken;
}

async function sendFcm(
  payload: GatewayPayload,
  env: (name: string) => string | undefined,
  runtimeFetch: typeof fetch,
  now: number,
) {
  const raw = env("BIL_FCM_SERVICE_ACCOUNT_JSON");
  const projectId = boundedText(env("BIL_FCM_PROJECT_ID"), 256);
  if (!raw || !projectId || !/^[a-z0-9-]+$/.test(projectId)) {
    return json(503, { error: "fcm_not_configured" });
  }
  let serviceAccount: Record<string, unknown>;
  try {
    serviceAccount = JSON.parse(raw);
  } catch {
    return json(503, { error: "fcm_not_configured" });
  }
  try {
    const accessToken = await fcmAccessToken(serviceAccount, runtimeFetch, now);
    const response = await runtimeFetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${accessToken}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token: payload.token,
            notification: { title: payload.title, body: payload.body },
            data: {
              deep_link: payload.deep_link ?? "",
              ...Object.fromEntries(
                Object.entries(payload.data ?? {}).map(([key, value]) => [key, String(value)]),
              ),
            },
            android: { priority: "high" },
          },
        }),
      },
    );
    if (response.ok) return json(200, { accepted: true });
    const detail = await response.text();
    const invalid = response.status === 404 ||
      /UNREGISTERED|registration-token-not-registered/i.test(detail);
    return json(invalid ? 410 : 502, { error: "fcm_rejected" }, invalid);
  } catch {
    return json(502, { error: "fcm_unavailable" });
  }
}

async function sendApns(
  payload: GatewayPayload,
  env: (name: string) => string | undefined,
  runtimeFetch: typeof fetch,
  now: number,
) {
  const privateKey = env("BIL_APNS_AUTH_KEY_P8")?.trim();
  const keyId = boundedText(env("BIL_APNS_KEY_ID"), 32);
  const teamId = boundedText(env("BIL_APNS_TEAM_ID"), 32);
  const topic = boundedText(env("BIL_APNS_BUNDLE_ID"), 256);
  if (!privateKey || !keyId || !teamId || !topic ||
      !/^[A-Z0-9]{10}$/.test(keyId) || !/^[A-Z0-9]{10}$/.test(teamId)) {
    return json(503, { error: "apns_not_configured" });
  }
  if (!/^[a-fA-F0-9]{64}$/.test(payload.token)) {
    return json(410, { error: "invalid_device_token" }, true);
  }
  try {
    const issuedAt = Math.floor(now / 1_000);
    const bearer = await signedJwt({
      algorithm: "ES256",
      privateKey,
      header: { kid: keyId },
      claims: { iss: teamId, iat: issuedAt },
    });
    const collapseDigest = new Uint8Array(await crypto.subtle.digest(
      "SHA-256",
      encoder.encode(payload.idempotency_key),
    ));
    const response = await runtimeFetch(
      `https://api.push.apple.com/3/device/${payload.token}`,
      {
        method: "POST",
        headers: {
          authorization: `bearer ${bearer}`,
          "content-type": "application/json",
          "apns-topic": topic,
          "apns-push-type": "alert",
          "apns-priority": "10",
          "apns-collapse-id": base64Url(collapseDigest).slice(0, 64),
        },
        body: JSON.stringify({
          aps: {
            alert: { title: payload.title, body: payload.body },
            sound: "default",
          },
          deep_link: payload.deep_link,
          data: payload.data ?? {},
        }),
      },
    );
    if (response.ok) return json(200, { accepted: true });
    const detail = await response.text();
    const invalid = response.status === 410 ||
      /BadDeviceToken|DeviceTokenNotForTopic|Unregistered/i.test(detail);
    return json(invalid ? 410 : 502, { error: "apns_rejected" }, invalid);
  } catch {
    return json(502, { error: "apns_unavailable" });
  }
}

export async function handler(
  request: Request,
  dependencies: PushGatewayDependencies = {},
): Promise<Response> {
  if (request.method !== "POST") return json(405, { error: "method_not_allowed" });
  const env = dependencies.env ?? ((name: string) => Deno.env.get(name));
  const expected = env("BIL_PUSH_GATEWAY_SECRET");
  if (!expected) return json(503, { error: "gateway_not_configured" });
  const supplied = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  if (!await secretMatches(supplied, expected)) return json(401, { error: "unauthorized" });
  const provider = new URL(request.url).searchParams.get("provider");
  if (provider !== "fcm" && provider !== "apns") {
    return json(400, { error: "unsupported_provider" });
  }
  const payload = await readRequest(request);
  if (!payload) return json(400, { error: "invalid_payload" });
  const runtimeFetch = dependencies.fetch ?? fetch;
  const now = (dependencies.now ?? Date.now)();
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), providerTimeoutMs);
  const boundedFetch: typeof fetch = (input, init = {}) =>
    runtimeFetch(input, { ...init, signal: controller.signal });
  try {
    return provider === "fcm"
      ? await sendFcm(payload, env, boundedFetch, now)
      : await sendApns(payload, env, boundedFetch, now);
  } finally {
    clearTimeout(timeout);
  }
}
