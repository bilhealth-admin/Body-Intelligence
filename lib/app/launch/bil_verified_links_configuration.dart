import 'dart:convert';

/// Produces verified-link documents only when owner/platform values are valid.
/// Null means "do not publish" and prevents placeholder claims.
abstract final class BilVerifiedLinksConfiguration {
  static const androidPackage = String.fromEnvironment(
    'BIL_GOOGLE_PACKAGE_NAME',
    defaultValue: 'com.bilhealth.bodyintelligencelog',
  );
  static const androidSha256 = String.fromEnvironment(
    'BIL_ANDROID_SIGNING_SHA256',
  );
  static const appleTeamId = String.fromEnvironment('BIL_APPLE_TEAM_ID');
  static const appleBundleId = String.fromEnvironment(
    'BIL_APPLE_BUNDLE_ID',
    defaultValue: 'com.bilhealth.bodyintelligencelog',
  );

  static String? assetLinksJson() {
    final fingerprint = androidSha256.trim().toUpperCase();
    if (!_validPackage(androidPackage) || !_validFingerprint(fingerprint)) {
      return null;
    }
    return const JsonEncoder.withIndent('  ').convert([
      {
        'relation': ['delegate_permission/common.handle_all_urls'],
        'target': {
          'namespace': 'android_app',
          'package_name': androidPackage,
          'sha256_cert_fingerprints': [fingerprint],
        },
      },
    ]);
  }

  static String? appleAppSiteAssociationJson() {
    final team = appleTeamId.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{10}$').hasMatch(team) ||
        !_validPackage(appleBundleId)) {
      return null;
    }
    return const JsonEncoder.withIndent('  ').convert({
      'applinks': {
        'apps': <String>[],
        'details': [
          {
            'appID': '$team.$appleBundleId',
            'components': [
              {'/': '/plans', 'comment': 'BIL plans'},
              {'/': '/login', 'comment': 'BIL login'},
              {'/': '/register', 'comment': 'BIL registration'},
              {'/': '/settings', 'comment': 'BIL settings'},
              {'/': '/notifications', 'comment': 'BIL notification settings'},
              {'/': '/privacy', 'comment': 'BIL privacy'},
            ],
          },
        ],
      },
    });
  }

  static bool _validPackage(String value) => RegExp(
    r'^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$',
  ).hasMatch(value.trim());

  static bool _validFingerprint(String value) =>
      RegExp(r'^([0-9A-F]{2}:){31}[0-9A-F]{2}$').hasMatch(value);
}
