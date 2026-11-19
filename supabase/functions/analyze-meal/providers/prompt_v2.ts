import { mealVisionPrompt } from "./prompt.ts";
import { geminiNutrientUnits } from "./nutrients_v2.ts";

export const geminiVisionEstimateRevision = "gemini-photo-estimate-v2-structured-schema-20261119";

export function mealVisionEstimatePrompt(locale: string): string {
  const legacy = mealVisionPrompt(locale);
  const rules = legacy.slice(legacy.indexOf("Create candidates"))
    .replace("Never estimate nutrition, calories, or health effects.",
      "Nutrition is a clearly attributed visual estimate under the rules below; never claim medical or health effects.");
  return `You are a meal-photo estimator. Return JSON matching the supplied response schema.\n${rules}
Estimate the pictured portion immediately when supported; a person must not be required to enter grams when you can estimate them. The amount and unit describe that pictured served portion, not a batch. Do not infer whether it has already been eaten. A later explicit user confirmation decides what to log.
Provide nutrition estimates directly from your analysis, never claim a catalog, USDA, verified record, or exact measurement. The estimate.basis states the exact portion to which ALL nutrient values apply. Prefer the pictured portion itself as the basis; an explicit per100g basis is also allowed. For a clearly countable item you may use piece; use ml for a liquid when appropriate. Never silently turn1piece or1ml into100grams. The pictured amount/unit and estimate.basis must use the SAME compatible unit: g with g, ml with ml, or piece with piece. For example amount150g with a per100g basis is valid; amount1piece with a100g basis is invalid. If you estimate mass, return the pictured amount in grams too. Never require an unstated count-to-mass conversion. If you cannot support a basis, use basis:null and all nutrient values:null. Do not invent a default portion.
Use the nutrient fields and canonical units in the supplied response schema. Include the macronutrients, fiber, sugar, electrolytes and other supported micronutrients you can reasonably estimate. Unknown values are null, not0. Use0 only as an actual estimated zero. Retain these units and do not add unsupported nutrient fields. Nutrients are NOT calculated by the application from calorie/macronutrient ratios, so provide each estimate independently. Total carbohydrates include fiber. Provide netCarbohydrates directly only when total carbohydrates and fiber are known and the value is consistent with them; otherwise use null. Do not derive calories using4/4/9 merely to fill a missing value. No health or treatment advice.
Identity confidence is not nutritional accuracy. estimate.uncertainty is a short localized limitation or null. Portions and all nutrition are estimates for review, never automatic logging. No hidden oil, recipe ingredients or secondary background food may be asserted as observed. Return a graceful empty candidates array for unrecognized/non-food images rather than random nutrient zeros.`;
}

// Only the documented Gemini responseSchema subset is used. Server validators
// still own text limits, strictly positive basis, cross-nutrient consistency,
// forbidden extras and provenance; a schema never supplies missing values.
type VisionOutputSchema = Record<string, unknown>;

export function mealVisionEstimateResponseSchema(locale: string): VisionOutputSchema {
  const text = (nullable = false): VisionOutputSchema => ({
    type: "STRING", ...(nullable ? { nullable: true } : {}),
  });
  const number = (nullable = false, maximum = 1e9): VisionOutputSchema => ({
    type: "NUMBER", minimum: 0, maximum, ...(nullable ? { nullable: true } : {}),
  });
  const object = (properties: Record<string, VisionOutputSchema>, nullable = false): VisionOutputSchema => ({
    type: "OBJECT", properties, required: Object.keys(properties),
    propertyOrdering: Object.keys(properties), ...(nullable ? { nullable: true } : {}),
  });
  const array = (items: VisionOutputSchema, maxItems: number): VisionOutputSchema => ({
    type: "ARRAY", items, maxItems,
  });
  const unit = (): VisionOutputSchema => ({ type: "STRING", enum: ["g", "ml", "piece"] });
  const namedConfidence = (): VisionOutputSchema => object({ name: text(), confidence: number(false, 1) });
  const nutrients = Object.fromEntries(Object.entries(geminiNutrientUnits).map(([key, canonicalUnit]) => [
    key, object({
      value: { ...number(true), description: "An independently supported estimate for the stated basis, or null when unknown; never invent zero." },
      unit: { type: "STRING", enum: [canonicalUnit] },
    }),
  ]));
  return object({
    response_locale: { type: "STRING", enum: [locale] },
    candidates: array(object({
      name: text(), confidence: number(false, 1), evidence: text(),
      amount: { ...number(true, 100000), description: "Positive estimated pictured portion, or null if unsupported." },
      unit: { ...unit(), nullable: true },
      alternatives: array(namedConfidence(), 3), uncertainty: text(true),
      warnings: array(text(), 5),
      dish_identity: object({
        name: text(), confidence: number(false, 1), alternatives: array(namedConfidence(), 3),
      }, true),
      visible_components: array(object({ name: text(), confidence: number(false, 1), evidence: text() }), 12),
      estimate: object({
        basis: object({
          quantity: { ...number(false, 100000), description: "Strictly positive explicit nutrient basis quantity; use a null basis if unsupported." },
          unit: unit(),
        }, true),
        nutrients: object(nutrients), uncertainty: text(true),
      }),
    }), 6),
  });
}
