import { FoodSearchMemo, searchMemoKey } from "./search_memo.ts";
import { type FoodSearchRuntime, handleFoodSearchRequest } from "./index.ts";
function equal(actual: unknown, expected: unknown) {
  if (actual !== expected) {
    throw new Error(`Expected ${expected}, got ${actual}`);
  }
}
Deno.test("memo coalesces concurrency, returns independent bodies, expires, and does not cache failures", async () => {
  let now = 0, calls = 0;
  const memo = new FoodSearchMemo(() => now);
  let release!: () => void;
  const pending = new Promise<void>((resolve) => release = resolve);
  const load = async () => {
    calls++;
    await pending;
    return new Response('{"status":"found"}', { status: 200 });
  };
  const a = memo.run("a", load), b = memo.run("a", load);
  equal(calls, 1);
  release();
  equal(await (await a).text(), '{"status":"found"}');
  equal(await (await b).text(), '{"status":"found"}');
  await memo.run("a", load);
  equal(calls, 1);
  now = 300001;
  await memo.run("a", load);
  equal(calls, 2);
  const fail = () => {
    calls++;
    return Promise.resolve(new Response("{}", { status: 503 }));
  };
  await memo.run("error", fail);
  await memo.run("error", fail);
  equal(calls, 4);
});
Deno.test("every identity and localization dimension partitions the memo", async () => {
  const base = await searchMemoKey("A", "apple", "ar", "JO", 12, "hint");
  for (
    const values of [
      ["B", "apple", "ar", "JO", 12, "hint"],
      ["A", "pear", "ar", "JO", 12, "hint"],
      ["A", "apple", "en", "JO", 12, "hint"],
      ["A", "apple", "ar", "US", 12, "hint"],
      ["A", "apple", "ar", "JO", 8, "hint"],
      ["A", "apple", "ar", "JO", 12, "other"],
    ] as [string, string, string, string, number, string][]
  ) {
    if (await searchMemoKey(...values) === base) {
      throw new Error("Scope collision");
    }
  }
});
Deno.test("warm requests still authenticate and consume quota; denied and new owners do not reuse a response", async () => {
  let owner = "A",
    quota: "allowed" | "rate_limited" = "allowed",
    auths = 0,
    quotas = 0,
    fetches = 0;
  const runtime: FoodSearchRuntime = {
    authorize: async () => {
      auths++;
      return {
        ok: true,
        ownerId: owner,
        consumeQuota: async () => {
          quotas++;
          return quota;
        },
      };
    },
    apiKey: () => "TEST-key",
    fetch: (async () => {
      fetches++;
      return new Response(
        JSON.stringify({
          foods: [{
            fdcId: 1,
            description: "TEST apple",
            foodNutrients: [{
              nutrientName: "Energy",
              value: 52,
              unitName: "KCAL",
            }],
          }],
        }),
      );
    }) as typeof fetch,
  };
  const request = () =>
    new Request("https://isolated.invalid/food-search", {
      method: "POST",
      body: JSON.stringify({ query: "apple", locale: "en" }),
    });
  equal((await handleFoodSearchRequest(request(), runtime)).status, 200);
  equal((await handleFoodSearchRequest(request(), runtime)).status, 200);
  equal(fetches, 1);
  equal(auths, 2);
  equal(quotas, 2);
  quota = "rate_limited";
  equal((await handleFoodSearchRequest(request(), runtime)).status, 429);
  equal(fetches, 1);
  quota = "allowed";
  owner = "B";
  equal((await handleFoodSearchRequest(request(), runtime)).status, 200);
  equal(fetches, 2);
});
