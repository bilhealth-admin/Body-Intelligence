import { mealVisionConsentIsCurrent } from "./consent.ts";

Deno.test("meal vision requires an explicit current consent grant", () => {
  const rejected = [
    null,
    {},
    { granted: false, policy_version: "1" },
    { granted: true, policy_version: "0" },
    { granted: true, policy_version: "2" },
  ];
  for (const consent of rejected) {
    if (mealVisionConsentIsCurrent(consent)) {
      throw new Error("stale or denied consent was accepted");
    }
  }
  if (!mealVisionConsentIsCurrent({ granted: true, policy_version: "1" })) {
    throw new Error("current explicit consent was rejected");
  }
});
