import assert from 'node:assert/strict';
import test from 'node:test';

import { containsExactHttpsUrl } from './exact_url.mjs';

const policy = 'https://www.bilhealth.com/community-guidelines';

test('recognizes the exact legal URL in plain and linked copy', () => {
  assert.equal(containsExactHttpsUrl(`Read ${policy}.`, policy), true);
  assert.equal(containsExactHttpsUrl(`[Guidelines](${policy})`, policy), true);
});

test('does not accept a legal URL embedded in a different destination', () => {
  for (const copy of [
    'https://evil.example/?next=https://www.bilhealth.com/community-guidelines',
    `${policy}.evil.example`,
    `${policy}?redirect=https://evil.example`,
    `${policy}#not-the-policy-page`,
    'https://attacker@www.bilhealth.com/community-guidelines',
    'http://www.bilhealth.com/community-guidelines',
  ]) {
    assert.equal(containsExactHttpsUrl(copy, policy), false, copy);
  }
  assert.equal(containsExactHttpsUrl('', policy), false);
  assert.equal(containsExactHttpsUrl(null, policy), false);
});
