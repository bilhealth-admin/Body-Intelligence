import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleTranslation, type TranslationRuntime } from "./index.ts";
function setup(
  access: "allowed" | "unauthorized" | "limited" | "unavailable" = "allowed",
) {
  const calls: { url: string; body: unknown }[] = [];
  const deps: TranslationRuntime = {
    key: () => "synthetic-server-key",
    authorize: async () => access,
    fetch: ((url: string, options: RequestInit) => {
      calls.push({ url, body: JSON.parse(options.body as string) });
      return Promise.resolve(
        new Response(JSON.stringify({
          data: {
            translations: [
              {
                translatedText: "مرحبا &amp; أهلا",
                detectedSourceLanguage: "en",
              },
            ],
          },
        })),
      );
    }) as typeof fetch,
  };
  const request = (body: unknown) =>
    new Request("https://fixture.invalid", {
      method: "POST",
      body: JSON.stringify(body),
    });
  return { calls, deps, request };
}
Deno.test("explicit text-only translation uses server credential and auto detection", async () => {
  const { calls, deps, request } = setup();
  const response = await handleTranslation(
    request({ texts: { body: "Hello" }, targetTag: "ar" }),
    deps,
  );
  assertEquals(response.status, 200);
  assertEquals(await response.json(), {
    texts: { body: "مرحبا & أهلا" },
    engine: "google",
    sameLanguage: false,
  });
  assertEquals(calls[0].body, { q: ["Hello"], target: "ar", format: "text" });
  assertEquals(response.headers.get("cache-control"), "no-store");
});
for (
  const [access, status] of [["unauthorized", 401], ["limited", 429], [
    "unavailable",
    503,
  ]] as const
) {
  Deno.test(`fails closed before provider when ${access}`, async () => {
    const { calls, deps, request } = setup(access);
    assertEquals(
      (await handleTranslation(
        request({ texts: { body: "Hello" }, targetTag: "ar" }),
        deps,
      )).status,
      status,
    );
    assertEquals(calls.length, 0);
  });
}
for (
  const texts of [
    {},
    { body: "x".repeat(12001) },
    { body: "x", title: "y", extra: "z" },
    { id: "private-id" },
    ["x"],
  ]
) {
  Deno.test(`rejects invalid text input ${JSON.stringify(texts).slice(0, 30)}`, async () => {
    const { calls, deps, request } = setup();
    assertEquals(
      (await handleTranslation(request({ texts, targetTag: "ar" }), deps))
        .status,
      400,
    );
    assertEquals(calls.length, 0);
  });
}
Deno.test("rejects oversized streams and invalid target before provider", async () => {
  const { calls, deps, request } = setup();
  assertEquals(
    (await handleTranslation(
      request({ texts: { body: "x".repeat(96000) }, targetTag: "ar" }),
      deps,
    )).status,
    413,
  );
  assertEquals(
    (await handleTranslation(
      request({ texts: { body: "Hi" }, targetTag: "ar?key=steal" }),
      deps,
    )).status,
    400,
  );
  assertEquals(calls.length, 0);
});
Deno.test("provider errors never echo text or credential", async () => {
  const { deps, request } = setup();
  deps.fetch = () =>
    Promise.reject(new Error("private provider body and synthetic-server-key"));
  const response = await handleTranslation(
    request({ texts: { body: "Hello" }, targetTag: "ar" }),
    deps,
  );
  assertEquals(response.status, 503);
  const result = await response.text();
  assert(!result.includes("synthetic-server-key"));
  assert(!result.includes("Hello"));
});
Deno.test("batch preserves empty title and rejects missing translated fields", async () => {
  const { deps, request, calls } = setup();
  const response = await handleTranslation(
    request({ texts: { title: "", body: "Hello" }, targetTag: "zh-Hant" }),
    deps,
  );
  assertEquals(response.status, 200);
  assertEquals((await response.json()).texts.title, "");
  assertEquals((calls[0].body as { target: string }).target, "zh-TW");
  deps.fetch = () =>
    Promise.resolve(new Response('{"data":{"translations":[]}}'));
  assertEquals(
    (await handleTranslation(
      request({ texts: { body: "Hello" }, targetTag: "ar" }),
      deps,
    )).status,
    502,
  );
});
