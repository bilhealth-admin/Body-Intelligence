import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handler } from "./server.ts";

const payload = { token: "ab".repeat(32), title: "BIL", body: "A private update",
  deep_link: "bil://community/messages", idempotency_key: "fixture-one" };
const request = (badge_count: unknown) => new Request("https://fixture.test/?provider=apns", {
  method: "POST", headers: { authorization: "Bearer fixture-secret" },
  body: JSON.stringify({ ...payload, badge_count }),
});
Deno.test("badge input rejects negative, fractional and string values", async () => {
  for (const count of [-1, 1.2, "7", 2147483648]) {
    assertEquals((await handler(request(count), {
      env: name => name === "BIL_PUSH_GATEWAY_SECRET" ? "fixture-secret" : undefined,
    })).status, 400);
  }
});
Deno.test("APNs receives the exact authoritative badge including zero", async () => {
  const keys = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]);
  const bytes = new Uint8Array(await crypto.subtle.exportKey("pkcs8", keys.privateKey));
  const pem = `-----BEGIN PRIVATE KEY-----\n${btoa(String.fromCharCode(...bytes))}\n-----END PRIVATE KEY-----`;
  const env: Record<string, string> = {
    BIL_PUSH_GATEWAY_SECRET: "fixture-secret", BIL_APNS_AUTH_KEY_P8: pem,
    BIL_APNS_KEY_ID: "TESTKEY001", BIL_APNS_TEAM_ID: "TESTTEAM01",
    BIL_APNS_BUNDLE_ID: "com.bilhealth.bodyintelligencelog",
  };
  for (const count of [0, 140]) {
    const result = await handler(request(count), {
      env: name => env[name],
      fetch: (_input, init) => {
        const body = JSON.parse(String(init?.body));
        assertEquals(body.aps.badge, count);
        assertEquals(body.aps.alert.body, "A private update");
        return Promise.resolve(new Response(null, { status: 200 }));
      },
    });
    assertEquals(result.status, 200);
  }
});
