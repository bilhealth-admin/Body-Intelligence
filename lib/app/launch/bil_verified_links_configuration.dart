import 'dart:convert';

/// Produces verified-link documents only when owner/platform values are valid.
/// Null means "do not publish" and prevents placeholder claims.
abstract final class BilVerifiedLinksConfiguration {
  /// Credential-bearing HTTPS returns that the native manifests and the
  /// production association-document generator intentionally claim.
  ///
  /// All other in-app routes use the audited `bil://` route allow-list. Keeping
  /// this list narrow prevents the website from opening arbitrary app pages
  /// and keeps OAuth/recovery behavior identical on Android and iOS.
  static const authenticatedReturnPaths = <String>[
    '/auth/callback',
    '/auth/reset-password',
  ];

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

  static String? appleAppSiteAssociationJson() =>
      appleAppSiteAssociationJsonFor(
        teamId: appleTeamId,
        bundleId: appleBundleId,
      );

  /// Builds the same modern AASA shape used by the release generator.
  ///
  /// The explicit variant also lets release tests verify the exact document
  /// without embedding a real production Team ID in source control.
  static String? appleAppSiteAssociationJsonFor({
    required String teamId,
    required String bundleId,
  }) {
    final team = teamId.trim().toUpperCase();
    final bundle = bundleId.trim();
    if (!RegExp(r'^[A-Z0-9]{10}$').hasMatch(team) || !_validPackage(bundle)) {
      return null;
    }
    return const JsonEncoder.withIndent('  ').convert({
      'applinks': {
        'details': [
          {
            'appIDs': ['$team.$bundle'],
            'components': <Map<String, String>>[
              for (final path in authenticatedReturnPaths)
                {'/': path, 'comment': 'BIL authenticated return'},
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
