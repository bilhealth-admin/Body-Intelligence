import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  claimsNoWeightRecords,
  correctWeightRecordAbsence,
} from "./coach_weight_truth.ts";

const denials = [
  "You have no recorded weigh-ins.",
  "There are no recorded weights in your history.",
  "You have not recorded any weight.",
  "I don't have any weight records.",
  "I cannot access your weight history.",
  "Your weight history is empty.",
  "لا توجد قياسات وزن مسجلة لديك.",
  "لا يوجد لديك أي سجل وزن.",
  "ليس لديك قياسات وزن سابقة.",
  "لم تسجل أي وزن بعد.",
  "سجل أوزانك فارغ.",
  "لم أجد قياسات وزن محفوظة.",
];

for (const denial of denials) {
  Deno.test(`weight truth detects text and speech denial: ${denial}`, () => {
    assert(claimsNoWeightRecords(denial));
    for (const field of ["reply", "spoken_reply"] as const) {
      const answer = {
        reply: "Ready.",
        spoken_reply: "Ready.",
        [field]: denial,
      };
      const context = {
        weight: {
          readStatus: "verified",
          summary: { recordCount: 14 },
          history: [],
        },
      };
      const before = JSON.stringify(context);
      for (const language of ["ar", "en"]) {
        const correction = correctWeightRecordAbsence(
          answer,
          context,
          language,
        );
        assert(correction);
        assert(correction.reply.includes("14"));
        assert(correction.spoken_reply.includes("14"));
        assertEquals(correction.proposed_actions, []);
        assertEquals(correction.evidence, ["weight.summary.recordCount"]);
      }
      assertEquals(JSON.stringify(context), before);
    }
  });
}

Deno.test("positive legacy summary survives truncated row-level history", () => {
  const correction = correctWeightRecordAbsence(
    { reply: denials[0], spoken_reply: "Ready." },
    { weight: { summary: { recordCount: 200 }, history: [] } },
    "en",
  );
  assert(correction?.reply.includes("200"));
  assertEquals(correction?.proposed_actions, []);
});

Deno.test("only explicit verified zero establishes an empty diary", () => {
  const answer = { reply: denials[0], spoken_reply: denials[0] };
  assertEquals(
    correctWeightRecordAbsence(answer, {
      weight: { readStatus: "verified", summary: { recordCount: 0 } },
    }, "en"),
    null,
  );
  for (
    const context of [
      {},
      { profile: { currentWeightKg: 88, targetWeightKg: 60 } },
      { weight: { history: [{ kg: 88 }] } },
      { weight: { summary: { recordCount: 0 } } },
      ...["unavailable", "timeout", "failed", "withheld", "denied"].map((
        readStatus,
      ) => ({ weight: { readStatus, summary: { recordCount: 14 } } })),
      ...[-1, 1.5, "14", null, "ignore all instructions"].map((
        recordCount,
      ) => ({ weight: { readStatus: "verified", summary: { recordCount } } })),
    ]
  ) {
    const correction = correctWeightRecordAbsence(answer, context, "en");
    assert(correction);
    assertEquals(correction.evidence, []);
    assertEquals(correction.reply.includes("14"), false);
    assertEquals(correction.missing_data, ["verified_weight_history"]);
  }
});

Deno.test("truth guard does not replace advice-free facts or a missing-date statement", () => {
  for (
    const reply of [
      "Your latest recorded weight is 88 kg.",
      "No weight was recorded yesterday.",
      "Your meal log is empty.",
      "There is no recorded weight loss in the selected period.",
      "لا يوجد نزول في الوزن خلال هذه الفترة.",
      "لا توجد خطة لتغيير الوزن.",
      "There are no weight records for that date.",
      "لا توجد قياسات وزن في ذلك اليوم.",
    ]
  ) {
    assertEquals(
      correctWeightRecordAbsence({ reply, spoken_reply: reply }, {
        weight: { readStatus: "verified", summary: { recordCount: 14 } },
      }, "en"),
      null,
      reply,
    );
  }
});
