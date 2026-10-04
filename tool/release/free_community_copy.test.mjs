import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';

const file = new URL('../../public_site/app.js', import.meta.url);
const source = fs.readFileSync(file, 'utf8');
// Extract only the static copy declarations; no DOM, browser or network runs.
function copyFrom(text) {
  const end = text.indexOf('\nfunction ');
  assert.ok(end > 0);
  return vm.runInNewContext(text.slice(0, end) + '\n({home, legal});', {}, { timeout: 1000 });
}
const current = copyFrom(source);

for (const lang of ['en', 'ar']) {
  test(`${lang}: home explains current Free Community availability`, () => {
    const feature = current.home[lang].features.at(-1);
    assert.match(feature[2], /BIL Free/);
    assert.match(feature[2], lang === 'en' ? /signed-in adults/ : /للبالغين المسجلين/);
    assert.doesNotMatch(feature[2], lang === 'en' ? /next BIL app update/ : /تحديث تطبيق BIL القادم/);
  });
  test(`${lang}: subscription copy separates Free social access from paid AI`, () => {
    const sections = current.legal[lang]['/subscription-terms'].sections;
    const copy = sections.find(([key]) => key === 'community')[2];
    assert.match(copy, /BIL Free/);
    assert.match(copy, /Premium/);
    assert.match(copy, /AI Boost/);
    assert.match(copy, lang === 'en' ? /No Premium subscription or AI Boost purchase is required/ : /لا تتطلب هذه الميزات اشتراك Premium أو شراء AI Boost/);
    assert.doesNotMatch(copy, lang === 'en' ? /Older app builds/ : /الإصدارات الأقدم/);
    assert.match(copy, lang === 'en' ? /blocking, reporting, and moderation/ : /الحظر والإبلاغ والإشراف/);
    assert.match(copy, lang === 'en' ? /does not cancel or reprice/ : /لا يلغي ذلك أي اشتراك قائم أو يغير سعره/);
  });
  test(`${lang}: Free copy keeps billing topics and the real Community policy`, () => {
    const sections = current.legal[lang]['/subscription-terms'].sections;
    for (const key of ['plans', 'community', 'billing', 'ai', 'cancel', 'restore', 'changes', 'support']) {
      assert.equal(sections.filter(([id]) => id === key).length, 1, key);
    }
    assert.equal(current.legal[lang]['/community-guidelines'].version, 'community-policy-v1');
    assert.ok(current.legal[lang]['/privacy'].sections.length > 0);
    assert.ok(current.legal[lang]['/account-deletion'].sections.length > 0);
  });
  test(`${lang}: privacy declares eligible Android and iOS advertising without health targeting`, () => {
    const privacy = current.legal[lang]['/privacy'];
    for (const id of ['data', 'sharing']) {
      const matches = privacy.sections.filter(([key]) => key === id);
      assert.equal(matches.length, 1, id);
      const copy = matches[0][2];
      assert.match(copy, /Android/);
      assert.match(copy, /iOS/);
      assert.match(copy, /Google Mobile Ads/);
    }
    const sharing = privacy.sections.find(([key]) => key === 'sharing')[2];
    assert.match(sharing, /Google UMP/);
    assert.match(sharing, lang === 'en' ? /Ads are excluded for guests and paid users/ : /لا تظهر الإعلانات للضيف أو للمستخدم المدفوع/);
    assert.match(sharing, lang === 'en' ? /Health data is not sold/ : /لا تُباع البيانات الصحية/);
    assert.match(privacy.updated, lang === 'en' ? /4 October 2026/ : /4 أكتوبر 2026/);
  });
}

test('public advertising publisher and deployment verification agree', () => {
  const ads = fs.readFileSync(new URL('../../public_site/app-ads.txt', import.meta.url), 'utf8');
  assert.match(ads, /^google\.com, pub-9688223318643509, DIRECT, f08c47fec0942fa0\s*$/m);
  assert.doesNotMatch(ads, /pub-2630397016527111/);
  const workflow = fs.readFileSync(new URL('../../.github/workflows/bil_public_site_deploy.yml', import.meta.url), 'utf8');
  assert.equal((workflow.match(/pub-9688223318643509/g) ?? []).length, 2);
  assert.doesNotMatch(workflow, /pub-2630397016527111/);
});

test('no-script privacy retains the current Android and iOS provider disclosure', () => {
  const html = fs.readFileSync(new URL('../../public_site/index.html', import.meta.url), 'utf8');
  const fallback = html.match(/<noscript>([\s\S]*?)<\/noscript>/)?.[1];
  assert.ok(fallback, 'Actual no-script legal fallback must remain readable');
  assert.match(fallback, /Last updated: 4 October 2026/);
  assert.match(fallback, /Google Mobile Ads.*supported Android and iOS builds/);
  assert.doesNotMatch(fallback, /Google Mobile Ads.*supported Android builds/);
  assert.match(fallback, /Health data is not sold or used to personalize advertising/);
  assert.match(fallback, /account-deletion/);
  assert.match(fallback, /privacy@bilhealth\.com/);
});
