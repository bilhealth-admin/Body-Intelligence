// EPHEMERAL READ-ONLY PROPOSAL. Not deployed. Root must replace the team
// placeholder from its existing secret channel, without logging the value.
// No DB client, outbound fetch, token minting, key hash output or logging.
import { createPrivateKey, timingSafeEqual } from "node:crypto";
import { Buffer } from "node:buffer";

const EXPECTED_APPLE_TEAM_ID = "__REPLACE_SECURELY_FROM_GITHUB_APPLE_TEAM_ID__";
const EXPECTED_BUNDLE_ID = "com.bilhealth.bodyintelligencelog";
type Env = (name: string) => string | undefined;
const trimmed = (env: Env, name: string) => env(name)?.trim() ?? "";

function json(status: number, body: Record<string, boolean>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json",
      "cache-control": "no-store, max-age=0",
      "pragma": "no-cache",
      "x-content-type-options": "nosniff",
    },
  });
}

// Exact constant-time byte comparison, including length, without key hashes.
// No JWT claim parsing: only the literal configured service-role key is valid.
export function authorized(request: Request, env: Env): boolean {
  const key = env("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const supplied = request.headers.get("authorization") ?? "";
  if (!key || key.length > 8185 || supplied.length > 8192) return false;
  const expectedBytes = Buffer.from("Bearer " + key, "utf8");
  const suppliedBytes = Buffer.from(supplied, "utf8");
  if (expectedBytes.length > 8192 || suppliedBytes.length > 8192) return false;
  const expected = Buffer.alloc(8196);
  const candidate = Buffer.alloc(8196);
  expected.writeUInt32BE(expectedBytes.length, 0);
  candidate.writeUInt32BE(suppliedBytes.length, 0);
  expectedBytes.copy(expected, 4);
  suppliedBytes.copy(candidate, 4);
  return timingSafeEqual(expected, candidate);
}

// Mirrors deployed app-attest v54 configuration() at5775d082 lines622–655.
// This predicate validates syntax, not a real Apple assertion.
export function appAttestConfiguration(env: Env) {
  const appId = trimmed(env, "BIL_APP_ATTEST_APP_ID");
  const environments = new Set(
    trimmed(env, "BIL_APP_ATTEST_ENVIRONMENTS").split(",")
      .map((value) => value.trim()).filter(Boolean),
  );
  const bundleVersions = new Set(
    trimmed(env, "BIL_APP_ATTEST_BUNDLE_VERSIONS").split(",")
      .map((value) => value.trim()).filter(Boolean),
  );
  const legacySetting = trimmed(env, "BIL_APP_ATTEST_ALLOW_LEGACY");
  const configValid =
    /^[A-Z0-9]{10}\.[A-Za-z0-9.-]{3,200}$/.test(appId) &&
    environments.size !== 0 &&
    ![...environments].some((value) =>
      value !== "development" && value !== "production"
    ) &&
    bundleVersions.size !== 0 &&
    (legacySetting === "" || legacySetting === "true" ||
      legacySetting === "false");
  return {
    appId, environments, bundleVersions, configValid,
    allowLegacy: legacySetting === "true",
  };
}

// Require PKCS8, as the actual push gateway imports pkcs8 via WebCrypto.
// Reject SEC1/PKCS1/private-key strings that the real gateway cannot import.
function privateKeyWellFormed(value: string, algorithm: "ec" | "rsa"): boolean {
  try {
    if (!/^-----BEGIN PRIVATE KEY-----[\s\S]+-----END PRIVATE KEY-----$/.test(value)) {
      return false;
    }
    const body = value.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, "");
    if (!/^[A-Za-z0-9+/]+={0,2}$/.test(body) || body.length % 4 !== 0) return false;
    const key = createPrivateKey({
      key: Buffer.from(body, "base64"), format: "der", type: "pkcs8",
    });
    if (key.asymmetricKeyType !== algorithm) return false;
    return algorithm === "ec"
      ? key.asymmetricKeyDetails?.namedCurve === "prime256v1"
      : (key.asymmetricKeyDetails?.modulusLength ?? 0) >= 2048;
  } catch { return false; }
}

function serviceAccountWellFormed(raw: string, requiredProject?: string): boolean {
  try {
    const account = JSON.parse(raw);
    return account !== null && typeof account === "object" &&
      typeof account.client_email === "string" &&
      /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(account.client_email.trim()) &&
      typeof account.private_key === "string" &&
      (!requiredProject || account.project_id === requiredProject) &&
      privateKeyWellFormed(account.private_key.trim(), "rsa");
  } catch { return false; }
}

export function readiness(env: Env, expectedTeam = EXPECTED_APPLE_TEAM_ID) {
  const cfg = appAttestConfiguration(env);
  const expectedTeamConfigured = /^[A-Z0-9]{10}$/.test(expectedTeam);
  const appIDMatchesExpected = expectedTeamConfigured &&
    cfg.appId === expectedTeam + "." + EXPECTED_BUNDLE_ID;
  const apnsTeam = trimmed(env, "BIL_APNS_TEAM_ID");
  const apnsTopic = trimmed(env, "BIL_APNS_BUNDLE_ID");
  const apnsKeyId = trimmed(env, "BIL_APNS_KEY_ID");
  let fcmCredentialsWellFormed = false;
  try {
    const sa = JSON.parse(trimmed(env, "BIL_FCM_SERVICE_ACCOUNT_JSON"));
    const project = trimmed(env, "BIL_FCM_PROJECT_ID");
    fcmCredentialsWellFormed = sa !== null && typeof sa === "object" &&
      typeof sa.client_email === "string" &&
      /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(sa.client_email.trim()) &&
      /^[a-z0-9-]+$/.test(project) &&
      typeof sa.private_key === "string" &&
      privateKeyWellFormed(sa.private_key.trim(), "rsa");
  } catch { /* Boolean false only. */ }
  return {
    expectedTeamConfigured,
    configValid: cfg.configValid,
    appIDMatchesExpected,
    // These mean this app/build passes the deployed configuration allowlist.
    // They are not proof a real AppAttest assertion or Apple request succeeds.
    ios37Allowed: cfg.configValid && appIDMatchesExpected &&
      cfg.bundleVersions.has("37"),
    productionAppAttestAllowed: cfg.configValid && appIDMatchesExpected &&
      cfg.environments.has("production"),
    allowLegacy: cfg.allowLegacy,
    apnsTopicMatchesExpected: apnsTopic === EXPECTED_BUNDLE_ID,
    apnsTeamMatchesExpected: expectedTeamConfigured && apnsTeam === expectedTeam,
    apnsCredentialsWellFormed: /^[A-Z0-9]{10}$/.test(apnsTeam) &&
      /^[A-Z0-9]{10}$/.test(apnsKeyId) &&
      privateKeyWellFormed(trimmed(env, "BIL_APNS_AUTH_KEY_P8"), "ec"),
    fcmCredentialsWellFormed,
    playIntegrityCredentialsWellFormed: serviceAccountWellFormed(
      trimmed(env, "BIL_PLAY_INTEGRITY_SERVICE_ACCOUNT_JSON"), "bil-health",
    ),
    googleBillingCredentialsWellFormed: serviceAccountWellFormed(
      trimmed(env, "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON") ||
        trimmed(env, "BIL_PLAY_INTEGRITY_SERVICE_ACCOUNT_JSON"),
    ),
    appleBillingCredentialsWellFormed:
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
        .test(trimmed(env, "APPLE_ISSUER_ID")) &&
      /^[A-Z0-9]{10}$/.test(trimmed(env, "APPLE_KEY_ID")) &&
      privateKeyWellFormed(
        trimmed(env, "APPLE_PRIVATE_KEY").replaceAll("\\n", "\n"), "ec",
      ),
    // Mirrors shared mobile_integrity.ts: unset defaults enforce; blank is off.
    integrityGlobalEnforce: (env("BIL_MOBILE_INTEGRITY_ENFORCEMENT") ?? "enforce")
      .trim().toLowerCase() === "enforce",
    playIntegrityPackageMatchesExpected:
      (trimmed(env, "BIL_PLAY_INTEGRITY_PACKAGE_NAME") || EXPECTED_BUNDLE_ID) ===
        EXPECTED_BUNDLE_ID,
    googleBillingPackageMatchesExpected:
      trimmed(env, "GOOGLE_PLAY_PACKAGE_NAME") === EXPECTED_BUNDLE_ID,
    appleBillingBundleMatchesExpected:
      trimmed(env, "APPLE_BUNDLE_ID") === EXPECTED_BUNDLE_ID,
  };
}

export function handler(request: Request, env: Env): Response {
  // Auth first, so no unauthenticated caller obtains method/config details.
  if (!authorized(request, env)) return json(401, { authorized: false });
  if (request.method !== "GET") return json(405, { methodAllowed: false });
  try { return json(200, readiness(env)); }
  catch { return json(503, { readinessAvailable: false }); }
}

if (import.meta.main) {
  Deno.serve((request: Request) => handler(request, (name) => Deno.env.get(name)));
}

