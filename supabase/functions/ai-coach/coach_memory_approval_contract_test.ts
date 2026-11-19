import { assertEquals, assertThrows } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { actionExecutionContract, parseModelJson } from "./server.ts";
import { validateCoachAnswerQuality } from "./coach_answer_quality.ts";

Deno.test("memory prompt requires a structured pending proposal, never a completion receipt", () => {
  assertEquals(actionExecutionContract.includes("save_memory"), true);
  assertEquals(actionExecutionContract.includes("requires_confirmation=true"), true);
  assertEquals(actionExecutionContract.includes("Would you like to save this preference?"), true);
  assertEquals(actionExecutionContract.includes("Memory is not saved until a later client receipt"), true);
});

for (const [reply, request] of [
  ["Would you like to save this preference?", "Remember that I prefer concise answers. Show approval before saving."],
  ["هل ترغب في حفظ هذا التفضيل؟", "تذكر أنني أفضل الإجابات الموجزة. اعرض الموافقة قبل الحفظ."],
]) {
  Deno.test(`valid structured memory approval remains allowed: ${reply}`, () => {
    const response = parseModelJson(JSON.stringify({
      reply, spoken_reply: reply, reason: "Explicit user preference request",
      confidence: 0.9, evidence: [], citations: [], requires_health_citation: false,
      missing_data: [], proposed_actions: [{
        type: "save_memory", arguments_json: JSON.stringify({ text: "I prefer concise answers", kind: "preference" }),
        requires_confirmation: true,
      }],
    }), false);
    validateCoachAnswerQuality(response, [{ role: "user", content: request }], {});
    assertEquals(response.proposed_actions.length, 1);
    assertEquals(response.proposed_actions[0].type, "save_memory");
    assertEquals(response.proposed_actions[0].requires_confirmation, true);
  });
}

Deno.test("unverified memory completion claims stay rejected even with a valid proposed action", () => {
  for (const reply of ["I have saved your preference.", "لقد حفظت لك هذا التفضيل."]) {
    assertThrows(() => validateCoachAnswerQuality({
      reply, spoken_reply: reply, proposed_actions: [{ type: "save_memory" }],
    }, [{ role: "user", content: "Remember my preference after approval." }], {}), Error, "unverified_action_claim");
  }
});
