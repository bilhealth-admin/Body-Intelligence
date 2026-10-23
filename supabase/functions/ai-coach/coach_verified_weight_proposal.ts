/** App-owned confirmation copy, never a measurement or execution receipt.
 * Only an exact current AR/EN command and an identical validated proposal
 * qualify. Other false execution claims remain rejected and refunded.
 */
export function verifiedWeightProposalCopy(
  messages: ReadonlyArray<{ role: string; content: string }>,
  actions: ReadonlyArray<{ type: string; arguments: Record<string, unknown>; requires_confirmation: boolean }>,
  locale: string,
): { reply: string; spoken_reply: string; reason: string } | null {
  if (actions.length !== 1) return null;
  const action = actions[0];
  if (action.type !== "log_weight" || action.requires_confirmation !== true ||
    Object.keys(action.arguments).length !== 1) return null;
  const measured = action.arguments.weightKg;
  if (typeof measured !== "number" || !Number.isFinite(measured) || measured < 20 || measured > 500) return null;
  const last = messages.at(-1);
  if (last?.role !== "user") return null;
  const digits = "٠١٢٣٤٥٦٧٨٩";
  const text = last.content.trim().toLowerCase()
    .replace(/[أإآ]/gu, "ا").replace(/[\u064B-\u065F\u0670ـ]/gu, "")
    .replace(/[٠-٩]/gu, (digit) => String(digits.indexOf(digit)))
    .replace(/٫/gu, ".");
  const match = text.match(/^(?:please[, ]+)?(?:log|record) my weight (?:as |at )?(\d{2,3}(?:[.,]\d{1,2})?)\s*(?:kg|kilograms?)?[.!]?$/u) ??
    text.match(/^(?:من فضلك\s+)?سجل وزني\s+(\d{2,3}(?:[.,]\d{1,2})?)\s*(?:كغ|كيلو|كيلوغرام)?[.!؟]?$/u);
  if (!match || Number(match[1].replace(",", ".")) !== measured) return null;
  const language = locale === "auto" ? (/^.*(?:log|record) my weight/u.test(text) ? "en" : "ar") : locale.split("-")[0];
  if (language === "ar") {
    const reply = `راجع الوزن ${measured} كغ واكّد تسجيله. لم يُضف إلى السجل بعد.`;
    return { reply, spoken_reply: reply, reason: "القيمة مطابقة لأمرك الصريح وتنتظر تأكيدك داخل التطبيق." };
  }
  if (language !== "en") return null;
  const reply = `Review ${measured} kg and confirm to log it. It has not been added to your records yet.`;
  return { reply, spoken_reply: reply, reason: "The value matches your explicit command and awaits confirmation in the app." };
}
