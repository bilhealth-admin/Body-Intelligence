import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handler } from "./server.ts";

const payload = {
  token: "a".repeat(64),
  title: "BIL",
  body: "You received a gift.",
  deep_link: "bil://settings/ai-coach",
  idempotency_key: "outbox:device",
  data: { category: "ai_coach" },
};

const request = (provider = "apns", secret = "gateway-secret") =>
  new Request(`https://example.test/gateway?provider=${provider}`, {
    method: "POST",
    headers: {
      authorization: `Bearer ${secret}`,
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });

Deno.test("gateway rejects unauthorized and malformed requests", async () => {
  const env = (name: string) => name === "BIL_PUSH_GATEWAY_SECRET" ? "gateway-secret" : undefined;
  assertEquals((await handler(request("apns", "wrong"), { env })).status, 401);
  assertEquals((await handler(request("unknown"), { env })).status, 400);
  assertEquals((await handler(new Request("https://example.test", { method: "GET" }), { env })).status, 405);
});

Deno.test("gateway fails closed when provider credentials are absent", async () => {
  const env = (name: string) => name === "BIL_PUSH_GATEWAY_SECRET" ? "gateway-secret" : undefined;
  assertEquals((await handler(request("apns"), { env })).status, 503);
  assertEquals((await handler(request("fcm"), { env })).status, 503);
});

Deno.test("APNs invalid token shape is terminal without a network request", async () => {
  const environment: Record<string, string> = {
    BIL_PUSH_GATEWAY_SECRET: "gateway-secret",
    BIL_APNS_AUTH_KEY_P8: "private-key-placeholder",
    BIL_APNS_KEY_ID: "ABCDEFGHIJ",
    BIL_APNS_TEAM_ID: "KLMNOPQRST",
    BIL_APNS_BUNDLE_ID: "com.bilhealth.bodyintelligencelog",
  };
  let fetched = false;
  const response = await handler(
    new Request("https://example.test/gateway?provider=apns", {
      method: "POST",
      headers: { authorization: "Bearer gateway-secret" },
      body: JSON.stringify({ ...payload, token: "not-an-apns-token" }),
    }),
    {
      env: (name) => environment[name],
      fetch: () => { fetched = true; return Promise.resolve(new Response()); },
    },
  );
  assertEquals(response.status, 410);
  assertEquals(response.headers.get("x-bil-token-status"), "invalid");
  assertEquals(fetched, false);
});
