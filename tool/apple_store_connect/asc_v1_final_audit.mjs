#!/usr/bin/env node

/**
 * Read-only App Store Connect v1.0 release-metadata audit for BIL.
 * Sensitive reviewer values are represented only as presence booleans.
 */

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

import { clientFromEnvironment } from './asc_catalog_sync.mjs';

const APP_ID = '6805349703';
const VERSION = '1.0.0';
const outputIndex = process.argv.indexOf('--output');
const output = outputIndex >= 0 ? process.argv[outputIndex + 1] : null;
if (!output) throw new Error('--output is required');
const target = path.resolve(output);
if (path.parse(target).root.toUpperCase() !== 'G:\\') {
  throw new Error(`Audit output must stay on G:, received ${target}`);
}

const client = clientFromEnvironment();
const nonEmpty = (value) => typeof value === 'string' && value.trim().length > 0;
const capture = async (work) => {
  try {
    return { ok: true, value: await work() };
  } catch (error) {
    return { ok: false, error: String(error?.message ?? error) };
  }
};
const getRelated = async (resource, relationship, suffix = '') => {
  const link = resource.relationships?.[relationship]?.links?.related;
  if (!link) return { ok: false, error: `Missing ${relationship} related link` };
  return capture(() => client.request('GET', `${link}${suffix}`));
};
const summarizeLocalization = (item) => ({
  id: item.id,
  locale: item.attributes?.locale ?? null,
  attributes: item.attributes,
});

const appResponse = await client.request('GET', `/v1/apps/${APP_ID}`);
const app = appResponse.data;
const versions = await client.all(`/v1/apps/${APP_ID}/appStoreVersions?filter[platform]=IOS&limit=200`);
const version = versions.find((item) => item.attributes?.versionString === VERSION);
if (!version) throw new Error(`Version ${VERSION} was not found`);
const builds = await capture(() => client.all(`/v1/builds?filter[app]=${APP_ID}&limit=200`));
const preReleaseVersions = await capture(() =>
  client.all(`/v1/apps/${APP_ID}/preReleaseVersions?limit=200`),
);

const appInfos = await client.all(`/v1/apps/${APP_ID}/appInfos?limit=200`);
const appInformation = [];
for (const info of appInfos) {
  const localizations = await client.all(`/v1/appInfos/${info.id}/appInfoLocalizations?limit=200`);
  appInformation.push({
    id: info.id,
    attributes: info.attributes,
    localizations: localizations.map(summarizeLocalization),
    ageRatingDeclaration: await getRelated(info, 'ageRatingDeclaration'),
    primaryCategory: await getRelated(info, 'primaryCategory'),
    secondaryCategory: await getRelated(info, 'secondaryCategory'),
  });
}

const versionLocalizations = await client.all(
  `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=200`,
);
const localizationReports = [];
for (const localization of versionLocalizations) {
  const sets = await client.all(
    `/v1/appStoreVersionLocalizations/${localization.id}/appScreenshotSets?limit=200`,
  );
  const screenshotSets = [];
  for (const set of sets) {
    const screenshots = await client.all(`/v1/appScreenshotSets/${set.id}/appScreenshots?limit=200`);
    screenshotSets.push({
      id: set.id,
      displayType: set.attributes?.screenshotDisplayType ?? null,
      count: screenshots.length,
      states: screenshots.map((shot) => shot.attributes?.assetDeliveryState?.state ?? null),
    });
  }
  localizationReports.push({
    ...summarizeLocalization(localization),
    requiredPresence: {
      description: nonEmpty(localization.attributes?.description),
      keywords: nonEmpty(localization.attributes?.keywords),
      supportUrl: nonEmpty(localization.attributes?.supportUrl),
    },
    optionalPresence: {
      marketingUrl: nonEmpty(localization.attributes?.marketingUrl),
      promotionalText: nonEmpty(localization.attributes?.promotionalText),
      whatsNew: nonEmpty(localization.attributes?.whatsNew),
    },
    screenshotSets,
  });
}

const review = await getRelated(version, 'appStoreReviewDetail');
let reviewSummary = review;
if (review.ok && review.value?.data) {
  const detail = review.value.data;
  const attrs = detail.attributes ?? {};
  const attachments = await client.all(
    `/v1/appStoreReviewDetails/${detail.id}/appStoreReviewAttachments?limit=200`,
  );
  reviewSummary = {
    ok: true,
    value: {
      id: detail.id,
      contact: {
        firstName: nonEmpty(attrs.contactFirstName),
        lastName: nonEmpty(attrs.contactLastName),
        phone: nonEmpty(attrs.contactPhone),
        email: nonEmpty(attrs.contactEmail),
      },
      demoAccountRequired: attrs.demoAccountRequired ?? null,
      demoAccountNamePresent: nonEmpty(attrs.demoAccountName),
      demoAccountPasswordPresent: nonEmpty(attrs.demoAccountPassword),
      notesPresent: nonEmpty(attrs.notes),
      attachmentCount: attachments.length,
    },
  };
}

const groups = await client.all(`/v1/apps/${APP_ID}/subscriptionGroups?limit=200`);
const groupReports = [];
for (const group of groups) {
  const localizations = await client.all(
    `/v1/subscriptionGroups/${group.id}/subscriptionGroupLocalizations?limit=200`,
  );
  const subscriptions = await client.all(`/v1/subscriptionGroups/${group.id}/subscriptions?limit=200`);
  groupReports.push({
    id: group.id,
    attributes: group.attributes,
    localizations: localizations.map(summarizeLocalization),
    subscriptions: subscriptions.map((item) => ({ id: item.id, attributes: item.attributes })),
  });
}

const inAppPurchases = await client.all(`/v1/apps/${APP_ID}/inAppPurchasesV2?limit=200`);
const result = {
  generatedAt: new Date().toISOString(),
  mode: 'read-only',
  mutationPerformed: false,
  app: { id: app.id, attributes: app.attributes },
  builds: builds.ok
    ? {
        ok: true,
        value: builds.value.map((item) => ({
          id: item.id,
          version: item.attributes?.version ?? null,
          uploadedDate: item.attributes?.uploadedDate ?? null,
          expirationDate: item.attributes?.expirationDate ?? null,
          expired: item.attributes?.expired ?? null,
          processingState: item.attributes?.processingState ?? null,
          minOsVersion: item.attributes?.minOsVersion ?? null,
          usesNonExemptEncryption: item.attributes?.usesNonExemptEncryption ?? null,
        })),
      }
    : builds,
  preReleaseVersions: preReleaseVersions.ok
    ? {
        ok: true,
        value: preReleaseVersions.value.map((item) => ({
          id: item.id,
          version: item.attributes?.version ?? null,
          platform: item.attributes?.platform ?? null,
        })),
      }
    : preReleaseVersions,
  version: {
    id: version.id,
    attributes: version.attributes,
    build: await getRelated(version, 'build'),
    appStoreVersionSubmission: await getRelated(version, 'appStoreVersionSubmission'),
    appStoreVersionPhasedRelease: await getRelated(version, 'appStoreVersionPhasedRelease'),
    appClipDefaultExperience: await getRelated(version, 'appClipDefaultExperience'),
    localizations: localizationReports,
    appReview: reviewSummary,
  },
  appInformation,
  subscriptionGroups: groupReports,
  inAppPurchases: inAppPurchases.map((item) => ({ id: item.id, attributes: item.attributes })),
};

fs.mkdirSync(path.dirname(target), { recursive: true });
fs.writeFileSync(target, `${JSON.stringify(result, null, 2)}\n`, 'utf8');
process.stdout.write(`Wrote ${target}\n`);
