import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { isPureCoachRecordInteraction as pure } from "./coach_answer_quality.ts";
import { answerNeedsHealthCitation, parseModelJson } from "./server.ts";
const english = [
  "Which exercise did you complete?",
  "How many hours did you exercise?",
  "I can open your saved exercise log for review.",
  "Great job! Which exercise did you complete?",
  "Great job finishing your workout! Which exercise did you complete?",
  "Well done on completing your session! How many hours did you exercise?",
  "Awesome work getting your session done! Which exercise did you complete?",
  "To log your workout, which exercise did you complete?",
  "Which workout was it and how long did it last?",
  "Which meal did you eat?",
  "How much water did you log?",
  "Let's get it logged. Which exercise did you complete?",
  "I need a bit more detail to record it accurately. Which exercise did you complete?",
];
const arabic = [
  "اي تمرين اكملت؟",
  "كم كانت مدة التمرين الذي انهيت؟",
  "هل تريد فتح سجل تمرينك؟",
  "ممتاز! اي تمرين اكملت؟",
  "يمكنني فتح سجل تمرينك للمراجعة.",
  "كم ماء شربت؟",
  "ما الوجبة التي تناولت؟",
];
function body(reply: string, flag: unknown = false) {
  return {
    reply,
    spoken_reply: reply,
    reason: "Record clarification only",
    confidence: 1,
    evidence: [],
    citations: [],
    requires_health_citation: flag,
    missing_data: ["workout"],
    proposed_actions: [],
  };
}
Deno.test("pure English record questions and navigation do not require a scientific citation", () => {
  for (const text of english) {
    assertEquals(pure(text), true, text);
    assertEquals(answerNeedsHealthCitation(text), false, text);
  }
});
Deno.test("Arabic record clarification stays citation-free without turning into guidance", () => {
  for (const text of arabic) {
    assertEquals(pure(text), true, text);
    assertEquals(answerNeedsHealthCitation(text), false, text);
  }
});
Deno.test("appended health guidance or numerical recommendations cannot masquerade as a record question", () => {
  for (const start of english.slice(0, 4)) {
    for (
      const addition of [
        "Exercise every day.",
        "Drink more water.",
        "You should eat more vegetables.",
        "Aim for 150 minutes of exercise weekly.",
        "You need 1800 kcal per day.",
      ]
    ) {
      const text = start + " " + addition;
      assertEquals(pure(text), false, text);
      assertEquals(answerNeedsHealthCitation(text), true, text);
      assertThrows(
        () => parseModelJson(JSON.stringify(body(text))),
        Error,
        "missing_health_citation",
      );
    }
  }
  for (
    const text of [
      "Would you like to try more exercise?",
      "What should you eat?",
      "How much protein should I eat?",
      "Did you know exercise causes cancer?",
      "Which exercise did you complete that causes cancer?",
      "هل يجب زيادة التمرين؟",
      "اي تمرين انهيت؟ يجب اشرب ماء.",
    ]
  ) {
    assertEquals(pure(text), false, text);
  }
});
Deno.test("strict response metadata remains mandatory while a conservative model flag is normalized for pure data flow", () => {
  for (const flag of [false, true]) {
    for (const text of [...english, ...arabic]) {
      const parsed = parseModelJson(JSON.stringify(body(text, flag)));
      assertEquals(parsed.reply, text);
      assertEquals(parsed.citations, []);
      assertEquals(parsed.requires_health_citation, false);
    }
  }
  for (const flag of [null, "false", 0, {}]) {
    assertThrows(
      () => parseModelJson(JSON.stringify(body(english[0], flag))),
      Error,
      "malformed_health_citation_classification",
    );
  }
});
Deno.test("citation classification cannot grant unnegotiated Smart Plan tools or prototype arguments", () => {
  const value = {
    ...body(english[2], true),
    proposed_actions: [{
      type: "read_active_smart_plan",
      arguments_json: "{}",
      requires_confirmation: true,
    }],
  };
  assertEquals(
    parseModelJson(JSON.stringify(value), false, 1, 1).proposed_actions[0].type,
    "read_active_smart_plan",
  );
  // Existing compatibility contract filters unsupported proposals while
  // retaining useful text; it does not reject the whole legacy response.
  assertEquals(
    parseModelJson(JSON.stringify(value), false, 1, 0).proposed_actions,
    [],
  );
  value.proposed_actions[0].arguments_json = '{"__proto__":{"polluted":true}}';
  assertThrows(() => parseModelJson(JSON.stringify(value), false, 1, 1), Error);
});
