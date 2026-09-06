#!/usr/bin/env node

/**
 * Read the Play App Signing certificate fingerprint for an uploaded bundle.
 *
 * This tool performs exactly one Android Publisher GET request. It does not
 * create an edit, upload an artifact, or mutate Google Play state. OAuth and
 * service-account material are never written to the report.
 */

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

export const PACKAGE_NAME = 'com.bilhealth.bodyintelligencelog';
const API_ROOT = 'https://androidpublisher.googleapis.com/androidpublisher/v3';
const TOKEN_URI = 'https://oauth2.googleapis.com/token';
const SCOPE = 'https://www.googleapis.com/auth/androidpublisher';

function argument(name, argv = process.argv.slice(2)) {
  const index = argv.indexOf(name);
  return index >= 0 ? argv[index + 1] : null;
}

function base64Url(value) {
  return Buffer.from(value).toString('base64url');
}

export function normalizeCertificateSha256(value) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new Error('PLAY_SIGNING_CERTIFICATE_HASH_MISSING');
  }

  const compactHex = value.replaceAll(':', '').replaceAll(' ', '').toUpperCase();
  let bytes;
  if (/^[A-F0-9]{64}$/.test(compactHex)) {
    bytes = Buffer.from(compactHex, 'hex');
  } else {
    try {
      bytes = Buffer.from(value, 'base64url');
    } catch {
      throw new Error('PLAY_SIGNING_CERTIFICATE_HASH_INVALID');
    }
  }
  if (bytes.length !== 32) {
    throw new Error('PLAY_SIGNING_CERTIFICATE_HASH_INVALID');
  }
  return [...bytes]
    .map((byte) => byte.toString(16).padStart(2, '0').toUpperCase())
    .join(':');
}

function validateCredentials(credentials) {
  if (
    credentials?.type !== 'service_account' ||
    typeof credentials.client_email !== 'string' ||
    !credentials.client_email.endsWith('.gserviceaccount.com') ||
    typeof credentials.private_key !== 'string' ||
    !credentials.private_key.includes('BEGIN PRIVATE KEY') ||
    (credentials.token_uri !== undefined && credentials.token_uri !== TOKEN_URI)
  ) {
    throw new Error('GOOGLE_SERVICE_ACCOUNT_INVALID');
  }
}

async function accessToken(credentials) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64Url(
    JSON.stringify({
      iss: credentials.client_email,
      scope: SCOPE,
      aud: TOKEN_URI,
      iat: now,
      exp: now + 3600,
    }),
  );
  const signingInput = `${header}.${claims}`;
  const signature = crypto
    .sign('RSA-SHA256', Buffer.from(signingInput), credentials.private_key)
    .toString('base64url');
  const response = await fetch(TOKEN_URI, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${signingInput}.${signature}`,
    }),
  });
  const body = await response.json().catch(() => null);
  if (!response.ok || typeof body?.access_token !== 'string') {
    throw new Error(`GOOGLE_OAUTH_FAILED:${response.status}`);
  }
  return body.access_token;
}

export function buildSafeReport({ versionCode, responseBody }) {
  const fingerprints = [
    ...new Set(
      (responseBody?.generatedApks ?? []).map((entry) =>
        normalizeCertificateSha256(entry?.certificateSha256Hash),
      ),
    ),
  ].sort();
  if (fingerprints.length === 0) {
    throw new Error('PLAY_SIGNING_CERTIFICATE_NOT_RETURNED');
  }
  return {
    generatedAt: new Date().toISOString(),
    mode: 'single-read-only-get-no-edit',
    mutationPerformed: false,
    packageName: PACKAGE_NAME,
    versionCode,
    certificateCount: fingerprints.length,
    sha256CertificateFingerprints: fingerprints,
  };
}

function writeJsonAtomic(outputPath, value) {
  const output = path.resolve(outputPath);
  if (path.extname(output).toLowerCase() !== '.json') {
    throw new Error('OUTPUT_MUST_BE_JSON');
  }
  fs.mkdirSync(path.dirname(output), { recursive: true });
  const temporary = `${output}.tmp`;
  fs.writeFileSync(temporary, `${JSON.stringify(value, null, 2)}\n`, 'utf8');
  fs.renameSync(temporary, output);
  return output;
}

export function selfTest() {
  const bytes = Buffer.from([...Array(32).keys()]);
  const expected = [...bytes]
    .map((byte) => byte.toString(16).padStart(2, '0').toUpperCase())
    .join(':');
  if (normalizeCertificateSha256(bytes.toString('base64')) !== expected) {
    throw new Error('SELF_TEST_BASE64_FAILED');
  }
  if (normalizeCertificateSha256(expected) !== expected) {
    throw new Error('SELF_TEST_HEX_FAILED');
  }
  const report = buildSafeReport({
    versionCode: 7,
    responseBody: {
      generatedApks: [
        { certificateSha256Hash: bytes.toString('base64') },
        { certificateSha256Hash: expected },
      ],
    },
  });
  if (report.certificateCount !== 1 || report.mutationPerformed !== false) {
    throw new Error('SELF_TEST_REPORT_FAILED');
  }
}

async function main() {
  if (process.argv.includes('--self-test')) {
    selfTest();
    console.log('SELF_TEST=PASS');
    return;
  }

  const credentialsPath = argument('--credentials');
  const versionCodeRaw = argument('--version-code');
  const outputPath = argument('--output');
  if (!credentialsPath || !versionCodeRaw || !outputPath) {
    throw new Error('--credentials, --version-code, and --output are required');
  }
  const versionCode = Number(versionCodeRaw);
  if (!Number.isSafeInteger(versionCode) || versionCode <= 0) {
    throw new Error('VERSION_CODE_MUST_BE_A_POSITIVE_INTEGER');
  }

  const credentials = JSON.parse(
    fs.readFileSync(path.resolve(credentialsPath), 'utf8'),
  );
  validateCredentials(credentials);
  const token = await accessToken(credentials);
  const resource =
    `${API_ROOT}/applications/${encodeURIComponent(PACKAGE_NAME)}` +
    `/generatedApks/${versionCode}`;
  const response = await fetch(resource, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: 'application/json',
    },
  });
  const body = await response.json().catch(() => null);
  if (!response.ok) {
    const status = body?.error?.status ?? 'UNKNOWN';
    throw new Error(`GENERATED_APKS_READ_FAILED:${response.status}:${status}`);
  }

  const report = buildSafeReport({ versionCode, responseBody: body });
  const output = writeJsonAtomic(outputPath, report);
  console.log(`REPORT_OUTPUT=${output}`);
  console.log(`CERTIFICATE_COUNT=${report.certificateCount}`);
  for (const fingerprint of report.sha256CertificateFingerprints) {
    console.log(`PLAY_APP_SIGNING_SHA256=${fingerprint}`);
  }
  console.log('MUTATION_PERFORMED=false');
}

const isDirectRun =
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);

if (isDirectRun) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  });
}

