#!/usr/bin/env node

/**
 * Read-only inspection of the currently effective BIL App Store prices.
 *
 * The script intentionally prints only product IDs, territories, customer
 * prices, proceeds, and effective dates. It never mutates App Store Connect
 * and never prints credentials.
 */

import fs from 'node:fs';

import { clientFromEnvironment } from './asc_catalog_sync.mjs';
import {
  APP_STORE_CALENDAR_TIME_ZONE,
  effectivePriceAt,
} from './asc_price_schedule.mjs';

const auditPath = process.argv[2];
if (!auditPath) {
  throw new Error('Usage: node asc_selected_prices_inspect.mjs <catalog-audit.json>');
}

const audit = JSON.parse(fs.readFileSync(auditPath, 'utf8'));
const client = clientFromEnvironment();
// Capture the clock once so every row in this report uses the same instant.
const observedAt = new Date();

const targetTerritories = {
  bil_premium_ai_coach: ['USA'],
  bil_premium_ai_coach_annual: ['USA'],
  bil_premium: ['EGY', 'IND', 'PAK', 'TUR'],
  bil_premium_annual: ['EGY', 'IND', 'PAK', 'TUR'],
};

const results = [];
for (const subscription of audit.subscriptions ?? []) {
  const prices = subscription.prices?.value ?? [];
  for (const territory of targetTerritories[subscription.productId] ?? []) {
    const current = effectivePriceAt(prices, territory, observedAt);
    if (!current) {
      results.push({
        productId: subscription.productId,
        territory,
        error: 'No effective price',
      });
      continue;
    }
    const pointId = current.relationships.subscriptionPricePoint.data.id;
    const point = await client.request(
      'GET',
      `/v1/subscriptionPricePoints/${encodeURIComponent(pointId)}`,
    );
    results.push({
      productId: subscription.productId,
      territory,
      customerPrice: point.data.attributes.customerPrice,
      proceeds: point.data.attributes.proceeds,
      startDate: current.attributes.startDate,
    });
  }
}

const boost = (audit.inAppPurchases ?? []).find(
  (purchase) => purchase.productId === 'bil_ai_boost',
);
const manualPrice =
  boost?.priceSchedule?.value?.data?.relationships?.manualPrices?.data?.[0];
if (manualPrice) {
  const pricePoints = await client.request(
    'GET',
    `/v2/inAppPurchases/${boost.id}/pricePoints` +
      '?filter[territory]=USA&include=territory&limit=200',
  );
  const manualPointId = JSON.parse(
    Buffer.from(manualPrice.id, 'base64url').toString('utf8'),
  ).p;
  const pricePoint = pricePoints.data?.find((item) => {
    const decoded = JSON.parse(Buffer.from(item.id, 'base64url').toString('utf8'));
    return decoded.p === manualPointId;
  });
  const territory = pricePoints.included?.find(
    (item) => item.type === 'territories' && item.id === 'USA',
  );
  results.push({
    productId: 'bil_ai_boost',
    territory: territory?.id ?? 'USA',
    customerPrice: pricePoint?.attributes?.customerPrice ?? null,
    proceeds: pricePoint?.attributes?.proceeds ?? null,
  });
}

process.stdout.write(`${JSON.stringify(results, null, 2)}\n`);
process.stderr.write(
  `NOTE: This is an App Store Connect API snapshot observed at ` +
    `${observedAt.toISOString()}; dated rows use the ` +
    `${APP_STORE_CALENDAR_TIME_ZONE} calendar. The App Store Connect UI may ` +
    `reflect a newer state while API changes propagate, so retain both ` +
    `observations and re-run the API audit if they temporarily disagree.\n`,
);
