import { mealVisionPrompt } from "./prompt.ts";
import { geminiNutrientUnits } from "./nutrients_v2.ts";

export const geminiVisionEstimateRevision = "gemini-photo-estimate-v2-portion-basis-20261118";

export function mealVisionEstimatePrompt(locale: string): string {
  const legacy = mealVisionPrompt(locale);
  const rules = legacy.slice(legacy.indexOf("Create candidates"))
    .replace("Never estimate nutrition, calories, or health effects.",
      "Nutrition is a clearly attributed visual estimate under the rules below; never claim medical or health effects.");
  const nutrients = Object.fromEntries(Object.entries(geminiNutrientUnits)
    .map(([key, unit]) => [key, { value: null, unit }]));
  const example = {
    response_locale: locale,
    candidates: [{
      name: "localized visible food", confidence: .8, evidence: "localized visual evidence",
      amount: 150, unit: "g", alternatives: [], uncertainty: null, warnings: [],
      dish_identity: null, visible_components: [],
      estimate: { basis: { quantity: 150, unit: "g" }, nutrients, uncertainty: null },
    }],
  };
  return `You are a meal-photo estimator. Return JSON only with this shape:\n${JSON.stringify(example)}\n${rules}
Estimate the pictured portion immediately when supported; a person must not be required to enter grams when you can estimate them. The amount and unit describe that pictured served portion, not a batch. Do not infer whether it has already been eaten. A later explicit user confirmation decides what to log.
Provide nutrition estimates directly from your analysis, never claim a catalog, USDA, verified record, or exact measurement. The estimate.basis states the exact portion to which ALL nutrient values apply. Prefer the pictured portion itself as the basis; an explicit per100g basis is also allowed. For a clearly countable item you may use piece; use ml for a liquid when appropriate. Never silently turn1piece or1ml into100grams. The pictured amount/unit and estimate.basis must use the SAME compatible unit: g with g, ml with ml, or piece with piece. For example amount150g with a per100g basis is valid; amount1piece with a100g basis is invalid. If you estimate mass, return the pictured amount in grams too. Never require an unstated count-to-mass conversion. If you cannot support a basis, use basis:null and all nutrient values:null. Do not invent a default portion.
Supported nutrient keys and preferred units are ${JSON.stringify(geminiNutrientUnits)}. Include the macronutrients, fiber, sugar, electrolytes and other supported micronutrients you can reasonably estimate. Unknown values are null, not0. Use0 only as an actual estimated zero. Retain these units and do not add unsupported nutrient fields. Nutrients are NOT calculated by the application from calorie/macronutrient ratios, so provide each estimate independently. Total carbohydrates include fiber. Provide netCarbohydrates directly only when total carbohydrates and fiber are known and the value is consistent with them; otherwise use null. Do not derive calories using4/4/9 merely to fill a missing value. No health or treatment advice.
Identity confidence is not nutritional accuracy. estimate.uncertainty is a short localized limitation or null. Portions and all nutrition are estimates for review, never automatic logging. No hidden oil, recipe ingredients or secondary background food may be asserted as observed. Return a graceful empty candidates array for unrecognized/non-food images rather than random nutrient zeros.`;
}
