import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const maxRequestBytes = 4096;
const minuteQuota = 10;
const hourlyQuota = 60;

const json = (body: unknown, status = 200) =>
  new Response(
    JSON.stringify(body),
    { status, headers: { "content-type": "application/json" } },
  );
const env = (name: string) => Deno.env.get(name)?.trim() ?? "";
const text = (value: unknown) => String(value ?? "").trim();
const finite = (value: unknown) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
};

type QuotaResult = "allowed" | "rate_limited" | "unavailable";

type AccessResult =
  | { ok: true; consumeQuota: () => Promise<QuotaResult> }
  | {
    ok: false;
    error: "invalid_session" | "server_not_configured";
    status: 401 | 503;
  };

export interface FoodSearchRuntime {
  authorize(request: Request): Promise<AccessResult>;
  apiKey(): string;
  fetch: typeof fetch;
}

type BoundedJsonResult =
  | { status: "ok"; value: Record<string, unknown> }
  | { status: "invalid" }
  | { status: "too_large" };

async function readBoundedJsonObject(
  request: Request,
): Promise<BoundedJsonResult> {
  if (request.body == null) return { status: "invalid" };
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > maxRequestBytes) {
      await reader.cancel("request_too_large").catch(() => undefined);
      return { status: "too_large" };
    }
    chunks.push(value);
  }

  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  try {
    const decoded = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
    const value = JSON.parse(decoded) as unknown;
    if (value == null || typeof value !== "object" || Array.isArray(value)) {
      return { status: "invalid" };
    }
    return { status: "ok", value: value as Record<string, unknown> };
  } catch {
    return { status: "invalid" };
  }
}

async function productionAuthorize(request: Request): Promise<AccessResult> {
  const url = env("SUPABASE_URL");
  const anon = env("SUPABASE_ANON_KEY");
  if (!url || !anon) {
    return { ok: false, error: "server_not_configured", status: 503 };
  }
  const authorization = request.headers.get("authorization") ?? "";
  const token = authorization.replace(/^Bearer\s+/i, "").trim();
  if (!token) return { ok: false, error: "invalid_session", status: 401 };

  const auth = createClient(url, anon, {
    global: { headers: { Authorization: authorization } },
  });
  const { data, error } = await auth.auth.getUser();
  if (error || !data.user) {
    return { ok: false, error: "invalid_session", status: 401 };
  }

  const consume = async (
    action: string,
    limit: number,
    windowSeconds: number,
  ): Promise<QuotaResult> => {
    const { error: quotaError } = await auth.rpc("bil_consume_rate_limit", {
      p_action: action,
      p_limit: limit,
      p_window_seconds: windowSeconds,
    });
    if (quotaError == null) return "allowed";
    return quotaError.message?.toLowerCase().includes("rate limit exceeded")
      ? "rate_limited"
      : "unavailable";
  };

  return {
    ok: true,
    consumeQuota: async () => {
      const perMinute = await consume("food_search_minute", minuteQuota, 60);
      if (perMinute !== "allowed") return perMinute;
      return consume("food_search_hour", hourlyQuota, 3600);
    },
  };
}

const productionRuntime: FoodSearchRuntime = {
  authorize: productionAuthorize,
  apiKey: () => env("BIL_USDA_API_KEY"),
  fetch,
};

const supportedLocales = new Set([
  "ar",
  "en",
  "fr",
  "es",
  "tr",
  "de",
  "it",
  "pt",
  "ur",
  "fa",
  "hi",
  "id",
  "ms",
  "ja",
  "ko",
  "zh",
  "ru",
  "bn",
  "vi",
  "th",
  "pl",
  "nl",
  "uk",
]);

function normalizedUsda(food: Record<string, unknown>) {
  const nutrients = Array.isArray(food.foodNutrients) ? food.foodNutrients : [];
  return {
    provider: "usda",
    fdc_id: food.fdcId ?? null,
    data_type: text(food.dataType),
    name: text(food.description),
    brand: text(food.brandOwner ?? food.brandName),
    ingredients: text(food.ingredients),
    gtin: text(food.gtinUpc).replace(/\D/g, "") || null,
    serving_size: finite(food.servingSize),
    serving_unit: text(food.servingSizeUnit) || null,
    nutrients: nutrients.slice(0, 60).map((raw) => {
      const row = raw as Record<string, unknown>;
      return {
        name: text(row.nutrientName),
        unit: text(row.unitName),
        amount: finite(row.value),
      };
    }),
  };
}

export async function handleFoodSearchRequest(
  request: Request,
  runtime: FoodSearchRuntime = productionRuntime,
) {
  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }
  const declaredLength = Number(request.headers.get("content-length") ?? 0);
  if (declaredLength > maxRequestBytes) {
    return json({ error: "request_too_large" }, 413);
  }

  const access = await runtime.authorize(request);
  if (!access.ok) return json({ error: access.error }, access.status);
  const usdaKey = runtime.apiKey().trim();
  if (!usdaKey) return json({ error: "server_not_configured" }, 503);

  const boundedBody = await readBoundedJsonObject(request);
  if (boundedBody.status === "too_large") {
    return json({ error: "request_too_large" }, 413);
  }
  if (boundedBody.status !== "ok") {
    return json({ error: "invalid_request" }, 400);
  }
  const body = boundedBody.value;
  const query = text(body.query).replace(/\s+/g, " ");
  if (query.length < 2 || query.length > 120) {
    return json({ error: "invalid_query" }, 400);
  }
  const requestedLimit = Math.trunc(finite(body.limit) ?? 10);
  const limit = Math.max(1, Math.min(requestedLimit, 20));
  const requestedLocale = text(body.locale).toLowerCase().split(/[-_]/)[0];
  const locale = supportedLocales.has(requestedLocale) ? requestedLocale : "en";

  const quota = await access.consumeQuota();
  if (quota === "rate_limited") return json({ error: "rate_limited" }, 429);
  if (quota !== "allowed") return json({ error: "quota_unavailable" }, 503);

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 8000);
  try {
    const response = await runtime.fetch(
      `https://api.nal.usda.gov/fdc/v1/foods/search?api_key=${
        encodeURIComponent(usdaKey)
      }`,
      {
        method: "POST",
        signal: controller.signal,
        headers: {
          "content-type": "application/json",
          "accept-language": locale,
        },
        body: JSON.stringify({
          query,
          pageSize: limit,
          pageNumber: 1,
          requireAllWords: true,
        }),
      },
    );
    if (!response.ok) {
      return json({ error: `usda_${response.status}` }, 503);
    }
    const root = await response.json() as Record<string, unknown>;
    const foods = ((Array.isArray(root.foods) ? root.foods : []) as Array<
      Record<string, unknown>
    >)
      .map(normalizedUsda)
      .filter((food) => food.fdc_id !== null && food.name.length > 0);
    return json({
      status: foods.length === 0 ? "unresolved" : "found",
      source: "usda",
      query,
      locale,
      foods,
    }, foods.length === 0 ? 404 : 200);
  } catch {
    return json({ error: "food_provider_unavailable" }, 503);
  } finally {
    clearTimeout(timer);
  }
}

if (import.meta.main) {
  Deno.serve((request) => handleFoodSearchRequest(request));
}
