import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

import {
  applyMarketAlignment,
  legacyTerritoriesFor,
  validateApplyStates,
} from './asc_subscription_market_sync.mjs';

test('reviewed legacy state is exactly the India and Nigeria swap', () => {
  assert.deepEqual(
    legacyTerritoriesFor('bil_premium', ['EGY', 'NGA', 'PAK', 'TUR']),
    ['EGY', 'IND', 'PAK', 'TUR'],
  );
  assert.deepEqual(
    legacyTerritoriesFor('bil_premium_annual', ['EGY', 'NGA', 'PAK', 'TUR']),
    ['EGY', 'IND', 'PAK', 'TUR'],
  );
  assert.deepEqual(
    legacyTerritoriesFor('bil_premium_ai_coach', ['IND', 'USA']),
    ['NGA', 'USA'],
  );
  assert.deepEqual(
    legacyTerritoriesFor('bil_premium_ai_coach_annual', ['IND', 'USA']),
    ['NGA', 'USA'],
  );
});

test('mutation path is double-gated, read-back verified, and rollback guarded', () => {
  const source = fs.readFileSync(
    new URL('./asc_subscription_market_sync.mjs', import.meta.url),
    'utf8',
  );
  assert.match(source, /ASC_ALLOW_AVAILABILITY_MUTATION !== 'YES'/);
  assert.match(source, /--confirm-owner-policy=EG,NG,PK,TR/);
  assert.match(source, /immediate App Store read-back did not match/);
  assert.match(source, /rollback was incomplete/);
  assert.match(source, /has no positive configured price/);
  assert.match(source, /availableInNewTerritories !== false/);
});

function state(overrides = {}) {
  return {
    productId: 'bil_premium',
    subscriptionId: 'subscription-1',
    planAvailabilityId: 'plan-1',
    planType: 'UPFRONT',
    availableInNewTerritories: false,
    territories: ['EGY', 'IND', 'PAK', 'TUR'],
    expected: ['EGY', 'NGA', 'PAK', 'TUR'],
    diff: { add: ['NGA'], remove: ['IND'] },
    exact: false,
    legacyExact: true,
    ...overrides,
  };
}

test('exact territories still fail closed when automatic new markets are enabled', () => {
  assert.throws(
    () => validateApplyStates([
      state({
        territories: ['EGY', 'NGA', 'PAK', 'TUR'],
        diff: { add: [], remove: [] },
        exact: true,
        legacyExact: false,
        availableInNewTerritories: true,
      }),
    ]),
    /disable automatic new-territory availability/,
  );
});

test('a resumable mixed final and legacy snapshot mutates only legacy rows', () => {
  const finalState = state({
    productId: 'bil_premium',
    territories: ['EGY', 'NGA', 'PAK', 'TUR'],
    diff: { add: [], remove: [] },
    exact: true,
    legacyExact: false,
  });
  const legacyState = state({
    productId: 'bil_premium_annual',
    subscriptionId: 'subscription-2',
    planAvailabilityId: 'plan-2',
  });
  assert.deepEqual(validateApplyStates([finalState, legacyState]), [legacyState]);
});

test('a partial apply failure rolls every changed product back to its snapshot', async () => {
  const first = state();
  const second = state({
    productId: 'bil_premium_annual',
    subscriptionId: 'subscription-2',
    planAvailabilityId: 'plan-2',
  });
  const territories = new Map([
    ['plan-1', [...first.territories]],
    ['plan-2', [...second.territories]],
  ]);
  let secondFailed = false;
  const client = {
    async request(method, resource, body) {
      if (method === 'GET' && resource.includes('/prices?')) {
        return {
          data: [{ type: 'subscriptionPrices', id: 'price' }],
          included: [{
            type: 'subscriptionPricePoints',
            id: 'point',
            attributes: { customerPrice: '1.00' },
          }],
        };
      }
      if (method === 'PATCH') {
        const planId = resource.includes('plan-1') ? 'plan-1' : 'plan-2';
        if (planId === 'plan-2' && !secondFailed) {
          secondFailed = true;
          throw new Error('simulated_second_patch_failure');
        }
        territories.set(planId, body.data.map((item) => item.id).sort());
        return null;
      }
      throw new Error(`unexpected_request:${method}:${resource}`);
    },
    async all(resource) {
      const planId = resource.includes('plan-1') ? 'plan-1' : 'plan-2';
      return (territories.get(planId) ?? []).map((id) => ({
        type: 'territories',
        id,
      }));
    },
  };
  const previous = process.env.ASC_ALLOW_AVAILABILITY_MUTATION;
  process.env.ASC_ALLOW_AVAILABILITY_MUTATION = 'YES';
  try {
    await assert.rejects(
      applyMarketAlignment(client, { products: [] }, [first, second]),
      /simulated_second_patch_failure/,
    );
  } finally {
    if (previous === undefined) delete process.env.ASC_ALLOW_AVAILABILITY_MUTATION;
    else process.env.ASC_ALLOW_AVAILABILITY_MUTATION = previous;
  }
  assert.deepEqual(territories.get('plan-1'), first.territories);
  assert.deepEqual(territories.get('plan-2'), second.territories);
});

test('final read-back fails closed if automatic new markets change concurrently', async () => {
  const before = state();
  let patched = false;
  const client = {
    async request(method, resource, body) {
      if (method === 'GET' && resource.includes('/prices?')) {
        return {
          data: [{ type: 'subscriptionPrices', id: 'price' }],
          included: [{
            type: 'subscriptionPricePoints',
            id: 'point',
            attributes: { customerPrice: '1.00' },
          }],
        };
      }
      if (method === 'PATCH') {
        patched = true;
        return null;
      }
      throw new Error(`unexpected_request:${method}:${resource}:${JSON.stringify(body)}`);
    },
    async all(resource) {
      if (resource.includes('/subscriptions/subscription-1/planAvailabilities')) {
        return [{
          type: 'subscriptionPlanAvailabilities',
          id: 'plan-1',
          attributes: {
            planType: 'UPFRONT',
            availableInNewTerritories: patched,
          },
        }];
      }
      if (resource.includes('/availableTerritories')) {
        const ids = patched ? before.expected : before.territories;
        return ids.map((id) => ({ type: 'territories', id }));
      }
      throw new Error(`unexpected_all:${resource}`);
    },
  };
  const catalog = {
    products: [{
      kind: 'subscription',
      productId: before.productId,
      appStoreConnectId: before.subscriptionId,
      territories: before.expected.map((iso3) => ({ iso3 })),
    }],
  };
  const previous = process.env.ASC_ALLOW_AVAILABILITY_MUTATION;
  process.env.ASC_ALLOW_AVAILABILITY_MUTATION = 'YES';
  try {
    await assert.rejects(
      applyMarketAlignment(client, catalog, [before]),
      /disable automatic new-territory availability/,
    );
  } finally {
    if (previous === undefined) delete process.env.ASC_ALLOW_AVAILABILITY_MUTATION;
    else process.env.ASC_ALLOW_AVAILABILITY_MUTATION = previous;
  }
});

test('market sync uses current subscription plan availability API only', () => {
  const source = fs.readFileSync(
    new URL('./asc_subscription_market_sync.mjs', import.meta.url),
    'utf8',
  );
  assert.match(source, /\/planAvailabilities\?limit=200/);
  assert.match(source, /subscriptionPlanAvailabilities/);
  assert.equal(source.includes('/subscriptionAvailabilities/'), false);
});
