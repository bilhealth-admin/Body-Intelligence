/** An app-owned clarification, never a workout, medical answer or receipt.
 * The entire rejected provider answer is discarded. Only a closed, current
 * completion utterance qualifies; extra health/goal/injection text does not.
 */
export function verifiedWorkoutReviewCopy(
  messages: ReadonlyArray<{ role: string; content: string }>,
  context: unknown,
  locale: string,
  smartPlanToolsVersion: number,
) {
  const last = messages.at(-1);
  if (last?.role !== "user") return null;
  const text = last.content.normalize("NFKC").trim().toLowerCase()
    .replace(/[أإآ]/gu, "ا").replace(/[\u064B-\u065F\u0670ـ]/gu, "")
    .replace(/\s+/gu, " ");
  const english =
    /^(?:(?:i(?: have|['’]ve)? (?:finished|completed)|i['’]m done with|done with|finished|completed) (?:my |the )?(?:workout|training session|exercise session)|workout done)(?: today)?[.!]?$/u
      .test(text);
  const arabic =
    /^(?:(?:انا )?(?:خلصت|انهيت|اكملت|اتممت) (?:تمريني|التمرين|تمرين|جلسة التمرين)|تمرنت)(?: اليوم)?[.!؟]?$/u
      .test(text);
  if (!english && !arabic) return null;
  const language = locale === "auto"
    ? (arabic ? "ar" : "en")
    : locale.split("-")[0];
  if (language !== "ar" && language !== "en") return null;
  const row = context && typeof context === "object" && !Array.isArray(context)
    ? context as Record<string, unknown>
    : {};
  const plan = row.smartPlan;
  const knownPlan = plan && typeof plan === "object" && !Array.isArray(plan) &&
    typeof (plan as Record<string, unknown>).planId === "string" &&
    Number.isInteger((plan as Record<string, unknown>).revision);
  const nativeReview = !!knownPlan && smartPlanToolsVersion === 1;
  const reply = language === "ar"
    ? nativeReview
      ? "يمكنني فتح خطتك للمراجعة."
      : knownPlan
      ? "كم كانت مدة التمرين الذي أنهيت؟"
      : "أي تمرين أكملت؟ كم كانت مدة التمرين الذي أنهيت؟"
    : nativeReview
    ? "I can open your plan for review."
    : knownPlan
    ? "How many minutes did you exercise?"
    : "Which workout was it and how long did it last?";
  return {
    reply,
    spoken_reply: reply,
    reason: language === "ar"
      ? "تحتاج مراجعة النشاط وتأكيده داخل التطبيق. لم يُسجّل تمرين بعد."
      : "The activity still needs review and confirmation in the app. No workout has been recorded.",
    confidence: 1,
    evidence: [],
    citations: [],
    requires_health_citation: false,
    missing_data: knownPlan
      ? ["actual_duration", "workout_confirmation"]
      : ["workout_identity", "actual_duration"],
    proposed_actions: nativeReview
      ? [{
        type: "read_active_smart_plan",
        arguments_json: "{}",
        requires_confirmation: true,
      }]
      : [],
  };
}
