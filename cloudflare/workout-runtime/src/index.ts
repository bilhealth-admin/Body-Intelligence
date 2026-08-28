import {
  AuthenticationError,
  bearerToken,
  type AuthenticatedUser,
  verifySupabaseJwt,
} from "./auth";
import {
  EntitlementError,
  verifyPremiumEntitlement,
} from "./entitlement";
import {
  resolveRecipeImage,
  type RecipeImageObject,
} from "./recipe-images";
import approvedObjects from "../../../artifacts/workout_media/cloudflare_runtime_v2/protected_object_keys_v2.json";

const protectedObjectPrefix = "/v2/objects/";
const videoKey = /^workouts\/v1\/(?:home|gym-six-month)\/movements\/[a-z0-9]+(?:-[a-z0-9]+)*\.mp4$/;
const posterKey = /^workouts\/v2\/(?:home|gym-six-month)\/posters\/[a-z0-9]+(?:-[a-z0-9]+)*-[0-9a-f]{64}\.webp$/;
const packKey = /^workouts\/v2\/packs\/bil-workouts-(?:home|gym-six-month)-v1-v1-[0-9a-f]{64}\.json$/;
const manifestKey = /^workouts\/v2\/catalog\/wellness-workouts-v2-[0-9a-f]{64}\.json$/;
const approvedObjectKeys = new Set(approvedObjects.keys);
if (
  approvedObjects.schema !== "bil.cloudflare-workout-protected-object-keys.v2" ||
  approvedObjectKeys.size !== 606
) {
  throw new Error("generated_workout_object_allowlist_invalid");
}

export interface RuntimeServices {
  authenticate(token: string, env: Env): Promise<AuthenticatedUser>;
  hasPremiumEntitlement(user: AuthenticatedUser, env: Env): Promise<boolean>;
}

const productionServices: RuntimeServices = {
  authenticate: verifySupabaseJwt,
  hasPremiumEntitlement: verifyPremiumEntitlement,
};

interface DeliveryPolicy {
  readonly cacheControl: string;
  readonly recipeImage?: RecipeImageObject;
  readonly varyAuthorization: boolean;
}

const publicManifestPolicy = {
  cacheControl: "public, max-age=300, must-revalidate",
  varyAuthorization: false,
} satisfies DeliveryPolicy;
const protectedWorkoutPolicy = {
  cacheControl: "private, max-age=31536000, immutable",
  varyAuthorization: true,
} satisfies DeliveryPolicy;

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    return handleRequest(request, env, ctx);
  },
} satisfies ExportedHandler<Env>;

async function handleRequest(
  request: Request,
  env: Env,
  ctx: ExecutionContext,
  services: RuntimeServices = productionServices,
): Promise<Response> {
  void ctx;
  const url = new URL(request.url);
  try {
    if (request.method === "OPTIONS") {
      return preflight(request, env);
    }
    if (request.method !== "GET" && request.method !== "HEAD") {
      return jsonError("method_not_allowed", 405, request, env, {
        allow: "GET, HEAD, OPTIONS",
      });
    }
    const publicManifest = resolvePublicManifest(url.pathname, env);
    if (publicManifest !== null) {
      return serveR2(
        request,
        env.WORKOUTS,
        publicManifest,
        publicManifestPolicy,
        env,
      );
    }
    const recipeImage = resolveRecipeImage(url.pathname);
    if (recipeImage !== null) {
      return serveR2(
        request,
        env.RECIPES,
        recipeImage.objectKey,
        {
          cacheControl: "public, max-age=31536000, immutable",
          recipeImage,
          varyAuthorization: false,
        },
        env,
      );
    }
    const objectKey = resolveProtectedObject(url.pathname);
    if (objectKey === null) {
      return jsonError("not_found", 404, request, env);
    }

    let user: AuthenticatedUser;
    try {
      user = await services.authenticate(bearerToken(request), env);
    } catch (error) {
      if (
        error instanceof AuthenticationError &&
        error.kind === "unavailable"
      ) {
        return jsonError("authentication_unavailable", 503, request, env);
      }
      return jsonError("authentication_required", 401, request, env, {
        "www-authenticate": 'Bearer realm="bil-workouts"',
      });
    }
    let entitled: boolean;
    try {
      entitled = await services.hasPremiumEntitlement(user, env);
    } catch (error) {
      if (error instanceof EntitlementError) {
        return jsonError("entitlement_unavailable", 503, request, env);
      }
      throw error;
    }
    if (!entitled) {
      return jsonError("premium_entitlement_required", 403, request, env);
    }
    return serveR2(
      request,
      env.WORKOUTS,
      objectKey,
      protectedWorkoutPolicy,
      env,
    );
  } catch (error) {
    console.error(
      JSON.stringify({
        error: error instanceof Error ? error.name : "UnknownError",
        message: "workout_runtime_request_failed",
        path: url.pathname,
        ray: request.headers.get("cf-ray"),
      }),
    );
    return jsonError("internal_error", 500, request, env);
  }
}

function resolvePublicManifest(pathname: string, env: Env): string | null {
  if (!manifestKey.test(env.PUBLIC_MANIFEST_KEY)) return null;
  const filename = env.PUBLIC_MANIFEST_KEY.split("/").at(-1);
  return filename !== undefined && pathname === `/v2/manifest/${filename}`
    ? env.PUBLIC_MANIFEST_KEY
    : null;
}

function resolveProtectedObject(pathname: string): string | null {
  if (!pathname.startsWith(protectedObjectPrefix)) return null;
  let key: string;
  try {
    key = decodeURIComponent(pathname.slice(protectedObjectPrefix.length));
  } catch {
    return null;
  }
  if (
    key.includes("%") ||
    key.includes("\\") ||
    key.startsWith("/") ||
    key.split("/").some((part) => part === "" || part === "." || part === "..")
  ) {
    return null;
  }
  return approvedObjectKeys.has(key) &&
    (videoKey.test(key) || posterKey.test(key) || packKey.test(key))
    ? key
    : null;
}

async function serveR2(
  request: Request,
  bucket: R2Bucket,
  key: string,
  policy: DeliveryPolicy,
  env: Env,
): Promise<Response> {
  const rangeHeader = request.headers.get("range");
  if (request.method === "HEAD") {
    const object = await bucket.get(key, { onlyIf: request.headers });
    if (object === null) return jsonError("not_found", 404, request, env);
    if (!objectMatchesPolicy(object, policy)) {
      if ("body" in object) await object.body.cancel();
      return jsonError("media_integrity_unavailable", 502, request, env);
    }
    const headers = objectHeaders(object, request, policy, env);
    if (!("body" in object)) {
      return new Response(null, {
        status: failedPreconditionStatus(request.headers),
        headers,
      });
    }
    await object.body.cancel();
    headers.set("content-length", String(object.size));
    return new Response(null, { status: 200, headers });
  }
  let requestedRange: { offset: number; length: number } | undefined;
  let fullSize: number | undefined;
  if (rangeHeader !== null) {
    const head = await bucket.head(key);
    if (head === null) return jsonError("not_found", 404, request, env);
    if (!objectMatchesPolicy(head, policy)) {
      return jsonError("media_integrity_unavailable", 502, request, env);
    }
    const useRange = ifRangeMatches(request.headers.get("if-range"), head);
    if (!useRange) {
      fullSize = undefined;
    } else {
      fullSize = head.size;
    }
    const parsed = useRange ? normalizedRange(rangeHeader, head.size) : undefined;
    if (parsed === null) {
      const headers = objectHeaders(head, request, policy, env);
      headers.set("content-range", `bytes */${head.size}`);
      return new Response(null, { status: 416, headers });
    }
    requestedRange = parsed;
  }
  const object = await bucket.get(
    key,
    requestedRange === undefined
      ? { onlyIf: request.headers }
      : { onlyIf: request.headers, range: requestedRange },
  );
  if (object === null) return jsonError("not_found", 404, request, env);
  if (!objectMatchesPolicy(object, policy)) {
    if ("body" in object) await object.body.cancel();
    return jsonError("media_integrity_unavailable", 502, request, env);
  }
  const headers = objectHeaders(object, request, policy, env);
  if (!("body" in object)) {
    return new Response(null, {
      status: failedPreconditionStatus(request.headers),
      headers,
    });
  }
  let status = 200;
  if (requestedRange !== undefined && fullSize !== undefined) {
    status = 206;
    headers.set(
      "content-range",
      `bytes ${requestedRange.offset}-${requestedRange.offset + requestedRange.length - 1}/${fullSize}`,
    );
    headers.set("content-length", String(requestedRange.length));
  } else {
    headers.set("content-length", String(object.size));
  }
  return new Response(object.body, { status, headers });
}

function failedPreconditionStatus(headers: Headers): 304 | 412 {
  return headers.has("if-match") || headers.has("if-unmodified-since")
    ? 412
    : 304;
}

function ifRangeMatches(value: string | null, object: R2Object): boolean {
  if (value === null) return true;
  const candidate = value.trim();
  if (candidate.startsWith("W/")) return false;
  if (candidate.startsWith('"')) return candidate === object.httpEtag;
  const timestamp = Date.parse(candidate);
  if (!Number.isFinite(timestamp)) return false;
  return Math.floor(object.uploaded.getTime() / 1000) <= Math.floor(timestamp / 1000);
}

function normalizedRange(
  header: string,
  size: number,
): { offset: number; length: number } | null {
  const match = /^bytes=(\d*)-(\d*)$/.exec(header);
  if (match === null || (match[1] === "" && match[2] === "")) return null;
  const startText = match[1] ?? "";
  const endText = match[2] ?? "";
  if (startText === "") {
    const suffix = Number(endText);
    if (!Number.isSafeInteger(suffix) || suffix <= 0) return null;
    const length = Math.min(suffix, size);
    return length > 0 ? { offset: size - length, length } : null;
  }
  const offset = Number(startText);
  if (!Number.isSafeInteger(offset) || offset < 0 || offset >= size) return null;
  if (endText === "") return { offset, length: size - offset };
  const requestedEnd = Number(endText);
  if (!Number.isSafeInteger(requestedEnd) || requestedEnd < offset) return null;
  const end = Math.min(requestedEnd, size - 1);
  return { offset, length: end - offset + 1 };
}

function objectHeaders(
  object: R2Object,
  request: Request,
  policy: DeliveryPolicy,
  env: Env,
): Headers {
  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set("accept-ranges", "bytes");
  headers.set("cache-control", policy.cacheControl);
  headers.set("etag", object.httpEtag);
  headers.set("x-content-type-options", "nosniff");
  headers.set("cross-origin-resource-policy", "cross-origin");
  if (policy.recipeImage !== undefined) {
    headers.set("content-disposition", "inline");
    headers.set("content-type", policy.recipeImage.mimeType);
    headers.set("x-bil-content-sha256", policy.recipeImage.sha256);
  }
  applyCors(headers, request, env, policy.varyAuthorization);
  return headers;
}

function objectMatchesPolicy(
  object: R2Object,
  policy: DeliveryPolicy,
): boolean {
  const expected = policy.recipeImage;
  if (expected === undefined) return true;
  const contentType = object.httpMetadata?.contentType
    ?.split(";", 1)[0]
    ?.trim()
    .toLowerCase();
  return object.size === expected.sizeBytes && contentType === expected.mimeType;
}

function preflight(request: Request, env: Env): Response {
  const origin = request.headers.get("origin");
  if (origin === null || origin !== env.ALLOWED_ORIGIN) {
    return jsonError("origin_not_allowed", 403, request, env);
  }
  const headers = new Headers({
    "access-control-allow-headers": "authorization, range",
    "access-control-allow-methods": "GET, HEAD, OPTIONS",
    "access-control-allow-origin": origin,
    "access-control-max-age": "86400",
    vary: "Origin",
  });
  return new Response(null, { status: 204, headers });
}

function applyCors(
  headers: Headers,
  request: Request,
  env: Env,
  varyAuthorization = true,
): void {
  const origin = request.headers.get("origin");
  if (origin === env.ALLOWED_ORIGIN) {
    headers.set("access-control-allow-origin", origin);
    headers.set(
      "access-control-expose-headers",
      "accept-ranges, content-length, content-range, etag, x-bil-content-sha256",
    );
    headers.append("vary", "Origin");
  }
  if (varyAuthorization) headers.append("vary", "Authorization");
}

function jsonError(
  code: string,
  status: number,
  request: Request,
  env: Env,
  extraHeaders: Record<string, string> = {},
): Response {
  const headers = new Headers({
    "cache-control": "no-store",
    "content-type": "application/json; charset=utf-8",
    ...extraHeaders,
  });
  headers.set("x-content-type-options", "nosniff");
  applyCors(headers, request, env);
  return Response.json({ error: code }, { status, headers });
}
