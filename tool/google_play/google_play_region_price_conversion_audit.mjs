#!/usr/bin/env node

/**
 * Non-persistent Google Play regional-price conversion audit.
 *
 * This calls only monetization.convertRegionPrices. Google documents that the
 * resource has no persistent data; the method calculates current conversions
 * and does not update a product, base plan, offer, listing, track, or release.
 * The report omits service-account identity, private-key data and access tokens.
 */

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const PACKAGE_NAME = 'com.bilhealth.bodyintelligencelog';
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
  const parsed = await response.json().catch(() => null);
  if (!response.ok || !parsed?.access_token) {
    throw new Error(`GOOGLE_OAUTH_FAILED:${response.status}`);
  }
  return parsed.access_token;
}

function money(units, nanos = 0) {
  return { currencyCode: 'USD', units: String(units), nanos };
}

function safeMoney(value) {
  if (!value) return null;
  return {
    currencyCode: value.currencyCode ?? null,
    units: value.units ?? '0',
    nanos: value.nanos ?? 0,
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

const credentials = JSON.parse(fs.readFileSync(credentialsPath, 'utf8'));
const token = await accessToken(credentials);
const endpoint = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE_NAME}/pricing:convertRegionPrices`;
const inputs = [
  { label: 'ai-monthly-reference', price: money(5, 990000000) },
  { label: 'ai-annual-reference', price: money(35, 990000000) },
  { label: 'boost-reference', price: money(4, 990000000) },
];
const conversions = [];

for (const input of inputs) {
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: 'application/json',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ price: input.price }),
  });
  const parsed = await response.json().catch(() => null);
  if (!response.ok) {
    conversions.push({ label: input.label, input: input.price, httpStatus: response.status, by: null });
    continue;
  }
  conversions.push({
    label: input.label,
    input: input.price,
    httpStatus: response.status,
    by: safeMoney(parsed?.convertedRegionPrices?.BY?.price),
    regionVersion: parsed?.regionVersion?.version ?? null,
  });
}

const report = {
  generatedAt: new Date().toISOString(),
  mode: 'NON_PERSISTENT_PRICE_CONVERSION_ONLY',
  packageName: PACKAGE_NAME,
  mutationPerformed: false,
  conversions,
};
fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
console.log(JSON.stringify({ output, conversions }, null, 2));
