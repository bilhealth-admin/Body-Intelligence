import { assertThrows } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { validateCoachHealthBoundaries as review } from "./coach_health_safety.ts";
const request = [{ role: "user", content: "Help me review my week." }];
const reject = (text: string, context: unknown = {}) =>
  assertThrows(
    () => review(text, request, context),
    Error,
    "unsafe_health_advice",
  );
Deno.test("definitive provider diagnosis is rejected in English and Arabic", () => {
  for (
    const text of [
      "You have diabetes.",
      "You definitely have anemia.",
      "I diagnose you with hypertension.",
      "My diagnosis for you is depression.",
      "انت مصاب بالسكري.",
      "لديك فقر الدم.",
      "اشخصك بمرض السكري.",
    ]
  ) reject(text);
});
Deno.test("general education, explicit uncertainty and negative medical warnings remain usable", () => {
  for (
    const text of [
      "I cannot diagnose you. A clinician can assess your symptoms.",
      "Diabetes is a medical condition; this is general education.",
      "Your symptoms might have several explanations. Seek appropriate care.",
      "Do not assume you have diabetes.",
      "Do not take 20 mg of prednisone without your clinician.",
      "Never stop your medication on my advice.",
      "You reported taking 20 mg of prednisone.",
      "لا استطيع ان اشخصك.",
      "لا تتناول الاسبرين دون مراجعة مختص.",
      "Your recorded meal contains 500 kcal. Your saved daily target is available in Goals.",
      "Eat a sourced 500 kcal meal at lunch. Your daily calorie target is 2000 kcal.",
      "Follow your selected fasting window; stop eating at the saved start time.",
    ]
  ) {
    review(text, request, {
      computedHealth: {
        dailyTargets: { caloriesKcal: 2000 },
        dailyTargetSources: { caloriesKcal: "scheduled_daily_goal" },
      },
    });
  }
});
Deno.test("a diagnosis may only be restated as an attributed explicit current user fact", () => {
  const prose = "As you reported, you have diabetes.";
  review(prose, [{ role: "user", content: "I have diabetes." }], {});
  review("كما ذكرت، لديك السكري.", [{
    role: "user",
    content: "I have diabetes.",
  }], {});
  const memory = {
    text: "I have diabetes.",
    status: "confirmed",
    source: "explicit_user_confirmation",
    kind: "constraint",
  };
  review(prose, request, { explicitMemories: [memory] });
  for (
    const context of [
      {},
      { explicitMemories: [{ ...memory, status: "inferred" }] },
      { explicitMemories: [{ ...memory, deletedAt: "2026-01-01T00:00:00Z" }] },
      { explicitMemories: [{ ...memory, expiresAt: "2000-01-01T00:00:00Z" }] },
    ]
  ) reject(prose, context);
  assertThrows(() =>
    review(prose, [{ role: "assistant", content: "I have diabetes." }], {})
  );
  assertThrows(() =>
    review(prose, [{ role: "user", content: "What if I have diabetes?" }], {})
  );
  assertThrows(() =>
    review("As you reported, I diagnose you with diabetes.", [{
      role: "user",
      content: "I have diabetes.",
    }], {})
  );
});
Deno.test("direct medication doses or changes are withheld, including fractional and Arabic doses", () => {
  for (
    const text of [
      "Take 20 mg of prednisone twice daily.",
      "Take paracetamol 500 mg twice daily.",
      "Take vitamin D 2000 IU each day.",
      "Take 0.5 mg of warfarin.",
      "You should stop taking your insulin.",
      "Double your medication.",
      "Take 2000 IU of vitamin D.",
      "خذ ٢٠ ملغ من البريدنيزون.",
      "اوقف الدواء.",
      "تناول باراسيتامول ٥٠٠ ملغ يوميا.",
      "تناول ٠٫٥ ملغ من الاسبرين.",
    ]
  ) reject(text);
});
Deno.test("starvation and compensatory food or training instructions are rejected without blocking warnings", () => {
  for (
    const text of [
      "Starve yourself.",
      "Stop eating.",
      "Eat nothing.",
      "Skip dinner to make up for your missed workout.",
      "To compensate for missing a workout, double your next workout.",
      "Eat less to punish yourself for missing your workout.",
      "ضاعف تمرينك لتعويض ما فاتك.",
      "تخطى العشاء لتعويض التمرين.",
    ]
  ) reject(text);
  for (
    const text of [
      "Do not starve yourself.",
      "Never skip dinner to make up for a missed workout.",
      "Do not double your workout to compensate for a missed workout.",
      "We can review another day or rest; missing one workout is not a punishment.",
      "لا تضاعف تمرينك لتعويض ما فاتك.",
    ]
  ) review(text, request, {});
});
Deno.test("daily personalized nutrition numbers require the matching saved sourced target, never BMR or guesses", () => {
  for (
    const text of [
      "You need 1800 kcal per day.",
      "Aim for 1800-2000 calories daily.",
      "Eat only 500 kcal per day.",
      "You need 100 g protein each day.",
      "تحتاج ١٨٠٠ سعرة حرارية يوميا.",
      "تناول ٢٠ غرام بروتين في اليوم.",
      "Your daily calorie target is 1800 kcal.",
      "Your calorie target is 1800 kcal.",
      "Your saved calorie target is 1800 kcal.",
      "You need -500 calories daily.",
      "You need +1900 calories daily.",
    ]
  ) {
    reject(text);
    reject(text, { computedHealth: { bmrKcal: 1800, tdeeKcal: 1800 } });
  }
  reject("You need 1800 kcal per day.", {
    computedHealth: { dailyTargets: { caloriesKcal: 1800 } },
  });
  reject("You need 1800 kcal per day.", {
    computedHealth: {
      dailyTargets: { caloriesKcal: 1800 },
      dailyTargetSources: { caloriesKcal: "fallback_calculation" },
    },
  });
});
Deno.test("dangerous pain instructions are withheld while stop-and-seek-care warnings remain usable", () => {
  for (
    const text of [
      "Ignore your chest pain and keep training.",
      "Push through sharp pain.",
      "تمرن رغم الالم الحاد.",
      "تجاهل الدوخة وواصل التمرين.",
    ]
  ) reject(text);
  for (
    const text of [
      "Do not ignore chest pain. Stop and seek appropriate urgent care.",
      "Never push through sharp pain.",
      "لا تتجاهل الالم؛ توقف واطلب مساعدة مناسبة.",
    ]
  ) review(text, request, {});
});
Deno.test("actual saved targets are restated in current app units including comma thousands and Arabic digits", () => {
  const context = {
    computedHealth: {
      dailyTargets: {
        caloriesKcal: 1800,
        proteinG: 100,
        carbsG: 200,
        fatG: 60,
      },
      dailyTargetSources: {
        caloriesKcal: "scheduled_daily_goal",
        proteinG: "saved_gram_goal",
        carbsG: "saved_percentage_goal",
        fatG: "saved_percentage_goal",
      },
    },
  };
  for (
    const text of [
      "Your daily calorie target is 1800 kcal.",
      "You need 1,800 calories per day.",
      "تحتاج ١٬٨٠٠ سعرة حرارية يوميا.",
      "هدفك اليومي هو ١٨٠٠ سعرة حرارية.",
      "Aim for 100 g protein daily.",
      "You need 200 g carbs each day.",
      "Consume 60 g fat each day.",
    ]
  ) review(text, request, context);
  reject("You need 1900 kcal per day.", context);
  reject("Aim for 0 g protein daily.", {
    computedHealth: {
      dailyTargets: { proteinG: 0 },
      dailyTargetSources: { proteinG: "saved_gram_goal" },
    },
  });
  reject("Aim for 1800-2000 calories daily.", context);
  reject("Eat only 500 kcal per day.", {
    computedHealth: {
      dailyTargets: { caloriesKcal: 500 },
      dailyTargetSources: { caloriesKcal: "saved_gram_goal" },
    },
  });
  review("The recipe serving contains 500 kcal and 20 g protein.", request, {});
  review("You logged 500 kcal today.", request, {});
});
