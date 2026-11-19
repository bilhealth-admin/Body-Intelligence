import { buildProviderRequest } from "./builders.ts";
import { ProviderConfig } from "./types.ts";

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
    if (!prompt.includes(key)) throw new Error(`Gemini schema2 prompt omits ${key}`);
  }
});
