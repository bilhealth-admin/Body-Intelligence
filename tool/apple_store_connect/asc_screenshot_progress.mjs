#!/usr/bin/env node

import { clientFromEnvironment } from './asc_catalog_sync.mjs';

const client = clientFromEnvironment();
const localizationId = '3866ba6c-b637-4f70-9c53-d6274c37bc62';
const sets = await client.all(
  `/v1/appStoreVersionLocalizations/${localizationId}/appScreenshotSets?limit=200`,
);
const result = [];
for (const set of sets) {
  const screenshots = await client.all(
    `/v1/appScreenshotSets/${set.id}/appScreenshots?limit=200`,
  );
  result.push({
    setId: set.id,
    displayType: set.attributes?.screenshotDisplayType ?? null,
    total: screenshots.length,
    complete: screenshots.filter(
      (item) => item.attributes?.assetDeliveryState?.state === 'COMPLETE',
    ).length,
    failed: screenshots.filter(
      (item) => item.attributes?.assetDeliveryState?.state === 'FAILED',
    ).length,
  });
}
process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
