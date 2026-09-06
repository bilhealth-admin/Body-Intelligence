const AASA_PATH = '/.well-known/apple-app-site-association';
const ASSETLINKS_PATH = '/.well-known/assetlinks.json';
const BUNDLE_ID = 'com.bilhealth.bodyintelligencelog';
const REQUIRED_RETURN_PATHS = new Set([
  '/auth/callback',
  '/auth/reset-password',
]);
const TEAM_APP_ID = new RegExp(`^[A-Z0-9]{10}\\.${BUNDLE_ID.replaceAll('.', '\\.')}$`);
const SHA256_FINGERPRINT = /^(?:[A-F0-9]{2}:){31}[A-F0-9]{2}$/;

function hasAasaContract(document) {
  const details = document?.applinks?.details;
  if (!Array.isArray(details) || details.length === 0) return false;
  return details.some((detail) => {
    const appIds = Array.isArray(detail?.appIDs) ? detail.appIDs : [];
    if (!appIds.some((appId) => TEAM_APP_ID.test(appId))) return false;
    const paths = new Set(
      Array.isArray(detail?.components)
        ? detail.components
            .filter((component) => component?.exclude !== true)
            .map((component) => component?.['/'])
        : [],
    );
    return [...REQUIRED_RETURN_PATHS].every((path) => paths.has(path));
  });
}

function hasAssetLinksContract(document) {
  if (!Array.isArray(document)) return false;
  return document.some((statement) => {
    const target = statement?.target;
    return Array.isArray(statement?.relation)
      && statement.relation.includes('delegate_permission/common.handle_all_urls')
      && target?.namespace === 'android_app'
      && target?.package_name === BUNDLE_ID
      && Array.isArray(target?.sha256_cert_fingerprints)
      && target.sha256_cert_fingerprints.length > 0
      && target.sha256_cert_fingerprints.every((value) =>
        SHA256_FINGERPRINT.test(value)
          && new Set(value.replaceAll(':', '')).size >= 4,
      );
  });
}

function failClosed(status, message) {
  return new Response(`${message}\n`, {
    status,
    headers: {
      'Cache-Control': 'no-store',
      'Content-Type': 'text/plain; charset=utf-8',
      'X-Content-Type-Options': 'nosniff',
    },
  });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (!url.pathname.startsWith('/.well-known/')) {
      return env.ASSETS.fetch(request);
    }
    if (url.pathname !== AASA_PATH && url.pathname !== ASSETLINKS_PATH) {
      return failClosed(404, 'Association document not found.');
    }
    if (request.method !== 'GET' && request.method !== 'HEAD') {
      return failClosed(405, 'Method not allowed.');
    }
    if (!env?.ASSETS?.fetch) {
      return failClosed(503, 'Association asset binding is unavailable.');
    }

    // Fetch as GET even for HEAD so malformed or SPA-fallback HTML can never be
    // reported as a valid association endpoint.
    const assetRequest = new Request(request.url, { method: 'GET' });
    const assetResponse = await env.ASSETS.fetch(assetRequest);
    const sourceType = assetResponse.headers.get('Content-Type')?.toLowerCase() ?? '';
    if (!assetResponse.ok || sourceType.includes('text/html')) {
      return failClosed(404, 'Association document not found.');
    }

    const body = await assetResponse.text();
    let document;
    try {
      document = JSON.parse(body);
    } catch {
      return failClosed(503, 'Association document is invalid.');
    }
    const isValid = url.pathname === AASA_PATH
      ? hasAasaContract(document)
      : hasAssetLinksContract(document);
    if (!isValid) {
      return failClosed(503, 'Association document is invalid.');
    }

    const headers = new Headers(assetResponse.headers);
    headers.set('Content-Type', 'application/json; charset=utf-8');
    headers.set('Cache-Control', 'public, max-age=300, must-revalidate');
    headers.set('X-Content-Type-Options', 'nosniff');
    headers.delete('Content-Length');
    return new Response(request.method === 'HEAD' ? null : body, {
      status: 200,
      headers,
    });
  },
};

export { hasAasaContract, hasAssetLinksContract };
