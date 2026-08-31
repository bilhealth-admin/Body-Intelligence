import assert from 'node:assert/strict';
import test from 'node:test';

import {
  googleGracePeriodEnd,
  parseGoogleNotification,
} from './google_play_notification.ts';

test('grace period uses the authoritative Play expiry boundary', () => {
  assert.equal(
    googleGracePeriodEnd('grace_period', '2026-09-01T00:00:00Z'),
    '2026-09-01T00:00:00Z',
  );
  assert.equal(googleGracePeriodEnd('active', '2026-09-01T00:00:00Z'), undefined);
  assert.equal(googleGracePeriodEnd('grace_period', null), undefined);
});

test('parses test and subscription RTDN envelopes', () => {
  assert.deepEqual(parseGoogleNotification({ testNotification: { version: '1.0' } }), {
    kind: 'test',
  });
  assert.deepEqual(parseGoogleNotification({
    subscriptionNotification: { purchaseToken: 'subscription-token' },
  }), { kind: 'subscription', purchaseToken: 'subscription-token' });
});

test('parses purchased and cancelled one-time product RTDN envelopes', () => {
  const base = { purchaseToken: 'boost-token', sku: 'bil_ai_boost' };
  assert.deepEqual(parseGoogleNotification({
    oneTimeProductNotification: { ...base, notificationType: 1 },
  }), {
    kind: 'one_time_purchased',
    purchaseToken: 'boost-token',
    productId: 'bil_ai_boost',
  });
  assert.deepEqual(parseGoogleNotification({
    oneTimeProductNotification: { ...base, notificationType: 2 },
  }), {
    kind: 'one_time_canceled',
    purchaseToken: 'boost-token',
    productId: 'bil_ai_boost',
  });
});

test('malformed or unknown RTDN fails closed', () => {
  assert.equal(parseGoogleNotification({}).kind, 'invalid');
  assert.equal(parseGoogleNotification({ subscriptionNotification: {} }).kind, 'invalid');
  assert.equal(parseGoogleNotification({
    oneTimeProductNotification: {
      purchaseToken: 'boost-token',
      sku: 'bil_ai_boost',
      notificationType: 99,
    },
  }).kind, 'invalid');
});
