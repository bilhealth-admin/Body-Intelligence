import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { runInNewContext } from 'node:vm';

// Build from the checked-in, trusted document source and existing renderer.
// Legal text and layout have one source; no duplicate policy is maintained.
export function renderPolicyPages() {
  const root = new URL('../../public_site/', import.meta.url);
  const source = readFileSync(new URL('app.js', root), 'utf8');
  const shell = readFileSync(new URL('index.html', root), 'utf8');
  const data = source.slice(0, source.indexOf('function currentLanguage()'));
  const renderer = source.slice(source.indexOf('function renderDocument('), source.indexOf('async function renderPasswordReset('));
  const pages = runInNewContext(`${data}\n${renderer}\nObject.fromEntries(Object.entries(legal).map(([lang, docs]) => [lang, Object.fromEntries(Object.entries(docs).map(([path, page]) => [path, {title:page.title,html:renderDocument(page, lang)}]))]));`, {}, { timeout: 1000 });
  return Object.entries(pages).flatMap(([lang, docs]) => Object.entries(docs).map(([path, page]) => {
    const html = shell
      .replace('<html lang="en" dir="ltr">', `<html lang="${lang}" dir="${lang === 'ar' ? 'rtl' : 'ltr'}" data-bil-document="${path}">`)
      .replace('<div id="app" aria-live="polite"></div>', `<div id="app" aria-live="polite">${page.html}</div>`)
      .replace('<title>BIL Health — Understand your body</title>', `<title>${page.title} — BIL Health</title>`)
      .replace('rel="canonical" href="https://www.bilhealth.com/"', `rel="canonical" href="https://www.bilhealth.com${path}"`);
    return {path, lang, html};
  }));
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const target = new URL('../../public_site/policy-pages/', import.meta.url);
  mkdirSync(target, { recursive: true });
  for (const page of renderPolicyPages()) {
    writeFileSync(new URL(`${page.path.slice(1)}.${page.lang}.html`, target), page.html);
  }
}
