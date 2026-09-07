import { type FoodSearchRuntime, handleFoodSearchRequest } from "./index.ts";

function expectEqual(actual: unknown, expected: unknown, label: string) {
  if (actual !== expected) {
    throw new Error(`${label}: expected ${expected}, got ${actual}`);
  }
}

function runtime({
  quota = "allowed",
  fetchImpl,
  translateImpl,
}: {
  quota?: "allowed" | "rate_limited" | "unavailable";
  fetchImpl?: typeof fetch;
  translateImpl?: FoodSearchRuntime["translate"];
} = {}): FoodSearchRuntime {
  return {
    authorize: async () => ({
      ok: true,
      consumeQuota: async () => quota,
    }),
    apiKey: () => "test-key",
    fetch: fetchImpl ?? (async () => {
      throw new Error("Unexpected USDA request");
    }) as typeof fetch,
    translate: translateImpl,
  };
}

Deno.test("rejects a chunked request over the byte cap without USDA access", async () => {
  let fetches = 0;
  const oversized = new ReadableStream<Uint8Array>({
    start(controller) {
      controller.enqueue(new Uint8Array(3000));
      controller.enqueue(new Uint8Array(1097));
      controller.close();
    },
  });
  const response = await handleFoodSearchRequest(
    new Request("https://example.test/food-search", {
      method: "POST",
      body: oversized,
    }),
    runtime({
      fetchImpl: (async () => {
        fetches += 1;
        return new Response("{}");
      }) as typeof fetch,
    }),
  );

  expectEqual(response.status, 413, "status");
  expectEqual(fetches, 0, "USDA fetch count");
});

Deno.test("rate-limited member cannot reach USDA", async () => {
  let fetches = 0;
  const response = await handleFoodSearchRequest(
    new Request("https://example.test/food-search", {
      method: "POST",
      body: JSON.stringify({ query: "apple", locale: "en" }),
    }),
    runtime({
      quota: "rate_limited",
      fetchImpl: (async () => {
        fetches += 1;
        return new Response("{}");
      }) as typeof fetch,
    }),
  );

  expectEqual(response.status, 429, "status");
  expectEqual(fetches, 0, "USDA fetch count");
});

Deno.test("quota backend failure fails closed before USDA", async () => {
  let fetches = 0;
  const response = await handleFoodSearchRequest(
    new Request("https://example.test/food-search", {
      method: "POST",
      body: JSON.stringify({ query: "apple", locale: "en" }),
    }),
    runtime({
      quota: "unavailable",
      fetchImpl: (async () => {
        fetches += 1;
        return new Response("{}");
      }) as typeof fetch,
    }),
  );

  expectEqual(response.status, 503, "status");
  expectEqual(fetches, 0, "USDA fetch count");
});

Deno.test("quota is consumed before one bounded USDA search", async () => {
  const events: string[] = [];
  const testRuntime: FoodSearchRuntime = {
    authorize: async () => ({
      ok: true,
      consumeQuota: async () => {
        events.push("quota");
        return "allowed";
      },
    }),
    apiKey: () => "test-key",
    fetch: (async () => {
      events.push("fetch");
      return new Response(
        JSON.stringify({
          foods: [{ fdcId: 1, description: "Apple" }],
        }),
        { status: 200 },
      );
    }) as typeof fetch,
  };
  const response = await handleFoodSearchRequest(
    new Request("https://example.test/food-search", {
      method: "POST",
      body: JSON.stringify({ query: "apple", locale: "en", limit: 10 }),
    }),
    testRuntime,
  );

  expectEqual(response.status, 200, "status");
  expectEqual(events.join(","), "quota,fetch", "event order");
});

Deno.test("translates a non-English query before the USDA request", async () => {
  let requestBody: Record<string, unknown> | null = null;
  const response = await handleFoodSearchRequest(
    new Request("https://example.test/food-search", {
      method: "POST",
      body: JSON.stringify({ query: "تفاح", locale: "ar", limit: 10 }),
    }),
    runtime({
      translateImpl: async (value, source, target) => {
        expectEqual(value, "تفاح", "translation input");
        expectEqual(source, "ar", "translation source");
        expectEqual(target, "en", "translation target");
        return "apple";
      },
      fetchImpl: (async (_url, init) => {
        requestBody = JSON.parse(String(init?.body)) as Record<string, unknown>;
        return new Response(
          JSON.stringify({ foods: [{ fdcId: 1, description: "Apple" }] }),
          { status: 200 },
        );
      }) as typeof fetch,
    }),
  );

  expectEqual(response.status, 200, "status");
  expectEqual(requestBody?.query, "apple", "USDA translated query");
  expectEqual((await response.json()).search_query, "apple", "response query");
});

Deno.test("uses a reviewed mobile search hint for a known non-English food", async () => {
  let translated = false;
  let requestBody: Record<string, unknown> | null = null;
  const response = await handleFoodSearchRequest(
    new Request("https://example.test/food-search", {
      method: "POST",
      body: JSON.stringify({
        query: "بطيخ الكيوي",
        locale: "ar",
        search_hint: "watermelon",
      }),
    }),
    runtime({
      translateImpl: async () => {
        translated = true;
        return "should not be used";
      },
      fetchImpl: (async (_url, init) => {
        requestBody = JSON.parse(String(init?.body)) as Record<string, unknown>;
        return new Response(
          JSON.stringify({ foods: [{ fdcId: 1, description: "Watermelon" }] }),
          { status: 200 },
        );
      }) as typeof fetch,
    }),
  );

  expectEqual(response.status, 200, "status");
  expectEqual(translated, false, "translation call");
  expectEqual(requestBody?.query, "watermelon", "USDA hinted query");
});

Deno.test("keeps the watermelon fallback when the mobile hint is absent", async () => {
  let requestBody: Record<string, unknown> | null = null;
  const response = await handleFoodSearchRequest(
    new Request("https://example.test/food-search", {
      method: "POST",
      body: JSON.stringify({
        query: "بطيخ الكيوي",
        locale: "ar",
      }),
    }),
    runtime({
      translateImpl: async () => {
        throw new Error("translation should not be required");
      },
      fetchImpl: (async (_url, init) => {
        requestBody = JSON.parse(String(init?.body)) as Record<string, unknown>;
        return new Response(
          JSON.stringify({ foods: [{ fdcId: 1, description: "Watermelon" }] }),
          { status: 200 },
        );
      }) as typeof fetch,
    }),
  );

  expectEqual(response.status, 200, "status");
  expectEqual(requestBody?.query, "watermelon", "USDA server fallback query");
});

Deno.test("does not invoke translation for an English query", async () => {
  let translated = false;
  const response = await handleFoodSearchRequest(
    new Request("https://example.test/food-search", {
      method: "POST",
      body: JSON.stringify({ query: "apple", locale: "en" }),
    }),
    runtime({
      translateImpl: async () => {
        translated = true;
        return "تفاح";
      },
      fetchImpl: (async () =>
        new Response(
          JSON.stringify({ foods: [{ fdcId: 1, description: "Apple" }] }),
          { status: 200 },
        )) as typeof fetch,
    }),
  );

  expectEqual(response.status, 200, "status");
  expectEqual(translated, false, "English translation call");
});
