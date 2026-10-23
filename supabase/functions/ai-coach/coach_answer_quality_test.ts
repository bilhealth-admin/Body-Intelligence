import { assertThrows } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { validateCoachAnswerQuality } from "./coach_answer_quality.ts";

Deno.test("deterministic quality review rejects hallucinated receipts in text or speech", () => {
  for (
    const prose of [
      "I have saved your plan.",
      "I have initiated a draft Smart Plan.",
      "I have drafted a plan for your review.",
      "جهزت لك الخطة.",
      "تم إنشاء المسودة.",
      "تم حفظ الخطة.",
      "حفظت الخطة بنجاح.",
    ]
  ) {
    assertThrows(
      () =>
        validateCoachAnswerQuality({
          reply: "Review the proposal",
          spoken_reply: prose,
          proposed_actions: [],
        }, []),
      Error,
      "unverified_action_claim",
    );
  }
  for (
    const prose of [
      "Please review the saved plan.",
      "I cannot save your plan.",
      "لم يتم حفظ الخطة.",
      "يمكنك حفظ الخطة بعد المراجعة.",
    ]
  ) {
    validateCoachAnswerQuality({
      reply: prose,
      spoken_reply: prose,
      proposed_actions: [],
    }, []);
  }
});
Deno.test("goal and missed session cannot masquerade as recording intent", () => {
  for (
    const [prompt, tool] of [
      ["My goal is 60 kg", "log_weight"],
      ["هدفي 60 كيلو", "log_weight"],
      ["ما خلصت التمرين", "record_smart_plan_workout"],
      ["I did not finish my workout", "record_smart_plan_workout"],
    ]
  ) {
    assertThrows(
      () =>
        validateCoachAnswerQuality({
          reply: "Review",
          spoken_reply: "Review",
          proposed_actions: [{ type: tool }],
        }, [{ role: "user", content: prompt }]),
      Error,
      "unsafe_action_intent",
    );
  }
  validateCoachAnswerQuality({
    reply: "Review",
    spoken_reply: "Review",
    proposed_actions: [{ type: "log_weight" }],
  }, [{ role: "user", content: "Log my weight as 60 kg" }]);
});
