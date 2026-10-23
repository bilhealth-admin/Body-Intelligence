import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { decodeCoachToolArguments } from "./coach_tool_arguments.ts";

Deno.test("provider JSON arguments preserve real numeric plan and nested food values", () => {
  for (
    const args of [{ weightKg: 60 }, { targetWeightKg: 60 }, {
      horizon: "threeMonths",
      focus: "combined",
    }, {
      portions: [{ foodId: "source-food", quantityGrams: 150 }],
      mealType: "lunch",
    }]
  ) {
    assertEquals(
      decodeCoachToolArguments({ arguments_json: JSON.stringify(args) }),
      args,
    );
    assertEquals(decodeCoachToolArguments({ arguments: args }), args);
  }
});
Deno.test("malformed ambiguous oversized and prototype arguments fail closed", () => {
  for (
    const item of [
      { arguments_json: "null" },
      { arguments_json: "[]" },
      { arguments_json: "60" },
      { arguments_json: "not json" },
      { arguments_json: "x".repeat(2001) },
      { arguments_json: '{"__proto__":{"admin":true}}' },
      { arguments_json: '{"weightKg":60}', arguments: { weightKg: 80 } },
    ]
  ) {
    assertThrows(
      () => decodeCoachToolArguments(item),
      Error,
      "malformed_action_arguments",
    );
  }
});
