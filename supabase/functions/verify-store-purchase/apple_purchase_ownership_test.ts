import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  assertApplePurchaseOwnership,
  deriveAppleAppAccountToken,
  type ExistingApplePurchaseOwner,
} from "./apple_purchase_ownership.ts";
import type { StoreEnvironment } from "./store_environment.ts";

const ownerId = "owner-1";
const token = "651a3935-1b54-5eac-b3c1-2e5307274f6c";
const anotherToken = "dbbea98e-af59-506f-911f-219825a11ce3";
const existingOwner: ExistingApplePurchaseOwner = Object.freeze({
  ownerId,
  environment: "sandbox",
});

Deno.test("Apple account UUID matches independently computed Flutter algorithm vectors", async () => {
  // Fixed vectors independently computed with .NET SHA256 + the client's
  // byte-level UUID formatting, not by calling the helper under test.
  for (
    const [owner, expected] of [
      [ownerId, token],
      [
        "00000000-0000-0000-0000-000000000000",
        "f52e1a23-f021-5255-a5a7-9bd6a5d06157",
      ],
      ["123e4567-e89b-12d3-a456-426614174000", anotherToken],
      ["مستخدم-اختبار", "f8017b19-e0c1-5fcf-bd1c-c862ad987f0d"],
    ]
  ) {
    assertEquals(await deriveAppleAppAccountToken(owner), expected);
  }
});

Deno.test("Apple account UUID and ownership reject malformed authenticated owner ids", async () => {
  for (const owner of ["", " ", "owner-1 ", " owner-1", null, 1]) {
    await assertRejects(
      () => deriveAppleAppAccountToken(owner as string),
      Error,
      "invalid_store_owner",
    );
    await assertRejects(
      () =>
        assertApplePurchaseOwnership(owner as string, [token], null, "sandbox"),
      Error,
      "invalid_store_owner",
    );
  }
});

Deno.test("Apple Restore cannot give a new BIL account access without signed binding", async () => {
  for (const tokens of [[], [null], [undefined], [null, undefined]]) {
    await assertRejects(
      () => assertApplePurchaseOwnership(ownerId, tokens, null, "sandbox"),
      Error,
      "apple_account_binding_required",
    );
  }
});

Deno.test("Apple first binding accepts matching signed token in either environment", async () => {
  for (const environment of ["sandbox", "production"] as const) {
    await assertApplePurchaseOwnership(ownerId, [token], null, environment);
  }
});

Deno.test("Apple canonical signed token may prove ownership when device token is absent", async () => {
  await assertApplePurchaseOwnership(
    ownerId,
    [undefined, token],
    null,
    "sandbox",
  );
  await assertApplePurchaseOwnership(ownerId, [null, token], null, "sandbox");
});

Deno.test("Apple device signed token may prove ownership when canonical token is absent", async () => {
  await assertApplePurchaseOwnership(ownerId, [token, null], null, "sandbox");
});

Deno.test("Apple signed tokens allow UUID case differences but not ownership differences", async () => {
  await assertApplePurchaseOwnership(
    ownerId,
    [token, token.toUpperCase(), undefined, null],
    existingOwner,
    "sandbox",
  );
});

Deno.test("Apple legacy tokenless refresh remains allowed only for its existing BIL owner", async () => {
  for (const tokens of [[], [null], [undefined], [null, undefined]]) {
    await assertApplePurchaseOwnership(
      ownerId,
      tokens,
      existingOwner,
      "sandbox",
    );
  }
});

Deno.test("Apple signed token for another BIL owner cannot create a new binding", async () => {
  await assertRejects(
    () =>
      assertApplePurchaseOwnership(ownerId, [anotherToken], null, "sandbox"),
    Error,
    "purchase_owned_by_another_account",
  );
});

Deno.test("Apple signed ownership mismatch overrides an existing possibly mistaken binding", async () => {
  await assertRejects(
    () =>
      assertApplePurchaseOwnership(
        ownerId,
        [anotherToken],
        existingOwner,
        "sandbox",
      ),
    Error,
    "purchase_owned_by_another_account",
  );
});

Deno.test("Apple every present device and canonical signed token must match the BIL owner", async () => {
  for (const tokens of [[token, anotherToken], [anotherToken, token]]) {
    await assertRejects(
      () => assertApplePurchaseOwnership(ownerId, tokens, null, "sandbox"),
      Error,
      "purchase_owned_by_another_account",
    );
  }
});

Deno.test("Apple existing owner conflict is rejected even with matching new user's token", async () => {
  for (const tokens of [[], [null], [token]]) {
    await assertRejects(
      () =>
        assertApplePurchaseOwnership(ownerId, tokens, {
          ...existingOwner,
          ownerId: "another-owner",
        }, "sandbox"),
      Error,
      "purchase_owned_by_another_account",
    );
  }
});

Deno.test("Apple existing bindings cannot cross sandbox and production", async () => {
  for (const tokens of [[], [token]]) {
    await assertRejects(
      () =>
        assertApplePurchaseOwnership(
          ownerId,
          tokens,
          existingOwner,
          "production",
        ),
      Error,
      "wrong_environment",
    );
  }
});

Deno.test("Apple malformed signed tokens are rejected rather than treated as missing legacy tokens", async () => {
  for (
    const value of [
      "",
      " ",
      0,
      false,
      {},
      [],
      ` ${token}`,
      `${token} `,
      token.replaceAll("-", ""),
      "not-a-uuid",
    ]
  ) {
    for (const previousOwner of [null, existingOwner]) {
      await assertRejects(
        () =>
          assertApplePurchaseOwnership(
            ownerId,
            [value],
            previousOwner,
            "sandbox",
          ),
        Error,
        "invalid_apple_account_token",
      );
    }
    await assertRejects(
      () =>
        assertApplePurchaseOwnership(ownerId, [token, value], null, "sandbox"),
      Error,
      "invalid_apple_account_token",
    );
  }
});

Deno.test("Apple wrong UUID version or nil UUID cannot match the deterministic account token", async () => {
  for (
    const value of [
      "00000000-0000-0000-0000-000000000000",
      token.replace("5eac", "4eac"),
    ]
  ) {
    await assertRejects(
      () => assertApplePurchaseOwnership(ownerId, [value], null, "sandbox"),
      Error,
      "purchase_owned_by_another_account",
    );
  }
});

Deno.test("Apple invalid database lookup records fail closed and never become new bindings", async () => {
  for (
    const value of [undefined, false, "owner-1", {}, { ownerId: "" }, {
      ownerId: " owner-1",
    }]
  ) {
    await assertRejects(
      () =>
        assertApplePurchaseOwnership(
          ownerId,
          [token],
          value as ExistingApplePurchaseOwner,
          "sandbox",
        ),
      Error,
      "purchase_owner_lookup_failed",
    );
  }
});

Deno.test("Apple invalid transaction or existing-record environment is rejected exactly", async () => {
  for (const value of [undefined, null, "", "Sandbox", "sandbox ", "other"]) {
    await assertRejects(
      () =>
        assertApplePurchaseOwnership(
          ownerId,
          [token],
          null,
          value as StoreEnvironment,
        ),
      Error,
      "wrong_environment",
    );
    await assertRejects(
      () =>
        assertApplePurchaseOwnership(ownerId, [token], {
          ownerId,
          environment: value as StoreEnvironment,
        }, "sandbox"),
      Error,
      "wrong_environment",
    );
  }
});

Deno.test("Apple malformed token collection fails closed even for an existing owner", async () => {
  for (const value of [undefined, null, token, {}]) {
    await assertRejects(
      () =>
        assertApplePurchaseOwnership(
          ownerId,
          value as readonly unknown[],
          existingOwner,
          "sandbox",
        ),
      Error,
      "invalid_apple_account_token",
    );
  }
});
