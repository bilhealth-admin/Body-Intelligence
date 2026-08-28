export type GoogleSubscriptionLifecycle =
  | 'pending'
  | 'trial'
  | 'active'
  | 'grace_period'
  | 'account_hold'
  | 'paused'
  | 'suspended'
  | 'cancelled'
  | 'expired';

const googlePlayTrialOfferId = 'trial-7-day';
const googlePlayTrialOfferTag = 'new-customer';

const googlePlayTrialProductIds = new Set([
  'bil_premium',
  'bil_premium_annual',
  'bil_premium_ai_coach',
  'bil_premium_ai_coach_annual',
]);

const googlePlayTrialAccessStates = new Set([
  'SUBSCRIPTION_STATE_ACTIVE',
  'SUBSCRIPTION_STATE_CANCELED',
]);

function asRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function isCurrentGooglePlayFreeTrial(
  state: string,
  lineItem: Record<string, unknown>,
) {
  if (!googlePlayTrialAccessStates.has(state)) return false;
  if (!googlePlayTrialProductIds.has(String(lineItem.productId ?? ''))) return false;

  const offerDetails = asRecord(lineItem.offerDetails);
  if (String(offerDetails?.offerId ?? '') !== googlePlayTrialOfferId) return false;
  const rawOfferTags = offerDetails?.offerTags;
  const offerTags = Array.isArray(rawOfferTags) ? rawOfferTags : [];
  if (!offerTags.includes(googlePlayTrialOfferTag)) return false;

  const offerPhase = asRecord(lineItem.offerPhase);
  if (!offerPhase) return false;
  if (asRecord(offerPhase.freeTrial)) return true;

  const prorationPeriod = asRecord(offerPhase.prorationPeriod);
  return String(prorationPeriod?.originalOfferPhaseType ?? '') === 'FREE_TRIAL';
}

export function googleLifecycle(
  state: string,
  lineItem: Record<string, unknown>,
  now = new Date(),
): GoogleSubscriptionLifecycle {
  if (lineItem.expiryTime && new Date(String(lineItem.expiryTime)) < now) {
    return 'expired';
  }
  if (isCurrentGooglePlayFreeTrial(state, lineItem)) return 'trial';
  return ({
    SUBSCRIPTION_STATE_PENDING: 'pending',
    SUBSCRIPTION_STATE_ACTIVE: 'active',
    SUBSCRIPTION_STATE_PAUSED: 'paused',
    SUBSCRIPTION_STATE_IN_GRACE_PERIOD: 'grace_period',
    SUBSCRIPTION_STATE_ON_HOLD: 'account_hold',
    SUBSCRIPTION_STATE_CANCELED: 'cancelled',
    SUBSCRIPTION_STATE_EXPIRED: 'expired',
  } as Record<string, GoogleSubscriptionLifecycle>)[state] ?? 'suspended';
}
