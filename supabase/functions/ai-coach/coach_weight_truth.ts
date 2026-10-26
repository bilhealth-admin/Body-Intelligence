/** Read-only post-model correction. No database, network, logging or billing.
 * Only the already authorized request context is examined. A profile weight,
 * a goal, a sampled history or a missing read status never establishes zero.
 */
type RecordValue = Record<string, unknown>;

function record(value: unknown): RecordValue {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as RecordValue
    : {};
}

function normalize(value: string): string {
  return value.normalize("NFKC").toLowerCase().replace(/[أإآٱ]/gu, "ا")
    .replace(/[\u064B-\u065F\u0670ـ]/gu, "").replace(/[’‘]/gu, "'");
}

/** Whole-diary absence claims, not a statement about one missing date. */
export function claimsNoWeightRecords(prose: string): boolean {
  return normalize(prose).split(/[.!?؟;؛\n]/u).some((clause) => {
    if (
      /\b(?:yesterday|on monday|on tuesday|on wednesday|on thursday|on friday|on saturday|on sunday|for that date|for this date)\b|بالامس|بتاريخ|لهذا اليوم|في ذلك اليوم/u
        .test(clause)
    ) {
      return false;
    }
    const weight = /\b(?:weights?|weigh[- ]?ins?)\b|وزن|اوزان/u;
    if (!weight.test(clause)) return false;
    if (
      /\bno\s+(?:recorded\s+)?weight\s+(?:loss|gain|change|target|goal)\b|(?:لا يوجد|لا توجد|ليس هناك).{0,15}(?:نزول|تغير|تغيير|زيادة|نقصان).{0,15}وزن/u
        .test(clause)
    ) return false;
    return /\b(?:no|zero|0)\s+(?:(?:saved|recorded|logged|previous|past|verified|available|existing|any)\s+)*(?:weights?(?:\s+(?:history|records?|data|measurements?|entries|logs?))?|weigh[- ]?ins?)\b/u
      .test(clause) ||
      /\b(?:have|has|haven't|hasn't|don't have|do not have|does not have|doesn't have)\s+(?:not\s+)?(?:any\s+)?(?:recorded|logged|saved)\s+(?:any\s+)?(?:your\s+)?weight\b/u
          .test(clause) &&
        /\b(?:not|haven't|hasn't|don't|doesn't)\b/u.test(clause) ||
      /\bweight\s+(?:history|log|diary|records?)\s+(?:is|are|remains?)\s+(?:currently\s+)?empty\b/u
        .test(clause) ||
      /\b(?:do not|don't|cannot|can't)\s+(?:have|find|see|access)\s+(?:any\s+)?(?:your\s+)?(?:recorded\s+|saved\s+)?weight\s+(?:records?|history|data|entries|measurements?)\b/u
        .test(clause) ||
      /\b(?:you|we|i)\s+(?:have|has)\s+(?:no|zero)\s+(?:recorded\s+)?(?:weigh[- ]?ins?|weight\s+records?)\b/u
        .test(clause) ||
      /(?:لا\s+(?:يوجد|توجد|تتوفر|يتوفر|لدي|لديك)|ليس\s+(?:لدي|لديك)|ما\s*(?:في|عندي|عندك)).{0,90}(?:قياس|سجل|بيانات|اوزان)/u
        .test(clause) ||
      /لم\s+(?:تسجل|يسجل|يتم تسجيل|اجد|اعثر على).{0,70}(?:وزن|اوزان)/u.test(
        clause,
      ) ||
      /(?:سجل|سجلات|بيانات|تاريخ).{0,30}(?:وزن|اوزان).{0,30}(?:فارغ|خالي|غير موجود)/u
        .test(clause);
  });
}

export function correctWeightRecordAbsence(
  answer: { reply: string; spoken_reply: string },
  context: unknown,
  locale: string,
) {
  if (!claimsNoWeightRecords(`${answer.reply}\n${answer.spoken_reply}`)) {
    return null;
  }
  const language = locale === "auto"
    ? (/[\u0600-\u06ff]/u.test(`${answer.reply} ${answer.spoken_reply}`)
      ? "ar"
      : "en")
    : locale.split("-")[0];
  if (language !== "ar" && language !== "en") return null;
  const weight = record(record(context).weight);
  const summary = record(weight.summary);
  const rawCount = summary.recordCount;
  const count =
    typeof rawCount === "number" && Number.isSafeInteger(rawCount) &&
      rawCount >= 0
      ? rawCount
      : null;
  const explicitStatus = weight.readStatus;
  // Positive legacy summaries remain usable. Legacy zero was also emitted
  // after failed reads, so only a new explicit verified status proves zero.
  const known = explicitStatus === "verified" ||
    (explicitStatus === undefined && count !== null && count > 0);
  if (known && count === 0) return null;
  const positive = known && count !== null && count > 0;
  const withheld = explicitStatus === "withheld" || explicitStatus === "denied";
  const reply = language === "ar"
    ? positive
      ? `الملخص المصرّح به يتضمن ${count} من قياسات الوزن المسجلة. هذا عدد السجل الكامل، وليس عدد أيام الفترة المطلوبة. لا يمكن افتراض قياسات للأيام غير المسجلة.`
      : withheld
      ? "سجل الوزن غير مشارك مع المدرب في هذا الطلب. هذا لا يعني عدم وجود قياسات. يمكنك مراجعة السجل داخل التطبيق."
      : "تعذّر التحقق من سجل الوزن في هذا الطلب. هذا لا يعني عدم وجود قياسات. أعد محاولة قراءة السجل داخل التطبيق."
    : positive
    ? `The authorized summary contains ${count} recorded weigh-ins across the full history, not necessarily the requested period. Missing dates are not assumed to contain measurements.`
    : withheld
    ? "Weight history is not shared with Coach in this request. This does not mean there are no records. You can review the history in the app."
    : "Weight history could not be verified for this request. This does not mean there are no records. Retry reading the history in the app.";
  return {
    reply,
    spoken_reply: reply,
    reason: language === "ar"
      ? "تصحيح ادعاء غياب البيانات باستخدام السياق المصرّح به فقط؛ لم يتغير أي سجل."
      : "Corrected an absence claim using only the authorized context; no records were changed.",
    confidence: 1,
    evidence: positive ? ["weight.summary.recordCount"] : [],
    citations: [],
    requires_health_citation: false,
    missing_data: positive ? [] : ["verified_weight_history"],
    proposed_actions: [],
  };
}
