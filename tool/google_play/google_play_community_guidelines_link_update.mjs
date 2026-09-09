#!/usr/bin/env node

/**
 * Narrow Google Play mutation for the Community Guidelines link.
 *
 * Android Publisher has no dedicated Community Guidelines URL field. The URL
 * belongs in the en-GB full store description. The script commits only that
 * listing value, then verifies the production track and app details are
 * byte-for-byte unchanged in a fresh transient edit. It never changes a track.
 */

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const PACKAGE_NAME = 'com.bilhealth.bodyintelligencelog';
const LOCALE = 'en-GB';
const POLICY_URL = 'https://www.bilhealth.com/community-guidelines';
const POLICY_LINE = `Community Guidelines: ${POLICY_URL}`;
const API_ROOT = 'https://androidpublisher.googleapis.com/androidpublisher/v3';
const SCOPE = 'https://www.googleapis.com/auth/androidpublisher';

function argument(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : null;
}

function base64Url(value) {
  return Buffer.from(value).toString('base64url');
}

function hash(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

async function accessToken(credentials) {
  const now = Math.floor(Date.now() / 1000);
  const tokenUri = credentials.token_uri || 'https://oauth2.googleapis.com/token';
  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64Url(JSON.stringify({
    iss: credentials.client_email,
    scope: SCOPE,
    aud: tokenUri,
    iat: now,
    exp: now + 3600,
  }));
  const signingInput = `${header}.${claims}`;
  const signature = crypto
    .sign('RSA-SHA256', Buffer.from(signingInput), credentials.private_key)
    .toString('base64url');
  const response = await fetch(tokenUri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${signingInput}.${signature}`,
    }),
  });
  const body = await response.json().catch(() => null);
  if (!response.ok || !body?.access_token) {
    throw new Error(`GOOGLE_OAUTH_FAILED:${response.status}`);
  }
  return body.access_token;
}

async function request(token, method, resource, body) {
  const response = await fetch(`${API_ROOT}${resource}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: 'application/json',
      ...(body === undefined ? {} : { 'Content-Type': 'application/json' }),
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  const text = await response.text();
  const parsed = text ? JSON.parse(text) : null;
  if (!response.ok) {
    throw new Error(`${method}_${response.status}:${parsed?.error?.status ?? 'UNKNOWN'}`);
  }
  return parsed;
}

const credentialsPath = argument('--credentials');
const outputPath = argument('--output');
if (
  !credentialsPath ||
  !outputPath ||
  argument('--confirm-url') !== POLICY_URL ||
  argument('--confirm-boundary') !== 'full-description-only-no-release'
) {
  throw new Error(
    `--credentials, --output, --confirm-url ${POLICY_URL}, and ` +
      '--confirm-boundary full-description-only-no-release are required',
  );
}
const output = path.resolve(outputPath);
if (path.parse(output).root.toUpperCase() !== 'G:\\') {
  throw new Error(`Evidence output must stay on G:, received ${output}`);
}
const credentials = JSON.parse(fs.readFileSync(path.resolve(credentialsPath), 'utf8'));
if (
  credentials.type !== 'service_account' ||
  !credentials.client_email ||
  !credentials.private_key
) {
  throw new Error('Credential file is not a complete Google service account');
}

const token = await accessToken(credentials);
const packagePath = `/applications/${encodeURIComponent(PACKAGE_NAME)}`;
let editId;
let committed = false;
let changed = false;
let beforeListing;
let beforeDetails;
let beforeProductionTrack;

try {
  const edit = await request(token, 'POST', `${packagePath}/edits`, {});
  editId = edit.id;
  if (!editId) throw new Error('EDIT_ID_MISSING');
  const editPath = `${packagePath}/edits/${encodeURIComponent(editId)}`;
  const listingPath = `${editPath}/listings/${encodeURIComponent(LOCALE)}`;
  [beforeListing, beforeDetails, beforeProductionTrack] = await Promise.all([
    request(token, 'GET', listingPath),
    request(token, 'GET', `${editPath}/details`),
    request(token, 'GET', `${editPath}/tracks/production`),
  ]);
  if (beforeListing?.title !== 'Body Intelligence Log') {
    throw new Error('Unexpected Google Play title');
  }
  const beforeDescription = beforeListing.fullDescription ?? '';
  const targetDescription = beforeDescription.includes(POLICY_URL)
    ? beforeDescription
    : `${beforeDescription.trimEnd()}\n\n${POLICY_LINE}`;
  if (targetDescription.length > 4000) {
    throw new Error(`Full description would exceed 4000 characters: ${targetDescription.length}`);
  }
  if (targetDescription !== beforeDescription) {
    if (!process.argv.includes('--apply')) {
      throw new Error('Mutation refused without --apply');
    }
    await request(token, 'PUT', listingPath, {
      title: beforeListing.title,
      fullDescription: targetDescription,
      shortDescription: beforeListing.shortDescription,
      ...(beforeListing.video === undefined ? {} : { video: beforeListing.video }),
    });
    await request(token, 'POST', `${editPath}:commit`, {});
    committed = true;
    changed = true;
  }
} finally {
  if (editId && !committed) {
    await request(
      token,
      'DELETE',
      `${packagePath}/edits/${encodeURIComponent(editId)}`,
    ).catch(() => null);
  }
}

const verifyEdit = await request(token, 'POST', `${packagePath}/edits`, {});
const verifyEditId = verifyEdit.id;
if (!verifyEditId) throw new Error('VERIFY_EDIT_ID_MISSING');
let afterListing;
let afterDetails;
let afterProductionTrack;
try {
  const verifyPath = `${packagePath}/edits/${encodeURIComponent(verifyEditId)}`;
  [afterListing, afterDetails, afterProductionTrack] = await Promise.all([
    request(token, 'GET', `${verifyPath}/listings/${encodeURIComponent(LOCALE)}`),
    request(token, 'GET', `${verifyPath}/details`),
    request(token, 'GET', `${verifyPath}/tracks/production`),
  ]);
} finally {
  await request(
    token,
    'DELETE',
    `${packagePath}/edits/${encodeURIComponent(verifyEditId)}`,
  );
}

if (!afterListing?.fullDescription?.includes(POLICY_LINE)) {
  throw new Error('Community Guidelines link read-back failed');
}
if (
  afterListing.title !== beforeListing.title ||
  afterListing.shortDescription !== beforeListing.shortDescription ||
  afterListing.video !== beforeListing.video ||
  JSON.stringify(afterDetails) !== JSON.stringify(beforeDetails) ||
  JSON.stringify(afterProductionTrack) !== JSON.stringify(beforeProductionTrack)
) {
  throw new Error('Protected Google Play listing or release metadata changed unexpectedly');
}

const beforeDescription = beforeListing.fullDescription ?? '';
const afterDescription = afterListing.fullDescription ?? '';
const evidence = {
  generatedAt: new Date().toISOString(),
  packageName: PACKAGE_NAME,
  locale: LOCALE,
  field: 'listing.fullDescription',
  policyUrl: POLICY_URL,
  changed,
  mutationPerformed: changed,
  editCommitted: committed,
  beforeDescriptionLength: beforeDescription.length,
  afterDescriptionLength: afterDescription.length,
  beforeDescriptionSha256: hash(beforeDescription),
  afterDescriptionSha256: hash(afterDescription),
  linkVerifiedByReadback: true,
  titlePreserved: true,
  shortDescriptionPreserved: true,
  videoPreserved: true,
  appDetailsPreserved: true,
  productionTrackPreserved: true,
  trackMutationPerformed: false,
  artifactUploadPerformed: false,
  submitOrReleasePerformed: false,
};
fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, `${JSON.stringify(evidence, null, 2)}\n`, 'utf8');
console.log(`GOOGLE_PLAY_COMMUNITY_GUIDELINES_LINK=${POLICY_URL}`);
console.log(`MUTATION_PERFORMED=${changed}`);
console.log('PRODUCTION_TRACK_PRESERVED=true');
console.log('SUBMIT_OR_RELEASE_PERFORMED=false');
console.log(`EVIDENCE=${output}`);
