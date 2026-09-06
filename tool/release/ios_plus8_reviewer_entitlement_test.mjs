import assert from 'node:assert/strict';
import test from 'node:test';

import { validateReviewerPremiumAiPreflight } from './ios_plus8_canary/reviewer_entitlement.mjs';

const OWNER_ID = '00000000-0000-4000-8000-000000000008';
const NOW = Date.parse('2030-01-15T12:00:00.000Z');
const STARTED = '2029-12-01T00:00:00.000Z';
const ENDED = '2030-01-15T11:59:59.999Z';
const FUTURE = '2030-02-15T12:00:00.000Z';
const VERIFIED = '2030-01-15T11:58:00.000Z';

function validInput({
  plan = 'premium',
  provider = plan === 'premium' ? 'google' : 'apple',
  lifecycle = 'active',
} = {}) {
  const productId = plan === 'premium'
    ? 'bil_premium_monthly'
    : 'bil_premium_ai_coach';
  return {
    expectedOwnerId: OWNER_ID,
    now: NOW,
    grantRows: [{ owner_id: OWNER_ID, active: true, expires_at: FUTURE }],
    subscriptionRows: [{
      owner_id: OWNER_ID,
      provider,
      product_id: productId,
      plan_id: plan,
      lifecycle,
      started_at: STARTED,
      expires_at: lifecycle === 'grace_period' ? ENDED : FUTURE,
      grace_period_ends_at: lifecycle === 'grace_period' ? FUTURE : null,
      verified_at: VERIFIED,
    }],
    entitlementRows: [{
      owner_id: OWNER_ID,
      entitlement_id: `plan:${plan}`,
      product_id: productId,
      provider,
      active: true,
      starts_at: STARTED,
      expires_at: lifecycle === 'grace_period' ? ENDED : FUTURE,
      server_updated_at: VERIFIED,
    }],
    usage: {
      plan: 'ai_coach',
      credits: { total_remaining: 2500 },
    },
  };
}

function rejectAfter(name, mutate, expectedReason) {
  test(name, () => {
    const input = validInput();
    mutate(input);
    assert.deepEqual(validateReviewerPremiumAiPreflight(input), {
      ok: false,
      reason: expectedReason,
      representation: null,
    });
  });
}

test('accepts canonical Premium plus active closed-test AI overlay', () => {
  assert.deepEqual(validateReviewerPremiumAiPreflight(validInput()), {
    ok: true,
    reason: null,
    representation: 'PREMIUM_WITH_CLOSED_TEST_AI_OVERLAY',
  });
});

test('accepts literal canonical Premium AI Coach plus closed-test grant', () => {
  assert.deepEqual(validateReviewerPremiumAiPreflight(validInput({
    plan: 'premium_ai_coach',
    provider: 'apple',
  })), {
    ok: true,
    reason: null,
    representation: 'PREMIUM_AI_COACH_WITH_CLOSED_TEST_GRANT',
  });
});

test('accepts server closed-test literal representation without fabricating a store receipt', () => {
  assert.equal(validateReviewerPremiumAiPreflight(validInput({
    plan: 'premium_ai_coach',
    provider: 'closed_test',
  })).ok, true);
});

test('uses grace_period_ends_at as the effective access boundary', () => {
  const result = validateReviewerPremiumAiPreflight(validInput({
    lifecycle: 'grace_period',
  }));
  assert.equal(result.ok, true);
});

test('keeps cancelled access only until the already-paid period boundary', () => {
  const input = validInput({ lifecycle: 'cancelled' });
  assert.equal(validateReviewerPremiumAiPreflight(input).ok, true);
  input.subscriptionRows[0].expires_at = ENDED;
  assert.equal(
    validateReviewerPremiumAiPreflight(input).reason,
    'subscription_access_boundary_expired',
  );
});

test('an old verification remains valid because verified_at is not a freshness lease', () => {
  const input = validInput();
  input.subscriptionRows[0].verified_at = '2025-01-01T00:00:00.000Z';
  input.entitlementRows[0].server_updated_at = '2025-01-01T00:00:00.000Z';
  assert.equal(validateReviewerPremiumAiPreflight(input).ok, true);
});

rejectAfter('rejects a missing closed-test grant', (input) => {
  input.grantRows = [];
}, 'closed_test_grant_count');

rejectAfter('rejects an inactive closed-test grant', (input) => {
  input.grantRows[0].active = false;
}, 'closed_test_grant_inactive');

rejectAfter('rejects an expired closed-test grant', (input) => {
  input.grantRows[0].expires_at = ENDED;
}, 'closed_test_grant_expired');

rejectAfter('rejects noncanonical compatibility plan aliases', (input) => {
  input.subscriptionRows[0].plan_id = 'pro';
  input.entitlementRows[0].entitlement_id = 'plan:pro';
}, 'subscription_plan_not_canonical');

rejectAfter('fails closed for object prototype names masquerading as plans', (input) => {
  input.subscriptionRows[0].plan_id = 'toString';
  input.entitlementRows[0].entitlement_id = 'plan:toString';
}, 'subscription_plan_not_canonical');

rejectAfter('rejects a closed-test provider for ordinary Premium', (input) => {
  input.subscriptionRows[0].provider = 'closed_test';
  input.entitlementRows[0].provider = 'closed_test';
}, 'subscription_provider_not_authoritative');

rejectAfter('rejects a lifecycle that cannot grant paid access', (input) => {
  input.subscriptionRows[0].lifecycle = 'billing_retry';
}, 'subscription_lifecycle_denied');

rejectAfter('rejects an expired active subscription', (input) => {
  input.subscriptionRows[0].expires_at = ENDED;
}, 'subscription_access_boundary_expired');

rejectAfter('rejects a future subscription start', (input) => {
  input.subscriptionRows[0].started_at = FUTURE;
}, 'subscription_not_started');

rejectAfter('rejects a missing server verification timestamp', (input) => {
  input.subscriptionRows[0].verified_at = null;
}, 'subscription_verification_invalid');

rejectAfter('rejects an implausibly future server verification timestamp', (input) => {
  input.subscriptionRows[0].verified_at = '2030-01-15T12:05:00.001Z';
}, 'subscription_verification_invalid');

rejectAfter('rejects mixed Premium and Premium AI entitlement rows', (input) => {
  input.entitlementRows[0].entitlement_id = 'plan:premium_ai_coach';
}, 'entitlement_plan_mismatch');

rejectAfter('rejects multiple active plan entitlements', (input) => {
  input.entitlementRows.push({
    ...input.entitlementRows[0],
    entitlement_id: 'plan:premium_ai_coach',
  });
}, 'active_plan_entitlement_count');

rejectAfter('rejects an entitlement from a different provider', (input) => {
  input.entitlementRows[0].provider = 'apple';
}, 'entitlement_provider_mismatch');

rejectAfter('rejects an entitlement for a different product', (input) => {
  input.entitlementRows[0].product_id = 'unexpected_product';
}, 'entitlement_product_mismatch');

rejectAfter('rejects an entitlement without a finite access boundary', (input) => {
  input.entitlementRows[0].expires_at = null;
}, 'entitlement_boundary_missing');

rejectAfter('rejects a future entitlement mirror verification timestamp', (input) => {
  input.entitlementRows[0].server_updated_at = '2030-01-15T12:05:00.001Z';
}, 'entitlement_verification_invalid');

rejectAfter('rejects an AI usage response from the wrong plan', (input) => {
  input.usage.plan = 'free';
}, 'usage_plan_not_ai_coach');

rejectAfter('rejects usable AI tokens below the reviewer floor', (input) => {
  input.usage.credits.total_remaining = 2499;
}, 'usage_floor_not_met');

rejectAfter('rejects owner authority mismatch even when all plans look valid', (input) => {
  input.subscriptionRows[0].owner_id = '00000000-0000-4000-8000-000000000009';
}, 'subscription_owner_mismatch');
