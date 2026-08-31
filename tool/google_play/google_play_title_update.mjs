#!/usr/bin/env node

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const PACKAGE_NAME = 'com.bilhealth.bodyintelligencelog';
const LOCALE = 'en-GB';
const TARGET_TITLE = 'Body Intelligence Log';
const PREVIOUS_TITLE = 'BIL - Body Intelligence Log';
const API_ROOT = 'https://androidpublisher.googleapis.com/androidpublisher/v3';
const SCOPE = 'https://www.googleapis.com/auth/androidpublisher';

function argument(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : null;
}

function base64Url(value) {
  return Buffer.from(value).toString('base64url');
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
    const message = String(parsed?.error?.message ?? 'UNKNOWN')
      .replaceAll(/\s+/g, ' ')
      .slice(0, 500);
    throw new Error(
      `${method}_${response.status}:${parsed?.error?.status ?? 'UNKNOWN'}:${message}`,
    );
  }
  return { status: response.status, value: parsed };
}

const credentialsPath = argument('--credentials');
const outputPath = argument('--output');
const confirmedTitle = argument('--confirm-title');
const confirmedBoundary = argument('--confirm-review-boundary');
if (
  !credentialsPath ||
  !outputPath ||
  confirmedTitle !== TARGET_TITLE ||
  confirmedBoundary !== 'metadata-only-no-production-release'
) {
  throw new Error(
    `--credentials, --output, --confirm-title "${TARGET_TITLE}" and ` +
      '--confirm-review-boundary "metadata-only-no-production-release" are required',
  );
}
const output = path.resolve(outputPath);
if (path.parse(output).root.toUpperCase() !== 'G:\\') {
  throw new Error(`Evidence output must stay on G:, received ${output}`);
}
const credentials = JSON.parse(
  fs.readFileSync(path.resolve(credentialsPath), 'utf8'),
);
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
let previousTitle;

try {
  const inserted = await request(token, 'POST', `${packagePath}/edits`, {});
  editId = inserted.value?.id;
  if (!editId) throw new Error('EDIT_ID_MISSING');
  const editPath = `${packagePath}/edits/${encodeURIComponent(editId)}`;
  const listingPath = `${editPath}/listings/${encodeURIComponent(LOCALE)}`;
  const productionTrack = (
    await request(token, 'GET', `${editPath}/tracks/production`)
  ).value;
  if ((productionTrack?.releases ?? []).length !== 0) {
    throw new Error('PRODUCTION_TRACK_NOT_EMPTY_ABORTING_METADATA_COMMIT');
  }
  const listing = (await request(token, 'GET', listingPath)).value;
  previousTitle = listing?.title;
  if (previousTitle !== TARGET_TITLE) {
    if (previousTitle !== PREVIOUS_TITLE) {
      throw new Error(`UNEXPECTED_CURRENT_TITLE:${previousTitle ?? 'MISSING'}`);
    }
    await request(token, 'PUT', listingPath, {
      title: TARGET_TITLE,
      fullDescription: listing.fullDescription,
      shortDescription: listing.shortDescription,
      ...(listing.video === undefined ? {} : { video: listing.video }),
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

const verifyInsert = await request(token, 'POST', `${packagePath}/edits`, {});
const verifyEditId = verifyInsert.value?.id;
if (!verifyEditId) throw new Error('VERIFY_EDIT_ID_MISSING');
let verifiedTitle;
try {
  verifiedTitle = (
    await request(
      token,
      'GET',
      `${packagePath}/edits/${encodeURIComponent(verifyEditId)}/listings/${encodeURIComponent(LOCALE)}`,
    )
  ).value?.title;
} finally {
  await request(
    token,
    'DELETE',
    `${packagePath}/edits/${encodeURIComponent(verifyEditId)}`,
  );
}
if (verifiedTitle !== TARGET_TITLE) {
  throw new Error(`TITLE_VERIFICATION_FAILED:${verifiedTitle ?? 'MISSING'}`);
}

fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(
  output,
  `${JSON.stringify({
    generatedAt: new Date().toISOString(),
    packageName: PACKAGE_NAME,
    locale: LOCALE,
    previousTitle,
    targetTitle: TARGET_TITLE,
    verifiedTitle,
    changed,
    committed,
    changesSentForReview: changed,
    productionReleasePresentAtCommit: false,
    publicProductionPublishPerformed: false,
  }, null, 2)}\n`,
  'utf8',
);
console.log(`GOOGLE_PLAY_TITLE=${verifiedTitle}`);
console.log(`MUTATION_PERFORMED=${changed}`);
console.log(`SENT_FOR_REVIEW=${changed}`);
console.log('PUBLIC_PRODUCTION_PUBLISH=false');
console.log(`EVIDENCE=${output}`);
