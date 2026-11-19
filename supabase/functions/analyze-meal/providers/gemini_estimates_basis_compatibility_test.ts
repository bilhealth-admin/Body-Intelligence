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
