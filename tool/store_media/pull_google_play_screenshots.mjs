#!/usr/bin/env node

/**
 * Read the exact screenshots currently attached to Google Play listings.
 *
 * This utility creates a disposable Android Publisher edit, reads every
 * listing locale and its phone screenshots, downloads the bytes, verifies
 * Google's hashes when present, and then deletes the edit in a finally block.
 * It never commits the edit and therefore cannot change the live listing.
 */

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const PACKAGE_NAME = 'com.bilhealth.bodyintelligencelog';
const TOKEN_URL = 'https://oauth2.googleapis.com/token';
const API_ROOT = 'https://androidpublisher.googleapis.com/androidpublisher/v3';
const SCOPE = 'https://www.googleapis.com/auth/androidpublisher';

function base64Url(value) {
  return Buffer.from(value).toString('base64url');
}

function sha256(bytes) {
  return crypto.createHash('sha256').update(bytes).digest('hex');
}

function sha1(bytes) {
  return crypto.createHash('sha1').update(bytes).digest('hex');
}

function googleHashMatches(remote, actualHex) {
  if (!remote) return true;
  const normalized = String(remote).trim();
  if (normalized.toLowerCase() === actualHex.toLowerCase()) return true;
  try {
    const decoded = Buffer.from(normalized.replace(/-/g, '+').replace(/_/g, '/'), 'base64');
    return decoded.toString('hex').toLowerCase() === actualHex.toLowerCase();
  } catch {
    return false;
  }
}

function fullResolutionGoogleImageUrl(url) {
  const parsed = new URL(url);
  const lastSlash = parsed.pathname.lastIndexOf('/');
  const suffix = parsed.pathname.indexOf('=', lastSlash + 1);
  if (suffix >= 0) parsed.pathname = parsed.pathname.slice(0, suffix);
  return `${parsed.toString()}=s0`;
}

function imageDimensions(bytes) {
  const png = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  if (bytes.length >= 24 && bytes.subarray(0, 8).equals(png)) {
    return {
      format: 'png',
      width: bytes.readUInt32BE(16),
      height: bytes.readUInt32BE(20),
    };
  }
  if (bytes.length >= 4 && bytes[0] === 0xff && bytes[1] === 0xd8) {
    let offset = 2;
    while (offset + 9 < bytes.length) {
      if (bytes[offset] !== 0xff) { offset += 1; continue; }
      const marker = bytes[offset + 1];
      if (marker === 0xd8 || marker === 0xd9) { offset += 2; continue; }
      const length = bytes.readUInt16BE(offset + 2);
      if (length < 2 || offset + 2 + length > bytes.length) break;
      if ([0xc0, 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7, 0xc9, 0xca, 0xcb, 0xcd, 0xce, 0xcf].includes(marker)) {
        return {
          format: 'jpg',
          width: bytes.readUInt16BE(offset + 7),
          height: bytes.readUInt16BE(offset + 5),
        };
      }
      offset += 2 + length;
    }
  }
  throw new Error('Unsupported or corrupt screenshot image');
}

async function googleToken(credentials) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const payload = base64Url(JSON.stringify({
    iss: credentials.client_email,
    scope: SCOPE,
    aud: TOKEN_URL,
    iat: now,
    exp: now + 3600,
  }));
  const input = `${header}.${payload}`;
  const signature = crypto.sign('RSA-SHA256', Buffer.from(input), credentials.private_key)
    .toString('base64url');
  const assertion = `${input}.${signature}`;
  const response = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  const body = await response.json();
  if (!response.ok || !body.access_token) {
    throw new Error(`Google OAuth failed (${response.status})`);
  }
  return body.access_token;
}

async function api(token, method, resource, body) {
  const response = await fetch(`${API_ROOT}${resource}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: 'application/json',
      ...(body ? { 'Content-Type': 'application/json' } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  const parsed = text ? JSON.parse(text) : null;
  if (!response.ok) {
    const safeReason = parsed?.error?.errors?.[0]?.reason ?? parsed?.error?.status ?? 'unknown';
    throw new Error(`Android Publisher ${method} failed (${response.status}, ${safeReason})`);
  }
  return parsed;
}

function localGooglePlayInventory(projectRoot) {
  const root = path.join(projectRoot, 'store_assets', 'screenshots', 'google_play');
  if (!fs.existsSync(root)) return [];
  return fs.readdirSync(root, { withFileTypes: true })
    .filter((entry) => entry.isFile() && /\.(png|jpe?g)$/i.test(entry.name))
    .map((entry) => {
      const bytes = fs.readFileSync(path.join(root, entry.name));
      return {
        fileName: entry.name,
        bytes: bytes.length,
        sha256: sha256(bytes),
        ...imageDimensions(bytes),
      };
    });
}

function writeJson(filePath, value) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`, 'utf8');
}

async function main() {
  const credentialPath = path.resolve(process.argv[2] ?? '');
  const outputRoot = path.resolve(process.argv[3] ?? '');
  if (!credentialPath || !outputRoot) {
    throw new Error('Usage: node pull_google_play_screenshots.mjs <service-account.json> <G:\\output>');
  }
  if (path.parse(outputRoot).root.toUpperCase() !== 'G:\\') {
    throw new Error(`Output must stay on G:, received ${outputRoot}`);
  }
  const credentials = JSON.parse(fs.readFileSync(credentialPath, 'utf8'));
  if (credentials.type !== 'service_account' || !credentials.client_email || !credentials.private_key) {
    throw new Error('Invalid Google service-account JSON');
  }
  fs.mkdirSync(outputRoot, { recursive: true });
  const token = await googleToken(credentials);
  let editId = null;
  try {
    const encodedPackage = encodeURIComponent(PACKAGE_NAME);
    const edit = await api(token, 'POST', `/applications/${encodedPackage}/edits`, {});
    editId = edit.id;
    if (!editId) throw new Error('Google did not return a temporary edit ID');
    const list = await api(
      token,
      'GET',
      `/applications/${encodedPackage}/edits/${encodeURIComponent(editId)}/listings`,
    );
    const locales = (list.listings ?? []).map((item) => item.language).filter(Boolean).sort();
    const listings = [];
    for (const locale of locales) {
      const listing = await api(
        token,
        'GET',
        `/applications/${encodedPackage}/edits/${encodeURIComponent(editId)}/listings/${encodeURIComponent(locale)}`,
      );
      // Google keeps listing text and listing images on separate resources.
      // The listing payload does not embed phoneScreenshots; read the exact
      // live image resources through edits.images.list.
      const imageList = await api(
        token,
        'GET',
        `/applications/${encodedPackage}/edits/${encodeURIComponent(editId)}` +
          `/listings/${encodeURIComponent(locale)}/phoneScreenshots`,
      );
      const screenshots = [];
      for (const [index, remote] of (imageList.images ?? []).entries()) {
        if (!remote.url) throw new Error(`Google screenshot ${locale}[${index}] has no URL`);
        const response = await fetch(fullResolutionGoogleImageUrl(remote.url), {
          headers: { Authorization: `Bearer ${token}` },
        });
        if (!response.ok) throw new Error(`Screenshot download failed (${response.status})`);
        const bytes = Buffer.from(await response.arrayBuffer());
        const dimensions = imageDimensions(bytes);
        const extension = dimensions.format === 'jpg' ? 'jpg' : 'png';
        const fileName = `${locale.replace(/[^A-Za-z0-9_-]/g, '_')}-${String(index + 1).padStart(2, '0')}.${extension}`;
        const filePath = path.join(outputRoot, fileName);
        fs.writeFileSync(filePath, bytes);
        const actualSha256 = sha256(bytes);
        const actualSha1 = sha1(bytes);
        if (!googleHashMatches(remote.sha256, actualSha256)) {
          throw new Error(`Google SHA-256 mismatch for ${locale}[${index}]`);
        }
        if (!googleHashMatches(remote.sha1, actualSha1)) {
          throw new Error(`Google SHA-1 mismatch for ${locale}[${index}]`);
        }
        screenshots.push({
          order: index + 1,
          fileName,
          filePath,
          bytes: bytes.length,
          sha1: actualSha1,
          sha256: actualSha256,
          googleSha1: remote.sha1 ?? null,
          googleSha256: remote.sha256 ?? null,
          downloadedFrom: 'googleusercontent_full_resolution_s0',
          ...dimensions,
        });
      }
      listings.push({
        locale,
        title: listing.title ?? null,
        phoneScreenshotCount: screenshots.length,
        screenshots,
      });
    }
    const local = localGooglePlayInventory(path.resolve(import.meta.dirname, '..', '..'));
    const localByHash = new Map(local.map((item) => [item.sha256, item]));
    for (const listing of listings) {
      for (const screenshot of listing.screenshots) {
        screenshot.localExactMatch = localByHash.get(screenshot.sha256)?.fileName ?? null;
      }
    }
    const preferredLocale = listings.find((item) => item.locale === 'en-GB' && item.phoneScreenshotCount > 0)
      ?? listings.find((item) => item.locale === 'en-US' && item.phoneScreenshotCount > 0)
      ?? listings.find((item) => item.phoneScreenshotCount > 0)
      ?? null;
    const report = {
      generatedAt: new Date().toISOString(),
      packageName: PACKAGE_NAME,
      mutation: 'temporary_edit_read_only_then_deleted',
      editCommitted: false,
      serviceAccountEmail: credentials.client_email,
      locales,
      preferredLocale: preferredLocale?.locale ?? null,
      listings,
      localGooglePlayInventory: local,
    };
    writeJson(path.join(outputRoot, 'manifest.json'), report);
    process.stdout.write(`${JSON.stringify({
      packageName: report.packageName,
      locales: report.locales,
      preferredLocale: report.preferredLocale,
      counts: Object.fromEntries(listings.map((item) => [item.locale, item.phoneScreenshotCount])),
      exactLocalMatches: listings.flatMap((item) => item.screenshots)
        .filter((item) => item.localExactMatch).length,
      manifest: path.join(outputRoot, 'manifest.json'),
    }, null, 2)}\n`);
  } finally {
    if (editId) {
      const encodedPackage = encodeURIComponent(PACKAGE_NAME);
      await api(
        token,
        'DELETE',
        `/applications/${encodedPackage}/edits/${encodeURIComponent(editId)}`,
      );
    }
  }
}

main().catch((error) => {
  process.stderr.write(`${error.stack ?? error.message}\n`);
  process.exitCode = 1;
});
