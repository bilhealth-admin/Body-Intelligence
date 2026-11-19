import { normalizeGeminiEstimateResponse } from "./normalize_v2.ts";
import { ProviderConfig, VisionProviderError } from "./types.ts";
const config = { provider: "gemini", model: "gemini-test", apiKey: "synthetic", endpoint: "https://example.invalid" } as ProviderConfig;
function envelope(unit: string, basis: string) {
  return { candidates: [{ content: { parts: [{ text: JSON.stringify({ response_locale: "en", candidates: [{
    name: "Visible meal", confidence: .8, evidence: "Visible portion", amount: 150, unit,
    alternatives: [], uncertainty: null, warnings: [], dish_identity: null, visible_components: [],
    estimate: { basis: { quantity: 100, unit: basis }, nutrients: { calories: {value:150,unit:"kcal"} }, uncertainty: null },
  }] }) }] } }], usageMetadata: {} };
}
Deno.test("pictured portion and nutrition basis require compatible units", () => {
  let rejected = false;
  try { normalizeGeminiEstimateResponse(envelope("piece", "g"), config, "en"); }
  catch (error) { rejected = error instanceof VisionProviderError && error.code === "malformed_response"; }
  if (!rejected) throw new Error("Count cannot silently acquire a gram basis");
});
Deno.test("different quantities in the same explicit unit remain valid", () => {
  const result = normalizeGeminiEstimateResponse(envelope("g", "g"), config, "en");
  if (result.candidates[0].amount !== 150 || result.candidates[0].estimate.basis?.quantity !== 100) throw new Error("Explicit per100g basis was lost");
});


// Wire mutations stay synthetic; no model call or conversion fallback is used.
function editedEnvelope(edit: (row: Record<string, unknown>) => void) {
  const result = envelope("g", "g");
  const part = result.candidates[0].content.parts[0];
  const body = JSON.parse(part.text) as { candidates: Array<Record<string, unknown>> };
  edit(body.candidates[0]);
  part.text = JSON.stringify(body);
  return result;
}

for (const [label, basisUnit] of [
  ["number", 100],
  ["array-g", ["g"]],
  ["array-ml", ["ml"]],
  ["array-piece", ["piece"]],
  ["object", { unit: "g" }],
  ["boolean", true],
  ["null", null],
] as const) {
  Deno.test(`basis rejects non-string ${label} with unknown pictured unit`, () => {
    const input = editedEnvelope((row) => {
      row.amount = null;
      row.unit = null;
      const estimate = row.estimate as Record<string, unknown>;
      estimate.basis = { quantity: 100, unit: basisUnit };
      // A coerced ["g"] formerly skipped the known240g/100g gram-mass gate.
      estimate.nutrients = {
        protein: { value: 80, unit: "g" },
        carbohydrates: { value: 80, unit: "g" },
        fat: { value: 80, unit: "g" },
      };
    });
    let error: unknown;
    try { normalizeGeminiEstimateResponse(input, config, "en"); }
    catch (caught) { error = caught; }
    if (!(error instanceof VisionProviderError) || error.code !== "malformed_response" ||
        error.message !== "Invalid Gemini estimate basis") {
      throw new Error(`Non-string ${label} did not stop at the basis type gate`);
    }
  });
}

for (const unit of ["g", "ml", "piece"] as const) {
  Deno.test(`basis preserves canonical ${unit} without quantity synthesis`, () => {
    const result = normalizeGeminiEstimateResponse(envelope(unit, unit), config, "en");
    const row = result.candidates[0];
    if (row.unit !== unit || row.amount !== 150 || row.estimate.basis?.unit !== unit ||
        row.estimate.basis?.quantity !== 100 || row.estimate.nutrients.calories !== 150) {
      throw new Error("Canonical units or explicit quantities changed");
    }
  });
}

Deno.test("null basis and unknown nutrient values stay null without numeric synthesis", () => {
  const input = editedEnvelope((row) => {
    const estimate = row.estimate as Record<string, unknown>;
    estimate.basis = null;
    estimate.nutrients = { calories: null, protein: { value: null, unit: "g" } };
  });
  const estimate = normalizeGeminiEstimateResponse(input, config, "en").candidates[0].estimate;
  if (estimate.basis !== null || Object.values(estimate.nutrients).some((v) => v !== null)) {
    throw new Error("Unknown nutrient values or basis were synthesized");
  }
});

Deno.test("literal null nutrient container remains invalid", () => {
  const input = editedEnvelope((row) => {
    const estimate = row.estimate as Record<string, unknown>;
    estimate.basis = null;
    estimate.nutrients = null;
  });
  let error: unknown;
  try { normalizeGeminiEstimateResponse(input, config, "en"); }
  catch (caught) { error = caught; }
  if (!(error instanceof VisionProviderError) || error.code !== "malformed_response" ||
      error.message !== "Invalid Gemini estimate nutrients") {
    throw new Error("Null nutrient container validation changed");
  }
});
