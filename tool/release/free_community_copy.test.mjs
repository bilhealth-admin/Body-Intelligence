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
  test(`${lang}: home explains Free Community and next-update availability`, () => {
    const feature = current.home[lang].features.at(-1);
    assert.match(feature[2], /BIL Free/);
    assert.match(feature[2], lang === 'en' ? /next BIL app update/ : /تحديث تطبيق BIL القادم/);
    assert.match(feature[2], lang === 'en' ? /signed-in adults/ : /للبالغين المسجلين/);
  });
  test(`${lang}: subscription copy separates Free social access from paid AI`, () => {
    const sections = current.legal[lang]['/subscription-terms'].sections;
    const copy = sections.find(([key]) => key === 'community')[2];
    assert.match(copy, /BIL Free/);
    assert.match(copy, /Premium/);
    assert.match(copy, /AI Boost/);
    assert.match(copy, lang === 'en' ? /Older app builds/ : /الإصدارات الأقدم/);
    assert.match(copy, lang === 'en' ? /blocking, reporting, and moderation/ : /الحظر والإبلاغ والإشراف/);
    assert.match(copy, lang === 'en' ? /does not cancel or reprice/ : /لا يلغي هذا التغيير أي اشتراك قائم أو يغير سعره/);
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
}
