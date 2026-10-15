import assert from 'node:assert/strict';
import test from 'node:test';

import {
  resolveSameOriginHttpsUrl,
  validateAppleUploadOperation,
  validateTrustedHttpsUrl,
} from './trusted_https_url.mjs';

test('same-origin API URLs accept relative paths and trusted pagination links', () => {
  const base = 'https://api.appstoreconnect.apple.com';
  assert.equal(
    resolveSameOriginHttpsUrl('/v1/apps/123', base, ['/v1/', '/v2/']),
    'https://api.appstoreconnect.apple.com/v1/apps/123',
  );
  assert.equal(
    resolveSameOriginHttpsUrl(
      'https://api.appstoreconnect.apple.com/v2/items?cursor=next',
      base,
      ['/v1/', '/v2/'],
    ),
    'https://api.appstoreconnect.apple.com/v2/items?cursor=next',
  );
});

test('same-origin URL guard rejects external origins, traversal and unsafe schemes', () => {
  const base = 'https://androidpublisher.googleapis.com/androidpublisher/v3';
  for (const value of [
    'https://attacker.example/steal',
    '//attacker.example/steal',
    'http://androidpublisher.googleapis.com/androidpublisher/v3/apps',
    '/../../attacker',
    'https://user@androidpublisher.googleapis.com/androidpublisher/v3/apps',
  ]) {
    assert.throws(
      () => resolveSameOriginHttpsUrl(
        value,
        base,
        ['/androidpublisher/v3/'],
      ),
      /TRUSTED_URL/,
      value,
    );
  }
  assert.equal(
    validateAppleUploadOperation({
      method: 'PUT',
      url: 'https://store-030.blobstore.apple.com/assets?token=opaque',
    }),
    'https://store-030.blobstore.apple.com/assets?token=opaque',
  );
  assert.throws(
    () => validateAppleUploadOperation({ method: 'POST', url: 'https://store-030.blobstore.apple.com/x' }),
    /APPLE_ASSET_UPLOAD_METHOD_REJECTED/,
  );
});

test('Apple asset URL guard accepts its documented blobstore and rejects lookalikes', () => {
  assert.equal(
    validateTrustedHttpsUrl(
      'https://store-030.blobstore.apple.com/assets?token=opaque',
      ['blobstore.apple.com'],
    ),
    'https://store-030.blobstore.apple.com/assets?token=opaque',
  );
  for (const value of [
    'https://blobstore.apple.com.attacker.example/assets',
    'http://store-030.blobstore.apple.com/assets',
    'https://user@store-030.blobstore.apple.com/assets',
  ]) {
    assert.throws(
      () => validateTrustedHttpsUrl(value, ['blobstore.apple.com']),
      /TRUSTED_ASSET_URL/,
      value,
    );
  }
});

test('Google Play image URLs are restricted to the exact image host', () => {
  assert.equal(
    validateTrustedHttpsUrl(
      'https://play-lh.googleusercontent.com/image=full',
      ['play-lh.googleusercontent.com'],
      { allowSubdomains: false },
    ),
    'https://play-lh.googleusercontent.com/image=full',
  );
  assert.throws(
    () => validateTrustedHttpsUrl(
      'https://sub.play-lh.googleusercontent.com/image',
      ['play-lh.googleusercontent.com'],
      { allowSubdomains: false },
    ),
    /TRUSTED_ASSET_URL_REJECTED/,
  );
});
