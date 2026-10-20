import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { API, APP, VERSION, LOCALE, imageUrl, inspectAppleStoreAssets } from './inspect_apple_store_assets.mjs';

const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j7K0AAAAASUVORK5CYII=', 'base64');
function fixture({ badApp = false, image = 'good', pagination = null, previewMissing = false } = {}) {
  const calls = [];
  let imageBodyRead = false;
  const json = value => new Response(JSON.stringify(value), { headers: { 'content-type': 'application/json' } });
  const fetcher = async (input, init) => {
    const u = new URL(input);
    calls.push({ url: u.href, init });
    assert.equal(init.method, 'GET');
    assert.equal(init.redirect, 'error');
    if (u.origin !== API) {
      assert.equal(init.headers.Authorization, undefined);
      if (image === 'too-large') return new Response(PNG, { headers: { 'content-type': 'image/png', 'content-length': String(26 * 1024 * 1024) } });
      imageBodyRead = true;
      const raw = image === 'wrong-dimensions' ? Buffer.from(PNG) : PNG;
      if (image === 'wrong-dimensions') raw.writeUInt32BE(2, 16);
      return new Response(raw, { headers: { 'content-type': 'image/png' } });
    }
    assert.equal(init.headers.Authorization, 'Bearer offline-mock-token');
    if (u.pathname === '/v1/apps/' + APP) return json({ data: { id: APP, attributes: { bundleId: badApp ? 'another.app' : 'com.bilhealth.bodyintelligencelog' } } });
    if (u.pathname === '/v1/appStoreVersions/' + VERSION) return json({ data: { id: VERSION, attributes: { platform: 'IOS', versionString: '1.0.0', appStoreState: 'PREPARE_FOR_SUBMISSION' } } });
    if (u.pathname === '/v1/appStoreVersionLocalizations/' + LOCALE) return json({ data: { id: LOCALE, attributes: { locale: 'en-US', description: 'Public store text' } } });
    if (u.pathname.endsWith('/appScreenshotSets')) return json({ data: [{ id: 'fixed-test-set', attributes: { screenshotDisplayType: 'APP_IPHONE_67' } }], links: { next: pagination } });
    if (u.pathname === '/v1/appScreenshotSets/fixed-test-set/appScreenshots') {
      return json({ data: [{ id: 'fixed-test-image', attributes: { fileName: 'public-screenshot.png', assetDeliveryState: { state: 'COMPLETE' },
        imageAsset: { width: 1, height: 1, templateUrl: image === 'bad-host' ? 'https://mzstatic.com.attacker.invalid/{w}x{h}.{f}' : 'https://is1-ssl.mzstatic.com/image/{w}x{h}.{f}' } } }] });
    }
    if (u.pathname.endsWith('/appPreviewSets')) return previewMissing ? new Response('', { status: 404 }) : json({ data: [] });
    throw new Error('Unexpected mocked endpoint');
  };
  return { fetcher, calls, imageBodyRead: () => imageBodyRead };
}
async function run(options) {
  const out = fs.mkdtempSync(path.join(os.tmpdir(), 'bil-assets-test-'));
  const f = fixture(options);
  try { return { report: await inspectAppleStoreAssets({ out, token: 'offline-mock-token', fetcher: f.fetcher }), out, f }; }
  catch (error) { fs.rmSync(out, { recursive: true, force: true }); throw error; }
}
test('fixed app collection uses GET only and does not forward Apple credentials to image CDN', async () => {
  const { report, out, f } = await run();
  try {
    assert.equal(report.status, 'COLLECTED_VISUAL_REVIEW_PENDING');
    assert.equal(report.downloadedImages, 1);
    assert.equal(report.mutations, 0);
    assert.equal(report.originalUploadByteIdentityClaimed, false);
    assert.equal(report.creativeAssetFormat2314, 'NOT_INSPECTED_BY_SCREENSHOT_OR_PREVIEW_API');
    const saved = report.screenshotSets[0].screenshots[0];
    assert.match(saved.sha256, /^[0-9a-f]{64}$/);
    assert.deepEqual(fs.readFileSync(path.join(out, saved.file)), PNG);
    assert.equal(f.calls.filter(c => new URL(c.url).hostname.endsWith('.mzstatic.com')).length, 1);
  } finally { fs.rmSync(out, { recursive: true, force: true }); }
});
test('lookalike image host is rejected before request and remains a recorded collection failure', async () => {
  const { report, out, f } = await run({ image: 'bad-host' });
  try {
    assert.equal(report.status, 'PARTIAL_COLLECTION_REQUIRES_REVIEW');
    assert.equal(report.failures[0].code, 'IMAGE_HOST_OR_TEMPLATE_REJECTED');
    assert.equal(f.calls.some(c => c.url.includes('attacker.invalid')), false);
  } finally { fs.rmSync(out, { recursive: true, force: true }); }
});
test('oversized image content length is rejected and no file is written', async () => {
  const { report, out } = await run({ image: 'too-large' });
  try {
    assert.equal(report.failures[0].code, 'RESPONSE_SIZE_LIMIT');
    assert.equal(fs.readdirSync(out).filter(n => n.endsWith('.png')).length, 0);
  } finally { fs.rmSync(out, { recursive: true, force: true }); }
});
test('native PNG dimensions must match the store metadata', async () => {
  const { report, out } = await run({ image: 'wrong-dimensions' });
  try { assert.equal(report.failures[0].code, 'PNG_DIMENSIONS_MISMATCH'); }
  finally { fs.rmSync(out, { recursive: true, force: true }); }
});
test('off-host pagination cannot receive API credentials', async () => {
  const { report, out, f } = await run({ pagination: 'https://attacker.invalid/v1/appScreenshotSets' });
  try {
    assert.equal(report.status, 'BLOCKED_OR_PARTIAL_COLLECTION');
    assert.equal(report.failures[0].code, 'API_PAGINATION_SCOPE_REJECTED');
    assert.equal(f.calls.some(c => c.url.includes('attacker.invalid')), false);
  } finally { fs.rmSync(out, { recursive: true, force: true }); }
});
test('wrong app identity stops before asset or localization reads', async () => {
  const { report, out, f } = await run({ badApp: true });
  try {
    assert.equal(report.failures[0].code, 'APP_IDENTITY_MISMATCH');
    assert.equal(f.calls.length, 1);
  } finally { fs.rmSync(out, { recursive: true, force: true }); }
});
test('preview404 is explicit unknown, never proof of no previews or creative assets', async () => {
  const { report, out } = await run({ previewMissing: true });
  try {
    assert.equal(report.previewInventoryStatus, 'API404_NOT_PROOF_OF_ABSENCE');
    assert.equal(report.guidelineAcceptance, 'NOT_ESTABLISHED');
  } finally { fs.rmSync(out, { recursive: true, force: true }); }
});
test('image URL guard rejects credentials, ports, nonHTTPS and incomplete placeholders', () => {
  for (const templateUrl of ['http://is1.mzstatic.com/{w}/{h}/{f}', 'https://user:secret@is1.mzstatic.com/{w}/{h}/{f}',
    'https://is1.mzstatic.com:444/{w}/{h}/{f}', 'https://is1.mzstatic.com/{width}/{h}/{f}']) {
    assert.throws(() => imageUrl({ width: 1, height: 1, templateUrl }));
  }
});
