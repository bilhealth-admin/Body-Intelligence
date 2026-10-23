import { validateCoachFoodBoundaries } from "./coach_food_safety.ts";
import { validateCoachHealthBoundaries } from "./coach_health_safety.ts";
const recordAcknowledgementWords = new Set(
  "great good nice well done congrats congratulations awesome fantastic brilliant thanks thank you okay ok sure job work on for finishing completing getting doing it that this your the a workout session training today"
    .split(" "),
);
const recordAcknowledgementStarts = new Set(
  "great good nice well congrats congratulations awesome fantastic brilliant thanks thank okay ok sure"
    .split(" "),
);
const recordQuestionWords = new Set(
  "which what when how many much long did have you would like me to do want tell let know i workout workouts exercise exercises session sessions training plan plans meal meals food foods water weight protein calorie calories log logged logging record recorded save saved open opened show read review complete completed finish finished perform performed done train trained eat ate eaten drink drank drunk weigh weighed measure measured last lasted duration durations minute minutes hour hours today yesterday that this the your active current previous it was and for in at total set sets repetition repetitions rep reps اي ما ماذا كم متى هل اخبرني خبرني حدد هي هو تريد تود لي ان اريد تمرين التمرين تمرينك تمارين التمارين تمرنت جلسة الجلسة جلستك خطة الخطة خطتك وجبة الوجبة وجبات الوجبات التي الذي طعام الطعام ماء الماء وزن الوزن وزنك بروتين البروتين سعرات السعرات سجل السجل تسجيل المسجل محفوظ المحفوظ فتح افتح عرض اعرض مراجعة انهيت انهيته اكملت اكملته خلصت خلصته مارست تناولت اكلت شربت مدة المدة دقيقة دقائق ساعة ساعات كانت كان اليوم امس بالامس شو ايش شنو قديش"
    .split(" "),
);
/** Citation-free only when EVERY clause is an acknowledgement or a clear
 * record/navigation question or offer. This never authorizes an action and
 * cannot exempt an appended health recommendation or numerical health claim. */
export function isPureCoachRecordInteraction(prose: string): boolean {
  const value = prose.toLowerCase().replace(/[أإآ]/gu, "ا")
    .replace(/[\u064B-\u065F\u0670ـ]/gu, "").replace(/[*_#]/gu, "");
  const clauses = value.split(/(?<!\d)\.|\.(?!\d)|[!?؟;؛\n]/u)
    .map((part) => part.trim()).filter(Boolean);
  if (clauses.length === 0) return false;
  let hasDataFlow = false;
  return clauses.every((original) => {
    let text = original.replace(/^[-•]\s*/u, "");
    const words = text.match(/[\p{L}\p{N}]+/gu) ?? [];
    if (
      recordAcknowledgementStarts.has(words[0] ?? "") &&
      words.every((word) => recordAcknowledgementWords.has(word))
    ) return true;
    const acknowledgement =
      /^(?:(?:great|good|nice)(?:\s+(?:job|work))?(?:\s+on\s+(?:finishing|completing)\s+(?:your\s+)?(?:workout|session))?|well done|congrats|congratulations|thanks|thank you|okay|ok|sure|ممتاز|رائع|احسنت|تمام|شكرا)$/u;
    if (acknowledgement.test(text)) return true;
    text = text.replace(
      /^(?:great job|nice work|well done|thanks|okay|sure|ممتاز|رائع|احسنت|تمام|شكرا)[,،:—–]\s*/u,
      "",
    );
    text = text.replace(
      /^(?:to (?:log|record) (?:it|this|that|your workout)|before (?:i can (?:log|record) (?:it|this|that)|recording anything))[,،]\s*/u,
      "",
    );
    const offer =
      /^(?:(?:i|we) can (?:help you (?:to )?)?(?:open|show|read|review|record|log) (?:your |the |this |that )?(?:saved |active |current |completed )?(?:workout|exercise|session|training|plan|food|meal|water|weight)(?: (?:log|entry|plan|history|details))?(?: (?:for review|before saving|with your confirmation))?|(?:i|we) can (?:help you )?(?:log|record|review) (?:that|it)(?: (?:after|once|when) you confirm)?|let.s (?:get (?:it|that|your workout|your session) (?:logged|recorded)|review (?:it|that|your workout|your session))|i need (?:a bit |some |a little )?more (?:detail|details|information)(?: to (?:log|record) (?:it|that|your workout)(?: accurately)?)?|(?:يمكنني|يمكننا|استطيع|اقدر)(?: (?:مساعدتك|ان اساعدك)(?: في)?)? (?:فتح|عرض|مراجعة|قراءة|تسجيل) (?:سجل )?(?:تمرينك|التمرين|جلسة التمرين|الخطة المحفوظة|خطتك|وزنك|الوزن|الوجبة|الطعام|الماء|ذلك|هذا)(?: (?:للمراجعة|قبل الحفظ|بعد تاكيدك))?)$/u;
    if (offer.test(text)) {
      hasDataFlow = true;
      return true;
    }
    const question =
      /^(?:which\b|what\b|when\b|how (?:many|much|long)\b|did you\b|have you\b|would you like(?: me)? to\b|do you want(?: me)? to\b|tell me\b|let me know\b|اي|ما|ماذا|كم|متى|هل|اخبرني|خبرني|حدد|شو|ايش|شنو|قديش)/u
        .test(text);
    const domain =
      /\b(?:workout|exercise|session|training|plan|meal|food|water|weight|protein|calories?)\w*\b|تمرين|تمارين|تمرنت|جلس[ةه]|خط[ةه]|وجبة|وجبات|طعام|ماء|وزن|بروتين|سعرات/u
        .test(text);
    const recordTask =
      /\b(?:log|record|save|saved|open|show|read|review|complete|completed|finish|finished|did|done|last|duration|minutes?|hours?)\b|سجل|تسجيل|محفوظ|فتح|عرض|مراجعة|انهيت|اكملت|خلصت|مارست|تمرنت|تناولت|اكلت|شربت|مدة|دقيقة|ساعة/u
        .test(text);
    const normative =
      /\b(?:should|must|need|recommend|aim|try|avoid|limit|increase|reduce|healthy|healthier|risk|prevent|treat|cure|improve)\w*\b|يجب|ينبغي|ينصح|توصية|استهدف|تجنب|قلل|زد|صحي|خطر|يعالج|يمنع|يحسن/u
        .test(text.replace(/\bshould i (?:log|record|open)\b/u, ""));
    const boundedRecordVocabulary = (text.match(/[\p{L}\p{N}]+/gu) ?? [])
      .every((word) => recordQuestionWords.has(word) || /^\p{N}+$/u.test(word));
    if (
      question && domain && recordTask && !normative && boundedRecordVocabulary
    ) {
      hasDataFlow = true;
      return true;
    }
    return false;
  }) && hasDataFlow;
}
/** Bounded deterministic review. No extra provider call, context or charge. */
export function validateCoachAnswerQuality(
  answer: {
    reply: string;
    spoken_reply: string;
    proposed_actions: Array<{ type: string }>;
  },
  messages: ReadonlyArray<{ role: string; content: string }>,
  context: unknown = {},
): void {
  const normalize = (text: string) =>
    text.toLowerCase().replace(/[أإآ]/gu, "ا")
      .replace(/[\u064B-\u065F\u0670ـ]/gu, "");
  const prose = normalize(`${answer.reply}\n${answer.spoken_reply}`);
  validateCoachHealthBoundaries(prose, messages, context);
  validateCoachFoodBoundaries(prose, messages, context);
  // Provider prose cannot be a receipt: this function has no mutation tools.
  if (
    /\b(?:i|we|bil)(?:'ve| have| has)?\s+(?:successfully\s+)?(?:logged|recorded|saved|activated|deleted|updated|completed|drafted|created|initiated|prepared)\s+(?:your|the|this|that|it|a)\b|(?:^|[.!؟\n]\s*)(?:لقد\s+)?(?:سجلت|حفظت|فعلت|اكملت|حذفت|عدلت|انشات|جهزت|اعددت)\s+(?:لك|ال|وزن|وجبة|تمرين|خط|مسودة)|(?:^|[.!؟\n]\s*)تم\s+(?:تسجيل|حفظ|تفعيل|حذف|تحديث|اكمال|انشاء|اعداد)\s+(?:ال|وزن|وجبة|تمرين|خط|مسودة)/u
      .test(prose)
  ) {
    throw new Error("unverified_action_claim");
  }
  const text = normalize(messages.at(-1)?.content ?? "");
  const goalOnly = /\b(goal|target|aim)\b|هدفي|مستهدف|هدف/u.test(text) &&
    !/\b(?:log|record)\b.*\b(?:current|measured) weight\b|سجل وزني (?:الحالي|المقاس)/u
      .test(text);
  const negatedWorkout =
    /\b(?:not|didn.t|couldn.t|missed|unable)\b.*\b(?:workout|train|finish|complete)\w*|ما قدرت|ما تمرنت|ما خلصت|لم اتمرن|لم اكمل|فاتني/u
      .test(text);
  if (
    answer.proposed_actions.some((action) =>
      (action.type === "log_weight" && goalOnly) ||
      (action.type === "record_smart_plan_workout" && negatedWorkout)
    )
  ) {
    throw new Error("unsafe_action_intent");
  }
}
