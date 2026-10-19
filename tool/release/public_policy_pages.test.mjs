import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import worker from './bilhealth_site_worker.mjs';
import { renderPolicyPages } from './render_public_policy_pages.mjs';

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
    }
    const head = await worker.fetch(new Request(`https://www.bilhealth.com${page.path}?lang=${page.lang}`, {method:'HEAD'}), env);
    assert.equal(head.status, 200);
    assert.equal(await head.text(), '');
  });
}
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
