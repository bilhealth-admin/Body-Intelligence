import { VisionProviderError } from "./types.ts";

// Keep aligned with FoodNutrient and CoachFoodNutrients.units. Net carbs is
// explicitly retained from Gemini, never synthesized for an omitted value.
export const geminiNutrientUnits = {
  calories: "kcal", protein: "g", carbohydrates: "g", fat: "g", fiber: "g",
  sugar: "g", sodium: "mg", potassium: "mg", calcium: "mg", magnesium: "mg",
  phosphorus: "mg", iron: "mg", vitaminC: "mg", saturatedFat: "g",
  polyunsaturatedFat: "g", monounsaturatedFat: "g", transFat: "g",
  cholesterol: "mg", vitaminA: "mcg RAE", netCarbohydrates: "g",
} as const;
export type GeminiNutrient = keyof typeof geminiNutrientUnits;
export type GeminiNutrients = Record<GeminiNutrient, number | null>;

function invalid(field: string): never {
  throw new VisionProviderError("malformed_response", `Invalid Gemini estimate ${field}`, "gemini");
}

function normalizedValue(key: GeminiNutrient, raw: unknown): number | null {
  if (raw == null) return null;
  if (typeof raw !== "object" || Array.isArray(raw)) invalid(key);
  const row = raw as Record<string, unknown>;
  if (Object.keys(row).some((k) => !["value", "unit"].includes(k))) invalid(key);
  if (row.value == null) return null;
  if (typeof row.value !== "number" || !Number.isFinite(row.value) || row.value < 0) invalid(key);
  if (typeof row.unit !== "string") invalid(`${key}.unit`);
  const unit = row.unit.trim().replaceAll("µ", "u").replaceAll("μ", "u");
  const target = geminiNutrientUnits[key];
  let factor: number;
  if (target === "kcal") {
    if (unit === "kcal") factor = 1;
    else if (unit === "kJ") factor = 1 / 4.184;
    else invalid(`${key}.unit`);
  } else if (target === "mcg RAE") {
    // Vitamin-A IU does not have one universal conversion. Never guess one.
    if (["mcg RAE", "ug RAE"].includes(unit)) factor = 1;
    else if (unit === "mg RAE") factor = 1000;
    else if (unit === "g RAE") factor = 1000000;
    else invalid(`${key}.unit`);
  } else {
    const grams = ({ g: 1, mg: .001, mcg: .000001, ug: .000001 } as Record<string, number>)[unit];
    if (grams === undefined) invalid(`${key}.unit`);
    factor = target === "mg" ? grams * 1000 : grams;
  }
  const value = row.value * factor;
  if (!Number.isFinite(value) || value < 0 || value > 1e9) invalid(key);
  return value;
}

export function normalizeGeminiNutrients(raw: unknown): GeminiNutrients {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) invalid("nutrients");
  const input = raw as Record<string, unknown>;
  const keys = Object.keys(geminiNutrientUnits) as GeminiNutrient[];
  if (Object.keys(input).some((key) => !keys.includes(key as GeminiNutrient))) invalid("nutrient key");
  const output = Object.fromEntries(keys.map((key) => [key, normalizedValue(key, input[key])])) as GeminiNutrients;
  const carbs = output.carbohydrates;
  const fiber = output.fiber;
  if (carbs !== null) {
    if (fiber !== null && fiber > carbs + .1) invalid("fiber basis");
    if (output.sugar !== null && output.sugar > carbs + .1) invalid("sugar basis");
  }
  if (output.netCarbohydrates !== null) {
    if (carbs === null || fiber === null ||
        Math.abs(output.netCarbohydrates - (carbs - fiber)) > .2) {
      invalid("net carbohydrate evidence");
    }
  }
  validateGeminiNutrientConsistency(output);
  return output;
}

// Technical consistency only, not a claim of nutritional accuracy. The small
// 2% (minimum0.2g) tolerance permits independently rounded visual estimates.
// It never fills, clamps, or derives a missing nutrient/calorie value.
function rounding(reference: number) { return Math.max(.2, reference * .02); }
export function validateGeminiNutrientConsistency(n: GeminiNutrients, basisGrams?: number): void {
  const carbs = n.carbohydrates;
  if (carbs !== null && n.fiber !== null && n.sugar !== null &&
      n.fiber + n.sugar > carbs + rounding(carbs)) invalid("fiber plus sugar exceeds carbohydrate");
  if (n.fat !== null) {
    // Each subtype is contained in total fat. Trans may overlap mono/poly,
    // so do not add all four subtypes and count that overlap twice.
    for (const key of ["saturatedFat", "polyunsaturatedFat", "monounsaturatedFat", "transFat"] as const) {
      const value = n[key];
      if (value !== null && value > n.fat + rounding(n.fat)) invalid(`${key} exceeds fat`);
    }
  }
  if (basisGrams !== undefined) {
    // Total carbohydrate already includes fiber/sugar; neither is added again.
    // Known values alone provide a lower bound even when another macro is null.
    const knownMass = [n.protein, n.carbohydrates, n.fat]
      .filter((v): v is number => v !== null).reduce((sum, value) => sum + value, 0);
    if (knownMass > basisGrams + rounding(basisGrams)) invalid("macro mass exceeds gram basis");
  }
}
