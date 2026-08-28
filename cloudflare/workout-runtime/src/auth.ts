import {
  createLocalJWKSet,
  decodeProtectedHeader,
  jwtVerify,
  type JSONWebKeySet,
  type JWTPayload,
} from "jose";

import { readBoundedJson } from "./bounded-json";

const maximumTokenLength = 8192;
const maximumJwksBytes = 64 * 1024;
const maximumUserBytes = 64 * 1024;
const jwksCacheMilliseconds = 10 * 60_000;
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

// Public signing keys are safe to share across requests in one isolate. The
// cache contains no user data and is deliberately bypassed by injected test
// fetchers. Entitlement rows are never cached here.
let productionJwksCache:
  | { expiresAt: number; jwks: JSONWebKeySet; origin: string }
  | undefined;
let productionJwksLoad:
  | { origin: string; promise: Promise<JSONWebKeySet> }
  | undefined;

export type RuntimeFetch = (
  input: RequestInfo | URL,
  init?: RequestInit,
) => Promise<Response>;

export interface AuthenticatedUser {
  readonly id: string;
  readonly token: string;
}

export class AuthenticationError extends Error {
  constructor(readonly kind: "unauthorized" | "unavailable") {
    super(kind);
    this.name = "AuthenticationError";
  }
}

export function bearerToken(request: Request): string {
  const authorization = request.headers.get("authorization");
  if (authorization === null) {
    throw new AuthenticationError("unauthorized");
  }
  const match = /^Bearer ([A-Za-z0-9._~-]+)$/.exec(authorization);
  if (match?.[1] === undefined || match[1].length > maximumTokenLength) {
    throw new AuthenticationError("unauthorized");
  }
  return match[1];
}

export async function verifySupabaseJwt(
  token: string,
  env: Env,
  runtimeFetch: RuntimeFetch = fetch,
): Promise<AuthenticatedUser> {
  const origin = supabaseOrigin(env.SUPABASE_URL);
  let header: ReturnType<typeof decodeProtectedHeader>;
  try {
    header = decodeProtectedHeader(token);
  } catch {
    throw new AuthenticationError("unauthorized");
  }
  if (header.alg === "HS256") {
    return verifyWithSupabaseAuthServer(token, env, origin, runtimeFetch);
  }
  if (
    (header.alg !== "RS256" && header.alg !== "ES256") ||
    typeof header.kid !== "string" ||
    header.kid.length === 0 ||
    header.kid.length > 256
  ) {
    throw new AuthenticationError("unauthorized");
  }

  let jwks: JSONWebKeySet;
  try {
    jwks = await loadJwks(origin, runtimeFetch);
  } catch {
    throw new AuthenticationError("unavailable");
  }
  let payload: JWTPayload;
  try {
    ({ payload } = await jwtVerify(token, createLocalJWKSet(jwks), {
      algorithms: ["RS256", "ES256"],
      audience: "authenticated",
      clockTolerance: 5,
      issuer: `${origin}/auth/v1`,
    }));
  } catch {
    throw new AuthenticationError("unauthorized");
  }
  return authenticatedPayload(payload, token);
}

async function loadJwks(
  origin: string,
  runtimeFetch: RuntimeFetch,
): Promise<JSONWebKeySet> {
  const cacheEligible = runtimeFetch === fetch;
  const now = Date.now();
  if (
    cacheEligible &&
    productionJwksCache?.origin === origin &&
    productionJwksCache.expiresAt > now
  ) {
    return productionJwksCache.jwks;
  }
  if (cacheEligible && productionJwksLoad?.origin === origin) {
    return productionJwksLoad.promise;
  }
  const pending = fetchJwks(origin, runtimeFetch);
  if (cacheEligible) productionJwksLoad = { origin, promise: pending };
  try {
    const jwks = await pending;
    if (cacheEligible) {
      productionJwksCache = {
        expiresAt: Date.now() + jwksCacheMilliseconds,
        jwks,
        origin,
      };
    }
    return jwks;
  } finally {
    if (productionJwksLoad?.promise === pending) {
      productionJwksLoad = undefined;
    }
  }
}

async function fetchJwks(
  origin: string,
  runtimeFetch: RuntimeFetch,
): Promise<JSONWebKeySet> {
  const jwksUrl = new URL("/auth/v1/.well-known/jwks.json", origin);
  let response: Response;
  try {
    response = await runtimeFetch(jwksUrl, {
      headers: { accept: "application/json" },
      redirect: "manual",
      signal: AbortSignal.timeout(5000),
    });
  } catch {
    throw new AuthenticationError("unavailable");
  }
  if (!response.ok) {
    throw new AuthenticationError("unavailable");
  }
  try {
    return parseJwks(await readBoundedJson(response, maximumJwksBytes));
  } catch {
    throw new AuthenticationError("unavailable");
  }
}

function supabaseOrigin(value: string): string {
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    throw new AuthenticationError("unavailable");
  }
  if (
    url.protocol !== "https:" ||
    url.username !== "" ||
    url.password !== "" ||
    (url.pathname !== "/" && url.pathname !== "") ||
    url.search !== "" ||
    url.hash !== ""
  ) {
    throw new AuthenticationError("unavailable");
  }
  return url.origin;
}

function parseJwks(value: unknown): JSONWebKeySet {
  if (!isRecord(value) || !Array.isArray(value.keys) || value.keys.length > 8) {
    throw new Error("invalid_jwks");
  }
  const keys: JsonWebKey[] = [];
  for (const key of value.keys) {
    if (
      !isRecord(key) ||
      typeof key.kty !== "string" ||
      typeof key.kid !== "string" ||
      typeof key.alg !== "string" ||
      !["RSA", "EC", "OKP"].includes(key.kty) ||
      !["RS256", "ES256"].includes(key.alg)
    ) {
      throw new Error("invalid_jwk");
    }
    keys.push({ ...key, kty: key.kty });
  }
  if (keys.length === 0) throw new Error("empty_jwks");
  return { keys };
}

async function verifyWithSupabaseAuthServer(
  token: string,
  env: Env,
  origin: string,
  runtimeFetch: RuntimeFetch,
): Promise<AuthenticatedUser> {
  let response: Response;
  try {
    response = await runtimeFetch(new URL("/auth/v1/user", origin), {
      headers: {
        accept: "application/json",
        apikey: env.SUPABASE_PUBLISHABLE_KEY,
        authorization: `Bearer ${token}`,
      },
      redirect: "manual",
      signal: AbortSignal.timeout(5000),
    });
  } catch {
    throw new AuthenticationError("unavailable");
  }
  if (response.status === 401 || response.status === 403) {
    throw new AuthenticationError("unauthorized");
  }
  if (!response.ok) {
    throw new AuthenticationError("unavailable");
  }
  let value: unknown;
  try {
    value = await readBoundedJson(response, maximumUserBytes);
  } catch {
    throw new AuthenticationError("unavailable");
  }
  if (!isRecord(value) || typeof value.id !== "string" || !uuidPattern.test(value.id)) {
    throw new AuthenticationError("unauthorized");
  }
  return { id: value.id, token };
}

function authenticatedPayload(
  payload: JWTPayload,
  token: string,
): AuthenticatedUser {
  if (
    typeof payload.sub !== "string" ||
    !uuidPattern.test(payload.sub) ||
    payload.role !== "authenticated"
  ) {
    throw new AuthenticationError("unauthorized");
  }
  return { id: payload.sub, token };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
