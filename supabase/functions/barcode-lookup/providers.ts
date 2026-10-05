import {
  barcodeLocales, finiteAmount, lookupGtinCandidates, offLanguage, Product,
  record, sameGtin, text,
} from "./gtin_lookup.ts";

export type Fetcher = typeof fetch;
const fields = [...new Set([
  "code", "product_type", "product_name", "brands", "categories", "categories_tags",
  "labels_tags", "ingredients_text", "nutriments", "serving_quantity", "serving_quantity_unit",
  ...barcodeLocales.flatMap((locale) => [
    `product_name_${offLanguage(locale)}`, `product_name_${locale.toLowerCase()}`,
  ]),
])].join(",");

export function normalizeOff(product: Product, gtin: string): Product {
  const names: Record<string, string> = {};
  for (const key of Object.keys(product)) {
    if (key.startsWith("product_name_")) {
      const value = text(product[key]);
      if (value) names[key.slice("product_name_".length)] = value;
    }
  }
  const fallback = text(product.product_name);
  const n = record(product.nutriments) ?? {};
  const nutrient = (name: string, key: string, unit: string, factor = 1) => {
    const value = finiteAmount(n[`${key}_100g`]);
    return { name, unit, amount: value === null ? null : value * factor };
  };
  const kj = finiteAmount(n["energy-kj_100g"]) ?? finiteAmount(n.energy_100g);
  const kcal = finiteAmount(n["energy-kcal_100g"]) ?? (kj === null ? null : kj / 4.184);
  return {
    provider: "open_facts", product_type: text(product.product_type) || "product",
    gtin, provider_gtin: text(product.code), name: names.en || fallback || text(product.brands),
    names, arabic_name: names.ar ?? null, brand: text(product.brands),
    categories: product.categories ?? "", categories_tags: product.categories_tags ?? [],
    labels_tags: product.labels_tags ?? [], ingredients: text(product.ingredients_text),
    serving_size: finiteAmount(product.serving_quantity),
    serving_unit: text(product.serving_quantity_unit) || null,
    nutrition_basis: "100g", source_url: `https://world.openfoodfacts.org/product/${text(product.code)}`,
    license: "ODbL-1.0", attribution: "Open Food Facts contributors", verified: false,
    nutrients: [
      { name: "Energy", unit: "kcal", amount: kcal },
      nutrient("Protein", "proteins", "g"),
      nutrient("Carbohydrate, by difference", "carbohydrates", "g"),
      nutrient("Total lipid (fat)", "fat", "g"),
      nutrient("Fiber, total dietary", "fiber", "g"), nutrient("Sugars, total", "sugars", "g"),
      nutrient("Sodium, Na", "sodium", "mg", 1000), nutrient("Potassium, K", "potassium", "mg", 1000),
      nutrient("Calcium, Ca", "calcium", "mg", 1000), nutrient("Magnesium, Mg", "magnesium", "mg", 1000),
      nutrient("Phosphorus, P", "phosphorus", "mg", 1000), nutrient("Iron, Fe", "iron", "mg", 1000),
      nutrient("Vitamin C", "vitamin-c", "mg", 1000),
    ],
  };
}

export function normalizeUsda(food: Product, gtin: string): Product {
  return {
    provider: "usda", product_type: "food", gtin, provider_gtin: text(food.gtinUpc),
    name: text(food.description), names: { en: text(food.description) },
    brand: text(food.brandOwner) || text(food.brandName), ingredients: text(food.ingredients),
    serving_size: finiteAmount(food.servingSize), serving_unit: text(food.servingSizeUnit) || null,
    nutrition_basis: "provider", fdc_id: food.fdcId ?? null,
    nutrients: (Array.isArray(food.foodNutrients) ? food.foodNutrients : []).slice(0, 60)
      .map((raw) => {
        const n = record(raw) ?? {};
        return { name: text(n.nutrientName), unit: text(n.unitName), amount: finiteAmount(n.value) };
      }),
  };
}

/** Retry-After circuit breaker is per warm isolate, not a cluster-wide rate limit. */
export class ProviderBackoff {
  private until = new Map<string, number>();
  constructor(private clock: () => number = Date.now) {}
  allowed(provider: string): boolean { return this.clock() >= (this.until.get(provider) ?? 0); }
  observe(provider: string, response: Response): void {
    if (response.status !== 429 && response.status !== 503) return;
    const raw = response.headers.get("retry-after");
    const seconds = raw !== null && /^\d+$/.test(raw) ? Number(raw) : NaN;
    const deadline = Number.isFinite(seconds) ? this.clock() + seconds * 1000
      : raw ? Date.parse(raw) : NaN;
    this.until.set(provider, Math.max(this.clock() + 1000,
      Number.isFinite(deadline) ? deadline : this.clock() + 60000));
  }
}
const backoff = new ProviderBackoff();

export async function lookupOff(
  gtin: string, locale: string, fetcher: Fetcher = fetch, budget = backoff,
): Promise<Product | null> {
  if (!budget.allowed("off")) throw new Error("open_facts_backoff");
  const controller = new AbortController();
  // One deadline across variants, not a fresh timeout for each extra request.
  const timer = setTimeout(() => controller.abort(), 5000);
  try {
    for (const candidate of lookupGtinCandidates(gtin).slice(0, 2)) {
      const endpoint = new URL(`https://world.openfoodfacts.org/api/v3/product/${candidate}`);
      endpoint.searchParams.set("product_type", "all");
      endpoint.searchParams.set("lc", offLanguage(locale));
      endpoint.searchParams.set("tags_lc", offLanguage(locale));
      endpoint.searchParams.set("fields", fields);
      const response = await fetcher(endpoint, {
        signal: controller.signal, redirect: "error",
        headers: { "user-agent": "BIL/1.0 (support@bilhealth.com; https://www.bilhealth.com)" },
      });
      budget.observe("off", response);
      if (response.status === 404) continue;
      if (!response.ok) throw new Error("open_facts_unavailable");
      const root = record(await response.json());
      if (root?.status !== "success" && root?.status !== 1) continue;
      const product = record(root.product);
      // Never relabel a fuzzy/upstream mismatch as the requested barcode.
      if (!product || !sameGtin(product.code, gtin)) throw new Error("open_facts_identity_mismatch");
      const normalized = normalizeOff(product, gtin);
      if (text(normalized.name)) return normalized;
    }
    return null;
  } finally { clearTimeout(timer); }
}

export async function lookupUsda(
  gtin: string, key: string, fetcher: Fetcher = fetch, budget = backoff,
): Promise<Product | null> {
  if (!key) return null;
  if (!budget.allowed("usda")) throw new Error("usda_backoff");
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 5000);
  try {
    for (const candidate of lookupGtinCandidates(gtin).slice(0, 2)) {
      const response = await fetcher(
        `https://api.nal.usda.gov/fdc/v1/foods/search?api_key=${encodeURIComponent(key)}`,
        { method: "POST", signal: controller.signal, redirect: "error",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ query: candidate, dataType: ["Branded"], pageSize: 20 }) },
      );
      budget.observe("usda", response);
      if (!response.ok) throw new Error("usda_unavailable");
      const root = record(await response.json());
      const foods = Array.isArray(root?.foods) ? root.foods : [];
      const exact = foods.map(record).find((row) => row && sameGtin(row.gtinUpc, gtin) && text(row.description));
      if (exact) return normalizeUsda(exact, gtin);
    }
    return null;
  } finally { clearTimeout(timer); }
}
