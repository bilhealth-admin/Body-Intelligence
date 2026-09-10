import { createClient } from "npm:@supabase/supabase-js@2.112.3";
import { timingSafeEqual } from "node:crypto";

export type PushDispatchDependencies = {
  env?: (name: string) => string | undefined;
  client?: typeof createClient;
  fetch?: typeof fetch;
};

async function secretMatches(provided: string, expected: string) {
  const encoder = new TextEncoder();
  const [left, right] = await Promise.all([
    crypto.subtle.digest("SHA-256", encoder.encode(provided)),
    crypto.subtle.digest("SHA-256", encoder.encode(expected)),
  ]);
  return timingSafeEqual(new Uint8Array(left), new Uint8Array(right));
}

const reply = (status: number, body: unknown) =>
  Response.json(body, { status });
const safeVisibleCopyKeys = new Set([
  "admin_notification_compensation_v1",
  "admin_notification_gift_v1",
]);
const providerTimeoutMs = 10_000;

type ClaimedDelivery = {
  device_token_id: string;
  provider_token: string;
  platform: string;
  sensitive_preview_allowed: boolean;
  delivery_key: string;
};

// A gateway status alone is not authoritative: a bad endpoint can return 404.
// Token deactivation therefore requires both a recognized terminal status and
// the explicit contract header from the trusted APNs/FCM gateway.
const isPermanentInvalidToken = (response: Response): boolean =>
  !response.ok &&
  [400, 404, 410].includes(response.status) &&
  response.headers.get("x-bil-token-status")?.trim().toLowerCase() ===
    "invalid";

const boundedDeepLink = (value: unknown): string | null =>
  typeof value === "string" && value.length <= 512 && value.startsWith("bil://")
    ? value
    : null;

const secureGateway = (value: string | undefined): string | null => {
  if (!value) return null;
  try {
    const parsed = new URL(value);
    return parsed.protocol === "https:" ? parsed.toString() : null;
  } catch {
    return null;
  }
};

export async function handler(
  request: Request,
  dependencies: PushDispatchDependencies = {},
): Promise<Response> {
  const readEnv = dependencies.env ?? ((name: string) => Deno.env.get(name));
  const runtimeFetch = dependencies.fetch ?? fetch;
  if (request.method !== "POST") {
    return reply(405, { error: "method_not_allowed" });
  }

  // Fail closed when the server secret itself is absent. Comparing two nulls
  // would otherwise authorize a request that omitted the header as well.
  const dispatchSecret = readEnv("BIL_INTERNAL_DISPATCH_SECRET");
  if (!dispatchSecret) {
    return reply(503, { error: "cloud_not_configured" });
  }
  if (
    !await secretMatches(
      request.headers.get("x-bil-dispatch-secret") ?? "",
      dispatchSecret,
    )
  ) {
    return reply(401, { error: "unauthorized" });
  }

  const url = readEnv("SUPABASE_URL");
  const key = readEnv("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return reply(503, { error: "cloud_not_configured" });

  const client = (dependencies.client ?? createClient)(url, key, {
    auth: { persistSession: false },
  });
  const { data: events, error } = await client.from("bil_push_outbox").select(
    "*",
  ).is("dispatched_at", null).order("created_at").limit(100);
  if (error) return reply(500, { error: "outbox_read_failed" });

  let delivered = 0;
  let failed = 0;
  for (const rawEvent of events ?? []) {
    const event = {
      ...rawEvent,
      deep_link: boundedDeepLink(rawEvent.deep_link),
    };
    // The database atomically leases only the still-undelivered device rows.
    // This makes concurrent invocations safe and avoids replaying successful
    // devices after another device in the same account fails.
    const { data: claimed, error: claimError } = await client.rpc(
      "bil_claim_push_deliveries",
      { p_outbox_id: event.id, p_lease_seconds: 60 },
    );
    if (claimError) {
      failed += 1;
      continue;
    }

    // Start every bounded claim promptly so no row waits behind another
    // device's network timeout and outlives its lease.
    await Promise.all(
      ((claimed ?? []) as ClaimedDelivery[]).map(async (token) => {
        const provider = token.platform === "apns"
          ? {
            gateway: secureGateway(readEnv("BIL_APNS_GATEWAY_URL")),
            secret: readEnv("BIL_APNS_GATEWAY_SECRET"),
          }
          : token.platform === "fcm"
          ? {
            gateway: secureGateway(readEnv("BIL_FCM_GATEWAY_URL")),
            secret: readEnv("BIL_FCM_GATEWAY_SECRET"),
          }
          : null;

        let accepted = false;
        let failureCode: string | null = null;
        let permanentTokenFailure = false;
        if (!provider?.gateway || !provider.secret) {
          failureCode = provider
            ? "provider_not_configured"
            : "unsupported_provider";
        } else {
          const showFullBody = safeVisibleCopyKeys.has(event.copy_key) ||
            token.sensitive_preview_allowed;
          const controller = new AbortController();
          const timeout = setTimeout(
            () => controller.abort(),
            providerTimeoutMs,
          );
          try {
            const response = await runtimeFetch(provider.gateway, {
              method: "POST",
              redirect: "error",
              signal: controller.signal,
              headers: {
                authorization: `Bearer ${provider.secret}`,
                "content-type": "application/json",
                // Gateways must use this stable key for provider-side
                // idempotency. It covers the crash window after acceptance but
                // before the result can be committed to the delivery ledger.
                "idempotency-key": token.delivery_key,
              },
              body: JSON.stringify({
                token: token.provider_token,
                title: event.title ?? "BIL",
                body: showFullBody
                  ? event.body
                  : "You have a new private update.",
                deep_link: event.deep_link,
                idempotency_key: token.delivery_key,
                data: {
                  deep_link: event.deep_link,
                  category: event.category,
                  outbox_id: event.id,
                },
              }),
            });
            accepted = response.ok;
            if (!accepted) {
              failureCode = `provider_${response.status}`;
              permanentTokenFailure = isPermanentInvalidToken(response);
            }
          } catch (error) {
            failureCode =
              error instanceof DOMException && error.name === "AbortError"
                ? "gateway_timeout"
                : "gateway_network_error";
          } finally {
            clearTimeout(timeout);
          }
        }

        const { error: resultError } = await client.rpc(
          "bil_record_push_delivery_result",
          {
            p_outbox_id: event.id,
            p_device_token_id: token.device_token_id,
            p_delivered: accepted,
            p_failure_code: failureCode,
            p_permanent_token_failure: permanentTokenFailure,
          },
        );
        if (resultError) {
          // The lease expires and the exact same idempotency key is used on the
          // retry, so an uncertain database write cannot duplicate a delivery.
          failed += 1;
        } else if (accepted) {
          delivered += 1;
        } else {
          failed += 1;
        }
      }),
    );

    const { error: finalizeError } = await client.rpc(
      "bil_finalize_push_outbox",
      { p_outbox_id: event.id },
    );
    if (finalizeError) failed += 1;
  }

  return reply(200, {
    processed: events?.length ?? 0,
    delivered,
    failed,
  });
}
