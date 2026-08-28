import assert from 'node:assert/strict';
import test from 'node:test';

import { googleLifecycle } from './google_play_subscription_lifecycle.ts';

const now = new Date('2026-08-28T12:00:00.000Z');

function trialLine(overrides: Record<string, unknown> = {}) {
  return {
    productId: 'bil_premium_ai_coach',
    expiryTime: '2026-09-04T12:00:00.000Z',
    offerDetails: {
      basePlanId: 'monthly',
      offerId: 'trial-7-day',
      offerTags: ['new-customer'],
    },
    offerPhase: { freeTrial: {} },
    ...overrides,
  };
}

test('recognizes the authoritative current free-trial phase', () => {
  assert.equal(
    googleLifecycle('SUBSCRIPTION_STATE_ACTIVE', trialLine(), now),
    'trial',
  );
});

test('keeps a cancelled-in-trial subscription as trial until expiry', () => {
  assert.equal(
    googleLifecycle('SUBSCRIPTION_STATE_CANCELED', trialLine(), now),
    'trial',
  );
});

test('recognizes a proration period whose original current phase is free trial', () => {
  assert.equal(
    googleLifecycle('SUBSCRIPTION_STATE_ACTIVE', trialLine({
      offerPhase: {
        prorationPeriod: { originalOfferPhaseType: 'FREE_TRIAL' },
      },
    }), now),
    'trial',
  );
});

test('expiry always wins over trial metadata', () => {
  assert.equal(
    googleLifecycle('SUBSCRIPTION_STATE_ACTIVE', trialLine({
      expiryTime: '2026-08-28T11:59:59.000Z',
    }), now),
    'expired',
  );
});

test('fails closed when the current offer phase is not free trial', () => {
  assert.equal(
    googleLifecycle('SUBSCRIPTION_STATE_ACTIVE', trialLine({
      offerPhase: { basePrice: {} },
    }), now),
    'active',
  );
});

test('fails closed when offer identity or eligibility tag does not match', () => {
  assert.equal(
    googleLifecycle('SUBSCRIPTION_STATE_ACTIVE', trialLine({
      offerDetails: { offerId: 'different-offer', offerTags: ['new-customer'] },
    }), now),
    'active',
  );
  assert.equal(
    googleLifecycle('SUBSCRIPTION_STATE_ACTIVE', trialLine({
      offerDetails: { offerId: 'trial-7-day', offerTags: [] },
    }), now),
    'active',
  );
});

test('fails closed for an unknown product or malformed offer payload', () => {
  assert.equal(
    googleLifecycle('SUBSCRIPTION_STATE_ACTIVE', trialLine({
      productId: 'unknown_subscription',
    }), now),
    'active',
  );
  assert.equal(
    googleLifecycle('SUBSCRIPTION_STATE_ACTIVE', trialLine({
      offerDetails: [],
      offerPhase: 'free',
    }), now),
    'active',
  );
});

test('does not promote non-access states to trial', () => {
  assert.equal(
    googleLifecycle('SUBSCRIPTION_STATE_PENDING', trialLine(), now),
    'pending',
  );
  assert.equal(
    googleLifecycle('SUBSCRIPTION_STATE_IN_GRACE_PERIOD', trialLine(), now),
    'grace_period',
  );
  assert.equal(
    googleLifecycle('SUBSCRIPTION_STATE_ON_HOLD', trialLine(), now),
    'account_hold',
  );
});

test('preserves existing lifecycle mappings and unknown-state suspension', () => {
  assert.equal(googleLifecycle('SUBSCRIPTION_STATE_ACTIVE', {}, now), 'active');
  assert.equal(googleLifecycle('SUBSCRIPTION_STATE_PAUSED', {}, now), 'paused');
  assert.equal(googleLifecycle('SUBSCRIPTION_STATE_CANCELED', {}, now), 'cancelled');
  assert.equal(googleLifecycle('UNKNOWN', {}, now), 'suspended');
});
