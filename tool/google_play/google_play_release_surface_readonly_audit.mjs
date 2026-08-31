#!/usr/bin/env node

/**
 * Read-only release-surface audit for Google Play.
 *
 * Google exposes listings/details/tracks/bundles through a transient App Edit.
 * This tool creates an edit, performs GET requests only inside it, never
 * validates or commits it, and deletes that exact transient edit in `finally`.
 * The report omits OAuth/service-account data and image preview URLs.
 */

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const PACKAGE_NAME = 'com.bilhealth.bodyintelligencelog';
const API_ROOT = 'https://androidpublisher.googleapis.com/androidpublisher/v3';
const SCOPE = 'https://www.googleapis.com/auth/androidpublisher';
const IMAGE_TYPES = [
  'icon',
  'featureGraphic',
  'phoneScreenshots',
  'sevenInchScreenshots',
  'tenInchScreenshots',
  'tvBanner',
  'tvScreenshots',
  'wearScreenshots',
];

function argument(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : null;
}

function base64Url(value) {
  return Buffer.from(value).toString('base64url');
}

function safeError(status, parsed) {
  return {
    status,
    code: parsed?.error?.code ?? status,
    statusText: parsed?.error?.status ?? null,
    message: parsed?.error?.message ?? null,
  };
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
  const parsed = await response.json().catch(() => null);
  if (!response.ok || !parsed?.access_token) {
    throw new Error(`GOOGLE_OAUTH_FAILED:${response.status}`);
  }
  return parsed.access_token;
}

class Client {
  constructor(token) {
    this.token = token;
  }

  async request(method, resource, body) {
    const response = await fetch(`${API_ROOT}${resource}`, {
      method,
      headers: {
        Authorization: `Bearer ${this.token}`,
        Accept: 'application/json',
        ...(body === undefined ? {} : { 'Content-Type': 'application/json' }),
      },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
    const text = await response.text();
    const parsed = text ? JSON.parse(text) : null;
    if (!response.ok) {
      return { ok: false, status: response.status, error: safeError(response.status, parsed) };
    }
    return { ok: true, status: response.status, value: parsed };
  }

  get(resource) {
    return this.request('GET', resource);
  }

  post(resource, body = {}) {
    return this.request('POST', resource, body);
  }

  delete(resource) {
    return this.request('DELETE', resource);
  }
}

function requireOk(result, label) {
  if (!result.ok) {
    throw new Error(`${label}_FAILED:${result.status}:${result.error?.statusText ?? 'UNKNOWN'}`);
  }
  return result.value;
}

function cleanResult(result) {
  return result.ok
    ? { ok: true, httpStatus: result.status, value: result.value }
    : { ok: false, httpStatus: result.status, error: result.error };
}

function summarizeImages(result) {
  if (!result.ok) return cleanResult(result);
  return {
    ok: true,
    httpStatus: result.status,
    imageCount: result.value?.images?.length ?? 0,
    images: (result.value?.images ?? []).map((image) => ({
      id: image.id,
      sha1: image.sha1,
      sha256: image.sha256,
    })),
  };
}

const credentialsPath = argument('--credentials');
const outputPath = argument('--output');
if (!credentialsPath || !outputPath) {
  throw new Error('--credentials and --output are required');
}
const output = path.resolve(outputPath);
if (path.parse(output).root.toUpperCase() !== 'G:\\') {
  throw new Error(`Audit output must stay on G:, received ${output}`);
}
const credentials = JSON.parse(fs.readFileSync(path.resolve(credentialsPath), 'utf8'));
if (credentials.type !== 'service_account' || !credentials.client_email ||
    !credentials.private_key) {
  throw new Error('Credential file is not a complete Google service account');
}

const client = new Client(await accessToken(credentials));
const packagePath = `/applications/${encodeURIComponent(PACKAGE_NAME)}`;
const insert = await client.post(`${packagePath}/edits`, {});
const edit = requireOk(insert, 'EDIT_INSERT');
const editId = edit.id;
if (!editId) throw new Error('EDIT_ID_MISSING');
const editPath = `${packagePath}/edits/${encodeURIComponent(editId)}`;
let report;
let deleteResult;

try {
  const [details, listings, tracks, bundles, apks] = await Promise.all([
    client.get(`${editPath}/details`),
    client.get(`${editPath}/listings`),
    client.get(`${editPath}/tracks`),
    client.get(`${editPath}/bundles`),
    client.get(`${editPath}/apks`),
  ]);
  const locales = listings.ok
    ? (listings.value?.listings ?? []).map((listing) => listing.language)
    : [];
  const images = [];
  for (const locale of locales) {
    for (const imageType of IMAGE_TYPES) {
      const result = await client.get(
        `${editPath}/listings/${encodeURIComponent(locale)}/${imageType}`,
      );
      images.push({ locale, imageType, result: summarizeImages(result) });
    }
  }
  const countryAvailability = [];
  if (tracks.ok) {
    for (const track of tracks.value?.tracks ?? []) {
      const result = await client.get(
        `${editPath}/countryAvailability/${encodeURIComponent(track.track)}`,
      );
      countryAvailability.push({
        track: track.track,
        result: result.ok ? {
          ok: true,
          httpStatus: result.status,
          syncWithProduction: result.value?.syncWithProduction ?? null,
          countryCount: result.value?.countries?.length ?? 0,
          countries: result.value?.countries ?? [],
        } : cleanResult(result),
      });
    }
  }
  report = {
    generatedAt: new Date().toISOString(),
    mode: 'transient-edit-read-only-no-commit',
    packageName: PACKAGE_NAME,
    mutationPerformed: false,
    transientEdit: {
      insertHttpStatus: insert.status,
      expiryTimeSeconds: edit.expiryTimeSeconds ?? null,
      committed: false,
    },
    details: cleanResult(details),
    listings: cleanResult(listings),
    tracks: cleanResult(tracks),
    bundles: cleanResult(bundles),
    apks: cleanResult(apks),
    images,
    countryAvailability,
  };
} finally {
  deleteResult = await client.delete(editPath);
}

report.transientEdit.deleted = deleteResult.ok;
report.transientEdit.deleteHttpStatus = deleteResult.status;
if (!deleteResult.ok) report.transientEdit.deleteError = deleteResult.error;
fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
if (!deleteResult.ok) throw new Error(`TRANSIENT_EDIT_DELETE_FAILED:${deleteResult.status}`);
process.stdout.write(`Wrote ${output}\n`);
