import assert from 'node:assert/strict';
import test from 'node:test';

import {
  appleServerStatusLifecycle,
  appleTransactionLifecycle,
} from './apple_subscription_lifecycle.ts';

const nowMs = Date.parse('2026-08-28T12:00:00.000Z');

function trialPayload(overrides: Record<string, unknown> = {}) {
  return {
    productId: 'bil_premium_ai_coach',
    expiresDate: Date.parse('2026-09-04T12:00:00.000Z'),
    offerType: 1,
    offerDiscountType: 'FREE_TRIAL',
    ...overrides,
  };
}

test('recognizes an unexpired Apple introductory free trial', () => {
  assert.equal(appleTransactionLifecycle(trialPayload(), nowMs), 'trial');
});

test('preserves a trial when App Store Server status is active', () => {
  assert.equal(appleServerStatusLifecycle(1, 'trial'), 'trial');
  assert.equal(appleServerStatusLifecycle(1, 'active'), 'active');
});

test('expiry and revocation override trial metadata', () => {
  assert.equal(
    appleTransactionLifecycle(trialPayload({ expiresDate: nowMs }), nowMs),
    'expired',
  );
  assert.equal(
    appleTransactionLifecycle(trialPayload({ revocationDate: nowMs }), nowMs),
    'revoked',
  );
});

test('fails closed for discounted intros, malformed metadata, and unknown ids', () => {
  assert.equal(
    appleTransactionLifecycle(
      trialPayload({ offerDiscountType: 'PAY_AS_YOU_GO', price: 1 }),
      nowMs,
    ),
    'active',
  );
  assert.equal(
    appleTransactionLifecycle(trialPayload({ offerType: 2 }), nowMs),
    'active',
  );
  assert.equal(
    appleTransactionLifecycle(trialPayload({ productId: 'bil_ai_boost' }), nowMs),
    'active',
  );
  assert.equal(
    appleTransactionLifecycle(trialPayload({ expiresDate: undefined }), nowMs),
    'expired',
  );
});

test('accepts explicit zero price only for an introductory known subscription', () => {
  assert.equal(
    appleTransactionLifecycle(
      trialPayload({ offerDiscountType: undefined, price: 0 }),
      nowMs,
    ),
    'trial',
  );
});

test('maps server lifecycle failures without silently granting access', () => {
  assert.equal(appleServerStatusLifecycle(2, 'trial'), 'expired');
  assert.equal(appleServerStatusLifecycle(3, 'trial'), 'billing_retry');
  assert.equal(appleServerStatusLifecycle(4, 'trial'), 'grace_period');
  assert.equal(appleServerStatusLifecycle(5, 'trial'), 'revoked');
  assert.equal(appleServerStatusLifecycle(1, 'suspended'), 'revoked');
  assert.equal(appleServerStatusLifecycle(0, 'unexpected'), 'revoked');
});
