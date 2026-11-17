import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  handler,
  type StoreBackendHandlerDependencies,
} from "./store_backend.ts";

const owner = "00000000-0000-4000-8000-000000000001";
const quota = { code: "P0001", message: "rate limit exceeded" };
const routes = [
  ["verify_purchase", "store_purchase_verification", "bil_premium"],
  ["verify_ai_boost", "ai_boost_purchase_verification", "bil_ai_boost"],
] as const;

function fixture(options: {
  rateError?: unknown;
  rpcThrows?: boolean;
  nowMs?: number;
  afterRpcMs?: number;
  expired?: boolean;
} = {}) {
  let nowMs = options.nowMs ?? Date.parse("2026-11-16T13:30:00.000Z");
  const effects: string[] = [];
  const rateCalls: unknown[] = [];
  const persistence: Record<string, unknown>[] = [];
  let clockReads = 0;
  const purchase = {
    provider: "apple" as const,
    productId: "bil_premium",
    originalTransactionId: "synthetic-original",
    transactionId: "synthetic-latest",
    packageOrBundleId: "app.bil.health",
    environment: "sandbox" as const,
    lifecycle: "expired" as const,
    expiresAt: "2026-11-15T00:00:00.000Z",
  };
  const dependencies: StoreBackendHandlerDependencies = {
    clients: () => ({
      auth: {
        auth: {
          getUser: () => {
            effects.push("authenticate");
            return Promise.resolve({
              data: { user: { id: owner } },
              error: null,
            });
          },
        },
        rpc: (name: string, args: Record<string, unknown>) => {
          assertEquals(name, "bil_consume_rate_limit");
          rateCalls.push(args);
          effects.push("quota_rpc");
          if (options.rpcThrows) {
            throw new Error("private transport failure: rate limit exceeded");
          }
          // Model the awaited RPC completing in the next fixed UTC window.
          if (options.afterRpcMs !== undefined) nowMs = options.afterRpcMs;
          return Promise.resolve({
            data: null,
            error: options.rateError ?? null,
          });
        },
      } as never,
      admin: {
        rpc: (name: string, args: Record<string, unknown>) => {
          effects.push(name);
          if (
            options.expired && name === "bil_lookup_store_subscription_owner"
          ) {
            return Promise.resolve({
              data: { owner_id: owner, environment: "sandbox" },
              error: null,
            });
          }
          assertEquals(name, "bil_persist_verified_store_purchase");
          assertEquals(options.expired, true);
          persistence.push(args);
          return Promise.resolve({
            data: {
              active: false,
              lifecycle: "expired",
              verified_at: "2026-11-16T13:30:00.000Z",
            },
            error: null,
          });
        },
      } as never,
    }),
    requireIntegrity: (input) => {
      effects.push(input.action);
      assertEquals(input.ownerId, owner);
      return Promise.resolve(input.body);
    },
    now: () => {
      clockReads++;
      assertEquals(effects.at(-1), "quota_rpc");
      return nowMs;
    },
    verifyAppleTransaction: () => {
      effects.push("verify_apple");
      assertEquals(options.expired, true);
      return Promise.resolve(purchase);
    },
    reconcileApple: () => {
      effects.push("reconcile_apple");
      assertEquals(options.expired, true);
      return Promise.resolve(purchase);
    },
    readAppleTransaction: () => {
      effects.push("read_apple");
      throw new Error("unexpected_store_read");
    },
  };
  const send = async (
    route: typeof routes[number],
    overrides: Record<string, unknown> = {},
    authorization = "Bearer synthetic-local-test",
  ) => {
    const response = await handler(
      new Request("https://fixture.invalid/verify-store-purchase", {
        method: "POST",
        headers: { authorization },
        body: JSON.stringify({
          action: route[0],
          source: "app_store",
          product_id: route[2],
          verification_data: "synthetic-unverified-input",
          // HTTP values cannot select the server clock or alter the limit.
          retry_after_seconds: 0,
          now: 0,
          p_limit: 999999,
          ...overrides,
        }),
      }),
      dependencies,
    );
    return { response, body: await response.json() };
  };
  return {
    send,
    effects,
    rateCalls,
    persistence,
    clockReads: () => clockReads,
  };
}

for (const route of routes) {
  Deno.test(`${route[0]} maps only the exact quota exception to 429 with body and header`, async () => {
    const f = fixture({ rateError: quota });
    const { response, body } = await f.send(route);
    assertEquals(response.status, 429);
    assertEquals(body, {
      error: "rate_limited",
      verified: false,
      entitlement_active: false,
      retry_after_seconds: 1800,
    });
    assertEquals(response.headers.get("retry-after"), "1800");
    assertEquals(response.headers.get("cache-control"), "no-store");
    assertEquals(response.headers.get("content-type"), "application/json");
    assertEquals(f.rateCalls, [{
      p_action: route[1],
      p_limit: 20,
      p_window_seconds: 3600,
    }]);
    assertEquals(f.effects, [
      "authenticate",
      `store.${route[0]}`,
      "quota_rpc",
    ]);
    assertEquals(f.persistence, []);
    assertEquals(f.clockReads(), 1);
  });

  Deno.test(`${route[0]} unknown RPC errors remain unavailable without leaking or claiming quota`, async () => {
    for (
      const rateError of [
        { code: "42501", message: "authentication_required" },
        { code: "22023", message: "invalid_rate_limit_contract" },
        { code: "08006", message: "rate limit exceeded" },
        { code: "P0001", message: "other private RPC exception" },
        { code: "P0001", message: "rate limit exceeded extra" },
        { code: "P0001", message: "Rate limit exceeded" },
        { message: "rate limit exceeded" },
        {},
      ]
    ) {
      const f = fixture({ rateError });
      const { response, body } = await f.send(route);
      assertEquals(response.status, 503);
      assertEquals(body, {
        error: "rate_limit_unavailable",
        verified: false,
        entitlement_active: false,
      });
      assertEquals(response.headers.get("retry-after"), null);
      assertEquals(f.clockReads(), 0);
      assertEquals(f.effects, [
        "authenticate",
        `store.${route[0]}`,
        "quota_rpc",
      ]);
      assertEquals(f.persistence, []);
    }
  });

  Deno.test(`${route[0]} Retry-After is a positive bounded fixed-UTC-window delay`, async () => {
    for (
      const [nowMs, expected] of [
        [Date.parse("2026-11-16T13:00:00.000Z"), 3600],
        [Date.parse("2026-11-16T13:00:00.001Z"), 3600],
        [Date.parse("2026-11-16T13:59:58.999Z"), 2],
        [Date.parse("2026-11-16T13:59:59.000Z"), 1],
        [Date.parse("2026-11-16T13:59:59.999Z"), 1],
        [Date.parse("2026-11-16T14:00:00.000Z"), 3600],
        [Number.NaN, 3600],
        [Number.POSITIVE_INFINITY, 3600],
      ]
    ) {
      const f = fixture({ rateError: quota, nowMs });
      const { response, body } = await f.send(route);
      assertEquals(response.status, 429);
      assertEquals(body.retry_after_seconds, expected);
      assertEquals(response.headers.get("retry-after"), String(expected));
      assertEquals(Number.isInteger(body.retry_after_seconds), true);
      assertEquals(body.retry_after_seconds >= 1, true);
      assertEquals(body.retry_after_seconds <= 3600, true);
      assertEquals(f.persistence, []);
    }
  });

  Deno.test(`${route[0]} a thrown RPC transport error is unavailable, never quota`, async () => {
    const f = fixture({ rpcThrows: true });
    const { response, body } = await f.send(route);
    assertEquals(response.status, 503);
    assertEquals(body, {
      error: "rate_limit_unavailable",
      verified: false,
      entitlement_active: false,
    });
    assertEquals(response.headers.get("retry-after"), null);
    assertEquals(f.clockReads(), 0);
    assertEquals(f.persistence, []);
  });

  Deno.test(`${route[0]} reads the rejection clock after an RPC crosses the UTC hour`, async () => {
    const f = fixture({
      rateError: quota,
      nowMs: Date.parse("2026-11-16T13:59:59.999Z"),
      afterRpcMs: Date.parse("2026-11-16T14:00:00.000Z"),
    });
    const { response, body } = await f.send(route);
    assertEquals(response.status, 429);
    assertEquals(body.retry_after_seconds, 3600);
    assertEquals(response.headers.get("retry-after"), "3600");
    assertEquals(f.clockReads(), 1);
  });
}

Deno.test("authentication failure cannot consume quota or receive a quota classification", async () => {
  const f = fixture({ rateError: quota });
  const { response, body } = await f.send(routes[0], {}, "");
  assertEquals(response.status, 401);
  assertEquals(body.error, "authentication_required");
  assertEquals(response.headers.get("retry-after"), null);
  assertEquals(f.effects, []);
  assertEquals(f.rateCalls, []);
  assertEquals(f.clockReads(), 0);
});

Deno.test("a successful quota RPC still rejects an empty receipt without granting", async () => {
  const f = fixture();
  const { response, body } = await f.send(routes[0], { verification_data: "" });
  assertEquals(response.status, 400);
  assertEquals(body.error, "invalid_receipt_payload");
  assertEquals(body.entitlement_active, false);
  assertEquals(response.headers.get("retry-after"), null);
  assertEquals(f.clockReads(), 0);
  assertEquals(f.persistence, []);
});

Deno.test("an allowed request preserves canonical expiry and never promotes inactive access", async () => {
  const f = fixture({ expired: true });
  const { response, body } = await f.send(routes[0]);
  assertEquals(response.status, 200);
  assertEquals(body.verified, true);
  assertEquals(body.entitlement_active, false);
  assertEquals(body.lifecycle, "expired");
  assertEquals(response.headers.get("retry-after"), null);
  assertEquals("retry_after_seconds" in body, false);
  assertEquals(f.clockReads(), 0);
  assertEquals(f.persistence.length, 1);
  assertEquals(f.persistence[0].p_lifecycle, "expired");
  assertEquals(f.persistence[0].p_owner_id, owner);
});
