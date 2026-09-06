#!/usr/bin/env node

/**
 * Fail-closed App Store Connect product-page screenshot uploader for BIL 1.0.0.
 *
 * Scope is deliberately narrow:
 * - iOS version 1.0.0 only;
 * - the sole en-US version localization only;
 * - one APP_IPHONE_67 screenshot set only;
 * - exactly the first eight sorted English PNGs in
 *   store_assets/screenshots/apple;
 * - no deletion, replacement, review submission, release, source-app, or
 *   commerce mutation.
 *
 * The live mutation is opt-in:
 *   ASC_ALLOW_PRODUCT_SCREENSHOT_UPLOAD=YES node \
 *     tool/apple_store_connect/asc_product_page_screenshots_upload.mjs \
 *     G:\\BIL_Temp\\asc-product-screenshots-upload.json
 */

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

import { clientFromEnvironment } from './asc_catalog_sync.mjs';

export const APP_ID = '6805349703';
export const VERSION = '1.0.0';
export const PLATFORM = 'IOS';
export const LOCALE = 'en-US';
export const DISPLAY_TYPE = 'APP_IPHONE_67';
export const SCREENSHOT_COUNT = 8;
export const EXPECTED_WIDTH = 1290;
export const EXPECTED_HEIGHT = 2796;

const projectRoot = path.resolve(import.meta.dirname, '..', '..');
export const screenshotRoot = path.join(
  projectRoot,
  'store_assets',
  'screenshots',
  'apple',
);

export function inspectPng(buffer) {
  const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  if (buffer.length < 26 || !buffer.subarray(0, 8).equals(signature)) {
    throw new Error('Asset is not a valid PNG');
  }
  return {
    width: buffer.readUInt32BE(16),
    height: buffer.readUInt32BE(20),
    bitDepth: buffer[24],
    colorType: buffer[25],
  };
}

export function selectScreenshotFiles(directory = screenshotRoot) {
  const candidates = fs.readdirSync(directory, { withFileTypes: true })
    .filter((entry) => entry.isFile())
    .map((entry) => entry.name)
    .filter((name) => /^epic15_iphone_69_en_.+\.png$/i.test(name))
    .sort((left, right) => left.localeCompare(right, 'en'));
  if (candidates.length < SCREENSHOT_COUNT) {
    throw new Error(
      `Expected at least ${SCREENSHOT_COUNT} English PNGs, found ${candidates.length}`,
    );
  }
  return candidates.slice(0, SCREENSHOT_COUNT).map((name) => path.join(directory, name));
}

export function validateScreenshot(filePath) {
  const bytes = fs.readFileSync(filePath);
  const png = inspectPng(bytes);
  if (png.width !== EXPECTED_WIDTH || png.height !== EXPECTED_HEIGHT) {
    throw new Error(
      `${path.basename(filePath)} must be exactly ${EXPECTED_WIDTH}x${EXPECTED_HEIGHT}; ` +
      `received ${png.width}x${png.height}`,
    );
  }
  if (png.bitDepth !== 8 || png.colorType !== 2) {
    throw new Error(
      `${path.basename(filePath)} must be flattened 8-bit RGB PNG without alpha; ` +
      `received bitDepth=${png.bitDepth}, colorType=${png.colorType}`,
    );
  }
  return { filePath, bytes, ...png };
}

export function assertNoExistingScreenshotSet(sets) {
  if (!Array.isArray(sets)) throw new Error('Screenshot-set inspection returned invalid data');
  if (sets.length !== 0) {
    const summary = sets.map((set) => ({
      id: set.id,
      displayType: set.attributes?.screenshotDisplayType ?? null,
    }));
    throw new Error(
      `Mutation refused: target localization already has ${sets.length} screenshot set(s): ` +
      JSON.stringify(summary),
    );
  }
}

async function uploadOperations(operations, bytes, fetchImpl = fetch) {
  if (!Array.isArray(operations) || operations.length === 0) {
    throw new Error('Apple did not return asset upload operations');
  }
  for (const operation of operations) {
    const offset = Number(operation.offset ?? 0);
    const length = Number(operation.length ?? bytes.length);
    if (!Number.isSafeInteger(offset) || !Number.isSafeInteger(length) ||
        offset < 0 || length <= 0 || offset + length > bytes.length) {
      throw new Error('Apple returned an invalid screenshot upload byte range');
    }
    const headers = Object.fromEntries(
      (operation.requestHeaders ?? []).map(({ name, value }) => [name, value]),
    );
    const response = await fetchImpl(operation.url, {
      method: operation.method ?? 'PUT',
      headers,
      body: bytes.subarray(offset, offset + length),
    });
    if (!response.ok) {
      throw new Error(`Apple screenshot asset upload failed with HTTP ${response.status}`);
    }
  }
}

async function waitForComplete(client, screenshotId, sleep = (milliseconds) =>
  new Promise((resolve) => setTimeout(resolve, milliseconds))) {
  for (let attempt = 1; attempt <= 60; attempt += 1) {
    const current = await client.request('GET', `/v1/appScreenshots/${screenshotId}`);
    const delivery = current.data?.attributes?.assetDeliveryState;
    if (delivery?.state === 'COMPLETE') return current.data;
    if (delivery?.state === 'FAILED') {
      throw new Error(
        `Apple rejected screenshot ${screenshotId}: ` +
        JSON.stringify(delivery?.errors ?? []),
      );
    }
    await sleep(1_000);
  }
  throw new Error(`Timed out waiting for screenshot ${screenshotId}`);
}

export async function discoverTarget(client) {
  const versions = await client.all(
    `/v1/apps/${APP_ID}/appStoreVersions?filter[platform]=${PLATFORM}&limit=200`,
  );
  const matches = versions.filter((item) => item.attributes?.versionString === VERSION);
  if (matches.length !== 1) {
    throw new Error(`Expected one iOS ${VERSION} version, found ${matches.length}`);
  }
  const version = matches[0];
  if (version.attributes?.appStoreState !== 'PREPARE_FOR_SUBMISSION') {
    throw new Error(
      `Mutation refused: version ${VERSION} state is ${version.attributes?.appStoreState}`,
    );
  }
  const localizations = await client.all(
    `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=200`,
  );
  const matchesByLocale = localizations.filter((item) => item.attributes?.locale === LOCALE);
  if (matchesByLocale.length !== 1 || localizations.length !== 1) {
    throw new Error(
      `Expected the sole version localization to be ${LOCALE}; ` +
      `found ${localizations.map((item) => item.attributes?.locale ?? null).join(',')}`,
    );
  }
  return { version, localization: matchesByLocale[0] };
}

async function createScreenshotSet(client, localizationId) {
  const created = await client.request('POST', '/v1/appScreenshotSets', {
    data: {
      type: 'appScreenshotSets',
      attributes: { screenshotDisplayType: DISPLAY_TYPE },
      relationships: {
        appStoreVersionLocalization: {
          data: { type: 'appStoreVersionLocalizations', id: localizationId },
        },
      },
    },
  });
  if (!created?.data?.id) throw new Error('Apple did not return a screenshot-set ID');
  return created.data;
}

async function uploadScreenshot(client, setId, asset) {
  const reservation = await client.request('POST', '/v1/appScreenshots', {
    data: {
      type: 'appScreenshots',
      attributes: {
        fileName: path.basename(asset.filePath),
        fileSize: asset.bytes.length,
      },
      relationships: {
        appScreenshotSet: {
          data: { type: 'appScreenshotSets', id: setId },
        },
      },
    },
  });
  const screenshot = reservation?.data;
  if (!screenshot?.id) throw new Error('Apple did not return a screenshot reservation ID');
  await uploadOperations(screenshot.attributes?.uploadOperations, asset.bytes);
  await client.request('PATCH', `/v1/appScreenshots/${screenshot.id}`, {
    data: {
      type: 'appScreenshots',
      id: screenshot.id,
      attributes: { uploaded: true },
    },
  });
  return waitForComplete(client, screenshot.id);
}

function writeReport(output, report) {
  if (!output) return;
  const target = path.resolve(output);
  if (path.parse(target).root.toUpperCase() !== 'G:\\') {
    throw new Error(`Report output must stay on G:, received ${target}`);
  }
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
}

export async function main() {
  if (process.env.ASC_ALLOW_PRODUCT_SCREENSHOT_UPLOAD !== 'YES') {
    throw new Error(
      'Mutation refused: set ASC_ALLOW_PRODUCT_SCREENSHOT_UPLOAD=YES after preflight review',
    );
  }

  // Validate every byte before making the first live mutation.
  const assets = selectScreenshotFiles().map(validateScreenshot);
  if (assets.length !== SCREENSHOT_COUNT) {
    throw new Error(`Expected exactly ${SCREENSHOT_COUNT} selected screenshots`);
  }

  const client = clientFromEnvironment();
  const { version, localization } = await discoverTarget(client);
  const existingBefore = await client.all(
    `/v1/appStoreVersionLocalizations/${localization.id}/appScreenshotSets?limit=200`,
  );
  assertNoExistingScreenshotSet(existingBefore);

  // Re-read immediately before the create to keep the mutation race window as
  // small as the public ASC API permits.
  const existingAtCommit = await client.all(
    `/v1/appStoreVersionLocalizations/${localization.id}/appScreenshotSets?limit=200`,
  );
  assertNoExistingScreenshotSet(existingAtCommit);

  const set = await createScreenshotSet(client, localization.id);
  const uploaded = [];
  for (const asset of assets) {
    const complete = await uploadScreenshot(client, set.id, asset);
    uploaded.push({
      id: complete.id,
      fileName: complete.attributes?.fileName ?? path.basename(asset.filePath),
      state: complete.attributes?.assetDeliveryState?.state ?? null,
      width: complete.attributes?.imageAsset?.width ?? null,
      height: complete.attributes?.imageAsset?.height ?? null,
    });
  }

  const liveSets = await client.all(
    `/v1/appStoreVersionLocalizations/${localization.id}/appScreenshotSets?limit=200`,
  );
  if (liveSets.length !== 1 || liveSets[0].id !== set.id ||
      liveSets[0].attributes?.screenshotDisplayType !== DISPLAY_TYPE) {
    throw new Error('Post-upload verification found an unexpected screenshot-set state');
  }
  const liveScreenshots = await client.all(
    `/v1/appScreenshotSets/${set.id}/appScreenshots?limit=200`,
  );
  if (liveScreenshots.length !== SCREENSHOT_COUNT ||
      liveScreenshots.some((item) => item.attributes?.assetDeliveryState?.state !== 'COMPLETE')) {
    throw new Error(
      `Post-upload verification expected ${SCREENSHOT_COUNT} COMPLETE screenshots; ` +
      `found ${liveScreenshots.length}`,
    );
  }

  const report = {
    generatedAt: new Date().toISOString(),
    mutation: 'app_store_product_page_screenshots',
    deletionsPerformed: false,
    reviewSubmitted: false,
    appReleased: false,
    appId: APP_ID,
    versionId: version.id,
    versionString: VERSION,
    versionState: version.attributes?.appStoreState ?? null,
    locale: LOCALE,
    localizationId: localization.id,
    screenshotSetId: set.id,
    displayType: DISPLAY_TYPE,
    selectedFiles: assets.map((asset) => path.basename(asset.filePath)),
    uploaded,
    liveSetCount: liveSets.length,
    liveScreenshotCount: liveScreenshots.length,
    liveCompleteCount: liveScreenshots.filter(
      (item) => item.attributes?.assetDeliveryState?.state === 'COMPLETE',
    ).length,
  };
  writeReport(process.argv[2], report);
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(import.meta.filename)) {
  main().catch((error) => {
    process.stderr.write(`${error.stack ?? error.message}\n`);
    process.exitCode = 1;
  });
}
