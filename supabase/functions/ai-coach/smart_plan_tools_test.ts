import { parseModelJson } from "./server.ts";

function answer(type: string) {
  return JSON.stringify({
    reply: "Review the saved plan in BIL.",
    spoken_reply: "Review the saved plan in BIL.",
    reason: "Navigation for human review", confidence: 0.8,
    evidence: [], citations: [], requires_health_citation: false, missing_data: [],
    proposed_actions: [{ type, arguments: {}, requires_confirmation: true }],
  });
}
Deno.test("Smart Plan tools require explicit new-client capability negotiation", () => {
  for (const tool of ["read_active_smart_plan", "create_smart_plan_draft", "preview_smart_plan_day",
    "request_smart_plan_revision", "record_smart_plan_workout"]) {
    if (parseModelJson(answer(tool), false, 1).proposed_actions.length !== 0) {
      throw new Error("Legacy client received an unsupported Smart Plan action");
    }
    if (parseModelJson(answer(tool), false, 1, 1).proposed_actions[0]?.type !== tool) {
      throw new Error("New client lost the validated tool identity");
    }
    if (parseModelJson(answer(tool), false, 1, 99).proposed_actions.length !== 0) {
      throw new Error("Unknown client capability was accepted");
    }
  }
});
Deno.test("New plan capability does not enable arbitrary tools", () => {
  if (parseModelJson(answer("run_sql"), false, 1, 1).proposed_actions.length) {
    throw new Error("Model instruction crossed the tool allow-list");
  }
});
