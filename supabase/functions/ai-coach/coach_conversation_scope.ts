/**
 * Cloud-side, bounded conversational intent hint and action gate.
 * Only the member's messages authorize Smart Plan tools; suggestions by an
 * assistant, context records and short bare time units never authorize writes.
 * This does not read user data or change the app's local intent router.
 */
export type CoachTurn = { role: "user" | "assistant"; content: string };
export type CoachTurnFocus = "weight_history" | "smart_plan" | "plan_denial" | "general";

function normalize(text: string): string {
  return text.toLowerCase().replace(/[أإآٱ]/gu, "ا")
    .replace(/[\u064B-\u065F\u0670ـ]/gu, "")
    .replace(/\s+/gu, " ").trim();
}

const planNoun = /\b(?:plans?|program(?:me)?|routines?)\b|خط[ةه]|خطتي|برنامج|جدول\s+(?:تمارين|تغذي[ةه]|رياضي)/u;
const planAction = /\b(?:create|make|build|design|prepare|draft|revise|adjust|change|edit|open|show|review|read|want|need)\b|(?:بدي|اريد|ابغ[ىي]|ابي|احتاج|اعمل|انش[ئء]|صمم|جهز|اقترح|غير|عدل|افتح|اعرض|راجع)/u;
const planDenial = /\b(?:do not|don't|dont|no|not|without|instead of)\b.{0,40}\b(?:plan|program|routine)\b|(?:لا|مش|مو|بدون)\s*(?:اريد|ابغ[ىي]|ابي|بدي|احتاج)?\s*(?:خط[ةه]|برنامج|جدول\s+تمارين)/u;
const weightSubject = /\b(?:weight|weigh(?:t|[- ]?in)?|weigh-ins?|scale)\b|وزن|اوزان|اوزاني|نزول|نزل|قياس(?:ات)?\s+(?:الوزن|جسمي)/u;
const historyTask = /\b(?:history|log|chart|table|trend|progress|timeline|graph|last|past|month|week|year|analy[sz]e|compare|show|review|read|plot)\b|سجل|جدول|تاريخ|رسم|مخطط|منحنى|خلال|اخر|شهر|اسبوع|سنه|سن[ةه]|حلل|تحليل|قارن|اعرض|اطلع|راجع|السابقة|الفترة/u;
const shortFollowup = /^(?:yes|sure|ok(?:ay)?|month|week|year|show|open|review|نعم|ايوا|ايوه|اه|تمام|اوكي|شهر|اسبوع|اسبوعين|سنه|سنة|اطلع|اعرض|افتح|راجع|ارني|وريني|٣|٦|30|٣٠)$/u;

function explicitFocus(text: string): CoachTurnFocus {
  if (planDenial.test(text)) return "plan_denial";
  // An explicit Plan authoring or reading request takes precedence over a
  // weight goal mentioned as incidental context: "create a weight-loss plan".
  if (planNoun.test(text) && planAction.test(text)) return "smart_plan";
  if (weightSubject.test(text) && historyTask.test(text)) return "weight_history";
  return "general";
}

/** Resolve only the immediately preceding user's request for short followups. */
export function coachTurnFocus(messages: ReadonlyArray<CoachTurn>): CoachTurnFocus {
  const turns = messages.filter((turn) => turn.role === "user");
  const latest = normalize(turns.at(-1)?.content ?? "");
  if (!latest) return "general";
  const current = explicitFocus(latest);
  if (current !== "general") return current;
  if (!shortFollowup.test(latest)) return "general";
  const precedingUser = normalize(turns.at(-2)?.content ?? "");
  const previous = explicitFocus(precedingUser);
  // A previous assistant offer is not a new instruction. The member must have
  // requested the same scope, and unrelated intervening user turns reset it.
  return previous === "smart_plan" || previous === "weight_history"
    ? previous
    : "general";
}

/** Smart Plan tools require a current, direct or adjacent user Plan request. */
export function canProposeSmartPlanAction(messages: ReadonlyArray<CoachTurn>): boolean {
  return coachTurnFocus(messages) === "smart_plan";
}

/** Safe fixed prompt text: no raw user phrases or private data are embedded. */
export function coachTurnFocusInstruction(messages: ReadonlyArray<CoachTurn>): string {
  switch (coachTurnFocus(messages)) {
    case "weight_history":
      return "Current member intent: inspect, chart, summarize or compare verified weight records. A weight table, a month, and short followups refer to the weight-record task, not to authoring a Smart Plan. Answer the weight question in chat when verified context is supplied; do not switch to a workout or nutrition plan, advertise Smart Plans, or propose Smart Plan tools. Use weight.summary when present; missing periods are unknown rather than zero. If records are unavailable or incomplete, state that they cannot be verified in this request, never assert that records do not exist.";
    case "smart_plan":
      return "Current member intent explicitly concerns an existing or requested Smart Plan. Read or propose only the Plan action that matches their exact request and capability; a draft or revision requires native human review and is never proof of saving or activation.";
    case "plan_denial":
      return "The member expressly rejected planning. Acknowledge the correction, respond to their actual request if clear, and never propose or promote Smart Plan actions in this turn.";
    default:
      return "Answer the member's actual current question. Do not introduce or promote Smart Plans or propose Smart Plan actions without an explicit member request to read or create one. A generic helpful next step is not permission to steer the conversation into planning.";
  }
}

/** Drop unrequested Smart Plan proposals, preserving unrelated safe actions. */
export function filterSmartPlanActionsForTurn<T extends { type: string }>(
  messages: ReadonlyArray<CoachTurn>,
  actions: ReadonlyArray<T>,
  smartActionTypes: ReadonlySet<string>,
): T[] {
  if (canProposeSmartPlanAction(messages)) return [...actions];
  return actions.filter((action) => !smartActionTypes.has(action.type));
}
