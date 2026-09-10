import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/legal_publication_verification.dart';

Map<String, Object?> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

Map<String, Object?> _copy(Map<String, Object?> source) =>
    jsonDecode(jsonEncode(source)) as Map<String, Object?>;

Matcher _invalidWith(String text) => isA<StateError>().having(
  (error) => error.message.toString(),
  'message',
  contains(text),
);

void main() {
  late Map<String, Object?> metadata;
  late Map<String, Object?> proof;

  setUp(() {
    metadata = _readJson('docs/release/BIL_EPIC15_STORE_METADATA.json');
    proof = _readJson(legalPublicationEvidencePath);
  });

  test('checked-in live publication proof matches local 18+ legal asset', () {
    expect(
      () => validateLegalPublicationVerification(
        metadata: metadata,
        proof: proof,
      ),
      returnsNormally,
    );
  });

  test('verification never substitutes for owner legal approval', () {
    final changedMetadata = _copy(metadata);
    final legal = changedMetadata['legal_and_support'] as Map<String, Object?>;
    legal['legal_approval'] = 'OWNER_APPROVED';

    expect(
      () => validateLegalPublicationVerification(
        metadata: changedMetadata,
        proof: proof,
      ),
      throwsA(_invalidWith('must not claim legal approval')),
    );

    final changedProof = _copy(proof);
    changedProof['legal_approval'] = 'OWNER_APPROVED';
    expect(
      () => validateLegalPublicationVerification(
        metadata: metadata,
        proof: changedProof,
      ),
      throwsA(_invalidWith('must not claim legal approval')),
    );
  });

  test('missing or invented evidence identity fails closed', () {
    final changedMetadata = _copy(metadata);
    final legal = changedMetadata['legal_and_support'] as Map<String, Object?>;
    legal['publication_verification_evidence'] = 'unverified.json';

    expect(
      () => validateLegalPublicationVerification(
        metadata: changedMetadata,
        proof: proof,
      ),
      throwsA(_invalidWith('must pin the verification evidence path')),
    );

    legal['publication_verification_evidence'] = legalPublicationEvidencePath;
    legal['status'] = 'OWNER_CONFIRMED_PUBLISHED_WITHOUT_PROOF';
    expect(
      () => validateLegalPublicationVerification(
        metadata: changedMetadata,
        proof: proof,
      ),
      throwsA(_invalidWith('verified HTTP/content state only')),
    );
  });

  test('remote/local hash mismatch fails closed', () {
    final changed = _copy(proof);
    final remote = changed['remote_asset'] as Map<String, Object?>;
    remote['sha256'] = List<String>.filled(64, '0').join();

    expect(
      () => validateLegalPublicationVerification(
        metadata: metadata,
        proof: changed,
      ),
      throwsA(_invalidWith('remote and local legal asset hashes differ')),
    );
  });

  test('changed local asset length invalidates stored publication proof', () {
    expect(
      () => validateLegalPublicationVerification(
        metadata: metadata,
        proof: proof,
        readBytes: (path) => [...File(path).readAsBytesSync(), 32],
      ),
      throwsA(_invalidWith('checked-in local asset byte count mismatch')),
    );
  });

  test('same-length local asset changes invalidate stored proof', () {
    expect(
      () => validateLegalPublicationVerification(
        metadata: metadata,
        proof: proof,
        readBytes: (path) {
          final changed = File(path).readAsBytesSync();
          changed[0] ^= 1;
          return changed;
        },
      ),
      throwsA(_invalidWith('checked-in local asset SHA-256 mismatch')),
    );
  });

  test('missing route and non-200 route fail closed', () {
    final missing = _copy(proof);
    final missingRoutes = missing['routes'] as List<Object?>;
    missingRoutes.removeLast();
    expect(
      () => validateLegalPublicationVerification(
        metadata: metadata,
        proof: missing,
      ),
      throwsA(_invalidWith('exactly the required public routes')),
    );

    final unavailable = _copy(proof);
    final routes = unavailable['routes'] as List<Object?>;
    final privacy = routes.first as Map<String, Object?>;
    privacy['http_status'] = 503;
    expect(
      () => validateLegalPublicationVerification(
        metadata: metadata,
        proof: unavailable,
      ),
      throwsA(_invalidWith('privacy did not return HTTP 200')),
    );
  });

  test('route URL and response hash proof are exact', () {
    final inventedUrl = _copy(proof);
    final urlRoutes = inventedUrl['routes'] as List<Object?>;
    final privacy = urlRoutes.first as Map<String, Object?>;
    privacy['url'] = 'https://example.invalid/privacy';
    expect(
      () => validateLegalPublicationVerification(
        metadata: metadata,
        proof: inventedUrl,
      ),
      throwsA(_invalidWith('privacy URL or final URL mismatch')),
    );

    final malformedHash = _copy(proof);
    final hashRoutes = malformedHash['routes'] as List<Object?>;
    final terms = hashRoutes[1] as Map<String, Object?>;
    terms['response_sha256'] = 'not-a-sha256';
    expect(
      () => validateLegalPublicationVerification(
        metadata: metadata,
        proof: malformedHash,
      ),
      throwsA(_invalidWith('terms response SHA-256 is malformed')),
    );
  });

  test('missing 18+ content assertion fails closed', () {
    final changed = _copy(proof);
    final assertions = changed['content_assertions'] as Map<String, Object?>;
    assertions.remove('terms_ar_minimum_age');

    expect(
      () => validateLegalPublicationVerification(
        metadata: metadata,
        proof: changed,
      ),
      throwsA(_invalidWith('content assertion set must be exact')),
    );
  });
}
