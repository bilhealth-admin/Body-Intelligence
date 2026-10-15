import { decodeTranslatedText } from "./translation_text.ts";

Deno.test("decodes provider entities once without recursively unescaping text", () => {
  if (
    decodeTranslatedText("&quot;fish &amp; chips&#39;") !== "\"fish & chips'"
  ) {
    throw new Error("Common translated entities should decode once");
  }
  if (decodeTranslatedText("&amp;lt;script&amp;gt;") !== "&lt;script&gt;") {
    throw new Error("Nested entity text must not be decoded a second time");
  }
  if (decodeTranslatedText("plain <text>") !== "plain <text>") {
    throw new Error("Plain text should remain unchanged");
  }
});
