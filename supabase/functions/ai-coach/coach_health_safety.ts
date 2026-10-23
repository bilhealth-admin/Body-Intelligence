/** Deterministic review of provider prose, never clinical diagnosis or a new
 * nutrient calculation. Uses only context already admitted by the client.
 * No network call, diary/memory write or additional reservation. */
const norm = (value: string) =>
  value.toLowerCase()
    .replace(/[أإآ]/gu, "ا").replace(/[\u064B-\u065F\u0670ـ]/gu, "")
    .replace(/٬/gu, ",").replace(/٫/gu, ".")
    .replace(/[٠-٩۰-۹]/gu, (digit) =>
      String(
        "٠١٢٣٤٥٦٧٨٩".includes(digit)
          ? "٠١٢٣٤٥٦٧٨٩".indexOf(digit)
          : "۰۱۲۳۴۵۶۷۸۹".indexOf(digit),
      ));
const object = (value: unknown): Record<string, unknown> =>
  value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
const fail = (): never => {
  throw new Error("unsafe_health_advice");
};
const negated = (before: string): boolean =>
  /(?:\b(?:do not|does not|doesn.t|don.t|never|shouldn.t|mustn.t|cannot|can.t)(?:\s+(?:ever|deliberately|assume|claim|say|conclude|mean))?(?:\s+that)?|لا(?:\s+(?:استطيع|يمكنني|اقدر)(?:\s+ان)?)?|لا\s+(?:يعني|تعني)(?:\s+ان)?|ليس(?:\s+هذا)?)\s*["'“]?\s*$/u
    .test(before);
const eachActive = (
  pattern: RegExp,
  text: string,
  visit: (match: RegExpMatchArray) => void,
) => {
  for (const match of text.matchAll(pattern)) {
    if (!negated(text.slice(0, match.index))) visit(match);
  }
};
const conditionGroups = [
  "diabetes|السكري|سكري|مرض السكر",
  "hypertension|ارتفاع ضغط الدم",
  "an(?:a)?emia|فقر الدم",
  "hypothyroidism|قصور الغدة الدرقية",
  "hyperthyroidism|فرط نشاط الغدة الدرقية",
  "cancer|سرطان",
  "depression|اكتئاب",
  "anxiety disorder|اضطراب قلق",
  "kidney disease|مرض الكلي",
  "insulin resistance|مقاومة الانسولين",
  "eating disorder|اضطراب اكل",
];
const conditions = conditionGroups.map((value) => "(?:" + value + ")").join(
  "|",
);
const conditionPattern = new RegExp(conditions, "u");
const clauses = (value: string) => value.split(/(?<!\d)\.|\.(?!\d)|[!?؟;\n]/u);
function explicitConditionSource(
  messages: ReadonlyArray<{ role: string; content: string }>,
  context: unknown,
  condition: string,
): boolean {
  const memory = object(context).explicitMemories;
  const texts = messages.filter((row) => row.role === "user").map((row) =>
    row.content
  );
  if (Array.isArray(memory)) {
    for (const row of memory.slice(0, 20)) {
      const item = object(row);
      if (
        item.status === "confirmed" &&
        item.source === "explicit_user_confirmation" &&
        item.deletedAt == null && (item.expiresAt == null ||
          (typeof item.expiresAt === "string" &&
            Date.parse(item.expiresAt) > Date.now())) &&
        typeof item.text === "string"
      ) texts.push(item.text);
    }
  }
  const escaped = "(?:" +
    (conditionGroups.find((group) =>
      new RegExp("^(?:" + group + ")$", "u").test(condition)
    ) ??
      condition.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")) +
    ")";
  const declaration = new RegExp(
    String
      .raw`(?:\bi (?:have|was diagnosed with)|\bmy (?:doctor|clinician) diagnosed me with|عندي|لدي|تم تشخيصي ب)\s*${escaped}`,
    "u",
  );
  return texts.some((text) => {
    const value = norm(text), match = declaration.exec(value);
    return match != null &&
      !/\b(?:if|whether|might|may|could|not|no)\b|هل|اذا|ليس|ما عندي|لو/u
        .test(value.slice(Math.max(0, match.index - 50), match.index));
  });
}
const medication = String
  .raw`(?:insulin|metformin|prednisone|prednisolone|aspirin|warfarin|antibiotics?|antidepressants?|your\s+(?:medication|medicine|dose)|(?:the\s+)?(?:medication|medicine)|الانسولين|انسولين|الميتفورمين|ميتفورمين|بريدنيزون|البريدنيزون|اسبرين|الاسبرين|المضاد الحيوي|مضاد حيوي|الدواء|دواء|جرعتك)`;
const drugInstruction = new RegExp(
  String
    .raw`(?<![\p{L}\p{N}])(?:(?:take|start|increase|decrease|reduce|stop(?:\s+taking)?|discontinue|double)\s+(?:(?:your|the)\s+)?(?:\d+(?:\.\d+)?\s*(?:mg|mcg|milligrams?|micrograms?|iu|units?)\s+(?:of\s+)?)?${medication}|(?:take|start|increase|double)\s+\d+(?:\.\d+)?\s*(?:mg|mcg|milligrams?|micrograms?|iu)\b|(?:خذ|تاخذ|تناول|تتناول|تناولي|ابدا|اوقف|توقف عن|زد|ضاعف|قلل|خفض)\s+(?:\d+(?:\.\d+)?\s*(?:ملغ|مغ|ميكروغرام|وحدة دولية)\s+(?:من\s+)?)?${medication}|(?:خذ|تناول|تناولي|ابدا|زد|ضاعف)\s+\d+(?:\.\d+)?\s*(?:ملغ|مغ|ميكروغرام|وحدة دولية))(?![\p{L}\p{N}])`,
  "gu",
);
const namedDose =
  /(?<![\p{L}\p{N}])(?:take|start|increase|double|خذ|تناول|تتناول|تناولي|زد|ضاعف)\s+(?:[\p{L}-]+\s+){1,4}\d+(?:\.\d+)?\s*(?:mg|mcg|milligrams?|micrograms?|iu|ملغ|مغ|ميكروغرام|وحدة دولية)(?![\p{L}\p{N}])/gu;
const deprivation =
  /(?<![\p{L}\p{N}])(?:starve(?: yourself)?|eat nothing|go without (?:any )?food|جوع نفسك|احرم نفسك من الطعام|امتنع عن الطعام تماما)(?![\p{L}\p{N}])/gu;
const stopEating = /\bstop eating\b/gu;
const dangerousPain =
  /(?<![\p{L}\p{N}])(?:(?:ignore|push through|train through|exercise through|work out through)\s+(?:your\s+)?(?:(?:sharp|severe)\s+)?(?:chest pain|pain|dizziness|fainting|injury|injuries)|(?:تجاهل|تتجاهل|تمرن رغم|واصل التمرين رغم|استمر رغم)\s+(?:الالم|الم|الدوخة|الاغماء|الاصابة))(?![\p{L}\p{N}])/gu;
const compensate =
  /\b(?:make up for|compensate for|punish|missed (?:your |a |the )?(?:workout|training)|missing (?:your |a |the )?(?:workout|training))\b|تعويض|تعوض|عقاب|فاتك|فاتني|فو?تت التمرين|تفويت/u;
const compensatoryAction =
  /(?<![\p{L}\p{N}])(?:(?:skip|miss|cut|remove|sacrifice)\s+(?:(?:your|the|a|next)\s+){0,2}(?:meal|dinner|lunch|breakfast|food)|(?:eat|consume)\s+(?:less|nothing)|(?:double|triple)\s+(?:your\s+)?(?:next\s+)?(?:workout|training|exercise)|train\s+(?:twice|three times)\s+(?:as long|as hard)|تخط(?:ى|ي)?\s+(?:وجبة\s+)?(?:العشاء|الغداء|الفطور|الطعام)|قلل\s+(?:اكلك|طعامك|وجباتك)|ضاعف\s+(?:تمرينك|التدريب|التمرين))(?![\p{L}\p{N}])/gu;
const quantity = String
  .raw`[+-]?(?:\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:[.,]\d+)?)`;
const number = "(" + quantity + ")(?:\\s*[-–]\\s*(" + quantity + "))?";
const nutrient = String
  .raw`(kcal|calories?|g\s+(?:of\s+)?protein|grams?\s+(?:of\s+)?protein|g\s+(?:of\s+)?carbs?|grams?\s+(?:of\s+)?carbohydrates?|g\s+(?:of\s+)?fat|grams?\s+(?:of\s+)?fat|سعرة(?:\s+حرارية)?|سعرات(?:\s+حرارية)?|(?:غرام|جرام|غ)\s+(?:من\s+)?(?:البروتين|بروتين|الكربوهيدرات|كربوهيدرات|الدهون|دهون))`;
const personalTarget = new RegExp(
  String
    .raw`(?<![\p{L}\p{N}])(?:you\s+(?:need|should eat|should consume|must eat)|aim for|eat|consume|stick to|your\s+(?:(?:saved|daily)\s+){0,2}(?:calorie|protein|carbohydrate|fat)\s+target\s+(?:is|should be)|احتياجك(?:\s+اليومي)?(?:\s+هو)?|تحتاج(?:ين)?(?:\s+الى)?|تناول(?:ي)?|استهدف|هدفك(?:\s+اليومي)?(?:\s+هو)?)\s+(?:(?:about|approximately|only|just|حوالي|فقط)\s+)?${number}\s*${nutrient}(?![\p{L}\p{N}])`,
  "gu",
);
const daily =
  /\b(?:daily|each day|every day|per day|a day)\b|\/\s*day\b|يوميا|كل يوم|في اليوم|باليوم/u;
function validatePersonalTargets(text: string, context: unknown): void {
  const health = object(object(context).computedHealth);
  const targets = object(health.dailyTargets),
    sources = object(health.dailyTargetSources);
  for (const clause of clauses(text)) {
    eachActive(personalTarget, clause, (match) => {
      if (
        !daily.test(clause) &&
        !/^(?:you need|your\b|احتياجك|تحتاج|هدفك)/u.test(match[0])
      ) return;
      const unit = match[3];
      const key = /kcal|calor|سعر/u.test(unit)
        ? "caloriesKcal"
        : /protein|بروتين/u.test(unit)
        ? "proteinG"
        : /carb|كربوهيدرات/u.test(unit)
        ? "carbsG"
        : "fatG";
      const raw = match[1];
      const value = Number(
        /^[+-]?\d{1,3}(?:,\d{3})+(?:\.\d+)?$/u.test(raw)
          ? raw.replaceAll(",", "")
          : raw.replace(",", "."),
      );
      const saved = targets[key], source = sources[key];
      // Same product review gate as BilPlanSafetyAssessment, not a claim
      // that every intake above this floor is suitable for this member.
      if (
        value <= 0 || (key === "caloriesKcal" && value < 1200) ||
        match[2] != null || typeof saved !== "number" ||
        !Number.isFinite(saved) ||
        Math.abs(saved - value) > .5 || typeof source !== "string" ||
        source.trim() === "" || source === "fallback_calculation"
      ) fail();
    });
  }
}
export function validateCoachHealthBoundaries(
  prose: string,
  messages: ReadonlyArray<{ role: string; content: string }>,
  context: unknown = {},
): void {
  const text = norm(prose);
  const diagnosis = new RegExp(
    String
      .raw`(?<![\p{L}\p{N}])(?:i (?:diagnose|have diagnosed|diagnosed) you|my diagnosis(?: for you)? is|that is my diagnosis|you (?:(?:definitely|certainly|clearly) )?(?:have|are suffering from|are diagnosed with)\s+(?:${conditions})|(?:انت\s+(?:بالتاكيد\s+)?مصاب(?:ة)?|اشخصك|تشخيصي لك|تم تشخيصك)|(?:عندك|لديك)\s+(?:مرض\s+)?(?:${conditions}))(?![\p{L}\p{N}])`,
    "gu",
  );
  for (const clause of clauses(text)) {
    eachActive(diagnosis, clause, (match) => {
      if (
        /\bi (?:diagnose|have diagnosed|diagnosed) you|\bmy diagnosis|that is my diagnosis|اشخصك|تشخيصي لك/u
          .test(match[0])
      ) fail();
      const condition = conditionPattern.exec(match[0])?.[0];
      const reporting =
        /\b(?:as you (?:said|reported|shared)|you told me)\b|حسب ما (?:ذكرت|سجلت)|كما (?:ذكرت|سجلت|اخبرتني)/u
          .test(clause.slice(0, match.index));
      if (
        !condition || !reporting ||
        !explicitConditionSource(messages, context, condition)
      ) fail();
    });
    eachActive(drugInstruction, clause, fail);
    eachActive(namedDose, clause, fail);
    eachActive(deprivation, clause, fail);
    eachActive(dangerousPain, clause, fail);
    eachActive(stopEating, clause, (match) => {
      const after = clause.slice(match.index! + match[0].length);
      // Do not mistake an explicitly timed routine for indefinite starvation.
      if (
        !/^\s+(?:at|from|during|until|after)\s+(?:(?:0?[1-9]|1[0-2])(?::[0-5]\d)?\s*(?:am|pm)\b|(?:[01]?\d|2[0-3]):[0-5]\d\b|the saved (?:start|end) time)/u
          .test(after)
      ) fail();
    });
    if (compensate.test(clause)) eachActive(compensatoryAction, clause, fail);
  }
  validatePersonalTargets(text, context);
}
