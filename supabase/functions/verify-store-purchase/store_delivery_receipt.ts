// Opt-in v2 only: older mobile clients retain their exact response shape.
// Inputs come from authenticated store verification and committed RPC results.
export async function deliveryReceipt(input: {
  ownerId: string;
  store: "app_store" | "google_play";
  environment: "sandbox" | "production";
  transactionId: string;
  productId: string;
  verifiedAt: string;
  kind: "subscription" | "boost";
  active: boolean;
  quantity?: number;
  creditedNow?: boolean;
  finishPending?: boolean;
}) {
  if (
    !input.ownerId || !input.transactionId || !input.productId ||
    !Number.isFinite(Date.parse(input.verifiedAt)) ||
    (input.kind === "boost" && input.active &&
      (!Number.isSafeInteger(input.quantity) || (input.quantity ?? 0) <= 0))
  ) {
    throw new Error("delivery_receipt_unavailable");
  }
  const bytes = new TextEncoder().encode(JSON.stringify([
    input.ownerId,
    input.store,
    input.environment,
    input.transactionId,
  ]));
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  const eventKey = Array.from(
    new Uint8Array(digest),
    (v) => v.toString(16).padStart(2, "0"),
  ).join("");
  return {
    version: 2,
    owner_id: input.ownerId,
    store: input.store,
    environment: input.environment,
    event_key: eventKey,
    product_id: input.productId,
    verified_at: input.verifiedAt,
    kind: input.kind,
    active: input.active,
    ...(input.kind === "boost"
      ? {
        quantity: input.active ? input.quantity : 0,
        credited_now: input.creditedNow === true,
      }
      : {}),
    finish_pending: input.finishPending === true,
  };
}

export function boostCreditOutcome(result: unknown) {
  if (!result || typeof result !== "object") {
    throw new Error("delivery_receipt_unavailable");
  }
  const row = result as Record<string, unknown>;
  if (row.refunded === true) {
    return { active: false, quantity: 0, credited: false };
  }
  // A duplicate canonical purchase still proves its original grant; use the
  // RPC policy quantity, never a difference between changing balances.
  const quantity = row.credited === true
    ? row.tokens_granted
    : row.tokens_per_boost;
  if (
    typeof row.credited !== "boolean" || !Number.isSafeInteger(quantity) ||
    (quantity as number) <= 0
  ) throw new Error("delivery_receipt_unavailable");
  return { active: true, quantity: quantity as number, credited: row.credited };
}
