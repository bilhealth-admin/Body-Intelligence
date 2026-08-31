import assert from 'node:assert/strict';
import test from 'node:test';

import { googleLifecycle } from './google_play_subscription_lifecycle.ts';

const now = new Date('2026-08-28T12:00:00.000Z');
const trialStartTime = '2026-08-28T12:00:00.000Z';

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

test('recognizes the trial for both Premium AI Coach products', () => {
  for (const productId of [
    'bil_premium_ai_coach',
    'bil_premium_ai_coach_annual',
  ]) {
    assert.equal(
      googleLifecycle(
        'SUBSCRIPTION_STATE_ACTIVE',
        trialLine({ productId }),
        now,
        trialStartTime,
      ),
      'trial',
    );
  }
});

test('never classifies either regular Premium product as an AI trial', () => {
  for (const productId of ['bil_premium', 'bil_premium_annual']) {
    assert.equal(
      googleLifecycle(
        'SUBSCRIPTION_STATE_ACTIVE',
        trialLine({ productId }),
        now,
        trialStartTime,
      ),
      'active',
    );
  }
});

test('keeps a cancelled-in-trial subscription as trial until expiry', () => {
  assert.equal(
    googleLifecycle(
      'SUBSCRIPTION_STATE_CANCELED',
      trialLine(),
      now,
      trialStartTime,
    ),
    'trial',
  );
});

test('recognizes a proration period whose original current phase is free trial', () => {
  assert.equal(
    googleLifecycle(
      'SUBSCRIPTION_STATE_ACTIVE',
      trialLine({
        offerPhase: {
          prorationPeriod: { originalOfferPhaseType: 'FREE_TRIAL' },
        },
      }),
      now,
      trialStartTime,
    ),
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
  assert.equal(
    googleLifecycle('SUBSCRIPTION_STATE_ACTIVE', trialLine({
      expiryTime: now.toISOString(),
    }), now),
    'expired',
  );
});

test('missing or malformed expiry suspends access fail closed', () => {
  for (const expiryTime of [undefined, null, '', 'not-a-date']) {
    assert.equal(
      googleLifecycle(
        'SUBSCRIPTION_STATE_ACTIVE',
        trialLine({ expiryTime }),
        now,
      ),
      'suspended',
    );
  }
});

test('fails closed when the current offer phase is not free trial', () => {
  assert.equal(
    googleLifecycle('SUBSCRIPTION_STATE_ACTIVE', trialLine({
      offerPhase: { basePrice: {} },
    }), now),
    'active',
  );
});

test('requires one exact seven-day verified Play trial window', () => {
  assert.equal(
    googleLifecycle('SUBSCRIPTION_STATE_ACTIVE', trialLine(), now),
    'active',
  );
  assert.equal(
    googleLifecycle(
      'SUBSCRIPTION_STATE_ACTIVE',
      trialLine(),
      now,
      'not-a-date',
    ),
    'active',
  );
  assert.equal(
    googleLifecycle(
      'SUBSCRIPTION_STATE_ACTIVE',
      trialLine({ expiryTime: '2026-09-05T12:00:00.000Z' }),
      now,
      trialStartTime,
    ),
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
    'suspended',
  );
  assert.equal(
    googleLifecycle('SUBSCRIPTION_STATE_ACTIVE', trialLine({
      offerDetails: [],
      offerPhase: 'free',
    }), now),
    'active',
  );
  for (const productId of [
    null,
    '',
    ' bil_premium_ai_coach',
    'bil_premium_ai_coach ',
    'BIL_PREMIUM_AI_COACH',
    'premium_ai_coach',
  ]) {
    assert.equal(
      googleLifecycle(
        'SUBSCRIPTION_STATE_ACTIVE',
        trialLine({ productId }),
        now,
      ),
      'suspended',
    );
  }
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
  const premiumLine = {
    productId: 'bil_premium',
    expiryTime: '2026-09-04T12:00:00.000Z',
  };
  assert.equal(
    googleLifecycle('SUBSCRIPTION_STATE_ACTIVE', premiumLine, now),
    'active',
  );
  assert.equal(
    googleLifecycle('SUBSCRIPTION_STATE_PAUSED', premiumLine, now),
    'paused',
  );
  assert.equal(
    googleLifecycle('SUBSCRIPTION_STATE_CANCELED', premiumLine, now),
    'cancelled',
  );
  assert.equal(googleLifecycle('UNKNOWN', premiumLine, now), 'suspended');
  assert.equal(googleLifecycle('SUBSCRIPTION_STATE_ACTIVE', {}, now), 'suspended');
});
