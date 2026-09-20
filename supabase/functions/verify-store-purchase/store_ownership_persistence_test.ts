import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handler, persistVerified } from "./store_backend.ts";
import { deriveAppleAppAccountToken } from "./apple_purchase_ownership.ts";

const ownerId = "00000000-0000-4000-8000-000000000001";
const otherOwnerId = "00000000-0000-4000-8000-000000000002";
const applePurchase = {
  provider: "apple" as const,
  productId: "bil_premium",
  originalTransactionId: "original-ownership-test",
  transactionId: "latest-ownership-test",
  packageOrBundleId: "app.bil.health",
  environment: "sandbox" as const,
  lifecycle: "active" as const,
};

function mockAdmin(
  existing: { owner_id: string; environment: string } | null = null,
  lookupError: { message: string } | null = null,
  active = true,
  rpcResult?: unknown,
) {
  const reads: unknown[] = [];
  const writes: unknown[] = [];
  const query = {
    select(fields: string) {
      reads.push(["select", fields]);
      return query;
    },
    eq(field: string, value: string) {
      reads.push([field, value]);
      return query;
    },
    maybeSingle() {
      return Promise.resolve({ data: existing, error: lookupError });
    },
  };
  const admin = {
    rpc(name: string, args: Record<string, unknown>) {
      if (name === "bil_lookup_store_subscription_owner") {
        reads.push([name, args]);
        return Promise.resolve({ data: existing, error: lookupError });
      }
      writes.push([name, args]);
      return Promise.resolve({
        data: rpcResult === undefined
          ? {
            active,
            lifecycle: args.p_lifecycle,
            verified_at: args.p_verified_at,
          }
          : rpcResult,
        error: null,
      });
    },
  } as unknown as Parameters<typeof persistVerified>[0];
  return { admin, reads, writes };
}

Deno.test("new Apple claim without signed owner token cannot write any entitlement", async () => {
  const fixture = mockAdmin();
  await assertRejects(
    () => persistVerified(fixture.admin, ownerId, applePurchase),
    Error,
    "apple_account_binding_required",
  );
  assertEquals(fixture.writes, []);
  assertEquals(fixture.reads, [
    ["bil_lookup_store_subscription_owner", {
      p_provider: "apple",
      p_original_transaction_id: applePurchase.originalTransactionId,
    }],
  ]);
});

Deno.test("restoring another BIL member's signed purchase cannot write entitlement", async () => {
  const fixture = mockAdmin();
  await assertRejects(
    () =>
      persistVerified(fixture.admin, otherOwnerId, {
        ...applePurchase,
        appAccountToken: awaitToken,
      }),
    Error,
    "purchase_owned_by_another_account",
  );
  assertEquals(fixture.writes, []);
});

// The token is synthetic and derived only from this test's constant user ID.
const awaitToken = await deriveAppleAppAccountToken(ownerId);

Deno.test("signed owner mismatch rejects even if an old row was bound to the wrong member", async () => {
  const fixture = mockAdmin({ owner_id: otherOwnerId, environment: "sandbox" });
  await assertRejects(
    () =>
      persistVerified(fixture.admin, otherOwnerId, {
        ...applePurchase,
        appAccountToken: awaitToken,
      }),
    Error,
    "purchase_owned_by_another_account",
  );
  assertEquals(fixture.writes, []);
});

Deno.test("verified matching Apple owner reaches the ordered atomic persistence RPC", async () => {
  const fixture = mockAdmin();
  const signedAt = "2026-09-16T12:00:00.000Z";
  const result = await persistVerified(fixture.admin, ownerId, {
    ...applePurchase,
    signedAt,
    appAccountToken: awaitToken,
  });
  assertEquals(result.active, true);
  assertEquals(fixture.writes.length, 1);
  const [name, args] = fixture.writes[0] as [string, Record<string, unknown>];
  assertEquals(name, "bil_persist_verified_store_purchase");
  assertEquals(args.p_owner_id, ownerId);
  assertEquals(Object.keys(args).length, 16);
  assertEquals(args.p_store_signed_at, signedAt);
  assertEquals("appAccountToken" in args, false);
});

Deno.test("legacy receipt without account token restores only its existing BIL owner", async () => {
  const fixture = mockAdmin({ owner_id: ownerId, environment: "sandbox" });
  await persistVerified(fixture.admin, ownerId, applePurchase);
  assertEquals(fixture.writes.length, 1);
  const [, args] = fixture.writes[0] as [string, Record<string, unknown>];
  assertEquals(args.p_store_signed_at, null);
});

Deno.test("canonical persistence result wins over a stale active receipt", async () => {
  const canonical = {
    active: false,
    lifecycle: "refunded",
    verified_at: "2026-09-16T14:00:00.000Z",
  };
  const fixture = mockAdmin(null, null, true, canonical);
  const result = await persistVerified(fixture.admin, ownerId, {
    ...applePurchase,
    appAccountToken: awaitToken,
  });
  assertEquals(result, {
    active: false,
    lifecycle: "refunded",
    verifiedAt: canonical.verified_at,
  });
});

Deno.test("legacy or malformed persistence responses cannot grant access", async () => {
  for (
    const result of [
      true,
      false,
      null,
      {},
      { active: true, lifecycle: "active" },
      { active: true, lifecycle: "active", verified_at: "invalid" },
      {
        active: "true",
        lifecycle: "active",
        verified_at: "2026-09-16T12:00:00Z",
      },
    ]
  ) {
    const fixture = mockAdmin(null, null, true, result);
    await assertRejects(
      () =>
        persistVerified(fixture.admin, ownerId, {
          ...applePurchase,
          appAccountToken: awaitToken,
        }),
      Error,
      "persistence_failed",
    );
  }
});

Deno.test("failed ownership lookup fails closed even when signed token matches", async () => {
  const fixture = mockAdmin(null, { message: "test read failure" });
  await assertRejects(
    () =>
      persistVerified(fixture.admin, ownerId, {
        ...applePurchase,
        appAccountToken: awaitToken,
      }),
    Error,
    "apple_ownership_check_unavailable",
  );
  assertEquals(fixture.writes, []);
});

Deno.test("conflicting signed historical receipt cannot bypass canonical account binding", async () => {
  const fixture = mockAdmin();
  const conflictingToken = await deriveAppleAppAccountToken(otherOwnerId);
  await assertRejects(
    () =>
      persistVerified(fixture.admin, ownerId, {
        ...applePurchase,
        appAccountToken: awaitToken,
      }, [conflictingToken]),
    Error,
    "purchase_owned_by_another_account",
  );
  assertEquals(fixture.writes, []);
});

Deno.test("matching account token does not promote an inactive server result", async () => {
  const fixture = mockAdmin(null, null, false);
  const result = await persistVerified(fixture.admin, ownerId, {
    ...applePurchase,
    lifecycle: "expired",
    appAccountToken: awaitToken,
  });
  assertEquals(result.active, false);
});

Deno.test("Apple terminal state can remove access from the exact previously misbound owner", async () => {
  for (const lifecycle of ["expired", "refunded", "revoked"] as const) {
    const fixture = mockAdmin(
      { owner_id: otherOwnerId, environment: "sandbox" },
      null,
      false,
    );
    const result = await persistVerified(fixture.admin, otherOwnerId, {
      ...applePurchase,
      lifecycle,
      appAccountToken: awaitToken,
    });
    assertEquals(result.active, false);
    assertEquals(fixture.writes.length, 1);
    const [, args] = fixture.writes[0] as [string, Record<string, unknown>];
    assertEquals(args.p_owner_id, otherOwnerId);
    assertEquals(args.p_lifecycle, lifecycle);
  }
});

Deno.test("terminal state exception cannot create ownership, cross owners or cross environments", async () => {
  for (
    const existing of [
      null,
      { owner_id: ownerId, environment: "sandbox" },
      { owner_id: otherOwnerId, environment: "production" },
    ]
  ) {
    const fixture = mockAdmin(existing, null, false);
    await assertRejects(
      () =>
        persistVerified(fixture.admin, otherOwnerId, {
          ...applePurchase,
          lifecycle: "revoked",
          appAccountToken: awaitToken,
        }),
    );
    assertEquals(fixture.writes, []);
  }
});

Deno.test("access-granting lifecycles never bypass mismatched Apple account binding", async () => {
  for (
    const lifecycle of ["active", "trial", "grace_period", "cancelled"] as const
  ) {
    const fixture = mockAdmin({
      owner_id: otherOwnerId,
      environment: "sandbox",
    });
    await assertRejects(
      () =>
        persistVerified(fixture.admin, otherOwnerId, {
          ...applePurchase,
          lifecycle,
          appAccountToken: awaitToken,
        }),
      Error,
      "purchase_owned_by_another_account",
    );
    assertEquals(fixture.writes, []);
  }
});

Deno.test("Google persistence remains on its existing path without an Apple lookup", async () => {
  const fixture = mockAdmin();
  await persistVerified(fixture.admin, ownerId, {
    ...applePurchase,
    provider: "google",
  });
  assertEquals(fixture.reads, []);
  assertEquals(fixture.writes.length, 1);
});

Deno.test("new member cannot restore without a receipt even with a client-supplied account token", async () => {
  const receipt = "";
  const fixture = mockAdmin();
  const response = await handler(
    new Request("https://example.test/verify-store-purchase", {
      method: "POST",
      headers: { authorization: "Bearer test-user" },
      body: JSON.stringify({
        action: "verify_purchase",
        source: "app_store",
        product_id: "bil_premium",
        verification_data: receipt,
        // A client-supplied claim is not a substitute for Apple's JWS.
        appAccountToken: awaitToken,
      }),
    }),
    {
      clients: () => ({
        admin: fixture.admin,
        auth: {
          auth: {
            getUser: () =>
              Promise.resolve({
                data: { user: { id: ownerId } },
                error: null,
              }),
          },
          rpc: () => Promise.resolve({ data: null, error: null }),
        } as never,
      }),
      requireIntegrity: (input) => Promise.resolve(input.body),
    },
  );
  const result = await response.json();
  assertEquals(result.error, "invalid_receipt_payload");
  assertEquals(result.verified, false);
  assertEquals(result.entitlement_active, false);
  assertEquals(fixture.writes, []);
});
