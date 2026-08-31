#!/usr/bin/env node

/**
 * Read-only App Store Connect product audit for BIL.
 *
 * This utility never mutates App Store Connect. It captures the metadata,
 * review-image, pricing, availability and introductory-offer state needed to
 * prove whether the five current BIL products are release-ready.
 */

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

import { clientFromEnvironment } from './asc_catalog_sync.mjs';

const bundleId = 'com.bilhealth.bodyintelligencelog';
const expectedProductIds = new Set([
  'bil_premium',
  'bil_premium_annual',
  'bil_premium_ai_coach',
  'bil_premium_ai_coach_annual',
  'bil_ai_boost',
]);

async function capture(action) {
  try {
    return { ok: true, value: await action() };
  } catch (error) {
    return { ok: false, error: String(error?.message ?? error) };
  }
}

async function relatedCollection(client, resource) {
  return capture(() => client.all(resource));
}

async function auditSubscription(client, subscription) {
  const id = subscription.id;
  const planAvailabilities = await relatedCollection(
    client,
    `/v1/subscriptions/${id}/planAvailabilities?limit=200`,
  );
  const planTerritories = [];
  if (planAvailabilities.ok) {
    for (const availability of planAvailabilities.value) {
      const related = availability.relationships?.availableTerritories?.links?.related;
      planTerritories.push({
        id: availability.id,
        attributes: availability.attributes,
        territories: related
          ? await relatedCollection(client, `${related}${related.includes('?') ? '&' : '?'}limit=200`)
          : { ok: false, error: 'Missing availableTerritories related link' },
      });
    }
  }
  const subscriptionAvailability = await capture(() => client.request(
    'GET',
    `/v1/subscriptions/${id}/subscriptionAvailability`,
  ));
  const availableTerritories = subscriptionAvailability.ok
    ? await relatedCollection(
        client,
        `${subscriptionAvailability.value.data.relationships.availableTerritories.links.related}?limit=200`,
      )
    : { ok: false, error: 'Subscription availability could not be read' };
  const versions = await relatedCollection(
    client,
    `/v1/subscriptions/${id}/versions?limit=200`,
  );
  const versionMetadata = [];
  if (versions.ok) {
    for (const version of versions.value) {
      versionMetadata.push({
        id: version.id,
        attributes: version.attributes,
        localizations: await relatedCollection(
          client,
          `/v1/subscriptionVersions/${version.id}/localizations?limit=200`,
        ),
        images: await relatedCollection(
          client,
          `/v1/subscriptionVersions/${version.id}/images?limit=200`,
        ),
      });
    }
  }
  return {
    id,
    productId: subscription.attributes?.productId,
    attributes: subscription.attributes,
    localizations: await relatedCollection(
      client,
      `/v1/subscriptions/${id}/subscriptionLocalizations?limit=200`,
    ),
    prices: await relatedCollection(
      client,
      `/v1/subscriptions/${id}/prices?include=subscriptionPricePoint,territory&limit=200`,
    ),
    usPricePoints: await relatedCollection(
      client,
      `/v1/subscriptions/${id}/pricePoints?filter[territory]=USA&include=territory&limit=200`,
    ),
    planAvailabilities,
    planTerritories,
    subscriptionAvailability,
    availableTerritories,
    versions,
    versionMetadata,
    introductoryOffers: await relatedCollection(
      client,
      `/v1/subscriptions/${id}/introductoryOffers?limit=200`,
    ),
    promotionalOffers: await relatedCollection(
      client,
      `/v1/subscriptions/${id}/promotionalOffers?limit=200`,
    ),
    reviewScreenshot: await capture(() => client.request(
      'GET',
      `/v1/subscriptions/${id}/appStoreReviewScreenshot`,
    )),
  };
}

async function auditInAppPurchase(client, purchase) {
  const id = purchase.id;
  return {
    id,
    productId: purchase.attributes?.productId,
    attributes: purchase.attributes,
    details: await capture(() => client.request(
      'GET',
      `/v2/inAppPurchases/${id}?include=inAppPurchaseLocalizations,appStoreReviewScreenshot,iapPriceSchedule,inAppPurchaseAvailability`,
    )),
    localizations: await relatedCollection(
      client,
      `/v2/inAppPurchases/${id}/inAppPurchaseLocalizations?limit=200`,
    ),
    priceSchedule: await capture(() => client.request(
      'GET',
      `/v2/inAppPurchases/${id}/iapPriceSchedule?include=baseTerritory,manualPrices,automaticPrices&limit[manualPrices]=50&limit[automaticPrices]=50`,
    )),
    availability: await capture(() => client.request(
      'GET',
      `/v2/inAppPurchases/${id}/inAppPurchaseAvailability?include=availableTerritories&limit[availableTerritories]=50`,
    )),
    reviewScreenshot: await capture(() => client.request(
      'GET',
      `/v2/inAppPurchases/${id}/appStoreReviewScreenshot`,
    )),
  };
}

async function main() {
  const outputIndex = process.argv.indexOf('--output');
  const output = outputIndex >= 0 ? process.argv[outputIndex + 1] : null;
  if (!output) throw new Error('--output on G: is required');
  const target = path.resolve(output);
  if (path.parse(target).root.toUpperCase() !== 'G:\\') {
    throw new Error(`Audit output must stay on G:, received ${target}`);
  }

  const client = clientFromEnvironment();
  const apps = await client.all(
    `/v1/apps?filter[bundleId]=${encodeURIComponent(bundleId)}&limit=10`,
  );
  if (apps.length !== 1) {
    throw new Error(`Expected one App Store app for ${bundleId}; found ${apps.length}`);
  }
  const app = apps[0];
  const groups = await client.all(`/v1/apps/${app.id}/subscriptionGroups?limit=200`);
  const subscriptions = [];
  for (const group of groups) {
    const members = await client.all(`/v1/subscriptionGroups/${group.id}/subscriptions?limit=200`);
    for (const subscription of members) {
      if (expectedProductIds.has(subscription.attributes?.productId)) {
        subscriptions.push(await auditSubscription(client, subscription));
      }
    }
  }
  const purchases = await client.all(`/v1/apps/${app.id}/inAppPurchasesV2?limit=200`);
  const inAppPurchases = [];
  for (const purchase of purchases) {
    if (expectedProductIds.has(purchase.attributes?.productId)) {
      inAppPurchases.push(await auditInAppPurchase(client, purchase));
    }
  }

  const found = new Set([
    ...subscriptions.map((item) => item.productId),
    ...inAppPurchases.map((item) => item.productId),
  ]);
  const report = {
    generatedAt: new Date().toISOString(),
    mode: 'read-only',
    mutationPerformed: false,
    app: { id: app.id, attributes: app.attributes },
    subscriptionGroups: groups,
    subscriptions,
    inAppPurchases,
    missingExpectedProducts: [...expectedProductIds].filter((id) => !found.has(id)),
  };
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
  process.stdout.write(`Wrote ${target}\n`);
}

main().catch((error) => {
  process.stderr.write(`${error.stack ?? error.message}\n`);
  process.exitCode = 1;
});
