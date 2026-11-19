import type { persistVerified } from "./store_backend.ts";

type Purchase = Parameters<typeof persistVerified>[2];
type Snapshot = NonNullable<Parameters<typeof persistVerified>[4]>;
type Rpc = (name: string, args: Record<string, unknown>) => Promise<{
  data: unknown;
  error: unknown;
}>;

export type OwnSubscriptionRefreshDependencies = {
  rpc: Rpc;
  readStore: (snapshot: RefreshSnapshot, signal: AbortSignal) => Promise<Purchase>;
  persist: (purchase: Purchase, snapshot: Snapshot) => ReturnType<typeof persistVerified>;
};

export type RefreshSnapshot = Snapshot & {
  ownerId: string;
  packageOrBundleId: string;
  refreshLease: string;
};

type RefreshStatus = "refreshed" | "superseded" | "not_required" | "checking";
const record = (value: unknown): value is Record<string, unknown> =>
  value !== null && typeof value === "object" && !Array.isArray(value);

function claimedSnapshot(data: Record<string, unknown>, ownerId: string): RefreshSnapshot {
  const row = data.snapshot;
  if (!record(row) || row.owner_id !== ownerId ||
    !["google", "apple"].includes(String(row.provider)) ||
    !["sandbox", "production"].includes(String(row.environment)) ||
    !Number.isSafeInteger(row.revision) || Number(row.revision) < 1 ||
    ![row.original_transaction_id, row.latest_transaction_id,
      row.package_or_bundle_id, data.lease_id].every((value) =>
        typeof value === "string" && value.trim().length > 0)) {
    throw new Error("subscription_refresh_unavailable");
  }
  return {
    ownerId,
    provider: String(row.provider),
    originalTransactionId: String(row.original_transaction_id),
    latestTransactionId: String(row.latest_transaction_id),
    environment: String(row.environment),
    revision: Number(row.revision),
    packageOrBundleId: String(row.package_or_bundle_id),
    refreshLease: String(data.lease_id),
  };
}

function assertStoredIdentity(snapshot: RefreshSnapshot, purchase: Purchase) {
  if (purchase.provider !== snapshot.provider ||
    purchase.environment !== snapshot.environment ||
    purchase.packageOrBundleId !== snapshot.packageOrBundleId ||
    purchase.originalTransactionId !== snapshot.originalTransactionId ||
    (snapshot.provider === "google" &&
      purchase.transactionId !== snapshot.latestTransactionId)) {
    throw new Error("subscription_refresh_identity_mismatch");
  }
}

async function bounded<T>(operation: (signal: AbortSignal) => Promise<T>): Promise<T> {
  const controller = new AbortController();
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    return await Promise.race([
      operation(controller.signal),
      new Promise<never>((_, reject) => {
        timer = setTimeout(() => {
          controller.abort();
          reject(new Error("subscription_refresh_unavailable"));
        }, 8000);
      }),
    ]);
  } finally {
    if (timer !== undefined) clearTimeout(timer);
  }
}

/** JWT ownership and one-use integrity are established by the HTTP adapter.
 * The service-only claim derives the lineage, environment and period from the
 * stored canonical row; no receipt or identity from the caller is accepted.
 * A response here is deliberately NOT an entitlement or delivery receipt.
 */
export async function refreshOwnSubscription(
  ownerId: string,
  dependencies: OwnSubscriptionRefreshDependencies,
): Promise<{ refresh_status: RefreshStatus; retry_after_seconds?: number }> {
  const { data, error } = await dependencies.rpc("bil_claim_own_subscription_refresh", {
    p_owner_id: ownerId,
  });
  if (error || !record(data)) throw new Error("subscription_refresh_unavailable");
  if (data.status === "not_required") return { refresh_status: "not_required" };
  if (data.status === "busy" || data.status === "rate_limited") {
    const seconds = Number(data.retry_after_seconds);
    return { refresh_status: "checking", retry_after_seconds:
      Number.isInteger(seconds) && seconds >= 1 && seconds <= 3600 ? seconds : 10 };
  }
  if (data.status !== "claimed") throw new Error("subscription_refresh_unavailable");
  const snapshot = claimedSnapshot(data, ownerId);
  try {
    // A late Store API response after the deadline is never persisted. The
    // lease is checked again atomically by the persistence RPC, along with
    // the original provider/lineage/revision compare-and-swap.
    const purchase = await bounded((signal) => dependencies.readStore(snapshot, signal));
    assertStoredIdentity(snapshot, purchase);
    const result = await dependencies.persist(purchase, snapshot);
    return { refresh_status: result.superseded ? "superseded" : "refreshed" };
  } finally {
    // Releasing an old lease cannot release a newer flight. Failure to release
    // is bounded by the database deadline and never grants financial access.
    await dependencies.rpc("bil_release_own_subscription_refresh", {
      p_owner_id: ownerId,
      p_lease_id: snapshot.refreshLease,
    }).catch(() => {});
  }
}
