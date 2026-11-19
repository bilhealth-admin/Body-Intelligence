import { candidate, jsonObject, textAndUsage } from "./normalize.ts";
import { validateVisionResponseLocale } from "./locale.ts";
import { BilVisionCandidate, ProviderConfig, VisionProviderError } from "./types.ts";
import { GeminiNutrients, normalizeGeminiNutrients, validateGeminiNutrientConsistency } from "./nutrients_v2.ts";
import { geminiVisionEstimateRevision } from "./prompt_v2.ts";

export type GeminiVisionEstimate = {
  kind: "gemini_photo_estimate";
  basis: { quantity: number; unit: "g" | "ml" | "piece" } | null;
  nutrients: GeminiNutrients;
  uncertainty: string | null;
};
export type GeminiVisionCandidate = Omit<BilVisionCandidate, "provenance"> & {
  estimate: GeminiVisionEstimate;
  provenance: {
    identification_provider: "gemini";
    model_revision: string;
    prompt_revision: string;
    nutrition_resolution: "gemini_photo_estimate";
  };
};

function invalid(field: string): never {
  throw new VisionProviderError("malformed_response", `Invalid Gemini estimate ${field}`, "gemini");
}
function object(raw: unknown, keys: string[], field: string): Record<string, unknown> {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) invalid(field);
  const row = raw as Record<string, unknown>;
  if (Object.keys(row).some((key) => !keys.includes(key))) invalid(field);
  return row;
}
function estimate(raw: unknown): GeminiVisionEstimate {
  const row = object(raw, ["basis", "nutrients", "uncertainty"], "estimate");
  const nutrients = normalizeGeminiNutrients(row.nutrients);
  let basis: GeminiVisionEstimate["basis"] = null;
  if (row.basis != null) {
    const rawBasis = object(row.basis, ["quantity", "unit"], "basis");
    if (typeof rawBasis.quantity !== "number" || !Number.isFinite(rawBasis.quantity) ||
        rawBasis.quantity <= 0 || rawBasis.quantity > 100000 ||
        typeof rawBasis.unit !== "string" ||
        !["g", "ml", "piece"].includes(rawBasis.unit)) invalid("basis");
    basis = { quantity: rawBasis.quantity, unit: rawBasis.unit as "g" | "ml" | "piece" };
  }
  const uncertainty = row.uncertainty == null ? null
      : typeof row.uncertainty === "string" && row.uncertainty.trim().length <= 300
      ? row.uncertainty.trim() || null : invalid("uncertainty");
  if (basis == null && Object.values(nutrients).some((value) => value !== null)) invalid("missing nutrient basis");
  validateGeminiNutrientConsistency(nutrients, basis?.unit === "g" ? basis.quantity : undefined);
  if (basis?.unit === "g") {
    for (const [key, value] of Object.entries(nutrients)) {
      if (value == null) continue;
      const grams = ["protein", "carbohydrates", "fat", "fiber", "sugar", "saturatedFat",
        "polyunsaturatedFat", "monounsaturatedFat", "transFat", "netCarbohydrates"].includes(key);
      const maximumPer100 = key === "calories" ? 1000 : grams ? 100 : 100000;
      if (value > maximumPer100 * basis.quantity / 100) invalid(`${key} basis`);
    }
  }
  return { kind: "gemini_photo_estimate", basis, nutrients, uncertainty };
}

export function normalizeGeminiEstimateResponse(envelope: unknown, config: ProviderConfig, requestedLocale: string) {
  if (config.provider !== "gemini") {
    throw new VisionProviderError("provider_error", "Gemini is required for photo estimates", config.provider);
  }
  const extracted = textAndUsage(envelope, config);
  if (new TextEncoder().encode(extracted.text).byteLength > 256 * 1024) invalid("response size");
  const root = jsonObject(extracted.text, config);
  if (!Array.isArray(root.candidates) || root.candidates.length > 8) invalid("candidates");
  const candidates: GeminiVisionCandidate[] = root.candidates.map((raw) => {
    const row = object(raw, ["name", "confidence", "evidence", "amount", "unit", "alternatives",
      "uncertainty", "warnings", "dish_identity", "visible_components", "estimate"], "candidate");
    const identity = candidate(row, config);
    if (identity.unit != null && !["g", "ml", "piece"].includes(identity.unit)) invalid("portion unit");
    const nutrition = estimate(row.estimate);
    if (nutrition.basis != null && identity.unit != null &&
        nutrition.basis.unit !== identity.unit) invalid("pictured portion/basis unit mismatch");
    return { ...identity, estimate: nutrition, provenance: {
      identification_provider: "gemini", model_revision: config.model,
      prompt_revision: geminiVisionEstimateRevision, nutrition_resolution: "gemini_photo_estimate",
    } };
  });
  const response_locale = validateVisionResponseLocale(root.response_locale, requestedLocale, candidates);
  // Nutrition uncertainty is also user-visible and must obey the same locale.
  validateVisionResponseLocale(root.response_locale, requestedLocale,
    candidates.map((row) => ({ ...row, uncertainty: row.estimate.uncertainty })));
  return { schema_version: 2 as const, response_locale, candidates, usage: {
    input_tokens: extracted.input, output_tokens: extracted.output, cost_usd: extracted.cost,
  } };
}
