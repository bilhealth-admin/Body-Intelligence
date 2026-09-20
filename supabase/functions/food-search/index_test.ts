import { type FoodSearchRuntime, handleFoodSearchRequest } from "./index.ts";

function expectEqual(actual: unknown, expected: unknown, label: string) {
  if (actual !== expected) {
    throw new Error(`${label}: expected ${expected}, got ${actual}`);
  }
}

function runtime({
  quota = "allowed",
  fetchImpl,
}: {
  quota?: "allowed" | "rate_limited" | "unavailable";
  fetchImpl?: typeof fetch;
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
