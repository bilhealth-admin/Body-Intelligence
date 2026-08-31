import { createClient } from "npm:@supabase/supabase-js@2.112.3";

const reply = (status: number, body: unknown) =>
  Response.json(body, { status });
const safeVisibleCopyKeys = new Set([
  "admin_notification_compensation_v1",
  "admin_notification_gift_v1",
]);
Deno.serve(async (request) => {
  if (
    request.headers.get("x-bil-dispatch-secret") !==
      Deno.env.get("BIL_INTERNAL_DISPATCH_SECRET")
  ) return reply(401, { error: "unauthorized" });
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return reply(503, { error: "cloud_not_configured" });
  const client = createClient(url, key, { auth: { persistSession: false } });
  const { data: events, error } = await client.from("bil_push_outbox").select(
    "*",
  ).is("dispatched_at", null).order("created_at").limit(100);
  if (error) return reply(500, { error: "outbox_read_failed" });
  let delivered = 0;
  for (const event of events ?? []) {
    const { data: tokens } = await client.from("bil_push_device_tokens").select(
      "token_ciphertext,platform,sensitive_preview_allowed",
    ).eq("user_id", event.recipient_id).eq("enabled", true);
    let failure: string | null = null;
    for (const token of tokens ?? []) {
      const gateway = Deno.env.get(
        token.platform === "apns"
          ? "BIL_APNS_GATEWAY_URL"
          : "BIL_FCM_GATEWAY_URL",
      );
      const secret = Deno.env.get(
        token.platform === "apns"
          ? "BIL_APNS_GATEWAY_SECRET"
          : "BIL_FCM_GATEWAY_SECRET",
      );
      if (!gateway || !secret) {
        failure = "provider_not_configured";
        continue;
      }
      const showFullBody = event.category === "ai_coach" ||
        safeVisibleCopyKeys.has(event.copy_key) ||
        token.sensitive_preview_allowed;
      const response = await fetch(gateway, {
        method: "POST",
        headers: {
          authorization: `Bearer ${secret}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          token: token.token_ciphertext,
          title: event.title ?? "BIL",
          body: showFullBody ? event.body : "You have a new private update.",
          deep_link: event.deep_link,
          data: { category: event.category, outbox_id: event.id },
        }),
      });
      if (response.ok) delivered += 1;
      else failure = `provider_${response.status}`;
    }
    await client.from("bil_push_outbox").update({
      dispatched_at: failure ? null : new Date().toISOString(),
      failure_code: failure,
    }).eq("id", event.id);
  }
  return reply(200, { processed: events?.length ?? 0, delivered });
});
