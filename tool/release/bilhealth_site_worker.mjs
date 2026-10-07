const AASA_PATH = '/.well-known/apple-app-site-association';
const ASSETLINKS_PATH = '/.well-known/assetlinks.json';
const BUNDLE_ID = 'com.bilhealth.bodyintelligencelog';
const CANONICAL_ORIGIN = 'https://www.bilhealth.com';
const INDEXABLE_PATHS = new Set([
  '/',
  '/privacy',
  '/terms',
  '/account-deletion',
  '/data-deletion',
  '/subscription-terms',
  '/health-disclaimer',
  '/support',
  '/community-guidelines',
  '/contact',
]);

function normalizedPath(pathname) {
  const clean = pathname.replace(/\/+$/, '') || '/';
  return clean === '/delete-account' ? '/account-deletion' : clean;
}

function canonicalUrlFor(url) {
  const path = normalizedPath(url.pathname);
  return `${CANONICAL_ORIGIN}${path === '/' ? '/' : path}`;
}

function escapeHtmlAttribute(value) {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('"', '&quot;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
}

function rewriteHtmlMetadata(html, canonicalUrl) {
  const escaped = escapeHtmlAttribute(canonicalUrl);
  const canonicalTag = `<link rel="canonical" href="${escaped}">`;
  const ogUrlTag = `<meta property="og:url" content="${escaped}">`;

  const defaultCanonical = '<link rel="canonical" href="https://www.bilhealth.com/">';
  const defaultOgUrl = '<meta property="og:url" content="https://www.bilhealth.com/">';

  if (html.includes(defaultCanonical)) {
    html = html.replace(defaultCanonical, canonicalTag);
  } else if (!html.includes('rel="canonical"')) {
    html = html.replace('</head>', `  ${canonicalTag}\n</head>`);
  }

  if (html.includes(defaultOgUrl)) {
    html = html.replace(defaultOgUrl, ogUrlTag);
  } else if (!html.includes('property="og:url"')) {
    html = html.replace('</head>', `  ${ogUrlTag}\n</head>`);
  }
  return html;
}

const REQUIRED_RETURN_PATHS = new Set([
  '/auth/callback',
  '/auth/reset-password',
]);
const REQUIRED_PUBLIC_PATHS = new Set(['/invite/*']);
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
    return [...REQUIRED_RETURN_PATHS, ...REQUIRED_PUBLIC_PATHS].every(
      (path) => paths.has(path),
    );
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
      if (url.protocol !== 'https:' || url.hostname !== 'www.bilhealth.com') {
        const target = new URL(canonicalUrlFor(url));
        target.search = url.search;
        return Response.redirect(target.toString(), 308);
      }

      const path = normalizedPath(url.pathname);
      if (url.pathname !== '/' && url.pathname.endsWith('/') && INDEXABLE_PATHS.has(path)) {
        const target = new URL(canonicalUrlFor(url));
        target.search = url.search;
        return Response.redirect(target.toString(), 308);
      }

      if (!env?.ASSETS?.fetch) {
        return failClosed(503, 'Site asset binding is unavailable.');
      }
      const assetResponse = await env.ASSETS.fetch(request);
      if (request.method !== 'GET') return assetResponse;

      const contentType = assetResponse.headers.get('Content-Type')?.toLowerCase() ?? '';
      if (!contentType.includes('text/html')) return assetResponse;

      const body = await assetResponse.text();
      const headers = new Headers(assetResponse.headers);
      headers.delete('Content-Length');
      if (!INDEXABLE_PATHS.has(path)) {
        headers.set('X-Robots-Tag', 'noindex,follow');
      }
      return new Response(rewriteHtmlMetadata(body, canonicalUrlFor(url)), {
        status: assetResponse.status,
        statusText: assetResponse.statusText,
        headers,
      });
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

export {
  canonicalUrlFor,
  hasAasaContract,
  hasAssetLinksContract,
  normalizedPath,
  rewriteHtmlMetadata,
};