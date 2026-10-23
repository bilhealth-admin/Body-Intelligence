import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { verifiedWeightProposalCopy } from "./coach_verified_weight_proposal.ts";

const action = { type: "log_weight", arguments: { weightKg: 60 }, requires_confirmation: true };
Deno.test("only exact matching current observed-weight commands receive app confirmation copy", () => {
  for (const [text, language] of [["Log my weight as 60 kg.", "auto"], ["Log my weight as 60 kg.", "en"], ["Please, record my weight at 60 kg", "en"], ["سجل وزني ٦٠ كغ", "ar"]]) {
    const copy = verifiedWeightProposalCopy([{ role: "user", content: text }], [action], language);
    assertEquals(copy !== null, true);
    assertEquals(copy!.reply.includes("60"), true);
  }
  for (const text of ["My goal is 60 kg.", "Don't log my weight as 60 kg.", "Log my weight as 60 kg yesterday", "If I say log my weight as 60 kg", "Log my weight as 61 kg."]) {
    assertEquals(verifiedWeightProposalCopy([{ role: "user", content: text }], [action], "en"), null);
  }
});
Deno.test("confirmation-copy recovery cannot change value, date, owner, language or write admission", () => {
  const messages = [{ role: "user", content: "Log my weight as 60 kg." }];
  for (const argumentsValue of [{ weightKg: 61 }, { weightKg: "60" }, { weightKg: 60, date: "2026-10-23" }, { weightKg: 60, ownerId: "foreign" }]) {
    assertEquals(verifiedWeightProposalCopy(messages, [{ ...action, arguments: argumentsValue }], "en"), null);
  }
  assertEquals(verifiedWeightProposalCopy(messages, [{ ...action, requires_confirmation: false }], "en"), null);
  assertEquals(verifiedWeightProposalCopy(messages, [], "en"), null);
  assertEquals(verifiedWeightProposalCopy(messages, [action], "fr"), null);
  assertEquals(verifiedWeightProposalCopy([{ role: "assistant", content: messages[0].content }], [action], "en"), null);
});
