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
import { fileURLToPath } from 'node:url';
import { googleOAuthTokenUri } from './google_oauth.mjs';

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

function sanitizedMessage(value, secrets = []) {
  if (typeof value !== 'string') return null;
  let message = value;
  for (const secret of secrets) {
    if (typeof secret === 'string' && secret) message = message.split(secret).join('[REDACTED]');
  }
  message = message
    .replace(/-----BEGIN[\s\S]*?-----END[^-]*-----/g, '[REDACTED]')
    .replace(/\bBearer\s+\S+/gi, 'Bearer [REDACTED]')
    .replace(/\b(access_token|refresh_token|id_token|assertion|private_key)["']?\s*[=:]\s*(?:"[^"\r\n]*"|'[^'\r\n]*'|[^&\s]+)/gi, '$1=[REDACTED]')
    .replace(/\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b/g, '[REDACTED]')
    .replace(/[\u0000-\u001f\u007f]+/g, ' ')
    .replace(/\s+/g, ' ').trim();
  if (!message) return null;
  return message.length > 400 ? message.slice(0, 397) + '...' : message;
}

function safeError(httpStatus, parsed, secrets = []) {
  const status = parsed?.error?.status;
  return {
    code: Number.isSafeInteger(parsed?.error?.code) ? parsed.error.code : httpStatus,
    status: typeof status === 'string' && /^[A-Z][A-Z0-9_]{0,79}$/.test(status) ? status : null,
    message: sanitizedMessage(parsed?.error?.message, secrets),
  };
}

class AuditFailure extends Error {
  constructor(stage, httpStatus = null, error = null) {
    super(`${stage}_FAILED:${httpStatus ?? 'UNKNOWN'}:${error?.status ?? 'UNKNOWN'}`);
    this.failure = { stage, httpStatus, error };
  }
}

function failureDetail(error, stage) {
  return error instanceof AuditFailure ? error.failure : {
    stage, httpStatus: null,
    error: { code: null, status: null, message: 'Audit operation failed without a safe Google diagnostic.' },
  };
}

async function accessToken(credentials, fetchImpl = fetch) {
  const now = Math.floor(Date.now() / 1000);
  const tokenUri = googleOAuthTokenUri(credentials);
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
  const response = await fetchImpl(tokenUri, {
    method: 'POST',
    redirect: 'error',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${signingInput}.${signature}`,
    }),
  });
  const parsed = await response.json().catch(() => null);
  if (!response.ok || !parsed?.access_token) {
    throw new AuditFailure('GOOGLE_OAUTH', response.status,
      safeError(response.status, parsed, [credentials.private_key, credentials.client_email]));
  }
  return parsed.access_token;
}

export class Client {
  constructor(token, fetchImpl = fetch, secrets = []) {
    this.token = token;
    this.fetchImpl = fetchImpl;
    this.secrets = [token, ...secrets];
  }

  async request(method, resource, body) {
    const response = await this.fetchImpl(`${API_ROOT}${resource}`, {
      method,
      headers: {
        Authorization: `Bearer ${this.token}`,
        Accept: 'application/json',
        ...(body === undefined ? {} : { 'Content-Type': 'application/json' }),
      },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
    const text = await response.text();
    let parsed = null;
    try { parsed = text ? JSON.parse(text) : null; } catch {
      const diagnostic = { code: response.status, status: null, message: 'Google API returned a non-JSON response.' };
      if (response.ok) throw new AuditFailure('GOOGLE_RESPONSE_JSON', response.status, diagnostic);
      return { ok: false, status: response.status, error: diagnostic };
    }
    if (!response.ok) {
      return { ok: false, status: response.status, error: safeError(response.status, parsed, this.secrets) };
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
    throw new AuditFailure(label, result.status, result.error);
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

export async function runReleaseSurfaceAudit({ clientFactory, output }) {
  const packagePath = `/applications/${encodeURIComponent(PACKAGE_NAME)}`;
  const report = {
    generatedAt: new Date().toISOString(),
    mode: 'transient-edit-read-only-no-commit',
    packageName: PACKAGE_NAME,
    mutationPerformed: false,
    transientEdit: { committed: false },
  };
  let client;
  let editPath;
  let stage = 'GOOGLE_OAUTH';

  try {
    client = await clientFactory();
    stage = 'EDIT_INSERT';
    const insert = await client.post(`${packagePath}/edits`, {});
    report.transientEdit.insertHttpStatus = insert.status;
    const edit = requireOk(insert, 'EDIT_INSERT');
    const editId = edit.id;
    if (!editId) throw new AuditFailure('EDIT_ID_MISSING');
    editPath = `${packagePath}/edits/${encodeURIComponent(editId)}`;
    report.transientEdit.expiryTimeSeconds = edit.expiryTimeSeconds ?? null;
    stage = 'EDIT_READ';
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
    Object.assign(report, {
      details: cleanResult(details),
      listings: cleanResult(listings),
      tracks: cleanResult(tracks),
      bundles: cleanResult(bundles),
      apks: cleanResult(apks),
      images,
      countryAvailability,
    });
  } catch (error) {
    report.failure = failureDetail(error, stage);
  } finally {
    if (editPath) {
      try {
        const result = await client.delete(editPath);
        report.transientEdit.deleted = result.ok;
        report.transientEdit.deleteHttpStatus = result.status;
        if (!result.ok) {
          report.transientEdit.deleteError = result.error;
          throw new AuditFailure('TRANSIENT_EDIT_DELETE', result.status, result.error);
        }
      } catch (error) {
        report.transientEdit.deleted = false;
        const cleanupFailure = failureDetail(error, 'TRANSIENT_EDIT_DELETE');
        if (report.failure) report.cleanupFailure = cleanupFailure;
        else report.failure = cleanupFailure;
      }
    }
    fs.mkdirSync(path.dirname(output), { recursive: true });
    fs.writeFileSync(output, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
  }
  if (report.failure) {
    throw new AuditFailure(report.failure.stage, report.failure.httpStatus, report.failure.error);
  }
  return report;
}

async function runCli() {
  const credentialsPath = argument('--credentials');
  const outputPath = argument('--output');
  if (!credentialsPath || !outputPath) throw new AuditFailure('ARGUMENTS_REQUIRED');
  const output = path.resolve(outputPath);
  if (path.parse(output).root.toUpperCase() !== 'G:\\') throw new AuditFailure('OUTPUT_DRIVE_INVALID');
  await runReleaseSurfaceAudit({ output, clientFactory: async () => {
    const credentials = JSON.parse(fs.readFileSync(path.resolve(credentialsPath), 'utf8'));
    if (credentials.type !== 'service_account' || !credentials.client_email || !credentials.private_key) {
      throw new AuditFailure('SERVICE_ACCOUNT_INVALID');
    }
    const token = await accessToken(credentials);
    return new Client(token, fetch, [credentials.private_key, credentials.client_email]);
  } });
  process.stdout.write(`Wrote ${output}\n`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  runCli().catch((error) => {
    process.stderr.write(`${JSON.stringify(failureDetail(error, 'GOOGLE_AUDIT'))}\n`);
    process.exitCode = 1;
  });
}
