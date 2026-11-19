import { buildProviderRequest } from "./builders.ts";
import { ProviderConfig, VisionProviderError } from "./types.ts";
import { normalizeGeminiEstimateResponse } from "./normalize_v2.ts";
import { geminiNutrientUnits } from "./nutrients_v2.ts";

// Baseline-compatible: only pre-existing public APIs/types are imported.
// Structural typing permits the future negotiated option on this variable;
// old code ignores it and produces the literal no-nutrition prompt.
Deno.test("explicit schema2 asks Gemini for photo portion and nutrition", () => {
  const config: ProviderConfig = { provider: "gemini", apiKey: "synthetic",
    model: "synthetic-model", endpoint: "https://generativelanguage.googleapis.com/v1beta" };
  const input = { imageBase64: "AA==", mimeType: "image/jpeg" as const,
    requestedLocale: "en", schemaVersion: 2 as const };
  const request = buildProviderRequest(config, input);
  const body = JSON.parse(request.body);
  const prompt = body.contents[0].parts[0].text;
  if (prompt.includes("Never estimate nutrition, calories")) {
    throw new Error("Schema2 still forbids the requested Gemini nutrition estimates");
  }
  for (const key of ["estimate", "basis", "netCarbohydrates", "sodium", "potassium", "vitaminA"]) {
    if (!JSON.stringify(body.generationConfig.responseSchema).includes(`"${key}"`)) {
      throw new Error(`Gemini schema2 wire schema omits ${key}`);
    }
  }
});

function assertContract(ok: boolean, message: string): asserts ok {
  if (!ok) throw new Error(message);
}
const syntheticGemini: ProviderConfig = { provider: "gemini", apiKey: "synthetic", model: "synthetic-model",
  endpoint: "https://generativelanguage.googleapis.com/v1beta" };
const syntheticInput = { imageBase64: "AA==", mimeType: "image/jpeg" as const, requestedLocale: "en" };

Deno.test("V2 wire schema fixes object types, nullable unknown nutrients and exact canonical units", () => {
  const body = JSON.parse(buildProviderRequest(syntheticGemini, { ...syntheticInput, schemaVersion: 2 }).body);
  const schema = body.generationConfig.responseSchema;
  assertContract(body.generationConfig.responseMimeType === "application/json", "V2 JSON mode absent");
  assertContract(schema.type === "OBJECT", "V2 must use an object root");
  const candidate = schema.properties.candidates.items;
  const estimate = candidate.properties.estimate;
  assertContract(estimate.properties.basis.nullable === true, "Unknown basis must remain nullable");
  assertContract(estimate.properties.basis.properties.unit.type === "STRING", "Non-string basis cannot be requested");
  assertContract(JSON.stringify(estimate.properties.basis.properties.unit.enum) === '["g","ml","piece"]', "Basis units changed");
  const expected = { calories: "kcal", protein: "g", carbohydrates: "g", fat: "g", fiber: "g", sugar: "g",
    sodium: "mg", potassium: "mg", calcium: "mg", magnesium: "mg", phosphorus: "mg", iron: "mg", vitaminC: "mg",
    saturatedFat: "g", polyunsaturatedFat: "g", monounsaturatedFat: "g", transFat: "g", cholesterol: "mg",
    vitaminA: "mcg RAE", netCarbohydrates: "g" };
  const nutrients = estimate.properties.nutrients;
  assertContract(JSON.stringify(Object.keys(nutrients.properties).sort()) === JSON.stringify(Object.keys(expected).sort()), "Wire must carry exactly20 canonical nutrient keys");
  for (const [name, canonical] of Object.entries(expected)) {
    const field = nutrients.properties[name];
    assertContract(field.type === "OBJECT" && field.properties.value.type === "NUMBER"
      && field.properties.value.nullable === true, "Unknown nutrient cannot become a required number");
    assertContract(field.properties.value.minimum === 0 && field.properties.value.maximum === 1e9, "Nutrient numeric bounds drifted");
    assertContract(field.properties.unit.type === "STRING" && JSON.stringify(field.properties.unit.enum) === JSON.stringify([canonical]), "Canonical unit changed");
    assertContract(!("default" in field.properties.value), "Schema must not fill missing values");
  }
  assertContract(schema.properties.candidates.maxItems === 6 && candidate.properties.alternatives.maxItems === 3
    && candidate.properties.warnings.maxItems === 5 && candidate.properties.visible_components.maxItems === 12, "Existing output caps drifted");
});

Deno.test("V2 provider schema uses only documented subset and matching property order for both locales", () => {
  const allowed = new Set(["type", "properties", "required", "propertyOrdering", "nullable", "enum", "items",
    "minimum", "maximum", "maxItems", "description"]);
  function inspect(schema: Record<string, unknown>) {
    assertContract(Object.keys(schema).every((key) => allowed.has(key)), "Unsupported provider schema keyword");
    if (schema.type === "OBJECT") {
      const properties = schema.properties as Record<string, Record<string, unknown>>;
      assertContract(JSON.stringify(schema.required) === JSON.stringify(Object.keys(properties)), "All declared fields must be explicit, with unknown values nullable");
      assertContract(JSON.stringify(schema.propertyOrdering) === JSON.stringify(Object.keys(properties)), "Property ordering differs from generated schema");
      for (const value of Object.values(properties)) inspect(value);
    }
    if (schema.items) inspect(schema.items as Record<string, unknown>);
  }
  for (const locale of ["en", "ar"]) {
    const body = JSON.parse(buildProviderRequest(syntheticGemini, { ...syntheticInput, requestedLocale: locale, schemaVersion: 2 }).body);
    inspect(body.generationConfig.responseSchema);
    assertContract(JSON.stringify(body.generationConfig.responseSchema.properties.response_locale.enum) === JSON.stringify([locale]), "Response locale not pinned");
    const prompt = body.contents[0].parts[0].text;
    assertContract(!prompt.includes('"response_locale":') && prompt.includes("supplied response schema"), "Duplicate JSON schema/example remains in prompt");
  }
});

Deno.test("V1 Gemini wire remains unchanged and non-Gemini V2 stays rejected", () => {
  const legacy = buildProviderRequest(syntheticGemini, syntheticInput);
  const explicit = buildProviderRequest(syntheticGemini, { ...syntheticInput, schemaVersion: 1 });
  assertContract(legacy.body === explicit.body, "V1 implicit/explicit bytes changed");
  const body = JSON.parse(legacy.body);
  assertContract(JSON.stringify(body.generationConfig) === '{"responseMimeType":"application/json"}', "V1 must not inherit V2 schema");
  assertContract(body.contents[0].parts[0].text.includes("Never estimate nutrition"), "V1 identification-only prompt changed");
  for (const provider of ["openai", "mistral"] as const) {
    let rejected = false;
    try { buildProviderRequest({ ...syntheticGemini, provider }, { ...syntheticInput, schemaVersion: 2 }); }
    catch { rejected = true; }
    assertContract(rejected, "V2 must not silently switch away from disclosed Gemini");
  }
});

Deno.test("V2 wire declares visible component objects and strict parser rejects the diagnosed nonobject class", () => {
  const wire = JSON.parse(buildProviderRequest(syntheticGemini, { ...syntheticInput, schemaVersion: 2 }).body);
  const item = wire.generationConfig.responseSchema.properties.candidates.items.properties.visible_components.items;
  assertContract(item.type === "OBJECT" && JSON.stringify(item.required) === '["name","confidence","evidence"]',
    "Visible components must be typed nested objects, not unspecified array items");
  const food = { name: "Red apple", confidence: .98, evidence: "One red foreground apple", amount: 150, unit: "g",
    alternatives: [], uncertainty: null, warnings: [], dish_identity: null,
    visible_components: ["apple"] as unknown[],
    estimate: { basis: { quantity: 150, unit: "g" }, uncertainty: null,
      nutrients: Object.fromEntries(Object.entries(geminiNutrientUnits).map(([key, unit]) => [key, { value: null, unit }])) } };
  const envelope = () => ({ candidates: [{ finishReason: "STOP", content: { parts: [{ text: JSON.stringify({
    response_locale: "en", candidates: [food],
  }) }] } }] });
  let diagnosedClassRejected = false;
  try { normalizeGeminiEstimateResponse(envelope(), syntheticGemini, "en"); }
  catch (error) {
    diagnosedClassRejected = error instanceof VisionProviderError && error.code === "malformed_response"
      && error.message === "Visible component is invalid";
  }
  assertContract(diagnosedClassRejected, "Do not weaken the exact diagnosed nonobject rejection");
  food.visible_components = [{ name: "Apple", confidence: .98, evidence: "Visible red skin and rounded fruit" }];
  const accepted = normalizeGeminiEstimateResponse(envelope(), syntheticGemini, "en");
  assertContract(accepted.candidates[0].visible_components[0].name === "Apple", "Valid typed visible component lost");
  assertContract(Object.values(accepted.candidates[0].estimate.nutrients).every((value) => value === null),
    "A shape repair must not fabricate unknown nutrient values");
});
