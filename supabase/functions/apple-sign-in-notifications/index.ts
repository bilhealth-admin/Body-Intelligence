import { createClient } from "npm:@supabase/supabase-js@2.112.3";

import {
  type AppleTokenRpcClient,
  applyAppleAccountEvent,
  loadAppleClientId,
  verifyAppleNotification,
} from "../_shared/apple_sign_in_token_lifecycle.ts";

function json(body: Record<string, unknown>, status = 200) {
  return Response.json(body, {
    status,
    headers: { "cache-control": "no-store" },
  });
}

function responseForError(error: unknown) {
  const code = error instanceof Error ? error.message : "";
  const name = error instanceof Error ? error.name : "";
  if (
    code === "invalid_apple_notification" ||
    code === "invalid_apple_notification_events"
  ) {
    return json({ error: "invalid_notification" }, 400);
  }
  if (code.startsWith("apple_configuration_")) {
    return json({ error: "apple_sign_in_not_configured" }, 503);
  }
  if (
    name.startsWith("JWS") || name.startsWith("JWT") ||
    code.toLowerCase().includes("jws") ||
    code.toLowerCase().includes("jwt") ||
    code.includes("signature") || code.includes("claim") ||
    code === "JWTExpired"
  ) {
    return json({ error: "invalid_notification" }, 401);
  }
  return json({ error: "notification_processing_failed" }, 503);
}

export async function handleAppleSignInNotification(request: Request) {
  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return json({ error: "cloud_not_configured" }, 503);

  try {
    const body = await request.json();
    if (!body || typeof body !== "object" || Array.isArray(body)) {
      throw new Error("invalid_apple_notification");
    }
    const signedPayload = typeof (body as Record<string, unknown>).payload ===
        "string"
      ? ((body as Record<string, unknown>).payload as string).trim()
      : "";
    if (signedPayload.length < 32 || signedPayload.length > 32768) {
      throw new Error("invalid_apple_notification");
    }

    const event = await verifyAppleNotification(
      signedPayload,
      loadAppleClientId(),
    );
    const admin = createClient(url, key, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    await applyAppleAccountEvent(
      admin as unknown as AppleTokenRpcClient,
      event,
    );
    // Do not disclose whether Apple's subject maps to an account.
    return json({ accepted: true });
  } catch (error) {
    return responseForError(error);
  }
}

if (import.meta.main) Deno.serve(handleAppleSignInNotification);
