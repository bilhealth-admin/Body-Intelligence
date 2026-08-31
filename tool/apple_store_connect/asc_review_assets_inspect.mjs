#!/usr/bin/env node

/**
 * Read-only App Store Connect review-asset inspector for BIL.
 *
 * This utility intentionally emits presence/count information only. It never
 * prints credentials, reviewer contact details, demo-account values, or notes.
 * It performs no mutation and cannot submit anything for review.
 */

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const APP_ID = '6805349703';
const VERSION = '1.0.0';
const METADATA_PATH = process.env.ASC_METADATA_PATH
  ?? 'G:\\BIL_Secrets\\Apple\\BIL_Store_Manager.metadata.json';
const downloadArg = process.argv.find((arg) => arg.startsWith('--download-dir='));
const downloadDir = downloadArg ? path.resolve(downloadArg.slice('--download-dir='.length)) : null;

function base64url(value) {
  return Buffer.from(value).toString('base64url');
}

function createJwt({ issuerId, keyId, privateKey }) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({ alg: 'ES256', kid: keyId, typ: 'JWT' }));
  const payload = base64url(JSON.stringify({
    iss: issuerId,
    iat: now,
    exp: now + 900,
    aud: 'appstoreconnect-v1',
  }));
  const input = `${header}.${payload}`;
  const signature = crypto.sign('sha256', Buffer.from(input), {
    key: privateKey,
    dsaEncoding: 'ieee-p1363',
  }).toString('base64url');
  return `${input}.${signature}`;
}

const metadata = JSON.parse(fs.readFileSync(METADATA_PATH, 'utf8'));
const privateKey = fs.readFileSync(metadata.privateKeyPath, 'utf8');
const token = createJwt({
  issuerId: metadata.issuerId,
  keyId: metadata.keyId,
  privateKey,
});

async function request(path, { allow = [] } = {}) {
  for (let attempt = 1; attempt <= 4; attempt += 1) {
    const response = await fetch(`https://api.appstoreconnect.apple.com${path}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (response.ok) return { status: response.status, ...(await response.json()) };
    if (allow.includes(response.status)) return { status: response.status, data: null };
    const body = await response.text();
    if ((response.status === 429 || response.status >= 500) && attempt < 4) {
      await new Promise((resolve) => setTimeout(resolve, attempt * 750));
      continue;
    }
    throw new Error(`${response.status} ${path}: ${body.slice(0, 500)}`);
  }
  throw new Error(`Unreachable request state for ${path}`);
}

function nonEmpty(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

async function saveReviewScreenshot(imageAsset, fileName) {
  if (!downloadDir || !imageAsset?.templateUrl) return false;
  const width = imageAsset.width;
  const height = imageAsset.height;
  const url = imageAsset.templateUrl
    .replace('{w}', String(width))
    .replace('{h}', String(height))
    .replace('{f}', 'png');
  const response = await fetch(url);
  if (!response.ok) throw new Error(`Review screenshot download failed: ${response.status}`);
  fs.mkdirSync(downloadDir, { recursive: true });
  fs.writeFileSync(path.join(downloadDir, fileName), Buffer.from(await response.arrayBuffer()));
  return true;
}

const versions = await request(
  `/v1/apps/${APP_ID}/appStoreVersions?filter%5Bplatform%5D=IOS&limit=200`,
);
const version = versions.data.find((item) => item.attributes.versionString === VERSION);
if (!version) throw new Error(`iOS version ${VERSION} was not found for app ${APP_ID}`);

const appInfos = await request(`/v1/apps/${APP_ID}/appInfos?limit=200`);
const appInfoReports = [];
for (const appInfo of appInfos.data) {
  const appInfoLocalizations = await request(
    `/v1/appInfos/${appInfo.id}/appInfoLocalizations?limit=200`,
  );
  appInfoReports.push({
    state: appInfo.attributes.appStoreState ?? null,
    localizations: appInfoLocalizations.data.map((localization) => ({
      locale: localization.attributes.locale,
      privacyPolicyUrlPresent: nonEmpty(localization.attributes.privacyPolicyUrl),
      privacyChoicesUrlPresent: nonEmpty(localization.attributes.privacyChoicesUrl),
      subtitlePresent: nonEmpty(localization.attributes.subtitle),
    })),
  });
}

const localizations = await request(
  `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=200`,
);

const localizationReports = [];
for (const localization of localizations.data) {
  const sets = await request(
    `/v1/appStoreVersionLocalizations/${localization.id}/appScreenshotSets?limit=200`,
  );
  const setReports = [];
  for (const set of sets.data) {
    const screenshots = await request(
      `/v1/appScreenshotSets/${set.id}/appScreenshots?limit=200`,
    );
    setReports.push({
      displayType: set.attributes.screenshotDisplayType,
      count: screenshots.data.length,
      assets: screenshots.data.map((item) => ({
        state: item.attributes.assetDeliveryState?.state ?? null,
        width: item.attributes.imageAsset?.width ?? null,
        height: item.attributes.imageAsset?.height ?? null,
        hasFileName: nonEmpty(item.attributes.fileName),
      })),
    });
  }
  localizationReports.push({
    locale: localization.attributes.locale,
    metadata: {
      description: nonEmpty(localization.attributes.description),
      keywords: nonEmpty(localization.attributes.keywords),
      marketingUrl: nonEmpty(localization.attributes.marketingUrl),
      promotionalText: nonEmpty(localization.attributes.promotionalText),
      supportUrl: nonEmpty(localization.attributes.supportUrl),
    },
    screenshotSets: setReports,
  });
}

const reviewResult = await request(
  `/v1/appStoreVersions/${version.id}/appStoreReviewDetail`,
  { allow: [404] },
);
let review = { exists: false };
if (reviewResult.data) {
  const attrs = reviewResult.data.attributes;
  const attachments = await request(
    `/v1/appStoreReviewDetails/${reviewResult.data.id}/appStoreReviewAttachments?limit=200`,
    { allow: [404] },
  );
  review = {
    exists: true,
    contact: {
      firstName: nonEmpty(attrs.contactFirstName),
      lastName: nonEmpty(attrs.contactLastName),
      email: nonEmpty(attrs.contactEmail),
      phone: nonEmpty(attrs.contactPhone),
    },
    demoAccountRequired: attrs.demoAccountRequired ?? null,
    demoAccountNamePresent: nonEmpty(attrs.demoAccountName),
    demoAccountPasswordPresent: nonEmpty(attrs.demoAccountPassword),
    notesPresent: nonEmpty(attrs.notes),
    attachmentCount: attachments.data?.length ?? 0,
  };
}

const buildResult = await request(
  `/v1/appStoreVersions/${version.id}/build`,
  { allow: [404] },
);

const subscriptionIds = [
  '6806555342',
  '6806555198',
  '6806555282',
  '6806555344',
];
const subscriptions = [];
for (const id of subscriptionIds) {
  const subscription = await request(`/v1/subscriptions/${id}`, { allow: [404] });
  if (!subscription.data) {
    subscriptions.push({ id, exists: false });
    continue;
  }
  const screenshot = await request(
    `/v1/subscriptions/${id}/appStoreReviewScreenshot`,
    { allow: [404] },
  );
  const localizationsResult = await request(
    `/v1/subscriptions/${id}/subscriptionLocalizations?limit=200`,
    { allow: [404] },
  );
  const reviewAsset = screenshot.data?.attributes.imageAsset ?? null;
  const downloaded = reviewAsset
    ? await saveReviewScreenshot(reviewAsset, `subscription-${subscription.data.attributes.productId}.png`)
    : false;
  subscriptions.push({
    id,
    exists: true,
    referenceName: subscription.data.attributes.name,
    state: subscription.data.attributes.state,
    productId: subscription.data.attributes.productId,
    period: subscription.data.attributes.subscriptionPeriod,
    reviewNotePresent: nonEmpty(subscription.data.attributes.reviewNote),
    reviewScreenshot: screenshot.data ? {
      state: screenshot.data.attributes.assetDeliveryState?.state ?? null,
      width: reviewAsset?.width ?? null,
      height: reviewAsset?.height ?? null,
      hasFileName: nonEmpty(screenshot.data.attributes.fileName),
      downloaded,
    } : null,
    localizations: (localizationsResult.data ?? []).map((item) => ({
      locale: item.attributes.locale,
      namePresent: nonEmpty(item.attributes.name),
      descriptionPresent: nonEmpty(item.attributes.description),
    })),
  });
}

const groupId = '22343739';
const group = await request(`/v1/subscriptionGroups/${groupId}`, { allow: [404] });
const groupLocalizations = group.data
  ? await request(`/v1/subscriptionGroups/${groupId}/subscriptionGroupLocalizations?limit=200`, { allow: [404] })
  : { data: [] };

const iapsResponse = await request(
  `/v1/apps/${APP_ID}/inAppPurchasesV2?limit=200&include=appStoreReviewScreenshot,inAppPurchaseLocalizations`,
  { allow: [404] },
);
const includedById = new Map((iapsResponse.included ?? []).map((item) => [item.id, item]));
const inAppPurchases = [];
for (const item of iapsResponse.data ?? []) {
  const screenshotId = item.relationships?.appStoreReviewScreenshot?.data?.id;
  const screenshot = screenshotId ? includedById.get(screenshotId) : null;
  const localizationIds = item.relationships?.inAppPurchaseLocalizations?.data?.map((entry) => entry.id) ?? [];
  const localizations = localizationIds.map((id) => includedById.get(id)).filter(Boolean);
  const reviewAsset = screenshot?.attributes.imageAsset ?? null;
  const downloaded = reviewAsset
    ? await saveReviewScreenshot(reviewAsset, `iap-${item.attributes.productId}.png`)
    : false;
  inAppPurchases.push({
    id: item.id,
    productId: item.attributes.productId,
    referenceName: item.attributes.name,
    type: item.attributes.inAppPurchaseType,
    state: item.attributes.state,
    reviewNotePresent: nonEmpty(item.attributes.reviewNote),
    reviewScreenshot: screenshot ? {
      state: screenshot.attributes.assetDeliveryState?.state ?? null,
      width: reviewAsset?.width ?? null,
      height: reviewAsset?.height ?? null,
      hasFileName: nonEmpty(screenshot.attributes.fileName),
      downloaded,
    } : null,
    localizations: localizations.map((localization) => ({
      locale: localization.attributes.locale,
      namePresent: nonEmpty(localization.attributes.name),
      descriptionPresent: nonEmpty(localization.attributes.description),
    })),
  });
}

const result = {
  generatedAt: new Date().toISOString(),
  appId: APP_ID,
  version: {
    id: version.id,
    versionString: version.attributes.versionString,
    platform: version.attributes.platform,
    state: version.attributes.appStoreState,
    buildAttached: Boolean(buildResult.data),
  },
  appInformation: appInfoReports,
  localizations: localizationReports,
  appReview: review,
  subscriptionGroup: {
    id: groupId,
    exists: Boolean(group.data),
    referenceNamePresent: nonEmpty(group.data?.attributes.referenceName),
    localizations: (groupLocalizations.data ?? []).map((item) => ({
      locale: item.attributes.locale,
      namePresent: nonEmpty(item.attributes.name),
      customAppNamePresent: nonEmpty(item.attributes.customAppName),
      state: item.attributes.state ?? null,
    })),
  },
  subscriptions,
  inAppPurchases,
};

process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
