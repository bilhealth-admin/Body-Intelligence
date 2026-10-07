import assert from 'node:assert/strict';
import test from 'node:test';

import worker, {
  canonicalUrlFor,
  rewriteHtmlMetadata,
} from './bilhealth_site_worker.mjs';

const productionShapeAasa = {
  applinks: {
    details: [{
      appIDs: ['A1B2C3D4E5.com.bilhealth.bodyintelligencelog'],
      components: [
        { '/': '/auth/callback' },
        { '/': '/auth/reset-password' },
        { '/': '/invite/*' },
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

const representativeHtml = `<!doctype html>
<html>
<head>
  <meta property="og:url" content="https://www.bilhealth.com/">
  <link rel="canonical" href="https://www.bilhealth.com/">
  <title>BIL Health</title>
</head>
<body><main>BIL</main></body>
</html>`;

test('canonical URL normalizes scheme, host, trailing slash, alias, and query', () => {
  assert.equal(
    canonicalUrlFor(new URL('http://bilhealth.com/privacy/?lang=ar')),
    'https://www.bilhealth.com/privacy',
  );
  assert.equal(
    canonicalUrlFor(new URL('https://www.bilhealth.com/delete-account?lang=ar')),
    'https://www.bilhealth.com/account-deletion',
  );
  assert.equal(
    canonicalUrlFor(new URL('http://www.bilhealth.com/')),
    'https://www.bilhealth.com/',
  );
});

test('rewrites canonical and Open Graph URL in initial HTML', () => {
  const html = rewriteHtmlMetadata(
    representativeHtml,
    'https://www.bilhealth.com/privacy',
  );
  assert.match(
    html,
    /<link rel="canonical" href="https:\/\/www\.bilhealth\.com\/privacy">/,
  );
  assert.match(
    html,
    /<meta property="og:url" content="https:\/\/www\.bilhealth\.com\/privacy">/,
  );
  assert.doesNotMatch(
    html,
    /<link rel="canonical" href="https:\/\/www\.bilhealth\.com\/">/,
  );
});

test('redirects the exact Search Console HTTP WWW root variant to HTTPS WWW', async () => {
  const response = await worker.fetch(
    new Request('http://www.bilhealth.com/'),
    environment(representativeHtml, 'text/html; charset=utf-8'),
  );
  assert.equal(response.status, 308);
  assert.equal(response.headers.get('location'), 'https://www.bilhealth.com/');
});

test('redirects apex and preserves harmless query parameters', async () => {
  const response = await worker.fetch(
    new Request('https://bilhealth.com/privacy?lang=ar'),
    environment(representativeHtml, 'text/html; charset=utf-8'),
  );
  assert.equal(response.status, 308);
  assert.equal(
    response.headers.get('location'),
    'https://www.bilhealth.com/privacy?lang=ar',
  );
});

test('redirects trailing slash variants for indexable routes', async () => {
  const response = await worker.fetch(
    new Request('https://www.bilhealth.com/privacy/?lang=ar'),
    environment(representativeHtml, 'text/html; charset=utf-8'),
  );
  assert.equal(response.status, 308);
  assert.equal(
    response.headers.get('location'),
    'https://www.bilhealth.com/privacy?lang=ar',
  );
});

test('serves self-canonical HTML before client JavaScript runs', async () => {
  const response = await worker.fetch(
    new Request('https://www.bilhealth.com/privacy'),
    environment(representativeHtml, 'text/html; charset=utf-8'),
  );
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('X-Robots-Tag'), null);
  const body = await response.text();
  assert.match(
    body,
    /<link rel="canonical" href="https:\/\/www\.bilhealth\.com\/privacy">/,
  );
  assert.match(
    body,
    /<meta property="og:url" content="https:\/\/www\.bilhealth\.com\/privacy">/,
  );
});

test('marks unknown SPA fallback pages noindex', async () => {
  const response = await worker.fetch(
    new Request('https://www.bilhealth.com/not-a-real-page'),
    environment(representativeHtml, 'text/html; charset=utf-8'),
  );
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('X-Robots-Tag'), 'noindex,follow');
});

test('keeps association documents direct on the apex host for app links', async () => {
  const response = await worker.fetch(
    new Request('https://bilhealth.com/.well-known/apple-app-site-association'),
    environment(JSON.stringify(productionShapeAasa)),
  );
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('location'), null);
});
