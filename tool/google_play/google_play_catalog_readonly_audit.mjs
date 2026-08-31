#!/usr/bin/env node

/**
 * GET-only Google Play Android Publisher catalog audit for BIL.
 *
 * The report intentionally omits service-account identity, private-key data,
 * OAuth assertions and access tokens. The client refuses every HTTP method
 * except GET after obtaining the short-lived OAuth token.
 */

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const PACKAGE_NAME = 'com.bilhealth.bodyintelligencelog';
const API_ROOT = 'https://androidpublisher.googleapis.com/androidpublisher/v3';
const SCOPE = 'https://www.googleapis.com/auth/androidpublisher';

function argument(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : null;
}

function base64Url(value) {
  return Buffer.from(value).toString('base64url');
}

function safeError(status, parsed) {
  const details = parsed?.error?.details ?? [];
  const reasons = details
    .flatMap((detail) => detail?.reason ? [detail.reason] : [])
    .filter((value, index, all) => all.indexOf(value) === index);
  return {
    status,
    code: parsed?.error?.code ?? status,
    statusText: parsed?.error?.status ?? null,
    reasons,
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

class GetOnlyClient {
  constructor(token) {
    this.token = token;
  }

  async get(resource) {
    const url = resource.startsWith('http') ? resource : `${API_ROOT}${resource}`;
    const response = await fetch(url, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${this.token}`,
        Accept: 'application/json',
      },
    });
    const parsed = await response.json().catch(() => null);
    if (!response.ok) return { ok: false, error: safeError(response.status, parsed) };
    return { ok: true, value: parsed };
  }
}

const credentialsPath = argument('--credentials');
const outputPath = argument('--output');
const credentialLabel = argument('--credential-label') || 'credential';
if (!credentialsPath || !outputPath) {
  throw new Error('--credentials and --output are required');
}
const output = path.resolve(outputPath);
if (path.parse(output).root.toUpperCase() !== 'G:\\') {
  throw new Error(`Audit output must stay on G:, received ${output}`);
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
const client = new GetOnlyClient(token);
const encodedPackage = encodeURIComponent(PACKAGE_NAME);
const [subscriptions, oneTimeProducts, legacyInAppProducts] = await Promise.all([
  client.get(`/applications/${encodedPackage}/subscriptions?pageSize=100`),
  client.get(`/applications/${encodedPackage}/oneTimeProducts?pageSize=100`),
  client.get(`/applications/${encodedPackage}/inappproducts?maxResults=100`),
]);
const subscriptionOffers = [];
if (subscriptions.ok) {
  for (const subscription of subscriptions.value.subscriptions ?? []) {
    for (const basePlan of subscription.basePlans ?? []) {
      const productId = encodeURIComponent(subscription.productId);
      const basePlanId = encodeURIComponent(basePlan.basePlanId);
      subscriptionOffers.push({
        productId: subscription.productId,
        basePlanId: basePlan.basePlanId,
        result: await client.get(
          `/applications/${encodedPackage}/subscriptions/${productId}` +
          `/basePlans/${basePlanId}/offers?pageSize=100`,
        ),
      });
    }
  }
}

const report = {
  generatedAt: new Date().toISOString(),
  mode: 'read-only',
  mutationPerformed: false,
  packageName: PACKAGE_NAME,
  credentialLabel,
  subscriptions,
  subscriptionOffers,
  oneTimeProducts,
  legacyInAppProducts,
};

fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
process.stdout.write(`Wrote ${output}\n`);
