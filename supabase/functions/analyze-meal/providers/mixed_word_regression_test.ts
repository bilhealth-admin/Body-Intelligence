// Copy to providers/ at SAFE. Exact synthetic v103 contamination is retained.
import { validateVisionResponseLocale } from "./locale.ts";
import { normalizeProviderResponse } from "./normalize.ts";
import { ProviderConfig, VisionProviderError } from "./types.ts";
const bad = "الوزن تقديري بناءً على الحجم الظاهر لمكونات الوعsingle وعاء";
const base = {
  name: "وعاء السلمون",
  confidence: .96,
  evidence: "وعاء سلمون وأفوكادو",
  amount: 450,
  unit: "g",
  uncertainty: null,
  warnings: [],
  alternatives: [],
};
function reject(run: () => unknown) {
  let caught = false;
  try {
    run();
  } catch (error) {
    if (
      !(error instanceof VisionProviderError) ||
      error.code !== "language_mismatch"
    ) throw error;
    caught = true;
  }
  if (!caught) {
    throw new Error("Arabic/Latin lexical contamination was accepted");
  }
}
Deno.test("v103 Arabic uncertainty rejects actual within-word English contamination", () => {
  reject(() =>
    validateVisionResponseLocale("ar", "ar", [{ ...base, uncertainty: bad }])
  );
});
Deno.test("mixed words are rejected across every human-readable field", () => {
  for (
    const detail of [
      { name: "سلمونsingle" },
      { evidence: "في الوعsingle وعاء" },
      { uncertainty: bad },
      { warnings: ["حجمplateغير مؤكد"] },
      { alternatives: [{ name: "وعbowlاء" }] },
      { dish_identity: { name: "سلsaladطة", alternatives: [] } },
      {
        dish_identity: { name: "سلطة", alternatives: [{ name: "سلsaladطة" }] },
      },
      { visible_components: [{ name: "سلمsalmonون", evidence: "سمك ظاهر" }] },
      { visible_components: [{ name: "سلمون", evidence: "في الوعsingle" }] },
    ]
  ) {
    reject(() =>
      validateVisionResponseLocale("ar", "ar", [{ ...base, ...detail }])
    );
  }
});
Deno.test("legitimate units, scientific labels, brands and source links stay readable", () => {
  for (
    const text of [
      "تقدير 450 g من الوعاء",
      "المرجع mg و RAE و B12 و µg",
      "منتج BIL من العلامة Nestle",
      "المصدر https://example.test/سلمون/salmon",
      "نسبة أوميغا 3 بوحدة mg",
    ]
  ) {
    const locale = validateVisionResponseLocale("ar", "ar", [{
      ...base,
      uncertainty: text,
    }]);
    if (locale !== "ar") throw new Error("Legitimate Arabic metadata rejected");
  }
});
for (const provider of ["gemini", "openai", "mistral"] as const) {
  Deno.test(`${provider} normalization fails closed before v103 mixed-word response reaches the app`, () => {
    const config: ProviderConfig = {
      provider,
      apiKey: "test-only",
      model: "fixture",
      endpoint: "https://fixture.invalid",
    };
    const text = JSON.stringify({
      response_locale: "ar",
      candidates: [{ ...base, uncertainty: bad }],
    });
    const envelope = provider === "gemini"
      ? { candidates: [{ content: { parts: [{ text }] } }] }
      : provider === "openai"
      ? { output: [{ content: [{ type: "output_text", text }] }] }
      : { choices: [{ message: { content: text } }] };
    reject(() => normalizeProviderResponse(envelope, config, "ar"));
  });
}
