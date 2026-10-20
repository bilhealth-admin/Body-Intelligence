// Fixed-app GET-only collector. Image files are Apple's native-dimension PNG
// renders, not a claim of byte-identical original uploads or policy acceptance.
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

export const API = 'https://api.appstoreconnect.apple.com';
export const APP = '6805349703';
export const VERSION = '7a132506-d5a8-4810-a51f-b2dc2bd636cf';
export const LOCALE = '3866ba6c-b637-4f70-9c53-d6274c37bc62';
const SOURCE = '5da21a5660b26e59e9ead7b0927d4ed7cf2c3996';
const MAX_IMAGE = 25 * 1024 * 1024;
const MAX_JSON = 4 * 1024 * 1024;
const MAX_TOTAL = 256 * 1024 * 1024;
const hash = raw => crypto.createHash('sha256').update(raw).digest('hex');
function guard(condition, code) {
  if (!condition) { const e = new Error(code); e.safeCode = code; throw e; }
}
export function imageUrl(asset) {
  guard(asset && Number.isInteger(asset.width) && Number.isInteger(asset.height)
    && asset.width > 0 && asset.height > 0 && asset.width <= 10000 && asset.height <= 10000, 'IMAGE_DIMENSIONS_INVALID');
  guard(typeof asset.templateUrl === 'string', 'IMAGE_TEMPLATE_MISSING');
  const raw = asset.templateUrl.replaceAll('{w}', String(asset.width))
    .replaceAll('{h}', String(asset.height)).replaceAll('{f}', 'png');
  const u = new URL(raw);
  guard(u.protocol === 'https:' && !u.username && !u.password && !u.port
    && (u.hostname === 'mzstatic.com' || u.hostname.endsWith('.mzstatic.com'))
    && !u.hash && !/[{}]/.test(raw), 'IMAGE_HOST_OR_TEMPLATE_REJECTED');
  return u;
}
async function bytes(response, cap) {
  const declared = response.headers.get('content-length');
  guard(declared === null || (/^\d+$/.test(declared) && Number(declared) <= cap), 'RESPONSE_SIZE_LIMIT');
  guard(response.body && typeof response.body.getReader === 'function', 'RESPONSE_STREAM_MISSING');
  const reader = response.body.getReader();
  const parts = [];
  let size = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > cap) {
      await reader.cancel();
      guard(false, 'RESPONSE_SIZE_LIMIT');
    }
    parts.push(Buffer.from(value));
  }
  return Buffer.concat(parts, size);
}
function jwt(env) {
  guard(env.APP_STORE_CONNECT_KEY_ID && env.APP_STORE_CONNECT_ISSUER_ID
    && env.APP_STORE_CONNECT_PRIVATE_KEY_BASE64, 'APPLE_READ_CREDENTIALS_MISSING');
  const part = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  const input = part({ alg: 'ES256', kid: env.APP_STORE_CONNECT_KEY_ID, typ: 'JWT' })
    + '.' + part({ iss: env.APP_STORE_CONNECT_ISSUER_ID, iat: now - 5, exp: now + 900, aud: 'appstoreconnect-v1' });
  return input + '.' + crypto.sign('sha256', Buffer.from(input), {
    key: Buffer.from(env.APP_STORE_CONNECT_PRIVATE_KEY_BASE64, 'base64'), dsaEncoding: 'ieee-p1363',
  }).toString('base64url');
}
export async function inspectAppleStoreAssets({ out, token, fetcher = fetch }) {
  fs.mkdirSync(out, { recursive: true });
  const report = {
    checkedAt: new Date().toISOString(), applicationSourceUnderComparison: SOURCE,
    controllerSource: process.env.GITHUB_SHA ?? null, workflowRun: process.env.GITHUB_RUN_ID ?? null,
    appId: APP, versionId: VERSION, localizationId: LOCALE,
    mode: 'GET_ONLY_NO_STORE_MUTATION', mutations: 0,
    screenshotEncoding: 'APPLE_SERVED_PNG_AT_RECORDED_NATIVE_DIMENSIONS',
    originalUploadByteIdentityClaimed: false,
    screenshotSets: [], previewSets: [], failures: [],
    creativeAssetFormat2314: 'NOT_INSPECTED_BY_SCREENSHOT_OR_PREVIEW_API',
    visualReview: 'PENDING', guidelineAcceptance: 'NOT_ESTABLISHED',
    status: 'COLLECTING',
  };
  const save = () => fs.writeFileSync(path.join(out, 'store-assets-inventory.json'), JSON.stringify(report, null, 2) + '\n');
  const allowedPaths = new Set([
    '/v1/apps/' + APP, '/v1/appStoreVersions/' + VERSION,
    '/v1/appStoreVersionLocalizations/' + LOCALE,
    '/v1/appStoreVersionLocalizations/' + LOCALE + '/appScreenshotSets',
    '/v1/appStoreVersionLocalizations/' + LOCALE + '/appPreviewSets',
  ]);
  async function request(resource, allowMissing = false) {
    const u = new URL(resource, API);
    guard(u.origin === API && !u.username && !u.password && !u.hash && allowedPaths.has(u.pathname), 'API_SCOPE_REJECTED');
    const response = await fetcher(u, { method: 'GET', redirect: 'error',
      signal: AbortSignal.timeout(30000), headers: { Authorization: 'Bearer ' + token, Accept: 'application/json' } });
    if (allowMissing && response.status === 404) return { missing: true, data: [] };
    if (!response.ok) { const e = new Error('APPLE_GET_HTTP_' + response.status); e.safeCode = e.message; throw e; }
    return JSON.parse((await bytes(response, MAX_JSON)).toString('utf8'));
  }
  async function all(resource, allowMissing = false) {
    const initial = new URL(resource, API);
    let next = initial.href;
    const rows = [];
    for (let page = 0; next; page++) {
      guard(page < 5, 'API_PAGINATION_LIMIT');
      const u = new URL(next, API);
      guard(u.origin === API && u.pathname === initial.pathname, 'API_PAGINATION_SCOPE_REJECTED');
      const result = await request(u.href, allowMissing);
      if (result.missing) return { missing: true, rows: [] };
      guard(Array.isArray(result.data), 'API_COLLECTION_SHAPE_INVALID');
      rows.push(...result.data);
      guard(rows.length <= 200, 'API_COLLECTION_LIMIT');
      next = result.links?.next ?? null;
    }
    return { missing: false, rows };
  }
  try {
    const app = await request('/v1/apps/' + APP);
    guard(app.data?.id === APP && app.data.attributes?.bundleId === 'com.bilhealth.bodyintelligencelog', 'APP_IDENTITY_MISMATCH');
    const version = await request('/v1/appStoreVersions/' + VERSION);
    guard(version.data?.id === VERSION && version.data.attributes?.platform === 'IOS'
      && version.data.attributes?.versionString === '1.0.0', 'VERSION_IDENTITY_MISMATCH');
    report.versionState = version.data.attributes.appStoreState ?? null;
    const locale = await request('/v1/appStoreVersionLocalizations/' + LOCALE);
    guard(locale.data?.id === LOCALE && locale.data.attributes?.locale === 'en-US', 'LOCALE_IDENTITY_MISMATCH');
    report.publicMetadata = Object.fromEntries(['locale', 'description', 'keywords', 'marketingUrl',
      'promotionalText', 'supportUrl', 'whatsNew'].map(key => [key, locale.data.attributes[key] ?? null]));
    const sets = await all('/v1/appStoreVersionLocalizations/' + LOCALE + '/appScreenshotSets?limit=200');
    guard(sets.rows.length <= 10, 'SCREENSHOT_SET_LIMIT');
    let total = 0;
    for (const set of sets.rows) {
      guard(typeof set.id === 'string' && /^[a-zA-Z0-9-]+$/.test(set.id), 'SCREENSHOT_SET_ID_INVALID');
      const resource = '/v1/appScreenshotSets/' + set.id + '/appScreenshots';
      allowedPaths.add(resource);
      const screenshots = await all(resource + '?limit=200');
      guard(screenshots.rows.length <= 10, 'SCREENSHOT_COUNT_LIMIT');
      const current = { id: set.id, displayType: set.attributes?.screenshotDisplayType ?? null, screenshots: [] };
      report.screenshotSets.push(current);
      save();
      for (let i = 0; i < screenshots.rows.length; i++) {
        const shot = screenshots.rows[i];
        const a = shot.attributes ?? {};
        const record = { id: shot.id, position: i + 1, state: a.assetDeliveryState?.state ?? null,
          width: a.imageAsset?.width ?? null, height: a.imageAsset?.height ?? null,
          originalFileNameSha256: typeof a.fileName === 'string' ? hash(a.fileName) : null,
          status: 'NOT_DOWNLOADED' };
        current.screenshots.push(record);
        try {
          guard(record.state === 'COMPLETE', 'SCREENSHOT_NOT_COMPLETE');
          const u = imageUrl(a.imageAsset);
          record.imageHost = u.hostname;
          const response = await fetcher(u, { method: 'GET', redirect: 'error',
            signal: AbortSignal.timeout(45000), headers: { Accept: 'image/png' } });
          guard(response.ok, 'IMAGE_GET_HTTP_' + response.status);
          guard(/^image\/(png|jpeg)(?:;|$)/i.test(response.headers.get('content-type') ?? ''), 'IMAGE_CONTENT_TYPE_INVALID');
          const raw = await bytes(response, MAX_IMAGE);
          total += raw.length;
          guard(total <= MAX_TOTAL, 'TOTAL_IMAGE_SIZE_LIMIT');
          guard(raw.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])), 'PNG_SIGNATURE_INVALID');
          guard(raw.length >= 24 && raw.subarray(12, 16).toString('ascii') === 'IHDR'
            && raw.readUInt32BE(16) === record.width && raw.readUInt32BE(20) === record.height, 'PNG_DIMENSIONS_MISMATCH');
          const name = 'screenshot-' + set.id + '-' + String(i + 1).padStart(2, '0') + '.png';
          fs.writeFileSync(path.join(out, name), raw);
          Object.assign(record, { file: name, bytes: raw.length, sha256: hash(raw), status: 'DOWNLOADED_NATIVE_RENDER' });
        } catch (error) {
          record.status = 'DOWNLOAD_FAILED_OR_BLOCKED';
          record.failure = error.safeCode ?? 'IMAGE_REQUEST_OR_RESPONSE_FAILED';
          report.failures.push({ screenshotId: shot.id, code: record.failure });
        }
        save();
      }
    }
    const previewSets = await all('/v1/appStoreVersionLocalizations/' + LOCALE + '/appPreviewSets?limit=200', true);
    report.previewInventoryStatus = previewSets.missing ? 'API404_NOT_PROOF_OF_ABSENCE' : 'GET_COMPLETE';
    for (const set of previewSets.rows) {
      guard(typeof set.id === 'string' && /^[a-zA-Z0-9-]+$/.test(set.id), 'PREVIEW_SET_ID_INVALID');
      const resource = '/v1/appPreviewSets/' + set.id + '/appPreviews';
      allowedPaths.add(resource);
      const previews = await all(resource + '?limit=200');
      report.previewSets.push({ id: set.id, displayType: set.attributes?.previewType ?? null,
        previews: previews.rows.map(item => ({ id: item.id,
          state: item.attributes?.assetDeliveryState?.state ?? null,
          mimeType: item.attributes?.mimeType ?? null, previewFrameTimeCode: item.attributes?.previewFrameTimeCode ?? null })),
        videoVisualReview: 'NOT_PERFORMED' });
    }
    report.downloadedImages = report.screenshotSets.flatMap(s => s.screenshots).filter(s => s.status === 'DOWNLOADED_NATIVE_RENDER').length;
    report.status = report.failures.length ? 'PARTIAL_COLLECTION_REQUIRES_REVIEW' : 'COLLECTED_VISUAL_REVIEW_PENDING';
  } catch (error) {
    report.status = 'BLOCKED_OR_PARTIAL_COLLECTION';
    report.failures.push({ code: error.safeCode ?? 'APPLE_READ_OR_CONFIGURATION_FAILED' });
  } finally { save(); }
  return report;
}
if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  const out = process.argv[2];
  guard(out, 'OUTPUT_DIRECTORY_REQUIRED');
  try {
    const report = await inspectAppleStoreAssets({ out, token: jwt(process.env) });
    console.log(JSON.stringify({ status: report.status, downloadedImages: report.downloadedImages ?? 0, failures: report.failures, mutations: 0 }));
    if (report.status !== 'COLLECTED_VISUAL_REVIEW_PENDING') process.exitCode = 1;
  } catch {
    console.log(JSON.stringify({ status: 'APPLE_READ_CREDENTIAL_CONFIGURATION_FAILED', mutations: 0 }));
    process.exitCode = 1;
  }
}
