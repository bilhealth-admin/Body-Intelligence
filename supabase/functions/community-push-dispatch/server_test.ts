import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handler, type PushDispatchDependencies } from "./server.ts";

const dispatchSecret = "unit-test-dispatch-secret";
const event = {
  id: "event-one",
  title: "BIL",
  body: "Private coach reply",
  category: "ai_coach",
  copy_key: "ai_coach_reply",
  deep_link: "bil://community",
};
const token = {
  device_token_id: "device-one",
  provider_token: "unit-provider-token",
  platform: "apns",
  sensitive_preview_allowed: false,
  delivery_key: "event-one:device-one",
};
function request(secret: string | null = dispatchSecret, method = "POST") {
  return new Request("https://example.test/push", {
    method,
    headers: secret === null ? {} : { "x-bil-dispatch-secret": secret },
  });
}
function fakeRuntime(options: {
  secret?: string | null;
  providerResponse?: Response;
  outboxError?: boolean;
  claimError?: boolean;
  resultError?: boolean;
  event?: Record<string, unknown>;
  sensitivePreviewAllowed?: boolean;
} = {}) {
  const calls: Array<{ name: string; args?: Record<string, unknown> }> = [];
  const payloads: Array<Record<string, unknown>> = [];
  const environment: Record<string, string> = {
    SUPABASE_URL: "https://example.test",
    SUPABASE_SERVICE_ROLE_KEY: "unit-service-key",
    BIL_APNS_GATEWAY_URL: "https://gateway.example.test/push",
    BIL_APNS_GATEWAY_SECRET: "unit-gateway-secret",
    ...(options.secret === null ? {} : {
      BIL_INTERNAL_DISPATCH_SECRET: options.secret ?? dispatchSecret,
    }),
  };
  const dependencies: PushDispatchDependencies = {
    env: (name) => environment[name],
    client: (() => ({
      from: () => ({
        select: () => ({
          is: () => ({
            order: () => ({
              limit: () =>
                Promise.resolve({
                  data: options.outboxError ? null : [{ ...event, ...options.event }],
                  error: options.outboxError ? { message: "offline" } : null,
                }),
            }),
          }),
        }),
      }),
      rpc: (name: string, args?: Record<string, unknown>) => {
        calls.push({ name, args });
        const fail =
          (name === "bil_claim_push_deliveries" && options.claimError) ||
          (name === "bil_record_push_delivery_result" && options.resultError);
        return Promise.resolve({
          data: name === "bil_claim_push_deliveries"
            ? [{ ...token, sensitive_preview_allowed: options.sensitivePreviewAllowed ?? false }]
            : null,
          error: fail ? { message: "offline" } : null,
        });
      },
    })) as unknown as PushDispatchDependencies["client"],
    fetch: (input, init) => {
      assertEquals(String(input), environment.BIL_APNS_GATEWAY_URL);
      assertEquals(init?.redirect, "error");
      assertEquals(
        new Headers(init?.headers).get("idempotency-key"),
        token.delivery_key,
      );
      payloads.push(JSON.parse(String(init?.body)));
      return Promise.resolve(
        options.providerResponse ?? new Response(null, { status: 200 }),
      );
    },
  };
  return { dependencies, calls, payloads };
}

Deno.test("push rejects absent or mismatched dispatch secrets before any work", async () => {
  for (const secret of [null, "wrong-secret", `${dispatchSecret}extra`]) {
    const fake = fakeRuntime();
    assertEquals(
      (await handler(request(secret), fake.dependencies)).status,
      401,
    );
    assertEquals(fake.calls.length, 0);
    assertEquals(fake.payloads.length, 0);
  }
  const missing = fakeRuntime({ secret: null });
  assertEquals(
    (await handler(request(null), missing.dependencies)).status,
    503,
  );
  assertEquals(
    (await handler(request(null, "GET"), missing.dependencies)).status,
    405,
  );
});

Deno.test("private push previews stay generic and every delivery is recorded once", async () => {
  const fake = fakeRuntime();
  const response = await handler(request(), fake.dependencies);
  assertEquals(response.status, 200);
  assertEquals(await response.json(), {
    processed: 1,
    delivered: 1,
    failed: 0,
  });
  assertEquals(fake.payloads.length, 1);
  assertEquals(fake.payloads[0].title, "BIL");
  assertEquals(fake.payloads[0].body, "You have a new private update.");
  assertEquals(fake.payloads[0].idempotency_key, token.delivery_key);
  assertEquals(fake.calls.map((c) => c.name), [
    "bil_quarantine_stale_push_outbox",
    "bil_claim_push_deliveries",
    "bil_record_push_delivery_result",
    "bil_finalize_push_outbox",
  ]);
  assertEquals(fake.calls[2].args?.p_delivered, true);
});

for (const invalidHeader of [false, true]) {
  Deno.test(`404 deactivates a token only with explicit trusted evidence: ${invalidHeader}`, async () => {
    const fake = fakeRuntime({
      providerResponse: new Response(null, {
        status: 404,
        headers: invalidHeader ? { "x-bil-token-status": "invalid" } : {},
      }),
    });
    const response = await handler(request(), fake.dependencies);
    assertEquals(await response.json(), {
      processed: 1,
      delivered: 0,
      failed: 1,
    });
    assertEquals(fake.calls[2].args?.p_permanent_token_failure, invalidHeader);
    assertEquals(fake.calls[2].args?.p_delivered, false);
  });
}

Deno.test("outbox, claim, and result failures cannot masquerade as delivery", async () => {
  const outbox = fakeRuntime({ outboxError: true });
  assertEquals((await handler(request(), outbox.dependencies)).status, 500);
  assertEquals(outbox.payloads.length, 0);
  const claim = fakeRuntime({ claimError: true });
  assertEquals(await (await handler(request(), claim.dependencies)).json(), {
    processed: 1,
    delivered: 0,
    failed: 1,
  });
  assertEquals(claim.payloads.length, 0);
  const result = fakeRuntime({ resultError: true });
  assertEquals(await (await handler(request(), result.dependencies)).json(), {
    processed: 1,
    delivered: 0,
    failed: 1,
  });
});


Deno.test("disabled sensitive previews mask health and identity in both visible fields", async () => {
  const fake = fakeRuntime({
    event: {
      title: "Private sender: glucose result 13.1",
      body: "Confidential diagnosis and private coach reply",
    },
  });
  assertEquals((await handler(request(), fake.dependencies)).status, 200);
  assertEquals(fake.payloads[0].title, "BIL");
  assertEquals(fake.payloads[0].body, "You have a new private update.");
  const delivered = JSON.stringify(fake.payloads[0]);
  assertEquals(delivered.includes("glucose"), false);
  assertEquals(delivered.includes("Confidential"), false);
  assertEquals(delivered.includes("Private sender"), false);
});

Deno.test("event locale never grants authority to expose or replace private copy", async () => {
  for (const locale of ["ar", "ar-EG", "zh-Hant", "unknown", null]) {
    const fake = fakeRuntime({
      event: {
        title: "Sensitive user title",
        body: "Sensitive user body",
        locale,
        recipient_locale: locale,
        private_preview_title: "Untrusted localized title",
        private_preview_body: "Untrusted localized body",
      },
    });
    await handler(request(), fake.dependencies);
    assertEquals(fake.payloads[0].title, "BIL");
    assertEquals(fake.payloads[0].body, "You have a new private update.");
  }
});

Deno.test("explicit sensitive preview consent preserves the intended title and body", async () => {
  const fake = fakeRuntime({
    sensitivePreviewAllowed: true,
    event: { title: "Chosen preview title", body: "Chosen preview body" },
  });
  await handler(request(), fake.dependencies);
  assertEquals(fake.payloads[0].title, "Chosen preview title");
  assertEquals(fake.payloads[0].body, "Chosen preview body");
});

Deno.test("known administrative copy preserves its existing visible notification", async () => {
  const fake = fakeRuntime({
    event: {
      copy_key: "admin_notification_gift_v1",
      title: "BIL account update",
      body: "Your account gift is available in BIL.",
    },
  });
  await handler(request(), fake.dependencies);
  assertEquals(fake.payloads[0].title, "BIL account update");
  assertEquals(fake.payloads[0].body, "Your account gift is available in BIL.");
});
