import {
  type AuthenticatedUser,
  type RuntimeFetch,
} from "./auth";
import { readBoundedJson } from "./bounded-json";

const maximumEntitlementBytes = 64 * 1024;
const paidPlans = new Set([
  "premium",
  "premium_ai_coach",
  "pro",
]);
const paidLifecycles = new Set(["trial", "active", "grace_period", "cancelled"]);
const trustedProviders = new Set(["apple", "google", "closed_test"]);

export class EntitlementError extends Error {
  constructor() {
    super("entitlement_unavailable");
    this.name = "EntitlementError";
  }
}

export async function verifyPremiumEntitlement(
  user: AuthenticatedUser,
  env: Env,
  runtimeFetch: RuntimeFetch = fetch,
  now: Date = new Date(),
): Promise<boolean> {
  const subscriptionUrl = restUrl(env, "bil_subscriptions", {
    limit: "1",
    owner_id: `eq.${user.id}`,
    select:
      "owner_id,provider,plan_id,lifecycle,started_at,expires_at,grace_period_ends_at,verified_at",
  });
  const closedTestUrl = restUrl(env, "bil_ai_closed_test_grants", {
    active: "eq.true",
    limit: "1",
    owner_id: `eq.${user.id}`,
    select: "owner_id,active,expires_at",
  });
  const [subscriptionValue, closedTestValue] = await Promise.all([
    fetchRows(subscriptionUrl, user.token, env, runtimeFetch),
    fetchRows(closedTestUrl, user.token, env, runtimeFetch),
  ]);
  const subscriptions = rows(subscriptionValue);
  const closedTests = rows(closedTestValue);
  if (closedTests.some((row) => activeClosedTest(row, user.id, now))) {
    return true;
  }
  return subscriptions.some((row) => activeSubscription(row, user.id, now));
}

function restUrl(
  env: Env,
  table: string,
  parameters: Record<string, string>,
): URL {
  let origin: URL;
  try {
    origin = new URL(env.SUPABASE_URL);
  } catch {
    throw new EntitlementError();
  }
  if (origin.protocol !== "https:") throw new EntitlementError();
  const url = new URL(`/rest/v1/${table}`, origin.origin);
  for (const [key, value] of Object.entries(parameters)) {
    url.searchParams.set(key, value);
  }
  return url;
}

async function fetchRows(
  url: URL,
  token: string,
  env: Env,
  runtimeFetch: RuntimeFetch,
): Promise<unknown> {
  let response: Response;
  try {
    response = await runtimeFetch(url, {
      headers: {
        accept: "application/json",
        apikey: env.SUPABASE_PUBLISHABLE_KEY,
        authorization: `Bearer ${token}`,
      },
      redirect: "manual",
      signal: AbortSignal.timeout(5000),
    });
  } catch {
    throw new EntitlementError();
  }
  if (!response.ok) throw new EntitlementError();
  try {
    return await readBoundedJson(response, maximumEntitlementBytes);
  } catch {
    throw new EntitlementError();
  }
}

function rows(value: unknown): ReadonlyArray<Record<string, unknown>> {
  if (
    !Array.isArray(value) ||
    value.length > 1 ||
    value.some((row) => !isRecord(row))
  ) {
    throw new EntitlementError();
  }
  return value;
}

function activeClosedTest(
  row: Record<string, unknown>,
  ownerId: string,
  now: Date,
): boolean {
  return (
    row.owner_id === ownerId &&
    row.active === true &&
    isCurrentBoundary(row.expires_at, now)
  );
}

function activeSubscription(
  row: Record<string, unknown>,
  ownerId: string,
  now: Date,
): boolean {
  if (
    row.owner_id !== ownerId ||
    typeof row.provider !== "string" ||
    !trustedProviders.has(row.provider) ||
    typeof row.plan_id !== "string" ||
    !paidPlans.has(row.plan_id) ||
    typeof row.lifecycle !== "string" ||
    !paidLifecycles.has(row.lifecycle)
  ) {
    return false;
  }
  const startedAt = parsedDate(row.started_at);
  if (startedAt !== null && now.getTime() < startedAt.getTime()) return false;
  const verifiedAt = parsedDate(row.verified_at);
  if (verifiedAt === null || verifiedAt.getTime() > now.getTime() + 5 * 60_000) {
    return false;
  }
  if (
    row.provider !== "closed_test" &&
    now.getTime() - verifiedAt.getTime() > 72 * 60 * 60_000
  ) {
    return false;
  }
  const boundary =
    row.lifecycle === "grace_period"
      ? row.grace_period_ends_at
      : row.expires_at;
  return isCurrentBoundary(boundary, now);
}

function isCurrentBoundary(value: unknown, now: Date): boolean {
  const boundary = parsedDate(value);
  return boundary !== null && now.getTime() <= boundary.getTime();
}

function parsedDate(value: unknown): Date | null {
  if (typeof value !== "string") return null;
  const milliseconds = Date.parse(value);
  return Number.isFinite(milliseconds) ? new Date(milliseconds) : null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
