/** Review only explicit app food-selection boundaries. No diagnosis, new
 * medical target, extra context or provider request is introduced.
 * Canonical categories match DietaryPreferences and FDA's major allergens:
 * https://www.fda.gov/food/buy-store-serve-safe-food/food-allergies-what-you-need-know
 */
// JavaScript \b is ASCII-oriented. Match complete Arabic ingredient words;
// otherwise اللبن would falsely match البني and البيض would match الابيض.
const arabic = (words: string) => String.raw`(?<![\p{L}\p{N}])(?:[وف])?(?:بال|لل|ال|ب)?(?:${words})(?:ا)?(?![\p{L}\p{N}])`;
const aliases: Record<string, string> = {
  milk: String.raw`\b(?:milk|dairy|cheese|yogurt|whey)\b|` + arabic("حليب|البان|لبن(?:ة)?|جبن(?:ة)?"),
  egg: String.raw`\beggs?\b|` + arabic("بيض(?:ة|تين|تان|ات)?"),
  fish: String.raw`\b(?:fish|salmon|tuna|cod)\b|` + arabic("سمك|اسماك|سلمون|تونة"),
  shellfish: String.raw`\b(?:shellfish|shrimp|prawns?|crab|lobster)\b|` + arabic("روبيان|جمبري|قشريات"),
  peanut: String.raw`\bpeanuts?\b|` + arabic(String.raw`فول\s+(?:ال)?سوداني|فستق\s+سوداني`),
  treenut: String.raw`\b(?:almonds?|walnuts?|cashews?|pistachios?|hazelnuts?|pecans?)\b|` + arabic(String.raw`لوز|جوز|كاجو|فستق\s+حلبي|بندق`),
  wheat: String.raw`\bwheat\b|` + arabic("قمح"),
  soy: String.raw`\b(?:soy|soya|tofu)\b|` + arabic("صويا|توفو"),
  sesame: String.raw`\b(?:sesame|tahini)\b|` + arabic("سمسم|طحينة"),
};
const normalize = (s: string) => s.toLowerCase().replace(/[أإآ]/gu, "ا")
  .replace(/[\u064B-\u065F\u0670ـ]/gu, "");
const object = (v: unknown): Record<string, unknown> =>
  v !== null && typeof v === "object" && !Array.isArray(v)
    ? v as Record<string, unknown> : {};
const strings = (v: unknown): string[] => Array.isArray(v)
  ? v.filter((s): s is string => typeof s === "string" && s.length <= 80).slice(0, 20)
  : [];
const escape = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const positive = /\b(?:(?:eat|add|include|choose|recommend|suggest|serve|use)s?|tr(?:y|ies)|ha(?:ve|s)|contain(?:s|ing)?)\b|تناول|اضف|اختر|اقترح|استخدم|جرب/gu;
const negative = /(?:does not|doesn.t|do not|don.t|never)\s+contain(?:s)?|\b(?:avoid(?:s|ing)?|without|exclude(?:d|s|ing)?|free (?:of|from)|never|don.t|do not|no)\b|تجنب|بدون|دون|بلا|استبعد|تستبعد|خال(?:ي|ية|يا)?\s+(?:تماما\s+)?من|لا\s+(?:تتناول|تضف|تاكل|تستخدم|تاخذ|يحتوي|تحتوي)/gu;
const strong = /\b(?:(?:eat|add|include|choose|recommend|suggest|serve)s?|tr(?:y|ies))\b|تناول|اضف|اختر|اقترح|جرب/u;
const inspectLabel = /\b(?:check(?:ing)?|read(?:ing)?|inspect(?:ing)?|review(?:ing)?)\b[^.!?;\n]{0,45}\b(?:labels?|ingredients?|allergen statements?)\b|(?:افحص|اقرا|راجع)\s+(?:ملصق|الملصق|مكونات|المكونات|قائمة المكونات)/gu;
const foodSelection = /\b(?:eat(?:ing|s)?|add(?:ing|s)?|includ(?:e|ing|es)|choos(?:e|es|ing)|recommend(?:s|ing)?|suggest(?:s|ing)?|serv(?:e|es|ing)|us(?:e|es|ing)|tr(?:y|ies|ying)|hav(?:e|ing)|has|contain(?:s|ing)?|consum(?:e|ing|es)|drink(?:ing|s)?)\b|تناول|اضف|اختر|اقترح|استخدم|جرب|اشرب|(?:ثم|بعد ذلك)\s+كل/gu;
const lastIndex = (pattern: RegExp, text: string, end = false) => {
  let index = -1;
  for (const match of text.matchAll(pattern)) index = match.index + (end ? match[0].length : 0);
  return index;
};
// A negative/uncertain free-from claim is not an allergen exclusion. Keep this
// local to the latest recommendation, so an earlier warning does not invert a
// later clear instruction. This only reviews wording; it certifies no recipe.
const doubtfulFreeClaim = (before: string) =>
  /\b(?:not|isn.t|aren.t|wasn.t|weren.t|cannot|can.t|uncertain|unsure|no guarantee)\b/u
    .test(before.slice(Math.max(0, lastIndex(positive, before))));

export function validateCoachFoodBoundaries(
  prose: string,
  messages: ReadonlyArray<{ role: string; content: string }>,
  context: unknown,
): void {
  const profile = object(object(context).profile);
  const preferences = object(profile.dietaryPreferences);
  const excluded = new Map<string, string>();
  for (const name of strings(preferences.allergens)) {
    const key = normalize(name);
    if (aliases[key]) excluded.set(key, aliases[key]);
  }
  for (const term of strings(preferences.excludedIngredients)) {
    const clean = normalize(term).trim();
    if (clean.length >= 2) excluded.set("explicit:" + clean, escape(clean));
  }
  const requirements = strings(preferences.requirements);
  if (requirements.includes("glutenFree")) {
    excluded.set("gluten", String.raw`\b(?:wheat|barley|rye|bulgur|couscous|seitan)\b|` + arabic("قمح|شعير|برغل|كسكس"));
  }
  if (requirements.includes("lactoseFree")) excluded.set("milk", aliases.milk);
  if (requirements.includes("halal") || requirements.includes("kosher")) {
    excluded.set("pork", String.raw`\b(?:pork|bacon|ham)\b|` + arabic("خنزير"));
  }
  if (requirements.includes("halal")) {
    excluded.set("alcohol", String.raw`\b(?:alcohol|wine|beer)\b|` + arabic("كحول|خمر|نبيذ|بيرة"));
  }
  if (requirements.includes("kosher")) excluded.set("shellfish", aliases.shellfish);
  if (preferences.pattern === "vegan" || preferences.pattern === "vegetarian") {
    excluded.set("meat", String.raw`\b(?:beef|chicken|turkey|pork|bacon|lamb)\b|` + arabic(String.raw`لحم|لحوم|دجاج|ديك\s+رومي`));
    excluded.set("fish", aliases.fish);
    excluded.set("shellfish", aliases.shellfish);
    if (preferences.pattern === "vegan") {
      excluded.set("milk", aliases.milk);
      excluded.set("egg", aliases.egg);
    }
  }
  if (excluded.size === 0) return;
  const question = normalize(messages.at(-1)?.content ?? "");
  const advice = /\b(?:meal|dinner|breakfast|lunch|recipe|eat|food|snack)\b|وجب|عشاء|فطور|غداء|اكل|وصفة|غذاء|غذا/u.test(question);
  for (const clause of normalize(prose).split(/[.!?؟;\n]/u)) {
    if (!advice && !strong.test(clause)) continue;
    // Repeating a declared constraint or an observed record is not a suggestion.
    if (!strong.test(clause) && /\byou (?:ate|logged|consumed)\b|تناولت|اكلت|سجلت/u.test(clause)) continue;
    if (!strong.test(clause) && /\ballerg(?:y|ic)\b|حساسية/u.test(clause) && !/\b(?:dinner|breakfast|lunch|meal|recipe|snack)\b|عشاء|فطور|غداء|وجبة|وصفة/u.test(clause)) continue;
    for (const [kind, expression] of excluded) {
      for (const match of clause.matchAll(new RegExp(expression, "gu"))) {
        const before = clause.slice(0, match.index);
        const after = clause.slice(match.index + match[0].length);
        // Reading an ingredient/allergen label is a safety check, not a food
        // selection. This exemption ends at any later consumption/proposal
        // verb, so "check the label, then add milk" remains rejected.
        if (lastIndex(inspectLabel, before) > lastIndex(foodSelection, before)) continue;
        // A constraint label is not a recommendation: "peanut allergy, try rice".
        // The exemption is tied to this occurrence, so a later "add peanuts"
        // in the same clause is still rejected.
        const positiveAt = lastIndex(positive, before);
        const constraintAt = lastIndex(/\ballerg(?:y|ies|ic)\b|حساس(?:ية|يتك|ياتك)/gu, before);
        const followingLabel = after.slice(0, 100).search(/\b(?:allergies|intolerances|restrictions)\b/u);
        const followingAction = after.search(positive);
        const menuAt = lastIndex(/\b(?:dinner|breakfast|lunch|meal|recipe|snack)\b|عشاء|فطور|غداء|وجبة|وصفة/gu, before);
        if (constraintAt > Math.max(positiveAt, menuAt) || (menuAt < 0 && positiveAt < 0 && followingLabel >= 0 && (followingAction < 0 || followingLabel < followingAction))) continue;
        if (/^-(?:[,\s]*(?:and\s+)?[\p{L}]+-)*[,\s]*(?:and\s+)?[\p{L}]+-free\b/u.test(after) && !doubtfulFreeClaim(before)) continue;
        if (/^\s+(?:allerg(?:y|ies)|intolerance)\b/u.test(after) ||
          /(?:\ballerg(?:y|ic) to|حساسية (?:من|تجاه))\s*$/u.test(before)) continue;

        if (kind === "milk" && /\blactose[- ]free\s*$/u.test(before) && !strings(preferences.allergens).includes("milk")) continue;
        if (/^\s*[-–]?\s*free\b/u.test(after) && !doubtfulFreeClaim(before)) continue;
        // Plant-based qualifiers apply to this occurrence only; a second cow
        // milk occurrence must still be reviewed. Never exempt a nut allergy.
        if (kind === "milk" && (/\b(?:almond|soy|soya|oat|rice|coconut|plant)\s*$/u.test(before) || /^\s+(?:نباتي|اللوز|الصويا|الشوفان)/u.test(after))) continue;
        const negativeAt = lastIndex(negative, before);
        // A negated presence verb includes the whole phrase (does not
        // contain); an earlier exclusion cannot hide a later ingredient.
        const negativeEnd = lastIndex(negative, before, true);
        const reversedExclusion = /^(?:avoid|exclude)/u.test(before.slice(negativeAt)) &&
          /\b(?:not|never|don.t|doesn.t|cannot|can.t|isn.t|aren.t)\s*$/u.test(before.slice(0, negativeAt));
        if (!reversedExclusion && negativeEnd > lastIndex(positive, before) &&
          (!/^free /u.test(before.slice(negativeAt)) || !doubtfulFreeClaim(before))) continue;
        throw new Error("unsafe_dietary_advice");
      }
    }
  }
}
