import assert from 'node:assert/strict';
import test from 'node:test';

import worker from './bilhealth_site_worker.mjs';

const productionShapeAasa = {
  applinks: {
    details: [{
      appIDs: ['A1B2C3D4E5.com.bilhealth.bodyintelligencelog'],
      components: [
        { '/': '/auth/callback' },
        { '/': '/auth/reset-password' },
      ],
    }],
  },
};
const fingerprint = Array.from({ length: 32 }, (_, index) =>
  index.toString(16).padStart(2, '0'),
).join(':').toUpperCase();
const productionShapeAssetLinks = [{
  relation: ['delegate_permission/common.handle_all_urls'],
  target: {
    namespace: 'android_app',
    package_name: 'com.bilhealth.bodyintelligencelog',
    sha256_cert_fingerprints: [fingerprint],
  },
}];

function environment(body, contentType = 'application/json') {
  return {
    ASSETS: {
      fetch: async () => new Response(body, {
        status: 200,
        headers: { 'Content-Type': contentType },
      }),
    },
  };
}

test('serves validated AASA as JSON', async () => {
  const response = await worker.fetch(
    new Request('https://www.bilhealth.com/.well-known/apple-app-site-association'),
    environment(JSON.stringify(productionShapeAasa)),
  );
  assert.equal(response.status, 200);
  assert.match(response.headers.get('Content-Type'), /^application\/json/);
});

test('serves validated Digital Asset Links as JSON', async () => {
  const response = await worker.fetch(
    new Request('https://www.bilhealth.com/.well-known/assetlinks.json'),
    environment(JSON.stringify(productionShapeAssetLinks)),
  );
  assert.equal(response.status, 200);
});

test('rejects SPA fallback HTML instead of returning index.html', async () => {
  const response = await worker.fetch(
    new Request('https://www.bilhealth.com/.well-known/assetlinks.json'),
    environment('<!doctype html><title>BIL</title>', 'text/html; charset=utf-8'),
  );
  assert.equal(response.status, 404);
  assert.match(response.headers.get('Content-Type'), /^text\/plain/);
});

test('rejects SPA fallback HTML even if an edge header labels it JSON', async () => {
  const response = await worker.fetch(
    new Request('https://www.bilhealth.com/.well-known/assetlinks.json'),
    environment('<!doctype html><title>BIL</title>', 'application/json'),
  );
  assert.equal(response.status, 503);
  assert.match(response.headers.get('Content-Type'), /^text\/plain/);
});

test('rejects AASA paths that are not bound to the production app entry', async () => {
  const splitAasa = {
    applinks: {
      details: [
        {
          appIDs: ['A1B2C3D4E5.com.bilhealth.bodyintelligencelog'],
          components: [],
        },
        {
          appIDs: ['A1B2C3D4E5.com.example.other'],
          components: productionShapeAasa.applinks.details[0].components,
        },
      ],
    },
  };
  const response = await worker.fetch(
    new Request('https://www.bilhealth.com/.well-known/apple-app-site-association'),
    environment(JSON.stringify(splitAasa)),
  );
  assert.equal(response.status, 503);
});

test('rejects every unknown well-known path', async () => {
  const response = await worker.fetch(
    new Request('https://www.bilhealth.com/.well-known/unknown'),
    environment(JSON.stringify(productionShapeAasa)),
  );
  assert.equal(response.status, 404);
});
