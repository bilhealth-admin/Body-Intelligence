import { coachTurnFocus } from "./coach_conversation_scope.ts";
import type { CoachTurn } from "./coach_conversation_scope.ts";

export type CoachThinkingLevel = "LOW" | "MEDIUM" | "HIGH";

/** Routing metadata only. This never grants a tool permission or a write. */
export function coachReasoningFor(
  messages: ReadonlyArray<CoachTurn>,
): { level: CoachThinkingLevel; task: "read" | "analysis" | "planning" } {
  const normalize = (value: string) =>
    value.toLowerCase()
      .replace(/[أإآٱ]/gu, "ا").replace(/[\u064B-\u065F\u0670ـ]/gu, "")
      .replace(/\s+/gu, " ").trim();
  const latest = normalize(messages.at(-1)?.content ?? "");
  // Reading a month of weight records is analysis, not plan authoring.
  if (coachTurnFocus(messages) === "weight_history") {
    return { level: "MEDIUM", task: "analysis" };
  }
  // A short slot reply inherits only the nearest explicit USER task. An
  // assistant offer or injected context must never increase data authority.
  let text = latest;
  if (
    /^(?:yes|ok|okay|please|week|month|[1-6]|نعم|اه|ايوه|تمام|شهر|اسبوع|٣|٦)$/u
      .test(latest)
  ) {
    const prior = messages.slice(0, -1).reverse().find((m) =>
      m.role === "user"
    );
    if (prior) text = `${normalize(prior.content)} ${latest}`;
  }
  const plan =
    /\b(?:plans?|program(?:me)?|routine|schedule)\b|خط[ةه]|خطتي|برنامج|جدول/u
      .test(text);
  const creation =
    /\b(?:need|want|create|make|build|design|prepare|change|adjust|revise|adapt|replace|reschedule)\b|بدي|ابغ[ىي]|ابي|عا[يو]ز|احتاج|اريد|اعمل|سو[يّ]|جهز|انش[ئء]|غير|بدل|عدل|سافر|مسافر/u
      .test(text);
  const readOnly = /\b(?:what|show|read|open|view)\b|شو|ايش|ما هو|اعرض|افتح/u
    .test(text);
  if (
    (plan && creation) ||
    /\b(?:reschedule|adapt|revise)\b.*\b(?:workout|training|week)\b|(?:غير|بدل|عدل).*(?:تمرين|الاسبوع)/u
      .test(text)
  ) {
    return { level: "HIGH", task: "planning" };
  }
  if (
    /\b(?:analy[sz]e|compare|progress|trend|why|fatigue|missed|injur|allerg|symptom|calorie|macro|protein)\w*|تقدم|حلل|قارن|تعب|اصاب[ةه]|حساسي[ةه]|اعراض|سعر|بروتين|ما قدرت|ما تمرنت|فاتني/u
      .test(text) ||
    (plan && !readOnly) || text.length > 160
  ) {
    return { level: "MEDIUM", task: "analysis" };
  }
  return { level: "LOW", task: "read" };
}

/** Google documents these aliases as routing to the same underlying model. */
export function canonicalGeminiModel(model: string): string {
  const name = model.trim().replace(/^models\//u, "").toLowerCase();
  if (name === "gemini-3.7-flash") return "gemini-3.8-flash";
  if (name === "gemini-3.5-flash") return "gemini-3.6-flash";
  return name;
}

export function independentGeminiFallback(
  primary: string,
  configured?: string,
): string {
  const canonical = canonicalGeminiModel(primary);
  const candidate = configured?.trim();
  if (candidate && canonicalGeminiModel(candidate) !== canonical) {
    return candidate;
  }
  return canonical === "gemini-3.6-flash"
    ? "gemini-3.5-flash-lite"
    : "gemini-3.6-flash";
}
