const ACCESS_LIFECYCLES = new Set([
  'trial',
  'active',
  'grace_period',
  'cancelled',
]);

const REPRESENTATIONS = Object.freeze({
  premium: Object.freeze({
    entitlementId: 'plan:premium',
    providers: new Set(['apple', 'google']),
    name: 'PREMIUM_WITH_CLOSED_TEST_AI_OVERLAY',
  }),
  premium_ai_coach: Object.freeze({
    entitlementId: 'plan:premium_ai_coach',
    providers: new Set(['apple', 'google', 'closed_test']),
    name: 'PREMIUM_AI_COACH_WITH_CLOSED_TEST_GRANT',
  }),
});

const MAXIMUM_SERVER_CLOCK_SKEW_MS = 5 * 60 * 1000;

function failure(reason) {
  return Object.freeze({ ok: false, reason, representation: null });
}

function timestamp(value) {
  const parsed = Date.parse(String(value ?? ''));
  return Number.isFinite(parsed) ? parsed : null;
}

function isSameOwner(row, expectedOwnerId) {
  return String(row?.owner_id ?? '') === expectedOwnerId;
}

function isVerifiedServerTime(value, now) {
  const parsed = timestamp(value);
  return parsed != null && parsed <= now + MAXIMUM_SERVER_CLOCK_SKEW_MS;
}

function effectiveSubscriptionBoundary(subscription) {
  return subscription.lifecycle === 'grace_period'
    ? subscription.grace_period_ends_at
    : subscription.expires_at;
}

/**
 * Validates the ordinary server rows used by the reviewer canary.
 *
 * This deliberately accepts only the two canonical representations that the
 * release backend can expose for a reviewer with an active closed-test AI
 * overlay: a Premium store subscription or a literal Premium AI Coach
 * subscription. It does not infer access from identity, email, or a local
 * preference.
 */
export function validateReviewerPremiumAiPreflight({
  expectedOwnerId,
  grantRows,
  entitlementRows,
  subscriptionRows,
  usage,
  now = Date.now(),
  minimumUsableTokens = 2500,
}) {
  const ownerId = String(expectedOwnerId ?? '');
  if (!ownerId) return failure('expected_owner_missing');
  if (!Number.isFinite(now)) return failure('invalid_evidence_time');
  if (!Array.isArray(grantRows) || grantRows.length !== 1) {
    return failure('closed_test_grant_count');
  }
  const grant = grantRows[0];
  if (!isSameOwner(grant, ownerId)) return failure('grant_owner_mismatch');
  if (grant.active !== true) return failure('closed_test_grant_inactive');
  const grantBoundary = timestamp(grant.expires_at);
  if (grantBoundary == null || grantBoundary <= now) {
    return failure('closed_test_grant_expired');
  }

  if (!Array.isArray(subscriptionRows) || subscriptionRows.length !== 1) {
    return failure('subscription_count');
  }
  const subscription = subscriptionRows[0];
  if (!isSameOwner(subscription, ownerId)) {
    return failure('subscription_owner_mismatch');
  }
  if (!Object.prototype.hasOwnProperty.call(
    REPRESENTATIONS,
    subscription.plan_id,
  )) return failure('subscription_plan_not_canonical');
  const representation = REPRESENTATIONS[subscription.plan_id];
  if (!representation.providers.has(subscription.provider)) {
    return failure('subscription_provider_not_authoritative');
  }
  if (!ACCESS_LIFECYCLES.has(subscription.lifecycle)) {
    return failure('subscription_lifecycle_denied');
  }
  const subscriptionBoundary = timestamp(
    effectiveSubscriptionBoundary(subscription),
  );
  if (subscriptionBoundary == null || subscriptionBoundary <= now) {
    return failure('subscription_access_boundary_expired');
  }
  const startedAt = subscription.started_at == null
    ? null
    : timestamp(subscription.started_at);
  if (subscription.started_at != null && (startedAt == null || startedAt > now)) {
    return failure('subscription_not_started');
  }
  if (!isVerifiedServerTime(subscription.verified_at, now)) {
    return failure('subscription_verification_invalid');
  }

  if (!Array.isArray(entitlementRows)) return failure('entitlements_not_rows');
  const activePlanEntitlements = entitlementRows.filter((row) =>
    row?.active === true && String(row?.entitlement_id ?? '').startsWith('plan:')
  );
  if (activePlanEntitlements.length !== 1) {
    return failure('active_plan_entitlement_count');
  }
  const entitlement = activePlanEntitlements[0];
  if (!isSameOwner(entitlement, ownerId)) {
    return failure('entitlement_owner_mismatch');
  }
  if (entitlement.entitlement_id !== representation.entitlementId) {
    return failure('entitlement_plan_mismatch');
  }
  if (entitlement.provider !== subscription.provider) {
    return failure('entitlement_provider_mismatch');
  }
  if (
    String(entitlement.product_id ?? '') === '' ||
    entitlement.product_id !== subscription.product_id
  ) {
    return failure('entitlement_product_mismatch');
  }
  const entitlementStartsAt = timestamp(entitlement.starts_at);
  if (entitlementStartsAt == null || entitlementStartsAt > now) {
    return failure('entitlement_not_started');
  }
  const entitlementBoundary = timestamp(entitlement.expires_at);
  if (entitlementBoundary == null) {
    return failure('entitlement_boundary_missing');
  }
  // The entitlement mirror stores the original period end while a subscription
  // in grace uses grace_period_ends_at as its effective access boundary.
  if (subscription.lifecycle !== 'grace_period' && entitlementBoundary <= now) {
    return failure('entitlement_expired');
  }
  if (!isVerifiedServerTime(entitlement.server_updated_at, now)) {
    return failure('entitlement_verification_invalid');
  }

  const usable = Number(usage?.credits?.total_remaining ?? Number.NaN);
  if (usage?.plan !== 'ai_coach') return failure('usage_plan_not_ai_coach');
  if (!Number.isFinite(usable) || usable < minimumUsableTokens) {
    return failure('usage_floor_not_met');
  }

  return Object.freeze({
    ok: true,
    reason: null,
    representation: representation.name,
  });
}
