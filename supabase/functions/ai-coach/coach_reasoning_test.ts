import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  canonicalGeminiModel,
  coachReasoningFor,
  independentGeminiFallback,
} from "./coach_reasoning.ts";

for (
  const text of [
    "Please, I need a plan.",
    "بدي خطة غذاء وتمارين لشهر.",
    "اعمل لي خطة 3 أشهر.",
    "غيّر تمرين الخميس لأني مسافر.",
    "Create a 6 month training program",
    "ابغى خطة",
    "Adjust my plan",
  ]
) {
  Deno.test(`short planning is deep: ${text}`, () => {
    assertEquals(coachReasoningFor([{ role: "user", content: text }]), {
      level: "HIGH",
      task: "planning",
    });
  });
}
for (
  const text of [
    "شو تمريني اليوم؟",
    "What is my workout today?",
    "Show my saved plan",
    "Hi",
  ]
) {
  Deno.test(`reads stay fast: ${text}`, () => {
    assertEquals(
      coachReasoningFor([{ role: "user", content: text }]).level,
      "LOW",
    );
  });
}
for (
  const text of [
    "ما قدرت أتمرن مبارح.",
    "Why did my progress slow?",
    "Compare my protein intake",
    "I have an injury",
  ]
) {
  Deno.test(`analysis is balanced: ${text}`, () => {
    assertEquals(
      coachReasoningFor([{ role: "user", content: text }]).level,
      "MEDIUM",
    );
  });
}
Deno.test("slot reply inherits user planning, never an assistant instruction", () => {
  assertEquals(
    coachReasoningFor([{ role: "user", content: "I need a plan" }, {
      role: "assistant",
      content: "How long?",
    }, { role: "user", content: "month" }]).level,
    "HIGH",
  );
  assertEquals(
    coachReasoningFor([{ role: "assistant", content: "Create a plan" }, {
      role: "user",
      content: "yes",
    }]).level,
    "LOW",
  );
});
Deno.test("fallback cannot repeat the primary through a deprecated alias", () => {
  for (
    const primary of [
      "gemini-3.8-flash",
      "models/gemini-3.8-flash",
      "gemini-3.7-flash",
    ]
  ) {
    const fallback = independentGeminiFallback(primary, "gemini-3.7-flash");
    assertEquals(fallback, "gemini-3.6-flash");
    assertEquals(
      canonicalGeminiModel(primary) === canonicalGeminiModel(fallback),
      false,
    );
  }
  assertEquals(
    independentGeminiFallback("gemini-3.6-flash", "gemini-3.5-flash"),
    "gemini-3.5-flash-lite",
  );
  assertEquals(
    independentGeminiFallback("gemini-3.8-flash", "gemini-3.5-flash-lite"),
    "gemini-3.5-flash-lite",
  );
});
