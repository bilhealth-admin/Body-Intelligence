import type { VerifiedApplePurchaseIdentity } from "./apple_purchase_reconciliation.ts";

type NotificationPurchase = VerifiedApplePurchaseIdentity & {
  lifecycle: string;
  signedAt?: string;
};

/** Reject a lagging canonical snapshot instead of acknowledging away a refund.
 * Both inputs are verified Apple JWS payloads, never HTTP request properties.
 * A later transaction in the same chain is authoritative over an older notice.
 */
export function assertAppleNotificationFreshness(
  notificationType: string,
  notice: NotificationPurchase,
  canonical: NotificationPurchase,
): void {
  if (notice.transactionId !== canonical.transactionId) return;
  const terminal = new Set(["expired", "refunded", "revoked", "billing_retry"]);
  const terminalNotice = ["REFUND", "REVOKE", "EXPIRED", "GRACE_PERIOD_EXPIRED"]
    .includes(notificationType);
  const reversal = notificationType === "REFUND_REVERSED";
  if (!terminalNotice && !reversal) return;
  // An authoritative inactive snapshot never grants access. For a reversal,
  // however, retry if that snapshot predates the verified reversal evidence.
  if (terminalNotice && terminal.has(canonical.lifecycle)) return;
  const noticeTime = Date.parse(notice.signedAt ?? "");
  const canonicalTime = Date.parse(canonical.signedAt ?? "");
  if (!Number.isFinite(noticeTime) || !Number.isFinite(canonicalTime)) {
    throw new Error("apple_canonical_state_pending");
  }
  const incompatible = notice.lifecycle !== canonical.lifecycle;
  if (
    canonicalTime < noticeTime ||
    (canonicalTime === noticeTime && incompatible) ||
    // A terminal notice with a still-active transaction snapshot is not proof
    // that Apple has finished publishing the new state. Do not discard it.
    (terminalNotice && canonicalTime === noticeTime)
  ) {
    throw new Error("apple_canonical_state_pending");
  }
}
