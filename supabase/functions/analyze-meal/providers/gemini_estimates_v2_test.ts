import { buildProviderRequest } from "./builders.ts";
import { normalizeProviderResponse } from "./normalize.ts";
import { normalizeGeminiEstimateResponse } from "./normalize_v2.ts";
import { geminiNutrientUnits, normalizeGeminiNutrients } from "./nutrients_v2.ts";
import { visionCacheInput } from "./locale.ts";
import { ProviderConfig } from "./types.ts";
import { mealVisionConsentIsCurrent, mealVisionNutritionConsentPurpose } from "../consent.ts";

const config: ProviderConfig = { provider: "gemini", apiKey: "synthetic", model: "synthetic-model",
  endpoint: "https://generativelanguage.googleapis.com/v1beta" };
function row() {
  const nutrients: Record<string, { value: unknown; unit: string } | null> = Object.fromEntries(
    Object.entries(geminiNutrientUnits).map(([key, unit]) =>
      [key, { value: key === "calories" ? 120 : key === "sodium" ? 200 : key === "vitaminA" ? 50 : 0, unit }]));
  return { name: "Cooked meal", confidence: .8, evidence: "Foreground meal", amount: 150, unit: "g",
    alternatives: [], uncertainty: null, warnings: [], dish_identity: null, visible_components: [],
    estimate: { basis: { quantity: 100, unit: "g" } as { quantity: number; unit: string } | null,
      uncertainty: null as string | null, nutrients } };
}
function envelope(candidate: unknown, locale = "en") {
  return { candidates: [{ finishReason: "STOP", content: { parts: [{ text: JSON.stringify({
    response_locale: locale, candidates: candidate == null ? [] : [candidate],
  }) }] } }], usageMetadata: { promptTokenCount: 11, candidatesTokenCount: 22, thoughtsTokenCount: 3 } };
}
function parse(candidate: unknown) { return normalizeGeminiEstimateResponse(envelope(candidate), config, "en"); }
function equal(actual: unknown, expected: unknown, label: string) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) throw new Error(`${label}: ${JSON.stringify(actual)}`);
}
function rejects(body: () => unknown, label: string) {
  let rejected = false;
  try { body(); } catch (_) { rejected = true; }
  if (!rejected) throw new Error(`Accepted ${label}`);
}

Deno.test("V2 keeps all19 supported nutrients plus direct net carbs, known0, units and real usage", () => {
  const result = parse(row());
  const candidate = result.candidates[0];
  equal(result.schema_version, 2, "schema");
  equal(Object.keys(candidate.estimate.nutrients).sort(), Object.keys(geminiNutrientUnits).sort(), "all nutrients");
  equal(candidate.estimate.nutrients.sodium, 200, "sodium");
  equal(candidate.estimate.nutrients.vitaminA, 50, "vitaminA");
  equal(candidate.estimate.nutrients.protein, 0, "known0");
  equal(candidate.provenance.nutrition_resolution, "gemini_photo_estimate", "estimate source");
  equal(result.usage, { input_tokens: 11, output_tokens: 25, cost_usd: null }, "real usage");
});

Deno.test("V2 unknown sparse values stay null without calorie or net-carb synthesis", () => {
  const input = row();
  input.estimate.nutrients = { protein: { value: 10, unit: "g" } };
  const result = parse(input).candidates[0].estimate.nutrients;
  equal(result.protein, 10, "provided");
  equal(result.calories, null, "unknown calories");
  equal(result.fiber, null, "unknown fiber");
  equal(result.netCarbohydrates, null, "unknown net carbs");
});

Deno.test("V2 performs canonical unit conversion once and preserves electrolyte/fat-family values", () => {
  const input = row();
  input.estimate.nutrients.sodium = { value: .2, unit: "g" };
  input.estimate.nutrients.protein = { value: 10000, unit: "mg" };
  input.estimate.nutrients.calories = { value: 502.08, unit: "kJ" };
  input.estimate.nutrients.fat = { value: 3000, unit: "mg" };
  input.estimate.nutrients.saturatedFat = { value: 1000, unit: "mg" };
  const nutrients = parse(input).candidates[0].estimate.nutrients;
  if (Math.abs(nutrients.calories! - 120) > 1e-9) throw new Error("energy conversion");
  equal(nutrients.sodium, 200, "mg once");
  equal(nutrients.protein, 10, "g once");
  equal(nutrients.saturatedFat, 1, "fat family");
});

for (const value of [-1, Infinity, NaN, "4"]) {
  Deno.test(`V2 rejects invalid nutrient ${String(value)}`, () => {
    const input = row();
    (input.estimate.nutrients as Record<string, unknown>).sodium = { value, unit: "mg" };
    if (typeof value === "number" && !Number.isFinite(value)) {
      // JSON.stringify would convert this to null and falsify the fixture.
      rejects(() => normalizeGeminiNutrients(input.estimate.nutrients), "nonfinite sodium");
    } else {
      rejects(() => parse(input), "invalid sodium");
    }
  });
}

Deno.test("V2 rejects unknown nutrient keys and unsupported vitamin-A IU conversion", () => {
  const input = row();
  (input.estimate.nutrients as Record<string, unknown>).inventedHormone = { value: 1, unit: "mg" };
  rejects(() => parse(input), "unsupported nutrient");
  const other = row();
  other.estimate.nutrients.vitaminA = { value: 100, unit: "IU" };
  rejects(() => parse(other), "universal IU conversion");
});

Deno.test("V2 retains source basis without making piece or ml into grams", () => {
  for (const unit of ["piece", "ml"]) {
    const input = row();
    input.unit = unit;
    input.amount = unit === "piece" ? 1 : 200;
    input.estimate.basis = { quantity: input.amount, unit };
    equal(parse(input).candidates[0].estimate.basis, input.estimate.basis, "basis");
  }
});

Deno.test("V2 rejects no-basis numerical estimates and inconsistent direct net carbs", () => {
  const missing = row();
  (missing.estimate as unknown as Record<string, unknown>).basis = null;
  rejects(() => parse(missing), "numeric estimate without basis");
  const input = row();
  input.estimate.nutrients.carbohydrates = { value: 12, unit: "g" };
  input.estimate.nutrients.fiber = { value: 4, unit: "g" };
  input.estimate.nutrients.netCarbohydrates = { value: 11, unit: "g" };
  rejects(() => parse(input), "inconsistent net carb");
  input.estimate.nutrients.netCarbohydrates = { value: 8, unit: "g" };
  equal(parse(input).candidates[0].estimate.nutrients.netCarbohydrates, 8, "direct provided net");
});

Deno.test("V2 cannot spoof verified/catalog provenance or switch provider", () => {
  const input = row();
  (input as Record<string, unknown>).provenance = { nutrition_resolution: "verified_food_record" };
  rejects(() => parse(input), "model provenance");
  rejects(() => normalizeGeminiEstimateResponse(envelope(row()), { ...config, provider: "openai" }, "en"), "provider fallback");
});

Deno.test("V2 returns graceful empty candidates and rejects mixed-language estimate copy", () => {
  equal(normalizeGeminiEstimateResponse(envelope(null), config, "en").candidates, [], "empty");
  const input = row();
  input.estimate.uncertainty = "تقدير تقريبي";
  rejects(() => parse(input), "wrong-language uncertainty");
});

Deno.test("V1 prompt/output remain unchanged while V2 cache/prompt identity is isolated", () => {
  const input = { imageBase64: "AA==", mimeType: "image/jpeg" as const, requestedLocale: "en" };
  const v1 = buildProviderRequest(config, input);
  const explicit1 = buildProviderRequest(config, { ...input, schemaVersion: 1 });
  equal(v1, explicit1, "V1 bytes");
  if (!v1.body.includes("Never estimate nutrition")) throw new Error("V1 prompt changed");
  const raw = row();
  delete (raw as Record<string, unknown>).estimate;
  const normalized = normalizeProviderResponse(envelope(raw), config, "en");
  equal(normalized.schema_version, 1, "legacy schema");
  equal(normalized.candidates[0].provenance.nutrition_resolution, "requires_verified_food_match", "legacy source");
  equal(visionCacheInput("en", "image/jpeg", "AA=="), "en:image/jpeg:AA==", "legacy digest input");
  if (visionCacheInput("en", "image/jpeg", "AA==", 2) === visionCacheInput("en", "image/jpeg", "AA==")) {
    throw new Error("cross-version cache collision");
  }
});

Deno.test("supplemental nutrition scope cannot replace current base photo consent", () => {
  equal(mealVisionNutritionConsentPurpose, "meal_vision_nutrition_ai", "new scope");
  equal(mealVisionConsentIsCurrent({ granted: false, policy_version: "1" }), false, "base withdrawal");
  equal(mealVisionConsentIsCurrent({ granted: true, policy_version: "2" }), false, "V1 policy unchanged");
});
