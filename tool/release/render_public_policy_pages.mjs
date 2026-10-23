import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { runInNewContext } from 'node:vm';

// Build from the checked-in, trusted document source and existing renderer.
// Legal text and layout have one source; no duplicate policy is maintained.
function canonicalDocuments() {
  const root = new URL('../../public_site/', import.meta.url);
  const source = readFileSync(new URL('app.js', root), 'utf8');
  const data = source.slice(0, source.indexOf('function currentLanguage()'));
  const renderer = source.slice(source.indexOf('function renderDocument('), source.indexOf('async function renderPasswordReset('));
  const pages = runInNewContext(`${data}\n${renderer}\nObject.fromEntries(Object.entries(legal).map(([lang, docs]) => [lang, Object.fromEntries(Object.entries(docs).map(([path, page]) => [path, {title:page.title,html:renderDocument(page, lang)}]))]));`, {}, { timeout: 1000 });
  return Object.entries(pages).flatMap(([lang, docs]) => Object.entries(docs).map(([path, page]) => ({path, lang, ...page})));
}

function withoutFallback(shell) {
  // Each policy already has its complete, localized document in #app.
  // A second generic no-script policy would duplicate or contradict it.
  return shell.replace(/\s*<noscript>[\s\S]*?<\/noscript>/, '');
}

export function renderPolicyPages() {
  const shell = withoutFallback(readFileSync(new URL('../../public_site/index.html', import.meta.url), 'utf8'));
  return canonicalDocuments().map(({path, lang, ...page}) => {
    const html = shell
      .replace('<html lang="en" dir="ltr">', `<html lang="${lang}" dir="${lang === 'ar' ? 'rtl' : 'ltr'}" data-bil-document="${path}">`)
      .replace('<div id="app" aria-live="polite"></div>', `<div id="app" aria-live="polite">${page.html}</div>`)
      .replace('<title>BIL Health — Understand your body</title>', `<title>${page.title} — BIL Health</title>`)
      .replace('rel="canonical" href="https://www.bilhealth.com/"', `rel="canonical" href="https://www.bilhealth.com${path}"`);
    return {path, lang, html};
  });
}

export function renderPolicyFallback() {
  const pages = canonicalDocuments();
  const links = ['en', 'ar'].map(lang => {
    const items = pages.filter(page => page.lang === lang).map(page =>
      `<li><a href="${page.path}?lang=${lang}">${page.title}</a></li>`).join('');
    return `<nav lang="${lang}" dir="${lang === 'ar' ? 'rtl' : 'ltr'}" aria-label="${lang === 'ar' ? 'وثائق BIL' : 'BIL documents'}"><ul>${items}</ul></nav>`;
  }).join('\n');
  const documents = pages.filter(page => ['/privacy', '/subscription-terms'].includes(page.path)).map(page => {
    // Both languages share section names. Namespace only local anchors so
    // every complete policy remains navigable without duplicate HTML IDs.
    const prefix = `noscript-${page.lang}-${page.path.slice(1)}-`;
    const html = page.html.replace(/\bid="([^"]+)"/g, (_, id) => `id="${prefix}${id}"`)
      .replace(/href="#([^"]+)"/g, (_, id) => `href="#${prefix}${id}"`);
    return `<div lang="${page.lang}" dir="${page.lang === 'ar' ? 'rtl' : 'ltr'}" data-bil-fallback-document="${page.path}">${html}</div>`;
  }).join('\n');
  return `<noscript>\n    <section class="noscript-card" id="no-script-policies">\n      <h1>BIL Health legal and privacy information · معلومات BIL القانونية والخصوصية</h1>\n      ${links}\n      ${documents}\n    </section>\n  </noscript>`;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const index = new URL('../../public_site/index.html', import.meta.url);
  const shell = readFileSync(index, 'utf8');
  if (!/<noscript>[\s\S]*?<\/noscript>/.test(shell)) {
    throw new Error('Public index is missing its no-script fallback slot');
  }
  writeFileSync(index, shell.replace(/<noscript>[\s\S]*?<\/noscript>/, renderPolicyFallback()));
  const target = new URL('../../public_site/policy-pages/', import.meta.url);
  mkdirSync(target, { recursive: true });
  for (const page of renderPolicyPages()) {
    writeFileSync(new URL(`${page.path.slice(1)}.${page.lang}.html`, target), page.html);
  }
}
