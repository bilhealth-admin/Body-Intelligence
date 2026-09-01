import { createClient } from "npm:@supabase/supabase-js@2.112.3";

const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers":
    "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "content-type": "application/json",
      "cache-control": "no-store",
    },
  });

const env = (name: string) => {
  try {
    return Deno.env.get(name)?.trim() ?? "";
  } catch {
    return "";
  }
};

function clients(authorization: string) {
  const url = env("SUPABASE_URL");
  const anon = env("SUPABASE_ANON_KEY");
  const service = env("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anon || !service) throw new Error("server_not_configured");
  return {
    auth: createClient(url, anon, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false },
    }),
    admin: createClient(url, service, { auth: { persistSession: false } }),
  };
}

export type GlobalResetHandlerDependencies = {
  clients?: typeof clients;
};

const validIdempotencyKey = (value: string) =>
  value.length >= 16 &&
  value.length <= 128 &&
  /^[A-Za-z0-9:_-]+$/.test(value);

const validEmail = (value: string) =>
  value.length >= 3 &&
  value.length <= 254 &&
  /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);

const notificationKinds = new Set(["compensation", "gift", "custom"]);
const notificationAudiences = new Set(["all", "email"]);
const characterLength = (value: string) => Array.from(value).length;

const containsControlCharacter = (value: string) => {
  for (const character of value) {
    const codePoint = character.codePointAt(0) ?? 0;
    if (codePoint <= 0x1f || codePoint === 0x7f) return true;
  }
  return false;
};

const deniedByDatabase = (message: unknown) =>
  String(message ?? "").includes("ai_coach_admin_required");

async function consumeRateLimit(
  auth: ReturnType<typeof clients>["auth"],
  action: string,
  limit: number,
) {
  const result = await auth.rpc("bil_consume_rate_limit", {
    p_action: action,
    p_limit: limit,
    p_window_seconds: 3600,
  });
  if (!result.error) return null;
  return String(result.error.message ?? "").toLowerCase().includes(
      "rate limit exceeded",
    )
    ? json({ error: "rate_limited" }, 429)
    : json({ error: "rate_limit_unavailable" }, 503);
}

async function resetWithConcurrencyRetry(
  admin: ReturnType<typeof clients>["admin"],
  functionName: string,
  args: Record<string, unknown>,
) {
  let result = await admin.rpc(functionName, args);
  const retryable = () =>
    ["55P03", "40P01", "40001"].includes(
      String(result.error?.code ?? "").toUpperCase(),
    );

  // The SQL transaction uses fail-fast NOWAIT locks and is fully rolled back
  // on contention. Retry at most twice (three total attempts), with the exact
  // same idempotency key/arguments and a short bounded backoff. The rate-limit
  // charge remains outside this loop.
  for (let retry = 0; retry < 2 && retryable(); retry += 1) {
    await new Promise((resolve) => setTimeout(resolve, 25 * (retry + 1)));
    result = await admin.rpc(functionName, args);
  }
  return result;
}

export async function handler(
  request: Request,
  dependencies: GlobalResetHandlerDependencies = {},
): Promise<Response> {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  try {
    const authorization = request.headers.get("authorization") ?? "";
    if (!authorization) return json({ error: "authentication_required" }, 401);

    const createClients = dependencies.clients ?? clients;
    const c = createClients(authorization);
    const authResult = await c.auth.auth.getUser();
    if (authResult.error || !authResult.data.user) {
      return json({ error: "invalid_session" }, 401);
    }

    // Probe authority before parsing or validating operation input. An
    // authenticated ordinary account therefore sees the same hidden 404 for
    // every payload and cannot discover this administration endpoint.
    const permission = await c.auth.rpc("bil_can_manage_ai_coach");
    if (permission.error) {
      return json({ error: "admin_permission_unavailable" }, 503);
    }
    if (permission.data !== true) {
      return json({ error: "not_found" }, 404);
    }

    let body: Record<string, unknown>;
    try {
      body = await request.json() as Record<string, unknown>;
    } catch {
      return json({ error: "invalid_request" }, 400);
    }
    const operation = String(body.operation ?? "global").trim();
    const idempotencyKey = String(body.idempotency_key ?? "").trim();
    if (!validIdempotencyKey(idempotencyKey)) {
      return json({ error: "invalid_idempotency_key" }, 400);
    }

    if (operation === "global") {
      const rateResponse = await consumeRateLimit(
        c.auth,
        "admin_ai_coach_global_reset",
        3,
      );
      if (rateResponse != null) return rateResponse;

      const reset = await resetWithConcurrencyRetry(
        c.admin,
        "bil_global_reset_ai_coach",
        {
          p_actor_id: authResult.data.user.id,
          p_idempotency_key: idempotencyKey,
        },
      );
      if (reset.error) {
        const denied = deniedByDatabase(reset.error.message);
        return json(
          { error: denied ? "not_found" : "reset_failed" },
          denied ? 404 : 500,
        );
      }
      return json(reset.data);
    }

    if (operation === "individual") {
      const normalizedEmail = String(body.email ?? "").trim().toLowerCase();
      const reason = String(body.reason ?? "").trim();
      if (!validEmail(normalizedEmail)) {
        return json({ error: "invalid_target" }, 400);
      }
      if (
        reason.length > 160 ||
        reason.length === 1 ||
        containsControlCharacter(reason)
      ) {
        return json({ error: "invalid_reason" }, 400);
      }

      const rateResponse = await consumeRateLimit(
        c.auth,
        "admin_ai_coach_individual_reset",
        20,
      );
      if (rateResponse != null) return rateResponse;

      // auth.users resolution is performed only through this service-role
      // client. Its UUID never crosses the Edge Function response boundary.
      const resolved = await c.admin.rpc("bil_resolve_ai_coach_reset_target", {
        p_actor_id: authResult.data.user.id,
        p_normalized_email: normalizedEmail,
      });
      if (resolved.error) {
        const denied = deniedByDatabase(resolved.error.message);
        return json(
          { error: denied ? "not_found" : "reset_failed" },
          denied ? 404 : 500,
        );
      }

      const targetId = typeof resolved.data === "string" ? resolved.data : null;
      if (targetId == null || targetId.length === 0) {
        return json({ matched: false });
      }

      const reset = await resetWithConcurrencyRetry(
        c.admin,
        "bil_individual_reset_ai_coach",
        {
          p_actor_id: authResult.data.user.id,
          p_target_id: targetId,
          p_reason: reason.length === 0 ? null : reason,
          p_idempotency_key: idempotencyKey,
        },
      );
      if (reset.error) {
        const denied = deniedByDatabase(reset.error.message);
        return json(
          { error: denied ? "not_found" : "reset_failed" },
          denied ? 404 : 500,
        );
      }

      // An authorized administrator learns only whether the submitted address
      // matched. UUIDs, reset ids, PII, and affected-row counts stay private.
      return json({ matched: true });
    }

    if (operation === "notification") {
      if (
        typeof body.notification_kind !== "string" ||
        typeof body.audience !== "string"
      ) {
        return json({ error: "invalid_notification_request" }, 400);
      }
      const notificationKind = body.notification_kind.trim().toLowerCase();
      const audience = body.audience.trim().toLowerCase();
      const normalizedEmail = typeof body.email === "string"
        ? body.email.trim().toLowerCase()
        : "";
      const message = typeof body.message === "string"
        ? body.message.trim()
        : "";

      if (!notificationKinds.has(notificationKind)) {
        return json({ error: "invalid_notification_kind" }, 400);
      }
      if (!notificationAudiences.has(audience)) {
        return json({ error: "invalid_notification_audience" }, 400);
      }
      if (
        body.message != null &&
        (typeof body.message !== "string" ||
          (message.length > 0 &&
            (characterLength(message) > 180 ||
              containsControlCharacter(message))))
      ) {
        return json({ error: "invalid_notification_message" }, 400);
      }
      if (notificationKind === "custom" && message.length < 1) {
        return json({ error: "invalid_notification_message" }, 400);
      }
      if (
        audience === "email"
          ? typeof body.email !== "string" || !validEmail(normalizedEmail)
          : body.email != null &&
            (typeof body.email !== "string" || normalizedEmail.length !== 0)
      ) {
        return json({ error: "invalid_target" }, 400);
      }

      const rateResponse = await consumeRateLimit(
        c.auth,
        audience === "all"
          ? "admin_notification_all"
          : "admin_notification_individual",
        audience === "all" ? 10 : 50,
      );
      if (rateResponse != null) return rateResponse;

      let targetId: string | null = null;
      if (audience === "email") {
        const resolved = await c.admin.rpc(
          "bil_resolve_admin_notification_target",
          {
            p_actor_id: authResult.data.user.id,
            p_normalized_email: normalizedEmail,
          },
        );
        if (resolved.error) {
          const denied = deniedByDatabase(resolved.error.message);
          return json(
            { error: denied ? "not_found" : "notification_failed" },
            denied ? 404 : 500,
          );
        }
        targetId = typeof resolved.data === "string" ? resolved.data : null;
        if (targetId == null || targetId.length === 0) {
          return json({
            matched: false,
            duplicate: false,
            recipients_enqueued: 0,
          });
        }
      }

      const authoredPreset = notificationKind !== "custom" &&
        message.length > 0;
      const enqueued = await resetWithConcurrencyRetry(
        c.admin,
        authoredPreset
          ? "bil_enqueue_admin_notification_with_message"
          : "bil_enqueue_admin_notification",
        authoredPreset
          ? {
            p_actor_id: authResult.data.user.id,
            p_notification_kind: notificationKind,
            p_audience: audience,
            p_target_id: targetId,
            p_message: message,
            p_idempotency_key: idempotencyKey,
          }
          : {
            p_actor_id: authResult.data.user.id,
            p_notification_kind: notificationKind,
            p_audience: audience,
            p_target_id: targetId,
            p_custom_body: notificationKind === "custom" ? message : null,
            p_idempotency_key: idempotencyKey,
          },
      );
      if (enqueued.error) {
        const denied = deniedByDatabase(enqueued.error.message);
        return json(
          { error: denied ? "not_found" : "notification_failed" },
          denied ? 404 : 500,
        );
      }

      const data = enqueued.data != null &&
          typeof enqueued.data === "object"
        ? enqueued.data as Record<string, unknown>
        : {};
      return json({
        matched: true,
        duplicate: data.duplicate === true,
        recipients_enqueued: typeof data.recipients_enqueued === "number"
          ? Math.max(0, Math.trunc(data.recipients_enqueued))
          : 0,
      });
    }

    return json({ error: "invalid_operation" }, 400);
  } catch {
    return json({ error: "reset_failed" }, 500);
  }
}
