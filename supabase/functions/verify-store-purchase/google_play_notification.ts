export type GoogleNotificationKind =
  | 'test'
  | 'subscription'
  | 'one_time_purchased'
  | 'one_time_canceled'
  | 'invalid';

export type ParsedGoogleNotification = {
  kind: GoogleNotificationKind;
  purchaseToken?: string;
  productId?: string;
};

export function googleGracePeriodEnd(
  lifecycle: string,
  expiryTime: unknown,
): string | undefined {
  return lifecycle === 'grace_period' && typeof expiryTime === 'string' && expiryTime
    ? expiryTime
    : undefined;
}

export function parseGoogleNotification(
  notice: Record<string, unknown>,
): ParsedGoogleNotification {
  if (notice.testNotification != null) return { kind: 'test' };

  const subscription = notice.subscriptionNotification as
    | Record<string, unknown>
    | undefined;
  if (subscription != null) {
    const purchaseToken = String(subscription.purchaseToken ?? '').trim();
    return purchaseToken
      ? { kind: 'subscription', purchaseToken }
      : { kind: 'invalid' };
  }

  const oneTime = notice.oneTimeProductNotification as
    | Record<string, unknown>
    | undefined;
  if (oneTime != null) {
    const purchaseToken = String(oneTime.purchaseToken ?? '').trim();
    const productId = String(oneTime.sku ?? '').trim();
    const notificationType = Number(oneTime.notificationType ?? 0);
    if (!purchaseToken || !productId) return { kind: 'invalid' };
    if (notificationType === 1) {
      return { kind: 'one_time_purchased', purchaseToken, productId };
    }
    if (notificationType === 2) {
      return { kind: 'one_time_canceled', purchaseToken, productId };
    }
  }
  return { kind: 'invalid' };
}
