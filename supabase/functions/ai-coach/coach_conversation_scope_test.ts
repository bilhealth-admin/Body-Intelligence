import {
  canProposeSmartPlanAction,
  coachTurnFocus,
  coachTurnFocusInstruction,
  filterSmartPlanActionsForTurn,
} from "./coach_conversation_scope.ts";

function assertEquals<T>(actual: T, expected: T) {
  if (actual !== expected) throw new Error("Expected " + String(expected) + ", got " + String(actual));
}

Deno.test("monthly weight table never becomes a Smart Plan request", () => {
  const messages = [{role: "user" as const, content: "أريد جدول نزولي بالوزن لشهر"}];
  assertEquals(coachTurnFocus(messages), "weight_history");
  assertEquals(canProposeSmartPlanAction(messages), false);
  assertEquals(coachTurnFocusInstruction(messages).includes("not to authoring a Smart Plan"), true);
});

Deno.test("short month and yes inherit only adjacent explicit weight analysis", () => {
  const base = [{role: "user" as const, content: "حلّل أوزاني في الشهر الماضي"}, {role: "assistant" as const, content: "أي نطاق؟"}];
  assertEquals(coachTurnFocus([...base, {role: "user", content: "شهر"}]), "weight_history");
  assertEquals(coachTurnFocus([...base, {role: "user", content: "تمام"}]), "weight_history");
});

Deno.test("an unrelated user topic clears stale plan permissions", () => {
  const messages = [
    {role: "user" as const, content: "أريد إنشاء خطة تمارين شهرية"},
    {role: "assistant" as const, content: "أي مدة؟"},
    {role: "user" as const, content: "هل يمكنك حساب الماء اليوم؟"},
    {role: "assistant" as const, content: "ما الكمية؟"},
    {role: "user" as const, content: "شهر"},
  ];
  assertEquals(coachTurnFocus(messages), "general");
  assertEquals(canProposeSmartPlanAction(messages), false);
});

Deno.test("a genuine Plan creation request retains draft capability", () => {
  const messages = [{role: "user" as const, content: "أريد إنشاء خطة تمارين وتغذية لمدة شهر"}];
  assertEquals(coachTurnFocus(messages), "smart_plan");
  assertEquals(canProposeSmartPlanAction(messages), true);
  assertEquals(coachTurnFocus([...messages, {role: "assistant", content: "موافق؟"}, {role: "user", content: "نعم"}]), "smart_plan");
});

Deno.test("a plan-denial override prevents proposal", () => {
  const messages = [
    {role: "user" as const, content: "أريد إنشاء خطة تمارين شهرية"},
    {role: "assistant" as const, content: "سأفتح المراجعة"},
    {role: "user" as const, content: "لا أريد خطة"},
  ];
  assertEquals(coachTurnFocus(messages), "plan_denial");
  assertEquals(canProposeSmartPlanAction(messages), false);
});

Deno.test("reading saved plan requires its own explicit user intent", () => {
  assertEquals(canProposeSmartPlanAction([{role: "user", content: "افتح خطتي"}]), true);
  assertEquals(canProposeSmartPlanAction([{role: "assistant", content: "Want a plan?"}, {role: "user", content: "yes"}]), false);
});

Deno.test("profile target is not a weight-history or plan command", () => {
  assertEquals(coachTurnFocus([{role:"user",content:"هدفي 70 كغ"}]), "general");
  assertEquals(coachTurnFocus([{role:"user",content:"can u talking en lang"}]), "general");
});

Deno.test("cloud drops unrequested plan proposals without blocking weight-log reads", () => {
  const actions = [{ type: "create_smart_plan_draft" }, { type: "open_weight_log" }];
  const types = new Set(["create_smart_plan_draft", "read_active_smart_plan"]);
  const context = [{ role: "user" as const, content: "أريد جدول نزولي بالوزن لشهر" }];
  assertEquals(filterSmartPlanActionsForTurn(context, actions, types).length, 1);
  assertEquals(filterSmartPlanActionsForTurn(context, actions, types)[0].type, "open_weight_log");
  assertEquals(filterSmartPlanActionsForTurn([{ role: "user", content: "أريد إنشاء خطة تمارين" }], actions, types).length, 2);
});

Deno.test("English monthly weight analysis is not program authoring", () => {
  assertEquals(coachTurnFocus([{ role: "user", content: "Show my weight progress for last month" }]), "weight_history");
  assertEquals(coachTurnFocus([{ role: "user", content: "Please create a six month training program" }]), "smart_plan");
});
