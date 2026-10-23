import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import worker from './bilhealth_site_worker.mjs';
import { renderPolicyFallback, renderPolicyPages } from './render_public_policy_pages.mjs';

const pages = renderPolicyPages();
for (const page of pages) {
  test(`${page.path} ${page.lang} serves the complete same-source policy without script execution`, async () => {
    const committed = readFileSync(new URL(`../../public_site/policy-pages${page.path}.${page.lang}.html`, import.meta.url), 'utf8');
    assert.equal(committed, page.html, 'Regenerate static policies after editing app.js');
    let fetched;
    const env = {ASSETS:{fetch:async request => {
      fetched = new URL(request.url).pathname;
      return new Response(committed, {headers:{'content-type':'text/html'}});
    }}};
    const response = await worker.fetch(new Request(`https://www.bilhealth.com${page.path}?lang=${page.lang}`), env);
    assert.equal(response.status, 200);
    assert.equal(response.headers.get('content-language'), page.lang);
    assert.equal(fetched, `/policy-pages${page.path}.${page.lang}.html`);
    const body = await response.text();
    assert.ok(body.includes('class="legal-section'));
    assert.ok(body.includes(`data-bil-document="${page.path}"`));
    assert.ok(!body.includes('<div id="app" aria-live="polite"></div>'));
    assert.ok(!body.includes('<noscript>'), 'The complete localized policy must not append a second generic policy');
    if (page.path === '/community-guidelines') {
      for (const section of ['scope','respect','content','report','circles','moderation','privacy']) {
        assert.ok(body.includes(`id="${section}"`));
      }
      assert.ok(body.includes('community-policy-v1'));
      assert.ok(body.includes('mailto:support@bilhealth.com'));
    }
    if (page.path === '/privacy') {
      assert.ok(body.includes('id="translation"'));
      assert.ok(body.includes('Google Cloud Translation'));
      assert.ok(body.includes(page.lang === 'ar' ? 'تبقى الخطط الذكية المحفوظة على الجهاز' : 'Saved Smart Plans stay on the device'));
      assert.ok(body.includes(page.lang === 'ar' ? 'علامة حذف' : 'deletion marker'));
      assert.ok(body.includes(page.lang === 'ar' ? 'إيقاف نسخ الخطة' : 'stop plan backup'));
    }
    const head = await worker.fetch(new Request(`https://www.bilhealth.com${page.path}?lang=${page.lang}`, {method:'HEAD'}), env);
    assert.equal(head.status, 200);
    assert.equal(await head.text(), '');
  });
}
test('the index no-script policies contain the complete current canonical copy in both languages', () => {
  const index = readFileSync(new URL('../../public_site/index.html', import.meta.url), 'utf8');
  const fallback = index.match(/<noscript>[\s\S]*?<\/noscript>/)?.[0];
  assert.equal(fallback, renderPolicyFallback(), 'Regenerate the public site after editing canonical policy copy');
  const text = html => html.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
  for (const page of pages) {
    assert.ok(fallback.includes(`href="${page.path}?lang=${page.lang}"`), 'Every complete localized policy remains accessible without JavaScript');
    if (!['/privacy', '/subscription-terms'].includes(page.path)) continue;
    const content = page.html.match(/<div id="app" aria-live="polite">([\s\S]*)<\/div>\s*<\/main>/)?.[1];
    assert.ok(content, 'Compare the actual complete canonical document, not only a date or heading');
    assert.ok(text(fallback).includes(text(content)), `${page.lang} ${page.path} must retain every canonical section and paragraph`);
    assert.ok(fallback.includes(`lang="${page.lang}" dir="${page.lang === 'ar' ? 'rtl' : 'ltr'}" data-bil-fallback-document="${page.path}"`));
  }
  const ids = [...fallback.matchAll(/\bid="([^"]+)"/g)].map(match => match[1]);
  assert.equal(new Set(ids).size, ids.length, 'Bilingual documents must not duplicate section IDs');
  for (const [, anchor] of fallback.matchAll(/href="#([^"]+)"/g)) {
    assert.ok(ids.includes(anchor), `No-script table of contents target missing: ${anchor}`);
  }
  assert.doesNotMatch(fallback, /<script|Last updated: 20 October 2026/);
});
test('missing, wrong-route or SPA policy fallback cannot be reported as available', async () => {
  for (const body of ['<html>generic SPA</html>', '<html data-bil-document="/privacy">']) {
    const response = await worker.fetch(new Request('https://www.bilhealth.com/community-guidelines'), {ASSETS:{fetch:async () => new Response(body)}});
    assert.equal(response.status, 503);
  }
});
test('policy pages never process a mutation request', async () => {
  const response = await worker.fetch(new Request('https://www.bilhealth.com/community-guidelines', {method:'POST'}), {ASSETS:{fetch:async () => {throw Error('unexpected asset access');}}});
  assert.equal(response.status, 405);
});
