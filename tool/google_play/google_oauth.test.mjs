import assert from 'node:assert/strict';
import test from 'node:test';

import {
  GOOGLE_OAUTH_TOKEN_URI,
  googleOAuthTokenUri,
} from './google_oauth.mjs';

test('Google service-account token URI defaults to the fixed Google endpoint', () => {
  assert.equal(googleOAuthTokenUri({}), GOOGLE_OAUTH_TOKEN_URI);
  assert.equal(
    googleOAuthTokenUri({ token_uri: GOOGLE_OAUTH_TOKEN_URI }),
    GOOGLE_OAUTH_TOKEN_URI,
  );
});

test('untrusted service-account token URIs fail before credentials are sent', () => {
  for (const token_uri of [
    'https://attacker.example/token',
    'http://oauth2.googleapis.com/token',
    'https://oauth2.googleapis.com/token.evil.example',
    '//attacker.example/token',
    '',
    null,
  ]) {
    assert.throws(
      () => googleOAuthTokenUri({ token_uri }),
      /GOOGLE_OAUTH_TOKEN_URI_NOT_ALLOWED/,
    );
  }
});
