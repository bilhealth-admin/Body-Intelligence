#!/usr/bin/env node

/**
 * Narrow App Store Connect mutation for the Community Guidelines link.
 *
 * App Store Connect has no dedicated Community Guidelines URL attribute. The
 * public URL therefore belongs in the en-US version description. This script
 * PATCHes only that description and verifies that release/review/support
 * metadata did not change. It never submits a version or changes its build.
 */

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

import { clientFromEnvironment } from './asc_catalog_sync.mjs';

const VERSION_ID = '7a132506-d5a8-4810-a51f-b2dc2bd636cf';
const LOCALIZATION_ID = '3866ba6c-b637-4f70-9c53-d6274c37bc62';
const POLICY_URL = 'https://www.bilhealth.com/community-guidelines';
const POLICY_LINE = `Community Guidelines: ${POLICY_URL}`;

function argument(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : null;
}

function hash(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function reviewPresence(attributes = {}) {
  const present = (value) => typeof value === 'string' && value.trim().length > 0;
  return {
    contactFirstName: present(attributes.contactFirstName),
    contactLastName: present(attributes.contactLastName),
    contactPhone: present(attributes.contactPhone),
    contactEmail: present(attributes.contactEmail),
    demoAccountRequired: attributes.demoAccountRequired ?? null,
    demoAccountName: present(attributes.demoAccountName),
    demoAccountPassword: present(attributes.demoAccountPassword),
    notes: present(attributes.notes),
  };
}

const outputPath = argument('--output');
const confirmedUrl = argument('--confirm-url');
const confirmedBoundary = argument('--confirm-boundary');
if (
  !outputPath ||
  confirmedUrl !== POLICY_URL ||
  confirmedBoundary !== 'description-only-no-submit'
) {
  throw new Error(
    `--output, --confirm-url ${POLICY_URL}, and ` +
      '--confirm-boundary description-only-no-submit are required',
  );
}
const output = path.resolve(outputPath);
if (path.parse(output).root.toUpperCase() !== 'G:\\') {
  throw new Error(`Evidence output must stay on G:, received ${output}`);
}

const client = clientFromEnvironment();
const versionEndpoint =
  `/v1/appStoreVersions/${VERSION_ID}` +
  '?fields[appStoreVersions]=versionString,appStoreState,releaseType';
const localizationEndpoint =
  `/v1/appStoreVersionLocalizations/${LOCALIZATION_ID}` +
  '?fields[appStoreVersionLocalizations]=locale,description,supportUrl,marketingUrl,promotionalText,keywords';
const reviewEndpoint = `/v1/appStoreVersions/${VERSION_ID}/appStoreReviewDetail`;

const beforeVersion = (await client.request('GET', versionEndpoint)).data;
const beforeLocalization = (await client.request('GET', localizationEndpoint)).data;
const beforeReview = (await client.request('GET', reviewEndpoint)).data;
if (
  beforeVersion?.attributes?.versionString !== '1.0.0' ||
  beforeVersion?.attributes?.releaseType !== 'MANUAL' ||
  beforeLocalization?.attributes?.locale !== 'en-US'
) {
  throw new Error('Unexpected App Store version, release type, or locale');
}

const beforeDescription = beforeLocalization.attributes.description ?? '';
const targetDescription = beforeDescription.includes(POLICY_URL)
  ? beforeDescription
  : `${beforeDescription.trimEnd()}\n\n${POLICY_LINE}`;
if (targetDescription.length > 4000) {
  throw new Error(`Description would exceed 4000 characters: ${targetDescription.length}`);
}

let changed = false;
if (targetDescription !== beforeDescription) {
  if (!process.argv.includes('--apply') || process.env.ASC_ALLOW_MUTATION !== 'YES') {
    throw new Error('Mutation refused without --apply and ASC_ALLOW_MUTATION=YES');
  }
  await client.request('PATCH', `/v1/appStoreVersionLocalizations/${LOCALIZATION_ID}`, {
    data: {
      type: 'appStoreVersionLocalizations',
      id: LOCALIZATION_ID,
      attributes: { description: targetDescription },
    },
  });
  changed = true;
}

const afterVersion = (await client.request('GET', versionEndpoint)).data;
const afterLocalization = (await client.request('GET', localizationEndpoint)).data;
const afterReview = (await client.request('GET', reviewEndpoint)).data;
const afterDescription = afterLocalization?.attributes?.description ?? '';
const beforeReviewPresence = reviewPresence(beforeReview?.attributes);
const afterReviewPresence = reviewPresence(afterReview?.attributes);
if (!afterDescription.includes(POLICY_LINE)) {
  throw new Error('Community Guidelines link read-back failed');
}
if (
  afterVersion?.attributes?.releaseType !== 'MANUAL' ||
  afterVersion?.attributes?.versionString !== beforeVersion.attributes.versionString ||
  afterLocalization?.attributes?.supportUrl !== beforeLocalization.attributes.supportUrl ||
  afterLocalization?.attributes?.marketingUrl !== beforeLocalization.attributes.marketingUrl ||
  JSON.stringify(afterReviewPresence) !== JSON.stringify(beforeReviewPresence)
) {
  throw new Error('Protected App Store metadata changed unexpectedly');
}

const evidence = {
  generatedAt: new Date().toISOString(),
  appStoreVersionId: VERSION_ID,
  localizationId: LOCALIZATION_ID,
  locale: 'en-US',
  field: 'appStoreVersionLocalization.description',
  policyUrl: POLICY_URL,
  changed,
  mutationPerformed: changed,
  beforeDescriptionLength: beforeDescription.length,
  afterDescriptionLength: afterDescription.length,
  beforeDescriptionSha256: hash(beforeDescription),
  afterDescriptionSha256: hash(afterDescription),
  linkVerifiedByReadback: true,
  releaseTypeBefore: beforeVersion.attributes.releaseType,
  releaseTypeAfter: afterVersion.attributes.releaseType,
  appStoreStateBefore: beforeVersion.attributes.appStoreState,
  appStoreStateAfter: afterVersion.attributes.appStoreState,
  supportUrlPreserved: true,
  marketingUrlPreserved: true,
  reviewCredentialPresencePreserved: true,
  versionSubmissionPerformed: false,
  buildChanged: false,
  releasePerformed: false,
};
fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, `${JSON.stringify(evidence, null, 2)}\n`, 'utf8');
console.log(`APPLE_COMMUNITY_GUIDELINES_LINK=${POLICY_URL}`);
console.log(`MUTATION_PERFORMED=${changed}`);
console.log('REVIEW_CREDENTIAL_PRESENCE_PRESERVED=true');
console.log('RELEASE_TYPE=MANUAL');
console.log('SUBMIT_OR_RELEASE_PERFORMED=false');
console.log(`EVIDENCE=${output}`);
