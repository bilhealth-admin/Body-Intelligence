import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handler } from "./store_backend.ts";

function isolatedRequest(
  headers: Record<string, string> = {},
): Request {
  return new Request("https://fixture.invalid/functions/v1/verify-store-purchase", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...headers,
    },
    body: JSON.stringify({ action: "reconcile" }),
  });
}

Deno.test("reconciliation rejection stays forbidden, not retryable 503", async () => {
  const cases: Array<{
    headers: Record<string, string>;
    secret: string;
  }> = [
      { headers: {}, secret: "" },
      { headers: {}, secret: "fixture-nonproduction-secret" },
      {
        headers: { "x-bil-reconciliation-secret": "incorrect" },
        secret: "fixture-nonproduction-secret",
      },
      {
        headers: { "x-bil-reconciliation-secret": "x".repeat(28) },
        secret: "fixture-nonproduction-secret",
      },
    ];
  for (const item of cases) {
    const response = await handler(
      isolatedRequest(item.headers),
      {
        readEnvironment: (key) =>
          key === "BIL_RECONCILIATION_SECRET" ? item.secret : "",
      },
    );
    assertEquals(response.status, 403);
    const value = await response.json();
    assertEquals(value.error, "reconciliation_forbidden");
    assertEquals(value.verified, false);
    assertEquals(value.entitlement_active, false);
    assert(!JSON.stringify(value).includes(item.secret || "__unknown_secret__"));
    assertEquals(response.headers.get("content-type"), "application/json");
  }
});

Deno.test("a foreign method cannot enter reconciliation", async () => {
  const response = await handler(new Request(
    "https://fixture.invalid/functions/v1/verify-store-purchase",
    { method: "GET" },
  ));
  assertEquals(response.status, 405);
  assertEquals((await response.json()).error, "method_not_allowed");
});
