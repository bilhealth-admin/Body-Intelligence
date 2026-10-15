import assert from 'node:assert/strict';
import test from 'node:test';
import { communityLandingModel, renderCommunityLanding } from '../../public_site/community_links.mjs';

const member = '0123456789abcdef0123456789abcdef';
const invite = `${member}0123456789abcdef`;
class Element {
  constructor(tag) { this.tagName = tag; this.children = []; }
  append(child) { this.children.push(child); }
  replaceChildren(...children) { this.children = children; }
}
function documentFixture() {
  const app = new Element('main');
  return { app, getElementById: (id) => id === 'app' ? app : null,
    createElement: (tag) => new Element(tag) };
}
function flatten(element) { return [element, ...element.children.flatMap(flatten)]; }

test('shared member and referral URLs preserve only their safe BIL route', () => {
  assert.deepEqual(communityLandingModel(`https://www.bilhealth.com/download?member=${member}`),
    { kind: 'member', appUrl: `bil://community/member/${member}` });
  assert.deepEqual(communityLandingModel(`https://www.bilhealth.com/invite/${invite}`),
    { kind: 'invite', appUrl: `bil://invite/${invite}` });
  assert.deepEqual(communityLandingModel('https://www.bilhealth.com/download'),
    { kind: 'download', appUrl: 'bil://community' });
});

test('landing rejects credentials, foreign hosts, duplicates, extra fields and malformed codes', () => {
  for (const url of [
    `https://www.bilhealth.com.evil.invalid/download?member=${member}`,
    `https://attacker@www.bilhealth.com/download?member=${member}`,
    `https://www.bilhealth.com:444/download?member=${member}`,
    `https://www.bilhealth.com:443/download?member=${member}`,
    `https://www.bilhealth.com/download?member=${member}&member=${member}`,
    `https://www.bilhealth.com/download?member=${member}&access_token=secret`,
    `https://www.bilhealth.com/download?member=${member}#token`,
    'https://www.bilhealth.com/download?member=wrong',
    'https://www.bilhealth.com/invite/not-a-token',
    `https://www.bilhealth.com/invite/${invite}?redirect=https://evil.invalid`,
  ]) assert.equal(communityLandingModel(url), null, url);
});

for (const language of ['en', 'ar']) {
  test(`real landing DOM fixture exposes chosen Open action and no automatic mutation ${language}`, () => {
    const document = documentFixture();
    const model = renderCommunityLanding(document,
      `https://www.bilhealth.com/download?member=${member}`, language);
    const elements = flatten(document.app);
    const open = elements.find((element) => element.id === 'community-open-app');
    assert.equal(open.tagName, 'a');
    assert.equal(open.href, model.appUrl);
    assert.equal(elements.some((element) => element.id === 'community-apple-store'), false);
    assert.match(elements.find((element) => element.id === 'community-google-play').href,
      /^https:\/\/play\.google\.com\/store\/apps\/details\?id=com\.bilhealth\.bodyintelligencelog$/);
    assert.equal(elements.some((element) => ['form', 'script', 'iframe'].includes(element.tagName)), false);
    assert.equal(elements.some((element) => element.onclick), false);
    assert.equal(elements.some((element) => String(element.textContent).includes('access_token')), false);
  });
}

test('invalid landing exposes support without any BIL or store destination', () => {
  const document = documentFixture();
  const model = renderCommunityLanding(document,
    'https://www.bilhealth.com/download?member=<script>', 'en');
  assert.equal(model, null);
  const anchors = flatten(document.app).filter((element) => element.tagName === 'a');
  assert.deepEqual(anchors.map((element) => element.href), ['/support']);
});

test('Apple installation link needs an explicit genuine store ID and approved host', () => {
  for (const [value, expected] of [
    ['https://apps.apple.com/us/app/bil/id1234567890', true],
    ['https://apps.apple.com.evil.invalid/us/app/bil/id1234567890', false],
    ['https://apps.apple.com/us/app/bil', false],
    ['https://user@apps.apple.com/us/app/bil/id1234567890', false],
  ]) {
    const document = documentFixture();
    renderCommunityLanding(document, `https://www.bilhealth.com/invite/${invite}`,
      'en', { appleStoreUrl: value });
    assert.equal(flatten(document.app).some((element) =>
      element.id === 'community-apple-store'), expected);
  }
});
