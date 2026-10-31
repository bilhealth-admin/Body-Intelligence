/** Request-local missingness. No database reads, new permissions, or model call.
 * Build40 sends partial, question-scoped snapshots. Empty arrays can mean a
 * withheld category or a failed read; neither establishes an empty diary. */
type Value = Record<string, unknown>;
const record = (raw: unknown): Value =>
  raw !== null && typeof raw === "object" && !Array.isArray(raw)
    ? raw as Value
    : {};

const categoryNames = [
  "nutrition_water",
  "training_activity",
  "sleep_habits",
  "weight_measurements_goal",
] as const;
type Category = typeof categoryNames[number];

/** Disclosure is descriptive only: it cannot authorize a read or supply data.
 * Only fixed category names and actual, allow-listed field names survive. */
export function coachRecordCoverage(context: unknown, disclosure: unknown) {
  const data = record(context);
  const raw = record(disclosure);
  const declared = raw.schema === "bil.coach-context-disclosure.v1" &&
      Array.isArray(raw.categories) &&
      raw.categories.every((name) => categoryNames.includes(name as Category))
    ? new Set(raw.categories as Category[])
    : null;
  const today = record(record(data.computedHealth).today);
  const activity = Array.isArray(data.activityHistory)
    ? data.activityHistory
    : [];
  const nonempty = (raw: unknown) =>
    Array.isArray(raw) ? raw.length > 0 : Object.keys(record(raw)).length > 0;
  const present: Record<Category, boolean> = {
    nutrition_water: nonempty(data.nutritionHistory) ||
      nonempty(data.waterHistory) ||
      nonempty(today.nutrition),
    training_activity: nonempty(today.exerciseEnergy) ||
      activity.some((row) =>
        "steps" in record(row) || "exercise" in record(row)
      ),
    sleep_habits: nonempty(today.sleep) || nonempty(today.fasting) ||
      nonempty(data.bodyContextHistory) ||
      activity.some((row) => "sleepHours" in record(row)),
    weight_measurements_goal: nonempty(data.weight),
  };
  return Object.fromEntries(categoryNames.map((category) => [
    category,
    declared !== null && !declared.has(category)
      ? "not_in_request"
      : present[category]
      ? "partial_context_present"
      : "not_verified",
  ]));
}

function normalize(value: string) {
  return value.normalize("NFKC").toLowerCase().replace(/[أإآٱ]/gu, "ا")
    .replace(/[\u064B-\u065F\u0670ـ]/gu, "").replace(/[’‘]/gu, "'");
}

/** Detect assertions about recorded entries, not a missed session, a missing
 * goal, a rest day, or an explicitly conditional suggestion. */
export function unsupportedRecordAbsenceCategories(
  prose: string,
  literalUserReport = "",
): Category[] {
  const found = new Set<Category>();
  for (
    const original of normalize(prose).split(
      /\bbut\b|\bhowever\b|ولكن|لكن|[.!?؟;؛\n]/u,
    )
  ) {
    // A literal, explicitly attributed user report preserves the exact topic
    // and date. Category equivalence is insufficient (meals are not water).
    const attribution =
      /^\s*(?:you (?:said|reported|told me)|ذكرت|قلت|اخبرتني)\s*:\s*/u;
    if (
      literalUserReport && attribution.test(original) &&
      original.replace(attribution, "").trim().replace(
          /^["'“”]+|["'“”]+$/gu,
          "",
        ) === literalUserReport
    ) continue;
    // A coordinated conditional antecedent is still conditional. "but" was
    // already split above, so an assertion after it is checked separately.
    if (/^\s*(?:if\b|unless\b|when\b|(?:اذا|لو)(?:\s|$))/u.test(original)) {
      continue;
    }
    // Qualifiers apply to their own proposition, not every assertion in a
    // compound sentence. Keep a topic list ("no meals, water, or workouts
    // recorded") together, while separating a new subject/negative clause.
    const clauses = original.split(
      /(?:,\s*(?:and\s+)?|\s+and\s+)(?=(?:your|you|there|that|this|no|missing|if|unless|when)\b)|(?:،\s*و?|\s+و)(?=(?:سجل|لا|لم|اذا|لو|ليس|عدم|بيانات)(?:\s|$))/u,
    );
    for (const part of clauses) {
      const clause = part.replace(
        /\b(?:(?:not|never|isn't|wasn't|aren't|weren't)\s+(?:(?:currently|actually)\s+)?empty|non[- ]empty)\b/gu,
        "",
      ).replace(/\bno need\b/gu, "")
        .replace(/(?:ليس[ت]?|غير|لم يكن|لم تكن)\s+(?:فارغ|خالي)[اةه]?/gu, "");
      if (
        /\b(?:does not mean|doesn't mean|not proof|not evidence)\b|لا يعني|ليس دليلا/u
          .test(clause) ||
        /^\s*(?:if\b|unless\b|when\b|(?:اذا|لو)(?:\s|$))/u.test(clause)
      ) continue;
      if (
        /\bno\s+(?:recorded\s+)?(?:meal|nutrition|water|workout|training|sleep)\s+(?:goal|target|plan|schedule)\b/u
          .test(clause) ||
        /^\s*(?:لا\s*(?:يوجد|توجد)|ليس\s*(?:لديك|لدي))\s*(?:هدف|خطة|جدول)(?:\s|$)/u
          .test(clause)
      ) continue;
      const recorded =
        /\b(?:record\w*|log\w*|diar(?:y|ies)|entr(?:y|ies)|tracked|saved)\b|سجل|مسجل|تسجيل|بيانات|مدخلات/u
          .test(clause);
      const absent =
        /\b(?:no|zero|empty)\b|\b(?:haven't|hasn't|have not|has not|did not|didn't)\b.{0,35}\b(?:record(?:ed)?|log(?:ged)?|tracked|saved)\b|لا\s*(?:يوجد|توجد|تتوفر|يتوفر)|ليس\s*(?:لديك|لدي)|ما\s*(?:في|عندك|عندي)|لم\s*(?:تسجل|اسجل|يسجل|يتم تسجيل)|فارغ|خالي|غير موجود/u
          .test(clause);
      if (!recorded || !absent) continue;
      if (
        /\b(?:meals?|foods?|nutrition)\b|وجبة|وجبات|طعام|تغذية|غذاء/u.test(
          clause,
        )
      ) found.add("nutrition_water");
      if (/\b(?:water|hydration|drinks?)\b|ماء|مياه|ميه|شرب/u.test(clause)) {
        found.add("nutrition_water");
      }
      if (/\b(?:sleep|slept)\b|نوم|نمت/u.test(clause)) {
        found.add("sleep_habits");
      }
      if (
        /\b(?:workouts?|exercises?|training|activity)\b|تمرين|تمارين|تدريب|نشاط/u
          .test(clause)
      ) found.add("training_activity");
    }
  }
  return [...found];
}

/** Discard the rejected prose and proposals, just like the existing weight
 * truth correction. No current client contract supplies a verified empty
 * nutrition/water/training/sleep read receipt, so zero must not be invented. */
export function correctCoachRecordAbsence(
  answer: { reply: string; spoken_reply: string },
  locale: string,
  latestUserText = "",
) {
  // An explicitly attributed repetition of a first-person user report is not
  // an independent diary audit. Context/assistant instructions cannot grant it.
  const ownReport =
    /^(?:i\s+(?:have\s+no|(?:have\s+not|haven't|did\s+not|didn't)\s+(?:record(?:ed)?|log(?:ged)?|track(?:ed)?|save(?:d)?))\b|لم\s+اسجل|ما\s+سجلت|ليس\s+لدي|ما\s*عندي)/u
        .test(normalize(latestUserText).trim())
      ? normalize(latestUserText).trim().replace(/[.!?؟]+$/u, "")
      : "";
  const categories = unsupportedRecordAbsenceCategories(
    `${answer.reply}\n${answer.spoken_reply}`,
    ownReport,
  );
  if (categories.length === 0) return null;
  const arabic = locale.split("-")[0] === "ar" ||
    (locale === "auto" &&
      /[\u0600-\u06ff]/u.test(`${answer.reply} ${answer.spoken_reply}`));
  const reply = arabic
    ? "لم يتم التحقق من أن هذه السجلات فارغة في هذا الطلب. البيانات غير المشاركة أو غير المتاحة لا تعني عدم وجود سجلات. يمكنك مراجعة السجل المحفوظ داخل BIL."
    : "An empty diary was not verified for this request. Missing or unshared data does not mean that records are absent. You can review your saved history in BIL.";
  return {
    reply,
    spoken_reply: reply,
    reason: arabic
      ? "تصحيح ادعاء غياب السجلات دون قراءة بيانات إضافية أو تغييرها."
      : "Corrected an unsupported absence claim without reading or changing any records.",
    confidence: 1,
    evidence: [],
    citations: [],
    requires_health_citation: false,
    missing_data: categories.map((category) => `verified_${category}_records`),
    proposed_actions: [],
  };
}
