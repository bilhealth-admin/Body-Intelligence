import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  buildCatalog,
  extractTerritoryMap,
  parsePrice,
  validateCatalog,
} from './asc_catalog_sync.mjs';

test('price parser preserves exact decimal intent and handles common grouping', () => {
  assert.deepEqual(parsePrice('EGP 99.99'), {
    display: 'EGP 99.99',
    amount: 99.99,
    normalizedAmount: '99.99',
  });
  assert.equal(parsePrice('₦ 1,859').amount, 1859);
  assert.equal(parsePrice('R$ 29,99').amount, 29.99);
  assert.equal(parsePrice('¥ 719').amount, 719);
  assert.equal(parsePrice('—'), null);
});

test('canonical market policy maps all 172 launch territories', () => {
  const catalog = buildCatalog();
  assert.equal(Object.keys(catalog.iso2ToIso3).length, 172);
  assert.equal(catalog.iso2ToIso3.EG, 'EGY');
  assert.equal(catalog.iso2ToIso3.US, 'USA');
  assert.equal(catalog.iso2ToIso3.XK, 'XKS');
});

test('catalog split and immutable product metadata match release truth', () => {
  const catalog = buildCatalog();
  const validation = validateCatalog(catalog);
  assert.equal(validation.valid, true, validation.errors.join('\n'));
  assert.equal(validation.applyReady, false);
  assert.deepEqual(catalog.split.premiumOnlyIso2, ['EG', 'IN', 'PK', 'TR']);
  assert.equal(catalog.split.premiumAiCoachIso2.length, 168);
  assert.equal(catalog.split.premiumAiCoachIso2.includes('NG'), true);
  assert.equal(catalog.split.premiumAiCoachIso2.includes('IN'), false);
  assert.equal(catalog.split.allLaunchIso2.length, 172);
  assert.deepEqual(catalog.split.heldIso2, ['BY', 'CN', 'RU']);

  const products = Object.fromEntries(catalog.products.map((item) => [item.productId, item]));
  assert.equal(products.bil_premium.subscriptionPeriod, 'ONE_MONTH');
  assert.equal(products.bil_premium_annual.subscriptionPeriod, 'ONE_YEAR');
  assert.equal(products.bil_premium.territoryCount, 4);
  assert.equal(products.bil_premium_ai_coach.territoryCount, 168);
  assert.equal(products.bil_ai_boost.territoryCount, 172);
  assert.equal(products.bil_ai_boost.appleReferencePrice.businessTargetAmount, 2.5);
  assert.equal(products.bil_ai_boost.appleReferencePrice.appleReferenceAmount, 2.49);
});

test('trial decision covers both AI products, excludes Premium, and is declarative', () => {
  const catalog = buildCatalog();
  const validation = validateCatalog(catalog);
  const byId = Object.fromEntries(catalog.products.map((item) => [item.productId, item]));

  assert.equal(catalog.policy.trialPolicy.decision,
    'BOTH_AI_PRODUCTS_NO_PREMIUM_TRIAL');
  assert.deepEqual(catalog.policy.trialPolicy.eligibleProductIds, [
    'bil_premium_ai_coach',
    'bil_premium_ai_coach_annual',
  ]);
  assert.deepEqual(catalog.policy.trialPolicy.ineligibleProductIds, [
    'bil_premium',
    'bil_premium_annual',
  ]);
  assert.equal(catalog.policy.trialPolicy.offersCreatedByThisPolicy, false);
  assert.equal(byId.bil_premium.introductoryOffer.state,
    'INELIGIBLE_BY_POLICY');
  assert.equal(byId.bil_premium_annual.introductoryOffer.state,
    'INELIGIBLE_BY_POLICY');
  assert.equal(byId.bil_premium_ai_coach.introductoryOffer.state,
    'DECLARED_NOT_CREATED');
  assert.equal(byId.bil_premium_ai_coach_annual.introductoryOffer.state,
    'DECLARED_NOT_CREATED');
  assert.equal(validation.unresolved.some((item) =>
    item.code === 'INTRO_OFFER_PRODUCT_ASSIGNMENT_UNRESOLVED'), false);
  assert.equal(validation.unresolved.some((item) =>
    item.code === 'PREMIUM_TRIAL_COPY_CONFLICT'), false);
});

test('catalog utility contains no introductory-offer mutation endpoint', () => {
  const source = fs.readFileSync(
    new URL('./asc_catalog_sync.mjs', import.meta.url),
    'utf8',
  );
  assert.equal(source.includes('/introductoryOffers'), false);
  assert.equal(source.includes('subscriptionIntroductoryOffers'), false);
  assert.match(source, /if \(options\.mode === '--dry-run'\)/);
});

test('dry-run proves zero live mutation without store credentials', () => {
  const script = fileURLToPath(new URL('./asc_catalog_sync.mjs', import.meta.url));
  const result = spawnSync(process.execPath, [script, '--dry-run'], {
    cwd: process.cwd(),
    encoding: 'utf8',
    env: {
      ...process.env,
      ASC_KEY_ID: '',
      ASC_ISSUER_ID: '',
      ASC_PRIVATE_KEY_PATH: '',
      ASC_ALLOW_MUTATION: '',
    },
  });
  assert.equal(result.status, 0, result.stderr);
  const report = JSON.parse(result.stdout);
  assert.equal(report.mode, 'dry-run');
  assert.equal(report.mutationPerformed, false);
  assert.equal(report.actions, null);
  assert.equal(report.trialPolicy.offersCreatedByThisPolicy, false);
});

test('canonical reference prices and annual campaign copy are exact', () => {
  const catalog = buildCatalog();
  const byId = Object.fromEntries(catalog.products.map((item) => [item.productId, item]));
  assert.equal(catalog.canonicalPricing.displayPolicy.annualBadgeText, '30% OFF');
  assert.equal(catalog.canonicalPricing.displayPolicy.pricesMustBeStoreDerived, true);
  assert.equal(catalog.canonicalPricing.displayPolicy.hardcodedFlutterPricesAllowed, false);
  assert.equal(byId.bil_premium.appleReferencePrice.businessTargetAmount, 2.5);
  assert.equal(byId.bil_premium.appleReferencePrice.appleReferenceAmount, 2.49);
  assert.equal(byId.bil_premium_annual.appleReferencePrice.appleReferenceAmount, 21);
  assert.equal(byId.bil_premium_ai_coach.appleReferencePrice.appleReferenceAmount, 5.99);
  assert.equal(byId.bil_premium_ai_coach_annual.appleReferencePrice.appleReferenceAmount, 49.99);
  assert.equal(
    catalog.canonicalPricing.history.supersedesForActivePricing.includes(
      'artifacts/pricing/BIL_FINAL_GLOBAL_STORE_PRICING_2026-08-28.json',
    ),
    true,
  );
});

test('territory parser rejects incomplete SQL input', () => {
  assert.throws(() => extractTerritoryMap("array['EG','IN','PK','TR']::text[]"));
});
