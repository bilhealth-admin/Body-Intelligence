import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { isValidGtin } from '../_shared/gtin.ts';

const json = (body: unknown, status = 200) => new Response(
  JSON.stringify(body),
  { status, headers: { 'content-type': 'application/json' } },
);
const env = (name: string) => Deno.env.get(name)?.trim() ?? '';
const text = (value: unknown) => String(value ?? '').trim();
const number = (value: unknown) => {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
};

const supportedLocales = new Set([
  'ar', 'en', 'fr', 'es', 'tr', 'de', 'it', 'pt', 'ur', 'fa', 'hi', 'id',
  'ms', 'ja', 'ko', 'zh', 'ru', 'bn', 'vi', 'th', 'pl', 'nl', 'uk',
]);
const productNameFields = [...supportedLocales]
  .map((locale) => `product_name_${locale}`);

function normalizedUsda(food: Record<string, unknown>, gtin: string) {
  const nutrients = Array.isArray(food.foodNutrients)
    ? food.foodNutrients
    : [];
  return {
    provider: 'usda',
    product_type: 'food',
    gtin,
    name: text(food.description),
    names: { en: text(food.description) },
    brand: text(food.brandOwner ?? food.brandName),
    ingredients: text(food.ingredients),
    serving_size: food.servingSize ?? null,
    serving_unit: food.servingSizeUnit ?? null,
    nutrition_basis: 'provider',
    fdc_id: food.fdcId ?? null,
    nutrients: nutrients.slice(0, 60).map((row) => {
      const nutrient = row as Record<string, unknown>;
      return {
        name: text(nutrient.nutrientName),
        unit: text(nutrient.unitName),
        amount: nutrient.value ?? null,
      };
    }),
  };
}

function normalizedOpenFacts(
  product: Record<string, unknown>,
  gtin: string,
) {
  const names: Record<string, string> = {};
  for (const locale of supportedLocales) {
    const localized = text(product[`product_name_${locale}`]);
    if (localized) names[locale] = localized;
  }
  const defaultName = text(product.product_name);
  if (defaultName && !names.en) names.en = defaultName;
  const brand = text(product.brands);
  const name = names.en || defaultName || brand || 'Recognized product';
  const nutriments = product.nutriments &&
      typeof product.nutriments === 'object' &&
      !Array.isArray(product.nutriments)
    ? product.nutriments as Record<string, unknown>
    : {};

  const nutrient = (
    name: string,
    key: string,
    unit: string,
    multiplier = 1,
  ) => {
    const amount = number(nutriments[`${key}_100g`]);
    return { name, unit, amount: amount === null ? null : amount * multiplier };
  };

  return {
    provider: 'open_facts',
    product_type: text(product.product_type) || 'product',
    gtin,
    name,
    names,
    arabic_name: names.ar ?? null,
    brand,
    categories: product.categories ?? '',
    categories_tags: product.categories_tags ?? [],
    labels_tags: product.labels_tags ?? [],
    ingredients: text(product.ingredients_text),
    serving_size: product.serving_quantity ?? null,
    serving_unit: 'g',
    nutrition_basis: '100g',
    nutrients: [
      nutrient('Energy', 'energy-kcal', 'kcal'),
      nutrient('Protein', 'proteins', 'g'),
      nutrient('Carbohydrate, by difference', 'carbohydrates', 'g'),
      nutrient('Total lipid (fat)', 'fat', 'g'),
      nutrient('Fiber, total dietary', 'fiber', 'g'),
      nutrient('Sugars, total', 'sugars', 'g'),
      nutrient('Sodium, Na', 'sodium', 'mg', 1000),
      nutrient('Potassium, K', 'potassium', 'mg', 1000),
      nutrient('Calcium, Ca', 'calcium', 'mg', 1000),
      nutrient('Magnesium, Mg', 'magnesium', 'mg', 1000),
      nutrient('Phosphorus, P', 'phosphorus', 'mg', 1000),
      nutrient('Iron, Fe', 'iron', 'mg', 1000),
      nutrient('Vitamin C', 'vitamin-c', 'mg', 1000),
    ],
  };
}

async function openFactsLookup(gtin: string, locale: string) {
  const fields = [
    'code', 'product_type', 'product_name', ...productNameFields, 'brands',
    'categories', 'categories_tags', 'labels_tags', 'ingredients_text',
    'nutriments', 'serving_quantity',
  ].join(',');
  const endpoint = new URL(
    `https://world.openfoodfacts.org/api/v3/product/${gtin}`,
  );
  endpoint.searchParams.set('product_type', 'all');
  endpoint.searchParams.set('lc', locale);
  endpoint.searchParams.set('tags_lc', locale);
  endpoint.searchParams.set('fields', fields);
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 8000);
  try {
    const response = await fetch(endpoint, {
      signal: controller.signal,
      redirect: 'follow',
      headers: {
        'user-agent': 'BIL/1.0 (barcode-support@bil-app.com)',
      },
    });
    if (response.status === 404) return null;
    if (!response.ok) throw new Error(`open_facts_${response.status}`);
    const root = await response.json() as Record<string, unknown>;
    if (root.status !== 'success' && root.status !== 1) return null;
    if (!root.product || typeof root.product !== 'object') return null;
    return normalizedOpenFacts(
      root.product as Record<string, unknown>,
      gtin,
    );
  } finally {
    clearTimeout(timer);
  }
}

async function usdaLookup(gtin: string) {
  const key = env('BIL_USDA_API_KEY');
  if (!key) return null;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 8000);
  try {
    const response = await fetch(
      `https://api.nal.usda.gov/fdc/v1/foods/search?api_key=${encodeURIComponent(key)}`,
      {
        method: 'POST',
        signal: controller.signal,
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          query: gtin,
          dataType: ['Branded'],
          pageSize: 10,
        }),
      },
    );
    if (!response.ok) throw new Error(`usda_${response.status}`);
    const result = await response.json() as Record<string, unknown>;
    const foods = (Array.isArray(result.foods) ? result.foods : []) as
      Array<Record<string, unknown>>;
    const exact = foods.find(
      (food) => text(food.gtinUpc).replace(/\D/g, '') === gtin,
    );
    return exact ? normalizedUsda(exact, gtin) : null;
  } finally {
    clearTimeout(timer);
  }
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return json({ error: 'method_not_allowed' }, 405);
  }
  const declaredLength = Number(request.headers.get('content-length') ?? 0);
  if (declaredLength > 4096) {
    return json({ error: 'request_too_large' }, 413);
  }
  const url = env('SUPABASE_URL');
  const service = env('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !service) return json({ error: 'server_not_configured' }, 503);

  const authorization = request.headers.get('authorization') ?? '';
  const token = authorization.replace(/^Bearer\s+/i, '').trim();
  if (!token) return json({ error: 'invalid_session' }, 401);
  const admin = createClient(url, service);
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user) return json({ error: 'invalid_session' }, 401);

  const body = await request.json().catch(() => null) as
    Record<string, unknown> | null;
  const gtin = body?.gtin;
  if (!isValidGtin(gtin)) return json({ error: 'invalid_gtin' }, 400);
  const requestedLocale = text(body?.locale).toLowerCase().split(/[-_]/)[0];
  const locale = supportedLocales.has(requestedLocale) ? requestedLocale : 'en';

  const { data: allowed, error: gateError } = await admin.rpc(
    'bil_has_premium_barcode_access',
    { p_owner_id: data.user.id },
  );
  if (gateError) return json({ error: 'entitlement_unavailable' }, 503);
  if(allowed!==true)return json({error:'premium_required'},403);

  const { data: cached, error: cacheError } = await admin.rpc(
    'bil_get_cached_barcode',
    { p_gtin: gtin },
  );
  if (cacheError) return json({ error: 'barcode_cache_unavailable' }, 503);
  if (cached && typeof cached === 'object' && !Array.isArray(cached)) {
    return json({ status: 'found', gtin, cache_hit: true, ...cached });
  }

  try {
    const openFacts = await openFactsLookup(gtin as string, locale);
    if (openFacts) {
      const { error: putError } = await admin.rpc('bil_put_cached_barcode', {
        p_gtin: gtin,
        p_source: 'open_facts',
        p_payload: openFacts,
        p_ttl_days: 30,
      });
      if (putError) return json({ error: 'barcode_cache_unavailable' }, 503);
      return json({
        status: 'found',
        gtin,
        source: 'open_facts',
        cache_hit: false,
        payload: openFacts,
      });
    }
  } catch {
    // Continue to the authoritative USDA fallback when the community catalog
    // is temporarily unavailable.
  }

  try {
    const usda = await usdaLookup(gtin as string);
    if (usda) {
      const { error: putError } = await admin.rpc('bil_put_cached_barcode', {
        p_gtin: gtin,
        p_source: 'usda',
        p_payload: usda,
        p_ttl_days: 30,
      });
      if (putError) return json({ error: 'barcode_cache_unavailable' }, 503);
      return json({
        status: 'found',
        gtin,
        source: 'usda',
        cache_hit: false,
        payload: usda,
      });
    }
  } catch {
    return json({ error: 'barcode_providers_unavailable' }, 503);
  }

  return json({status:'unresolved',gtin,cache_hit:false,
    next_step:'capture_product_label',
    notice:'No trusted product record matched. Scan the product label; BIL will not invent nutrition.'},404);
});
