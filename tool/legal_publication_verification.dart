import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const legalPublicationStatus =
    'LIVE_HTTP_200_LOCAL_CONTENT_SHA256_MATCH_VERIFIED_2026_09_10_'
    'LEGAL_APPROVAL_NOT_CLAIMED';
const legalPublicationEvidencePath =
    'docs/release/BIL_EPIC15_PUBLICATION_VERIFICATION_2026-09-10.json';

const _requiredContentAssertions = <String, String>{
  'privacy_en_adults_only': 'BIL is intended only for adults aged 18 or older',
  'privacy_ar_adults_only': 'التطبيق مخصص فقط للبالغين بعمر 18 عامًا فأكثر',
  'terms_en_minimum_age': 'You must be at least 18 years old',
  'terms_ar_minimum_age': 'يجب أن يكون عمرك 18 عامًا على الأقل',
};

Never _invalid(String message) =>
    throw StateError('Invalid legal publication verification: $message');

Map<String, Object?> _map(Map<String, Object?> parent, String key) {
  final value = parent[key];
  if (value is! Map<String, Object?>) _invalid('$key must be an object');
  return value;
}

String _string(Map<String, Object?> parent, String key) {
  final value = parent[key];
  if (value is! String || value.trim().isEmpty) {
    _invalid('$key must be a non-empty string');
  }
  return value;
}

int _integer(Map<String, Object?> parent, String key) {
  final value = parent[key];
  if (value is! int) _invalid('$key must be an integer');
  return value;
}

void _expect(bool condition, String message) {
  if (!condition) _invalid(message);
}

/// Verifies a checked-in, immutable observation of the public legal pages.
///
/// This proves only endpoint availability and byte identity between the
/// deployed JavaScript and the checked-in public-site JavaScript. It never
/// represents legal review or owner legal approval.
void validateLegalPublicationVerification({
  required Map<String, Object?> metadata,
  required Map<String, Object?> proof,
  List<int> Function(String path)? readBytes,
}) {
  final legal = _map(metadata, 'legal_and_support');
  _expect(legal['domain'] == 'bilhealth.com', 'unexpected legal domain');
  _expect(
    legal['support_email'] == 'support@bilhealth.com',
    'unexpected support email',
  );
  _expect(
    legal['status'] == legalPublicationStatus,
    'metadata status must describe verified HTTP/content state only',
  );
  _expect(
    legal['legal_approval'] == 'NOT_CLAIMED',
    'metadata must not claim legal approval',
  );
  _expect(
    legal['publication_verification_evidence'] == legalPublicationEvidencePath,
    'metadata must pin the verification evidence path',
  );

  _expect(proof['schema_version'] == 1, 'unsupported proof schema');
  _expect(
    proof['status'] == 'VERIFIED_LIVE_HTTP_200_LOCAL_CONTENT_SHA256_MATCH',
    'proof status is not a verified live/local match',
  );
  _expect(
    proof['verification_scope'] ==
        'PUBLIC_ENDPOINT_AVAILABILITY_AND_DEPLOYED_STATIC_ASSET_BYTE_IDENTITY',
    'proof scope is missing or overbroad',
  );
  _expect(
    proof['legal_approval'] == 'NOT_CLAIMED',
    'proof must not claim legal approval',
  );
  _expect(
    proof['method'] == 'GET_ONLY_NO_STORE_OR_SITE_MUTATION',
    'proof method must be GET-only',
  );
  _expect(proof['domain'] == legal['domain'], 'proof domain mismatch');

  final verifiedAt = DateTime.tryParse(_string(proof, 'verified_at_utc'));
  _expect(
    verifiedAt != null && verifiedAt.isUtc,
    'verified_at_utc must be a UTC timestamp',
  );

  final localAsset = _map(proof, 'local_asset');
  final localPath = _string(localAsset, 'path');
  _expect(localPath == 'public_site/app.js', 'unexpected local legal asset');
  final localSha = _string(localAsset, 'sha256').toLowerCase();
  _expect(
    RegExp(r'^[0-9a-f]{64}$').hasMatch(localSha),
    'local asset SHA-256 is malformed',
  );
  final actualBytes = readBytes == null
      ? File(localPath).readAsBytesSync()
      : readBytes(localPath);
  _expect(
    _integer(localAsset, 'bytes') == actualBytes.length,
    'checked-in local asset byte count mismatch',
  );
  _expect(
    sha256.convert(actualBytes).toString() == localSha,
    'checked-in local asset SHA-256 mismatch',
  );

  final remoteAsset = _map(proof, 'remote_asset');
  const expectedRemoteAssetUrl = 'https://www.bilhealth.com/app.js';
  _expect(
    remoteAsset['url'] == expectedRemoteAssetUrl &&
        remoteAsset['final_url'] == expectedRemoteAssetUrl,
    'remote legal asset URL or final URL mismatch',
  );
  _expect(
    _integer(remoteAsset, 'http_status') == 200,
    'remote legal asset did not return HTTP 200',
  );
  _expect(
    remoteAsset['content_type'] == 'text/javascript',
    'remote legal asset content type mismatch',
  );
  _expect(
    _integer(remoteAsset, 'bytes') == actualBytes.length,
    'remote/local legal asset byte count mismatch',
  );
  _expect(
    remoteAsset['sha256'] == localSha,
    'remote and local legal asset hashes differ',
  );
  _expect(
    remoteAsset['byte_identical_to_local'] == true,
    'remote/local byte identity was not recorded',
  );

  const routeMetadataKeys = <String, String>{
    'privacy': 'privacy_path',
    'terms': 'terms_path',
    'support': 'support_path',
    'account_deletion': 'account_deletion_path',
  };
  final rawRoutes = proof['routes'];
  if (rawRoutes is! List<Object?>) _invalid('routes must be a list');
  _expect(
    rawRoutes.length == routeMetadataKeys.length,
    'proof must contain exactly the required public routes',
  );
  final routes = <String, Map<String, Object?>>{};
  for (final rawRoute in rawRoutes) {
    if (rawRoute is! Map<String, Object?>) {
      _invalid('each route must be an object');
    }
    final name = _string(rawRoute, 'name');
    _expect(!routes.containsKey(name), 'duplicate route proof: $name');
    routes[name] = rawRoute;
  }
  _expect(
    routes.keys.toSet().containsAll(routeMetadataKeys.keys),
    'required route proof is missing',
  );
  for (final entry in routeMetadataKeys.entries) {
    final route = routes[entry.key]!;
    final path = _string(legal, entry.value);
    _expect(route['path'] == path, '${entry.key} path mismatch');
    final expectedUrl = 'https://www.bilhealth.com$path';
    _expect(
      route['url'] == expectedUrl && route['final_url'] == expectedUrl,
      '${entry.key} URL or final URL mismatch',
    );
    _expect(
      _integer(route, 'http_status') == 200,
      '${entry.key} did not return HTTP 200',
    );
    _expect(
      route['content_type'] == 'text/html',
      '${entry.key} content type mismatch',
    );
    _expect(_integer(route, 'bytes') > 0, '${entry.key} response was empty');
    _expect(
      route['redirected'] == false,
      '${entry.key} unexpectedly redirected',
    );
    final responseSha = _string(route, 'response_sha256').toLowerCase();
    _expect(
      RegExp(r'^[0-9a-f]{64}$').hasMatch(responseSha),
      '${entry.key} response SHA-256 is malformed',
    );
  }

  final rawAssertions = proof['content_assertions'];
  if (rawAssertions is! Map<String, Object?>) {
    _invalid('content_assertions must be an object');
  }
  _expect(
    rawAssertions.length == _requiredContentAssertions.length,
    'content assertion set must be exact',
  );
  final localText = utf8.decode(actualBytes);
  for (final entry in _requiredContentAssertions.entries) {
    _expect(
      rawAssertions[entry.key] == entry.value,
      'content assertion ${entry.key} is missing or changed',
    );
    _expect(
      localText.contains(entry.value),
      'local legal asset does not contain ${entry.key}',
    );
  }
}
