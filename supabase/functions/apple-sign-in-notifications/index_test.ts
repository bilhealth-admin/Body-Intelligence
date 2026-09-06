import { assertEquals } from "jsr:@std/assert@1";

import { handleAppleSignInNotification } from "./index.ts";

Deno.test("malformed signed payload fails closed without being treated as an outage", async () => {
  const previousUrl = Deno.env.get("SUPABASE_URL");
  const previousRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const previousClientId = Deno.env.get("BIL_APPLE_SIGN_IN_CLIENT_ID");
  try {
    Deno.env.set("SUPABASE_URL", "https://example.supabase.co");
    Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "test-service-role-key");
    Deno.env.set(
      "BIL_APPLE_SIGN_IN_CLIENT_ID",
      "com.bilhealth.bodyintelligencelog",
    );

    const response = await handleAppleSignInNotification(
      new Request("https://example.com/apple-sign-in-notifications", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ payload: "a".repeat(40) }),
      }),
    );

    assertEquals(response.status, 401);
    assertEquals(await response.json(), { error: "invalid_notification" });
  } finally {
    restoreEnvironment("SUPABASE_URL", previousUrl);
    restoreEnvironment("SUPABASE_SERVICE_ROLE_KEY", previousRoleKey);
    restoreEnvironment("BIL_APPLE_SIGN_IN_CLIENT_ID", previousClientId);
  }
});

function restoreEnvironment(name: string, value: string | undefined) {
  if (value === undefined) {
    Deno.env.delete(name);
  } else {
    Deno.env.set(name, value);
  }
}
