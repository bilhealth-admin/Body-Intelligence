#!/usr/bin/env node

/** Read-only final commerce audit. Never prints credentials or mutates ASC. */

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

import { clientFromEnvironment } from './asc_catalog_sync.mjs';

const APP_ID = '6805349703';
const PRODUCT_IDS = new Set([
  'bil_premium',
  'bil_premium_annual',
  'bil_premium_ai_coach',
  'bil_premium_ai_coach_annual',
  'bil_ai_boost',
]);
const outputIndex = process.argv.indexOf('--output');
const output = outputIndex >= 0 ? process.argv[outputIndex + 1] : null;
if (!output) throw new Error('--output is required');
const target = path.resolve(output);
if (path.parse(target).root.toUpperCase() !== 'G:\\') throw new Error('Output must stay on G:');

const client = clientFromEnvironment();
const capture = async (work) => {
  try { return { ok: true, value: await work() }; }
  catch (error) { return { ok: false, error: String(error?.message ?? error) }; }
};
const collection = (resource) => capture(() => client.all(resource));

const groups = await client.all(`/v1/apps/${APP_ID}/subscriptionGroups?limit=200`);
const subscriptions = [];
for (const group of groups) {
  const members = await client.all(`/v1/subscriptionGroups/${group.id}/subscriptions?limit=200`);
  for (const subscription of members) {
    if (!PRODUCT_IDS.has(subscription.attributes?.productId)) continue;
    const id = subscription.id;
    const [localizations, prices, availability, versions, reviewScreenshot, introductoryOffers, promotionalOffers] =
      await Promise.all([
        collection(`/v1/subscriptions/${id}/subscriptionLocalizations?limit=200`),
        collection(`/v1/subscriptions/${id}/prices?include=subscriptionPricePoint,territory&limit=200`),
        capture(() => client.request('GET', `/v1/subscriptions/${id}/subscriptionAvailability`)),
        collection(`/v1/subscriptions/${id}/versions?limit=200`),
        capture(() => client.request('GET', `/v1/subscriptions/${id}/appStoreReviewScreenshot`)),
        collection(`/v1/subscriptions/${id}/introductoryOffers?limit=200`),
        collection(`/v1/subscriptions/${id}/promotionalOffers?limit=200`),
      ]);
    const availableTerritories = availability.ok
      ? await collection(`${availability.value.data.relationships.availableTerritories.links.related}?limit=200`)
      : { ok: false, error: 'Availability unavailable' };
    const versionDetails = [];
    if (versions.ok) {
      for (const version of versions.value) {
        const [versionLocalizations, images] = await Promise.all([
          collection(`/v1/subscriptionVersions/${version.id}/localizations?limit=200`),
          collection(`/v1/subscriptionVersions/${version.id}/images?limit=200`),
        ]);
        versionDetails.push({ id: version.id, attributes: version.attributes, localizations: versionLocalizations, images });
      }
    }
    subscriptions.push({
      id,
      groupId: group.id,
      attributes: subscription.attributes,
      localizations,
      prices,
      availability,
      availableTerritories,
      versions,
      versionDetails,
      reviewScreenshot,
      introductoryOffers,
      promotionalOffers,
    });
  }
}

const purchases = await client.all(`/v1/apps/${APP_ID}/inAppPurchasesV2?limit=200`);
const inAppPurchases = [];
for (const purchase of purchases) {
  if (!PRODUCT_IDS.has(purchase.attributes?.productId)) continue;
  const id = purchase.id;
  const [localizations, priceSchedule, availability, reviewScreenshot] = await Promise.all([
    collection(`/v2/inAppPurchases/${id}/inAppPurchaseLocalizations?limit=200`),
    capture(() => client.request('GET', `/v2/inAppPurchases/${id}/iapPriceSchedule?include=baseTerritory,manualPrices,automaticPrices&limit[manualPrices]=50&limit[automaticPrices]=50`)),
    capture(() => client.request('GET', `/v2/inAppPurchases/${id}/inAppPurchaseAvailability?include=availableTerritories&limit[availableTerritories]=50`)),
    capture(() => client.request('GET', `/v2/inAppPurchases/${id}/appStoreReviewScreenshot`)),
  ]);
  const availableTerritories = availability.ok
    ? await collection(`${availability.value.data.relationships.availableTerritories.links.related}?limit=200`)
    : { ok: false, error: 'Availability unavailable' };
  inAppPurchases.push({
    id,
    attributes: purchase.attributes,
    localizations,
    priceSchedule,
    availability,
    availableTerritories,
    reviewScreenshot,
  });
}

const result = {
  generatedAt: new Date().toISOString(),
  mode: 'read-only',
  mutationPerformed: false,
  appId: APP_ID,
  subscriptionGroups: groups,
  subscriptions,
  inAppPurchases,
};
fs.mkdirSync(path.dirname(target), { recursive: true });
fs.writeFileSync(target, `${JSON.stringify(result, null, 2)}\n`, 'utf8');
process.stdout.write(`Wrote ${target}\n`);
