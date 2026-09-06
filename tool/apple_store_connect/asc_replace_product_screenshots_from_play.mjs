#!/usr/bin/env node

/**
 * Replace the one known incorrect App Store product-page screenshot set with
 * the exact Google Play listing artwork fitted into Apple-valid iPhone and
 * iPad canvases.
 *
 * Safety boundaries:
 * - App 6805349703, iOS 1.0.0, sole en-US localization only.
 * - Delete only screenshot set f0a1b5b2-8a4e-4668-b835-f6c60589d6b8.
 * - Create only APP_IPHONE_67 and APP_IPAD_PRO_3GEN_129 sets.
 * - No review submission, version release, build, or commerce mutation.
 */

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

import { clientFromEnvironment } from './asc_catalog_sync.mjs';

const APP_ID = '6805349703';
const VERSION = '1.0.0';
const PLATFORM = 'IOS';
const LOCALE = 'en-US';
const WRONG_SET_ID = 'f0a1b5b2-8a4e-4668-b835-f6c60589d6b8';
const EXPECTED_COUNT = 8;
const TARGETS = new Map([
  ['APP_IPHONE_67', { width: 1290, height: 2796 }],
  ['APP_IPAD_PRO_3GEN_129', { width: 2048, height: 2732 }],
]);

function sha256(bytes) {
  return crypto.createHash('sha256').update(bytes).digest('hex');
}

function inspectPng(bytes) {
  const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  if (bytes.length < 26 || !bytes.subarray(0, 8).equals(signature)) {
    throw new Error('Screenshot is not a PNG');
  }
  return {
    width: bytes.readUInt32BE(16),
    height: bytes.readUInt32BE(20),
    bitDepth: bytes[24],
    colorType: bytes[25],
  };
}

function validatePreparedManifest(manifestPath) {
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  if (manifest.sourceStore !== 'Google Play live listing via Android Publisher API' ||
      manifest.sourceLocale !== 'en-GB') {
    throw new Error('Prepared assets are not tied to the live Google Play en-GB listing');
  }
  const byDisplayType = new Map();
  for (const [displayType, expected] of TARGETS.entries()) {
    const items = (manifest.outputs ?? [])
      .filter((item) => item.displayType === displayType)
      .sort((a, b) => a.order - b.order);
    if (items.length !== EXPECTED_COUNT) {
      throw new Error(`Expected ${EXPECTED_COUNT} ${displayType} assets; found ${items.length}`);
    }
    const seenSources = new Set();
    const assets = items.map((item, index) => {
      if (item.order !== index + 1 || item.cropped !== false || item.stretched !== false ||
          item.scaledProportionally !== true ||
          item.visibleContentMatchesProportionalFit !== true) {
        throw new Error(`${displayType} asset ${index + 1} failed transformation provenance`);
      }
      if (item.sourceSha256 !== item.googlePlaySha256 || seenSources.has(item.sourceSha256)) {
        throw new Error(`${displayType} asset ${index + 1} failed Google source identity`);
      }
      seenSources.add(item.sourceSha256);
      const filePath = path.resolve(item.outputPath);
      const bytes = fs.readFileSync(filePath);
      const png = inspectPng(bytes);
      if (sha256(bytes) !== item.outputSha256) {
        throw new Error(`${path.basename(filePath)} output SHA-256 changed after preparation`);
      }
      if (png.width !== expected.width || png.height !== expected.height ||
          png.bitDepth !== 8 || png.colorType !== 2) {
        throw new Error(
          `${path.basename(filePath)} must be opaque RGB ${expected.width}x${expected.height}`,
        );
      }
      return { item, filePath, bytes, ...png };
    });
    byDisplayType.set(displayType, assets);
  }
  const sourceOrderByTarget = [...byDisplayType.values()].map((assets) =>
    assets.map((asset) => asset.item.sourceSha256));
  if (JSON.stringify(sourceOrderByTarget[0]) !== JSON.stringify(sourceOrderByTarget[1])) {
    throw new Error('iPhone and iPad sets do not derive from the same eight Google sources in order');
  }
  return { manifest, byDisplayType };
}

async function discoverTarget(client) {
  const versions = await client.all(
    `/v1/apps/${APP_ID}/appStoreVersions?filter[platform]=${PLATFORM}&limit=200`,
  );
  const matches = versions.filter((item) => item.attributes?.versionString === VERSION);
  if (matches.length !== 1) throw new Error(`Expected one iOS ${VERSION}; found ${matches.length}`);
  const version = matches[0];
  if (version.attributes?.appStoreState !== 'PREPARE_FOR_SUBMISSION') {
    throw new Error(`Mutation refused in version state ${version.attributes?.appStoreState}`);
  }
  const localizations = await client.all(
    `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=200`,
  );
  if (localizations.length !== 1 || localizations[0].attributes?.locale !== LOCALE) {
    throw new Error('Expected the sole version localization to be en-US');
  }
  return { version, localization: localizations[0] };
}

async function uploadOperations(operations, bytes) {
  if (!Array.isArray(operations) || operations.length === 0) {
    throw new Error('Apple returned no screenshot upload operations');
  }
  for (const operation of operations) {
    const offset = Number(operation.offset ?? 0);
    const length = Number(operation.length ?? bytes.length);
    if (!Number.isSafeInteger(offset) || !Number.isSafeInteger(length) ||
        offset < 0 || length <= 0 || offset + length > bytes.length) {
      throw new Error('Apple returned an invalid upload byte range');
    }
    const headers = Object.fromEntries(
      (operation.requestHeaders ?? []).map(({ name, value }) => [name, value]),
    );
    const response = await fetch(operation.url, {
      method: operation.method ?? 'PUT',
      headers,
      body: bytes.subarray(offset, offset + length),
    });
    if (!response.ok) throw new Error(`Apple asset PUT failed (${response.status})`);
  }
}

async function waitForComplete(client, screenshotId) {
  for (let attempt = 1; attempt <= 90; attempt += 1) {
    const current = await client.request('GET', `/v1/appScreenshots/${screenshotId}`);
    const delivery = current.data?.attributes?.assetDeliveryState;
    if (delivery?.state === 'COMPLETE') return current.data;
    if (delivery?.state === 'FAILED') {
      throw new Error(`Apple rejected screenshot ${screenshotId}: ${JSON.stringify(delivery.errors ?? [])}`);
    }
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }
  throw new Error(`Timed out waiting for screenshot ${screenshotId}`);
}

async function createSet(client, localizationId, displayType) {
  const response = await client.request('POST', '/v1/appScreenshotSets', {
    data: {
      type: 'appScreenshotSets',
      attributes: { screenshotDisplayType: displayType },
      relationships: {
        appStoreVersionLocalization: {
          data: { type: 'appStoreVersionLocalizations', id: localizationId },
        },
      },
    },
  });
  if (!response.data?.id) throw new Error(`Apple did not create ${displayType} set`);
  return response.data;
}

async function uploadAsset(client, setId, asset) {
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
  const screenshot = reservation.data;
  if (!screenshot?.id) throw new Error('Apple did not reserve screenshot asset');
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

async function main() {
  if (process.env.ASC_ALLOW_EXACT_PLAY_SCREENSHOT_REPLACEMENT !== 'YES') {
    throw new Error(
      'Mutation refused: set ASC_ALLOW_EXACT_PLAY_SCREENSHOT_REPLACEMENT=YES after output QA',
    );
  }
  const preparedManifestPath = path.resolve(process.argv[2] ?? '');
  const reportPath = path.resolve(process.argv[3] ?? '');
  if (!preparedManifestPath || !reportPath || path.parse(reportPath).root.toUpperCase() !== 'G:\\') {
    throw new Error('Usage: node asc_replace...mjs <prepared-manifest.json> <G:\\report.json>');
  }
  // Validate every local byte and provenance record before touching Apple.
  const prepared = validatePreparedManifest(preparedManifestPath);
  const client = clientFromEnvironment();
  const { version, localization } = await discoverTarget(client);
  const setsBefore = await client.all(
    `/v1/appStoreVersionLocalizations/${localization.id}/appScreenshotSets?limit=200`,
  );
  const wrong = setsBefore.find((item) => item.id === WRONG_SET_ID);
  if (!wrong || wrong.attributes?.screenshotDisplayType !== 'APP_IPHONE_67') {
    throw new Error('Known incorrect APP_IPHONE_67 set is absent or has changed identity');
  }
  const unexpected = setsBefore.filter((item) => item.id !== WRONG_SET_ID);
  if (unexpected.length !== 0) {
    throw new Error(`Unexpected pre-existing screenshot sets: ${unexpected.map((item) => item.id).join(',')}`);
  }
  const oldAssets = await client.all(
    `/v1/appScreenshotSets/${WRONG_SET_ID}/appScreenshots?limit=200`,
  );
  if (oldAssets.length !== EXPECTED_COUNT ||
      oldAssets.some((item) => item.attributes?.assetDeliveryState?.state !== 'COMPLETE')) {
    throw new Error('Known incorrect set is no longer the expected 8/8 COMPLETE set');
  }
  // Narrow race check immediately before the only destructive request.
  const setsAtCommit = await client.all(
    `/v1/appStoreVersionLocalizations/${localization.id}/appScreenshotSets?limit=200`,
  );
  if (setsAtCommit.length !== 1 || setsAtCommit[0].id !== WRONG_SET_ID) {
    throw new Error('Screenshot state changed during preflight; deletion refused');
  }
  await client.request('DELETE', `/v1/appScreenshotSets/${WRONG_SET_ID}`);

  const createdSets = [];
  for (const [displayType, assets] of prepared.byDisplayType.entries()) {
    const set = await createSet(client, localization.id, displayType);
    const uploaded = [];
    for (const asset of assets) {
      const complete = await uploadAsset(client, set.id, asset);
      uploaded.push({
        id: complete.id,
        fileName: complete.attributes?.fileName ?? path.basename(asset.filePath),
        state: complete.attributes?.assetDeliveryState?.state ?? null,
        width: complete.attributes?.imageAsset?.width ?? null,
        height: complete.attributes?.imageAsset?.height ?? null,
        sourceSha256: asset.item.sourceSha256,
        outputSha256: asset.item.outputSha256,
      });
    }
    createdSets.push({ id: set.id, displayType, uploaded });
  }

  const liveSets = await client.all(
    `/v1/appStoreVersionLocalizations/${localization.id}/appScreenshotSets?limit=200`,
  );
  if (liveSets.length !== TARGETS.size || liveSets.some((set) => !TARGETS.has(
    set.attributes?.screenshotDisplayType,
  ))) {
    throw new Error('Post-upload set inventory does not contain exactly the two intended types');
  }
  const liveVerification = [];
  for (const set of liveSets) {
    const displayType = set.attributes?.screenshotDisplayType;
    const expected = TARGETS.get(displayType);
    const screenshots = await client.all(
      `/v1/appScreenshotSets/${set.id}/appScreenshots?limit=200`,
    );
    const complete = screenshots.filter(
      (item) => item.attributes?.assetDeliveryState?.state === 'COMPLETE' &&
        item.attributes?.imageAsset?.width === expected.width &&
        item.attributes?.imageAsset?.height === expected.height,
    );
    if (screenshots.length !== EXPECTED_COUNT || complete.length !== EXPECTED_COUNT) {
      throw new Error(`${displayType} verification expected 8/8 COMPLETE at target dimensions`);
    }
    liveVerification.push({
      setId: set.id,
      displayType,
      screenshotCount: screenshots.length,
      completeAtExpectedDimensions: complete.length,
      dimensions: expected,
    });
  }
  const report = {
    generatedAt: new Date().toISOString(),
    mutation: 'replace_known_wrong_apple_screenshot_set_with_exact_google_play_artwork',
    appId: APP_ID,
    versionId: version.id,
    versionString: VERSION,
    versionState: version.attributes?.appStoreState ?? null,
    locale: LOCALE,
    sourceStoreLocale: prepared.manifest.sourceLocale,
    deletedSetIds: [WRONG_SET_ID],
    deletionCount: 1,
    reviewSubmitted: false,
    appReleased: false,
    buildMutated: false,
    commerceMutated: false,
    createdSets,
    liveVerification,
    preparedManifestPath,
  };
  fs.mkdirSync(path.dirname(reportPath), { recursive: true });
  fs.writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
  process.stdout.write(`${JSON.stringify({
    deletedSetIds: report.deletedSetIds,
    created: createdSets.map((item) => ({
      id: item.id,
      displayType: item.displayType,
      complete: item.uploaded.filter((asset) => asset.state === 'COMPLETE').length,
    })),
    liveVerification,
    versionState: report.versionState,
    report: reportPath,
  }, null, 2)}\n`);
}

main().catch((error) => {
  process.stderr.write(`${error.stack ?? error.message}\n`);
  process.exitCode = 1;
});
