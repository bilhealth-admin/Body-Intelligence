export type AppleSubscriptionLifecycle =
  | 'trial'
  | 'active'
  | 'grace_period'
  | 'billing_retry'
  | 'expired'
  | 'refunded'
  | 'revoked';

const appleEligibleSubscriptionProductIds = new Set([
  'bil_premium',
  'bil_premium_annual',
  'bil_premium_ai_coach',
  'bil_premium_ai_coach_annual',
]);

const appleAiTrialProductIds = new Set([
  'bil_premium_ai_coach',
  'bil_premium_ai_coach_annual',
]);

const appleSubscriptionLifecycles = new Set<AppleSubscriptionLifecycle>([
  'trial',
  'active',
  'grace_period',
  'billing_retry',
  'expired',
  'refunded',
  'revoked',
]);

function normalizedAppleLifecycle(
  lifecycle: string,
): AppleSubscriptionLifecycle {
  return appleSubscriptionLifecycles.has(
      lifecycle as AppleSubscriptionLifecycle,
    )
    ? lifecycle as AppleSubscriptionLifecycle
    : 'revoked';
}

function isAppleIntroductoryFreeTrial(payload: Record<string, unknown>) {
  if (!appleAiTrialProductIds.has(String(payload.productId ?? ''))) {
    return false;
  }
  if (Number(payload.offerType) !== 1) return false;
  const purchaseDate = Number(payload.purchaseDate ?? 0);
  const expiresDate = Number(payload.expiresDate ?? 0);
  const sevenDaysMs = 7 * 24 * 60 * 60 * 1000;
  if (
    !Number.isFinite(purchaseDate) ||
    !Number.isFinite(expiresDate) ||
    purchaseDate <= 0 ||
    expiresDate - purchaseDate !== sevenDaysMs
  ) return false;
  if (String(payload.offerDiscountType ?? '').toUpperCase() === 'FREE_TRIAL') {
    return true;
  }
  return typeof payload.price === 'number' && payload.price === 0;
}

export function appleTransactionLifecycle(
  payload: Record<string, unknown>,
  nowMs = Date.now(),
): AppleSubscriptionLifecycle {
  if (payload.revocationDate) return 'revoked';
  const productId = String(payload.productId ?? '');
  // The verified Apple transaction helper is also used for the exact Boost
  // consumable. Unknown, legacy, aliased, or malformed product identities are
  // terminal here even though persistence repeats the registry check.
  if (productId === 'bil_ai_boost') return 'active';
  if (!appleEligibleSubscriptionProductIds.has(productId)) return 'revoked';
  const expires = Number(payload.expiresDate ?? 0);
  if (
    !Number.isFinite(expires) || expires <= 0
  ) {
    return 'expired';
  }
  if (expires > 0 && expires <= nowMs) return 'expired';
  if (isAppleIntroductoryFreeTrial(payload)) return 'trial';
  return 'active';
}

export function appleServerStatusLifecycle(
  status: number,
  verifiedLifecycle: string,
): AppleSubscriptionLifecycle {
  const fallback = normalizedAppleLifecycle(verifiedLifecycle);
  // A server-status code cannot rehabilitate an unknown/aliased transaction
  // lifecycle. Keep the terminal fail-closed result across every status.
  if (fallback === 'revoked') return 'revoked';
  switch (status) {
    case 1:
      return fallback === 'trial' || fallback === 'active'
        ? fallback
        : 'revoked';
    case 2:
      return 'expired';
    case 3:
      return 'billing_retry';
    case 4:
      return 'grace_period';
    case 5:
      return 'revoked';
    default:
      return fallback;
  }
}
