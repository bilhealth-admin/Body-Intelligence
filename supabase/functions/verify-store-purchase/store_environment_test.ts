import assert from 'node:assert/strict';
import test from 'node:test';

import {
  appleServerHost,
  googleProductEnvironment,
  googleSubscriptionEnvironment,
  verifiedStoreEnvironment,
} from './store_environment.ts';

test('Google API truth supports sandbox and production without client input', () => {
  assert.equal(googleSubscriptionEnvironment({}), 'sandbox');
  assert.equal(googleSubscriptionEnvironment(undefined), 'production');
  assert.equal(googleProductEnvironment(0), 'sandbox');
  assert.equal(googleProductEnvironment(undefined), 'production');
});

test('verified Apple environment selects the matching server API', () => {
  assert.equal(verifiedStoreEnvironment('Sandbox'), 'sandbox');
  assert.equal(verifiedStoreEnvironment('Production'), 'production');
  assert.equal(
    appleServerHost('sandbox'),
    'api.storekit-sandbox.itunes.apple.com',
  );
  assert.equal(appleServerHost('production'), 'api.storekit.itunes.apple.com');
});

test('unknown environment fails closed', () => {
  assert.throws(() => verifiedStoreEnvironment('staging'), /wrong_environment/);
  assert.throws(() => verifiedStoreEnvironment(''), /wrong_environment/);
});
