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
const firstEnv = (...names: string[]) => {
  for (const name of names) {
    const value = env(name);
    if (value) return value;
  }
  return "";
};
const text = (value: unknown) => String(value ?? "").trim();
const finite = (value: unknown) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
};
const isSafeSearchHint = (value: string) =>
  /^[A-Za-z0-9][A-Za-z0-9 ,.'"&()\/-]{1,119}$/.test(value);
const reviewedSearchHints = new Map<string, string>([
  ["بطيخ", "watermelon"],
]);

const reviewedHintForQuery = (value: string) => {
  const words = value.toLowerCase().split(/\s+/).filter(Boolean);
  for (const word of words) {
    const hint = reviewedSearchHints.get(word);
    if (hint) return hint;
  }
  return "";
};

type QuotaResult = "allowed" | "rate_limited" | "unavailable";

type AccessResult =
  | { ok: true; consumeQuota: () => Promise<QuotaResult> }
  | {
    ok: false;
    error: "invalid_session" | "server_not_configured";
    status: 401 | 503;
  };

type TranslationFunction = (
  value: string,
  sourceLocale: string,
  targetLocale: string,
) => Promise<string | null>;

export interface FoodSearchRuntime {
  authorize(request: Request): Promise<AccessResult>;
  apiKey(): string;
  fetch: typeof fetch;
  translate?: TranslationFunction;
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

  // Pass the token explicitly to GoTrue as well as keeping it on the client
  // headers. This removes any dependency on header propagation inside the
  // Edge runtime and keeps the same member identity for auth and RPC calls.
  const auth = createClient(url, anon, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data, error } = await auth.auth.getUser(token);
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
  // Keep the canonical BIL names while accepting the shorter names already
  // used by the deployed project. Secret values never leave the Edge
  // Function, and this prevents a naming-only configuration outage.
  apiKey: () => firstEnv("BIL_USDA_API_KEY", "USDA"),
  fetch,
  translate: (value, sourceLocale, targetLocale) =>
    translateWithGoogle(
      value,
      sourceLocale,
      targetLocale,
      fetch,
    ),
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

/// Translates only the user's search phrase. USDA remains the nutrition
/// authority and its stored food name is never replaced by an unreviewed
/// translation. This keeps the search multilingual without pretending that a
/// machine translation is a canonical food identity.
async function translateWithGoogle(
  value: string,
  sourceLocale: string,
  targetLocale: string,
  fetcher: typeof fetch,
): Promise<string | null> {
  const key = firstEnv("BIL_TRANSLATION_API_KEY", "Translation");
  if (!key || !value.trim() || sourceLocale === targetLocale) return null;

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 2500);
  try {
    const response = await fetcher(
      `https://translation.googleapis.com/language/translate/v2?key=${
        encodeURIComponent(key)
      }`,
      {
        method: "POST",
        signal: controller.signal,
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          q: [value],
          source: sourceLocale,
          target: targetLocale,
          format: "text",
        }),
      },
    );
    if (!response.ok) return null;
    const root = await response.json() as Record<string, unknown>;
    const data = root.data;
    if (data == null || typeof data !== "object" || Array.isArray(data)) {
      return null;
    }
    const translations = (data as Record<string, unknown>).translations;
    if (!Array.isArray(translations) || translations.length === 0) return null;
    const first = translations[0];
    if (first == null || typeof first !== "object" || Array.isArray(first)) {
      return null;
    }
    const translated = text(
      (first as Record<string, unknown>).translatedText,
    );
    return translated.length >= 2 && translated.length <= 120
      ? translated
      : null;
  } catch {
    // Search must still be able to use the reviewed offline aliases or the
    // original query when the optional translation provider is unavailable.
    return null;
  } finally {
    clearTimeout(timer);
  }
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

  // The mobile app already expands the reviewed offline lexicon. This server
  // step closes the remaining gap for arbitrary food phrases in any supported
  // language before USDA's English-centric catalog is queried. If the optional
  // provider is not configured, keep the old deterministic USDA request.
  const searchHint = text(body.search_hint);
  // The mobile app may provide a reviewed English concept for a known
  // multilingual food term (for example Arabic "بطيخ" -> "watermelon").
  // It is bounded and syntax-checked here, then used as the authoritative
  // USDA query so a compound phrase cannot make a known food disappear when
  // the optional translation provider is unavailable.
  const serverReviewedHint = reviewedHintForQuery(query);
  const translatedQuery = locale === "en"
    ? isSafeSearchHint(searchHint)
      ? searchHint
      : isSafeSearchHint(serverReviewedHint)
      ? serverReviewedHint
      : query
    : isSafeSearchHint(searchHint)
    ? searchHint
    : isSafeSearchHint(serverReviewedHint)
    ? serverReviewedHint
    : ((await runtime.translate?.(query, locale, "en"))?.trim() || query);

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
          query: translatedQuery,
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
      search_query: translatedQuery,
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
