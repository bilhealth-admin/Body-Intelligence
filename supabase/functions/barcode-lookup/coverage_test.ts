import { handleBarcodeRequest, BarcodeRuntime, BarcodeAccess } from "./index.ts";
import { canonicalGtin, lookupGtinCandidates, normalizeLookupGtin, sameGtin,
  canonicalBarcodeLocale, barcodeLocales, responseProduct, Product } from "./gtin_lookup.ts";
import { lookupOff, lookupUsda, normalizeOff, ProviderBackoff } from "./providers.ts";

function assert(value: unknown, message = "assertion failed"): asserts value {
  if (!value) throw new Error(message);
}
function equal(left: unknown, right: unknown) {
  assert(JSON.stringify(left) === JSON.stringify(right), `${JSON.stringify(left)} != ${JSON.stringify(right)}`);
}
const gtin = "3017624010701";
function product(provider = "open_facts", complete = true, code = gtin): Product {
  return { provider, gtin: code, name: "Fixture food", product_type: "food", names: { en: "Fixture food" },
    nutrients: (complete ? ["Energy", "Protein", "Carbohydrate, by difference", "Total lipid (fat)"] : ["Energy"])
      .map((name) => ({ name, unit: name === "Energy" ? "kcal" : "g", amount: 10 })) };
}
function runtime(overrides: Partial<BarcodeRuntime> = {}, cache: Partial<Extract<BarcodeAccess, { ok: true }>> = {}): BarcodeRuntime {
  return { authorize: async () => ({ ok: true, getCached: async () => null, putCached: async () => {}, ...cache }),
    openFacts: async () => product(), usda: async () => null, ...overrides };
}
function request(body: unknown = { gtin, locale: "ar" }) {
  return new Request("https://example.invalid/barcode-lookup", { method: "POST", body: JSON.stringify(body) });
}
Deno.test("equivalent GTIN formats preserve identity", () => {
  equal(canonicalGtin(gtin), "03017624010701");
  assert(sameGtin("036000291452", "0036000291452"));
  equal(lookupGtinCandidates("0036000291452"), ["0036000291452", "036000291452", "00036000291452"]);
  assert(!sameGtin("13017624010708", gtin));
  equal(lookupGtinCandidates("13017624010708"), ["13017624010708"]);
});
Deno.test("strict Arabic Persian input and invalid check digits", () => {
  equal(normalizeLookupGtin(" ٣٠١٧٦٢٤٠١٠٧٠١ "), gtin);
  equal(normalizeLookupGtin("۳۰۱۷۶۲۴۰۱۰۷۰۱"), gtin);
  for (const raw of ["00000000", "3017624010702", "x3017624010701", "https://x/3017624010701", 3017624010701, true]) {
    equal(normalizeLookupGtin(raw), null);
  }
});
Deno.test("all 25 canonical locale tags accepted and script-specific names preserved", () => {
  equal(barcodeLocales.length, 25);
  for (const tag of barcodeLocales) equal(canonicalBarcodeLocale(tag), tag);
  equal(canonicalBarcodeLocale("zh_TW"), "zh-Hant");
  equal(canonicalBarcodeLocale("ar-IQ"), "ar");
  const p = { ...product(), names: { zh: "简体", "zh-tw": "繁體", ar: "منتج" } };
  equal((responseProduct(p, "zh-Hant").names as Product).zh, "繁體");
  equal(p.names.zh, "简体");
});
Deno.test("missing values are never zero; kJ and mineral units normalize", () => {
  const p = normalizeOff({ code: gtin, product_name: "Food", nutriments: { "energy-kj_100g": 418.4, sodium_100g: 0.2 } }, gtin);
  const rows = p.nutrients as Product[];
  assert(Math.abs(Number(rows[0].amount) - 100) < 1e-9);
  equal(rows.find((r) => r.name === "Sodium, Na")?.amount, 200);
  equal(rows.find((r) => r.name === "Protein")?.amount, null);
  equal(p.verified, false);
});
Deno.test("provider lookup matches zero-padded returned USDA GTIN", async () => {
  let calls = 0;
  const found = await lookupUsda("0036000291452", "test-key", (() => {
    calls++;
    return Promise.resolve(Response.json({ foods: [{ gtinUpc: "036000291452", description: "Exact", fdcId: 1 }] }));
  }) as typeof fetch, new ProviderBackoff());
  equal(calls, 1); equal(found?.name, "Exact");
});
Deno.test("OFF retries equivalent spelling once, not the whole world", async () => {
  const urls: string[] = [];
  const found = await lookupOff("03017624010701", "ar", ((url, init) => {
    urls.push(String(url));
    const headers = (init as { headers?: HeadersInit } | undefined)?.headers;
    assert(new Headers(headers).get("user-agent")?.includes("support@bilhealth.com"));
    return Promise.resolve(urls.length === 1 ? new Response("", { status: 404 })
      : Response.json({ status: "success", product: { code: gtin, product_name: "Food" } }));
  }) as typeof fetch, new ProviderBackoff());
  equal(urls.length, 2); equal(found?.provider_gtin, gtin);
});
Deno.test("upstream mismatched product cannot acquire requested barcode", async () => {
  let rejected = false;
  try {
    await lookupOff(gtin, "en", (() => Promise.resolve(Response.json({
      status: "success", product: { code: "036000291452", product_name: "Wrong food" },
    }))) as typeof fetch, new ProviderBackoff());
  } catch { rejected = true; }
  assert(rejected);
});
Deno.test("Retry-After cooldown prevents immediate repeated provider calls", async () => {
  let now = 0, calls = 0;
  const budget = new ProviderBackoff(() => now);
  const fetcher = (() => { calls++; return Promise.resolve(new Response("", { status: 429, headers: { "retry-after": "120" } })); }) as typeof fetch;
  for (let i = 0; i < 2; i++) { try { await lookupOff(gtin, "en", fetcher, budget); } catch { /* expected */ } }
  equal(calls, 1); now = 120001; assert(budget.allowed("off"));
});
Deno.test("cache hit uses stable response contract and no network", async () => {
  const result = await handleBarcodeRequest(request(), runtime({ openFacts: async () => { throw new Error("must not run"); } },
    { getCached: async () => ({ source: "open_facts", payload: product() }) }));
  equal(result.status, 200); equal((await result.json()).cache_hit, true);
});
Deno.test("cache failure cannot discard successful provider evidence", async () => {
  const result = await handleBarcodeRequest(request(), runtime({}, {
    getCached: async () => { throw new Error("read"); }, putCached: async () => { throw new Error("write"); },
  }));
  equal(result.status, 200); equal((await result.json()).payload.provider, "open_facts");
});
Deno.test("incomplete OFF product can be enriched by exact USDA record", async () => {
  const result = await handleBarcodeRequest(request(), runtime({
    openFacts: async () => product("open_facts", false), usda: async () => product("usda"),
  }));
  equal((await result.json()).payload.provider, "usda");
});
Deno.test("incomplete cache no longer masks complete live nutrition", async () => {
  const result = await handleBarcodeRequest(request(), runtime({}, {
    getCached: async () => ({ source: "open_facts", payload: product("open_facts", false) }),
  }));
  const body = await result.json(); equal(body.cache_hit, false); equal(body.payload.nutrients.length, 4);
});
Deno.test("partial evidence is retained without inventing missing macros", async () => {
  const result = await handleBarcodeRequest(request(), runtime({ openFacts: async () => product("open_facts", false) }));
  equal(result.status, 200); equal((await result.json()).payload.nutrients.length, 1);
});
Deno.test("real miss differs from provider outage", async () => {
  equal((await handleBarcodeRequest(request(), runtime({ openFacts: async () => null }))).status, 404);
  equal((await handleBarcodeRequest(request(), runtime({ openFacts: async () => { throw new Error("offline"); } }))).status, 503);
});
Deno.test("forbidden session never reaches any provider", async () => {
  for (const status of [401, 403]) {
    let called = false;
    const r = await handleBarcodeRequest(request(), runtime({
      authorize: async () => ({ ok: false, status, error: "forbidden" }),
      openFacts: async () => { called = true; return product(); },
    }));
    equal(r.status, status); assert(!called);
  }
});
Deno.test("invalid requests, arrays and chunked oversized bodies fail closed", async () => {
  for (const body of [null, [], {}, { gtin: "wrong" }]) {
    equal((await handleBarcodeRequest(request(body), runtime())).status, 400);
  }
  const huge = request({ gtin, extra: "x".repeat(5000) });
  equal((await handleBarcodeRequest(huge, runtime())).status, 413);
  equal((await handleBarcodeRequest(new Request("https://x.invalid"), runtime())).status, 405);
});
