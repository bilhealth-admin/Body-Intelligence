import type { SupabaseClient } from "npm:@supabase/supabase-js@2.112.3";

export function subscriptionRpcRequest(
  body: Record<string, unknown>,
  actorId: string,
): { name: string; args: Record<string, unknown> } {
  const operation = body.operation;
  if (operation === "subscription_list") {
    const offset = body.offset ?? 0;
    if (
      !Number.isInteger(offset) || Number(offset) < 0 ||
      Number(offset) > 1000000
    ) {
      throw new Error("invalid_subscription_request");
    }
    return {
      name: "bil_list_admin_subscriptions",
      args: { p_actor_id: actorId, p_offset: offset },
    };
  }
  const args: Record<string, unknown> = {
    p_actor_id: actorId,
    p_idempotency_key: body.idempotency_key,
  };
  if (operation === "subscription_grant") {
    const email = typeof body.email === "string"
      ? body.email.trim().toLowerCase()
      : "";
    const reason = typeof body.reason === "string" ? body.reason.trim() : "";
    const duration = body.duration_days ?? null;
    if (
      email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ||
      !["premium", "premium_ai_coach"].includes(String(body.plan_id)) ||
      (duration !== null && ![30, 90, 365].includes(duration as number)) ||
      Array.from(reason).length > 160 ||
      Array.from(reason).some((character) => {
        const code = character.charCodeAt(0);
        return code < 32 || code === 127;
      })
    ) {
      throw new Error("invalid_subscription_request");
    }
    Object.assign(args, {
      p_operation: "grant",
      p_email: email,
      p_plan_id: body.plan_id,
      p_duration_days: duration,
      p_reason: reason,
    });
  } else if (
    operation === "subscription_revoke" && typeof body.grant_id === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(body.grant_id)
  ) {
    Object.assign(args, { p_operation: "revoke", p_grant_id: body.grant_id });
  } else {
    throw new Error("invalid_subscription_request");
  }
  return { name: "bil_manage_admin_subscription", args };
}

export async function handleSubscriptionOperation(
  body: Record<string, unknown>,
  actorId: string,
  admin: SupabaseClient,
  respond: (body: unknown, status?: number) => Response,
): Promise<Response> {
  let rpc: ReturnType<typeof subscriptionRpcRequest>;
  try {
    rpc = subscriptionRpcRequest(body, actorId);
  } catch {
    return respond({ error: "invalid_subscription_request" }, 400);
  }
  const result = await admin.rpc(rpc.name, rpc.args);
  if (result.error) {
    const message = String(result.error.message ?? "");
    if (message.includes("administrator_required")) {
      return respond({ error: "not_found" }, 404);
    }
    if (message.includes("existing_admin_subscription")) {
      return respond({ error: "existing_admin_subscription" }, 409);
    }
    if (message.includes("idempotency_conflict")) {
      return respond({ error: "idempotency_conflict" }, 409);
    }
    return respond({ error: "subscription_admin_unavailable" }, 503);
  }
  try {
    return respond(safeSubscriptionResponse(body.operation, result.data));
  } catch {
    return respond({ error: "subscription_admin_unavailable" }, 503);
  }
}

/** Explicit projection: never return an unexpected auth/receipt/audit field. */
export function safeSubscriptionResponse(operation: unknown, value: unknown) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("invalid_response");
  }
  const data = value as Record<string, unknown>;
  if (operation === "subscription_list") {
    if (
      !Array.isArray(data.rows) || data.rows.length > 50 ||
      typeof data.has_more !== "boolean"
    ) throw new Error("invalid_response");
    return {
      has_more: data.has_more,
      rows: data.rows.map((candidate) => {
        if (
          !candidate || typeof candidate !== "object" ||
          Array.isArray(candidate)
        ) throw new Error("invalid_response");
        const row = candidate as Record<string, unknown>;
        if (
          typeof row.id !== "string" || typeof row.email !== "string" ||
          !["premium", "premium_ai_coach"].includes(String(row.plan_id)) ||
          !["active", "expired", "revoked"].includes(String(row.status)) ||
          typeof row.created_at !== "string" ||
          (row.expires_at !== null && typeof row.expires_at !== "string")
        ) throw new Error("invalid_response");
        return {
          id: row.id,
          email: row.email,
          plan_id: row.plan_id,
          status: row.status,
          created_at: row.created_at,
          expires_at: row.expires_at,
        };
      }),
    };
  }
  if (
    typeof data.matched !== "boolean" || typeof data.changed !== "boolean" ||
    (!data.matched && data.changed) ||
    (data.grant_id !== null && typeof data.grant_id !== "string")
  ) throw new Error("invalid_response");
  return {
    matched: data.matched,
    changed: data.changed,
    grant_id: data.grant_id,
  };
}
