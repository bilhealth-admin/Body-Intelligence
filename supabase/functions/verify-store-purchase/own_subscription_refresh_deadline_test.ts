import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { FakeTime } from "https://deno.land/std@0.224.0/testing/time.ts";
import { refreshOwnSubscription } from "./own_subscription_refresh.ts";

const owner = "00000000-0000-4000-8000-000000000001";
const snapshot = { owner_id: owner, provider: "google", environment: "sandbox", revision: 7,
  package_or_bundle_id: "com.bilhealth", original_transaction_id: "chain", latest_transaction_id: "token" };
const purchase = { provider: "google" as const, environment: "sandbox" as const,
  productId: "bil_premium", packageOrBundleId: "com.bilhealth", originalTransactionId: "chain",
  transactionId: "token", lifecycle: "active" as const, expiresAt: "2026-11-18T15:01:00Z" };

Deno.test("late Store API completion after deadline is aborted and cannot persist", async () => {
  const time = new FakeTime();
  let releaseRead!: (value: typeof purchase) => void;
  let entered!: () => void;
  const started = new Promise<void>((resolve) => entered = resolve);
  const held = new Promise<typeof purchase>((resolve) => releaseRead = resolve);
  let signal: AbortSignal | undefined;
  let persists = 0;
  const calls: string[] = [];
  try {
    const result = refreshOwnSubscription(owner, {
      rpc: (name) => {
        calls.push(name);
        return Promise.resolve({ data: name === "bil_claim_own_subscription_refresh"
          ? { status: "claimed", lease_id: "lease", snapshot } : null, error: null });
      },
      readStore: (_, abortSignal) => { signal = abortSignal; entered(); return held; },
      persist: () => { persists++; return Promise.resolve({ active: true, lifecycle: "active", verifiedAt: "2026-11-18T14:31:08Z" }); },
    });
    const rejected = assertRejects(() => result, Error, "subscription_refresh_unavailable");
    await started;
    time.tick(8000);
    await rejected;
    assertEquals(signal?.aborted, true);
    releaseRead(purchase);
    await Promise.resolve();
    assertEquals(persists, 0);
    assertEquals(calls, ["bil_claim_own_subscription_refresh", "bil_release_own_subscription_refresh"]);
  } finally { time.restore(); }
});

Deno.test("old expired proof then an eight-second-late signed renewal never returns rights", async () => {
  let reads = 0;
  const persisted: string[] = [];
  const dependencies = {
    rpc: (name: string) => Promise.resolve({ data: name === "bil_claim_own_subscription_refresh"
      ? { status: "claimed", lease_id: `lease-${reads}`, snapshot } : null, error: null }),
    readStore: () => Promise.resolve(++reads === 1
      ? { ...purchase, lifecycle: "expired" as const, expiresAt: "2026-11-18T14:31:00Z" }
      : purchase),
    persist: (proof: Parameters<Parameters<typeof refreshOwnSubscription>[1]["persist"]>[0]) => {
      persisted.push(proof.lifecycle);
      return Promise.resolve({ active: proof.lifecycle === "active", lifecycle: proof.lifecycle,
        verifiedAt: reads === 1 ? "2026-11-18T14:31:00Z" : "2026-11-18T14:31:08Z" });
    },
  };
  assertEquals(await refreshOwnSubscription(owner, dependencies), { refresh_status: "refreshed" });
  assertEquals(await refreshOwnSubscription(owner, dependencies), { refresh_status: "refreshed" });
  assertEquals(persisted, ["expired", "active"]);
});
