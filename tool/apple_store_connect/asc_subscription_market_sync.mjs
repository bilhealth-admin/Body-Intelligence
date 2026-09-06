#!/usr/bin/env node

/**
 * Fail-closed App Store subscription market alignment.
 *
 * Read-only:
 *   node asc_subscription_market_sync.mjs --inspect
 *
 * Mutation is accepted only when both gates are present and every live product
 * still matches the reviewed India-for-Nigeria legacy state:
 *   ASC_ALLOW_AVAILABILITY_MUTATION=YES node asc_subscription_market_sync.mjs \
 *     --apply --confirm-owner-policy=EG,NG,PK,TR
 */

import assert from 'node:assert/strict';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

import {
  buildCatalog,
  clientFromEnvironment,
  validateCatalog,
} from './asc_catalog_sync.mjs';

const scriptPath = fileURLToPath(import.meta.url);

function sorted(values) {
  return [...new Set(values)].sort();
}

function sameSet(left, right) {
  return JSON.stringify(sorted(left)) === JSON.stringify(sorted(right));
}

function setDiff(from, to) {
  const fromSet = new Set(from);
  const toSet = new Set(to);
  return {
    add: sorted(to.filter((value) => !fromSet.has(value))),
    remove: sorted(from.filter((value) => !toSet.has(value))),
  };
}

export function legacyTerritoriesFor(productId, expectedIso3) {
  const legacy = new Set(expectedIso3);
  if (productId === 'bil_premium' || productId === 'bil_premium_annual') {
    assert.equal(legacy.delete('NGA'), true, `${productId} expected policy must contain NGA`);
    legacy.add('IND');
  } else {
    assert.equal(legacy.delete('IND'), true, `${productId} expected policy must contain IND`);
    legacy.add('NGA');
  }
  return sorted(legacy);
}

function parseArgs(argv) {
  const args = new Set(argv.slice(2));
  const modes = ['--inspect', '--apply'].filter((mode) => args.has(mode));
  if (modes.length !== 1) throw new Error('Choose exactly one mode: --inspect or --apply');
  const confirm = argv.slice(2).find((arg) => arg.startsWith('--confirm-owner-policy='));
  return {
    mode: modes[0],
    confirm: confirm?.slice('--confirm-owner-policy='.length) ?? '',
  };
}

async function readTerritories(client, planAvailabilityId) {
  const rows = await client.all(
    `/v1/subscriptionPlanAvailabilities/${encodeURIComponent(planAvailabilityId)}` +
      '/availableTerritories?limit=200',
  );
  return sorted(rows.map((item) => item.id));
}

async function readProductState(client, product) {
  const planAvailabilities = await client.all(
    `/v1/subscriptions/${product.appStoreConnectId}/planAvailabilities?limit=200`,
  );
  const upfront = planAvailabilities.filter(
    (item) => item.attributes?.planType === 'UPFRONT',
  );
  if (upfront.length !== 1 || planAvailabilities.length !== 1) {
    throw new Error(
      `${product.productId} must have exactly one UPFRONT plan availability; ` +
        `found total=${planAvailabilities.length}, upfront=${upfront.length}`,
    );
  }
  const plan = upfront[0];
  return {
    productId: product.productId,
    subscriptionId: product.appStoreConnectId,
    planAvailabilityId: plan.id,
    planType: plan.attributes.planType,
    availableInNewTerritories: plan.attributes.availableInNewTerritories,
    territories: await readTerritories(client, plan.id),
  };
}

async function assertPriceExists(client, subscriptionId, territoryId, productId) {
  const response = await client.request(
    'GET',
    `/v1/subscriptions/${subscriptionId}/prices?filter[territory]=${territoryId}` +
      '&include=subscriptionPricePoint,territory&limit=200',
  );
  const pricePoints = (response?.included ?? []).filter(
    (item) => item.type === 'subscriptionPricePoints' &&
      Number(item.attributes?.customerPrice) > 0,
  );
  if ((response?.data?.length ?? 0) === 0 || pricePoints.length === 0) {
    throw new Error(`${productId} has no positive configured price for ${territoryId}`);
  }
}

export async function inspectMarketState(client, catalog) {
  const subscriptions = catalog.products.filter((item) => item.kind === 'subscription');
  const results = [];
  for (const product of subscriptions) {
    const state = await readProductState(client, product);
    const expected = sorted(product.territories.map((entry) => entry.iso3));
    const diff = setDiff(state.territories, expected);
    results.push({
      ...state,
      expectedTerritoryCount: expected.length,
      currentTerritoryCount: state.territories.length,
      diff,
      exact: sameSet(state.territories, expected),
      legacyExact: sameSet(
        state.territories,
        legacyTerritoriesFor(product.productId, expected),
      ),
      expected,
    });
  }
  return results;
}

function publicState(states) {
  return states.map((state) => ({
    productId: state.productId,
    planType: state.planType,
    availableInNewTerritories: state.availableInNewTerritories,
    currentTerritoryCount: state.currentTerritoryCount,
    expectedTerritoryCount: state.expectedTerritoryCount,
    diff: state.diff,
    exact: state.exact,
    legacyExact: state.legacyExact,
  }));
}

export function validateApplyStates(states) {
  const pending = [];
  for (const state of states) {
    if (state.planType !== 'UPFRONT') {
      throw new Error(`${state.productId} must use the UPFRONT plan type`);
    }
    if (state.availableInNewTerritories !== false) {
      throw new Error(`${state.productId} must disable automatic new-territory availability`);
    }
    if (!state.exact && !state.legacyExact) {
      throw new Error(
        `${state.productId} matches neither the final nor reviewed legacy state`,
      );
    }
    if (state.exact) {
      if (state.diff.add.length !== 0 || state.diff.remove.length !== 0) {
        throw new Error(`${state.productId} exact-state diff is inconsistent`);
      }
      continue;
    }
    if (state.diff.add.length !== 1 || state.diff.remove.length !== 1) {
      throw new Error(`${state.productId} must be an exact one-market swap`);
    }
    pending.push(state);
  }
  return pending;
}

export async function applyMarketAlignment(client, catalog, before) {
  if (process.env.ASC_ALLOW_AVAILABILITY_MUTATION !== 'YES') {
    throw new Error('Mutation refused: ASC_ALLOW_AVAILABILITY_MUTATION must equal YES');
  }
  const pending = validateApplyStates(before);
  if (pending.length === 0) return { actions: [], after: before };

  for (const state of pending) {
    await assertPriceExists(
      client,
      state.subscriptionId,
      state.diff.add[0],
      state.productId,
    );
  }

  const changed = [];
  try {
    for (const state of pending) {
      await client.request(
        'PATCH',
        `/v1/subscriptionPlanAvailabilities/${encodeURIComponent(state.planAvailabilityId)}` +
          '/relationships/availableTerritories',
        {
          data: state.expected.map((id) => ({ type: 'territories', id })),
        },
      );
      changed.push(state);
      const readBack = await readTerritories(client, state.planAvailabilityId);
      if (!sameSet(readBack, state.expected)) {
        throw new Error(`${state.productId} immediate App Store read-back did not match`);
      }
    }
  } catch (error) {
    const rollbackFailures = [];
    for (const state of changed.reverse()) {
      try {
        await client.request(
          'PATCH',
          `/v1/subscriptionPlanAvailabilities/${encodeURIComponent(state.planAvailabilityId)}` +
            '/relationships/availableTerritories',
          {
            data: state.territories.map((id) => ({ type: 'territories', id })),
          },
        );
        const rolledBack = await readTerritories(client, state.planAvailabilityId);
        if (!sameSet(rolledBack, state.territories)) {
          rollbackFailures.push(`${state.productId}:read-back-mismatch`);
        }
      } catch (rollbackError) {
        rollbackFailures.push(`${state.productId}:${rollbackError.message}`);
      }
    }
    if (rollbackFailures.length > 0) {
      throw new AggregateError(
        [error],
        `Availability apply failed and rollback was incomplete: ${rollbackFailures.join('; ')}`,
      );
    }
    throw error;
  }

  const after = await inspectMarketState(client, catalog);
  const remaining = validateApplyStates(after);
  if (remaining.length !== 0) {
    throw new Error('Final App Store availability verification failed');
  }
  return {
    actions: pending.map((state) => ({ productId: state.productId, ...state.diff })),
    after,
  };
}

export async function main(argv = process.argv) {
  const options = parseArgs(argv);
  const catalog = buildCatalog();
  const validation = validateCatalog(catalog);
  if (!validation.valid) throw new Error(validation.errors.join('\n'));
  if (options.mode === '--apply' && options.confirm !== 'EG,NG,PK,TR') {
    throw new Error('Mutation refused: exact --confirm-owner-policy=EG,NG,PK,TR is required');
  }

  const client = clientFromEnvironment();
  const before = await inspectMarketState(client, catalog);
  let result = { actions: null, after: null };
  if (options.mode === '--apply') {
    result = await applyMarketAlignment(client, catalog, before);
  }
  process.stdout.write(`${JSON.stringify({
    generatedAt: new Date().toISOString(),
    mode: options.mode.slice(2),
    ownerPolicy: ['EG', 'NG', 'PK', 'TR'],
    before: publicState(before),
    actions: result.actions,
    after: result.after ? publicState(result.after) : null,
  }, null, 2)}\n`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === scriptPath) {
  main().catch((error) => {
    process.stderr.write(`${error.stack ?? error.message}\n`);
    process.exitCode = 1;
  });
}
