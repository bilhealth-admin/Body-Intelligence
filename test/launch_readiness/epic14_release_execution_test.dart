import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  test(
    'Android release config is optimized and legacy gate cannot certify',
    () {
      final gradle = read('android/app/build.gradle.kts');
      expect(gradle, contains('isMinifyEnabled = true'));
      expect(gradle, contains('isShrinkResources = true'));
      expect(gradle, contains('proguard-rules.pro'));
      expect(gradle, contains('abiFilters += listOf("arm64-v8a", "x86_64")'));
      expect(gradle, isNot(contains('abiFilters += listOf("armeabi-v7a"')));
      expect(gradle, contains('excludes += setOf("**/armeabi-v7a/**")'));
      expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
      expect(File('android/app/proguard-rules.pro').existsSync(), isTrue);
      final gate = read('artifacts/release/epic14/run_epic14_gate.ps1');
      final stop = gate.indexOf('HISTORICAL_NON_AUTHORITATIVE');
      expect(stop, greaterThanOrEqualTo(0));
      expect(
        stop,
        lessThan(gate.indexOf('flutter build appbundle')),
        reason: 'The historical gate must stop before any local AAB build.',
      );
      expect(
        gate,
        contains('.github/workflows/bil_android_release_candidate.yml'),
      );
    },
  );

  test('private Android upload identity has a recoverable local workflow', () {
    final script = read(
      'artifacts/release/epic14/prepare_android_upload_key.ps1',
    );
    final ignores = read('.gitignore') + read('android/.gitignore');
    expect(script, contains('RandomNumberGenerator]::Create()'));
    expect(script, contains('-keysize 4096'));
    expect(script, contains('BACKUP_REQUIRED=True'));
    expect(script, contains('.bil-package-evidence'));
    expect(ignores, contains('key.properties'));
    expect(ignores, contains('*.jks'));
  });

  test('Apple workflows distinguish unsigned proof from signed release', () {
    final unsigned = read('.github/workflows/bil_ios_unsigned_release.yml');
    final signed = read('.github/workflows/bil_ios_signed_release.yml');
    expect(unsigned, contains('--no-codesign'));
    expect(unsigned, contains('UNSIGNED_VALIDATION_ONLY'));
    expect(signed, contains('APPLE_TEAM_ID'));
    expect(signed, contains('APPLE_PROVISIONING_PROFILE_BASE64'));
    expect(signed, contains('APP_STORE_CONNECT_PRIVATE_KEY_BASE64'));
    expect(signed, contains('flutter build ipa --release'));
    expect(signed, contains('codesign -dv --verbose=4'));
    expect(signed, contains('altool --validate-app'));
  });

  test('release permissions and external boundaries remain honest', () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');
    final entitlements = read('ios/Runner/Runner.entitlements');
    final debugEntitlements = read('ios/Runner/RunnerDebug.entitlements');
    final coverage = read('docs/release/BIL_EPIC14_RELEASE_COVERAGE.md');
    expect(
      manifest,
      contains('android:usesPermissionFlags="neverForLocation"'),
    );
    expect(entitlements, contains('<key>aps-environment</key>'));
    expect(entitlements, contains('<key>com.apple.developer.healthkit</key>'));
    expect(debugEntitlements, isNot(contains('aps-environment')));
    expect(coverage, contains('OWNER_INPUT_REQUIRED'));
    expect(coverage, contains('EXTERNAL_REQUIRED_NOT_CLAIMED'));
    expect(coverage, contains('No placeholder URL'));
  });

  test('superseded artwork is not shipped in the release bundle', () {
    final pubspec = read('pubspec.yaml');
    for (final legacyAsset in <String>[
      'assets/images/v9/v9_hologram.webp',
      'assets/images/v9/v9_logo_registered.webp',
      'assets/images/v9/v9_glow_rings.webp',
      'assets/images/v9/v9_hdr_background.webp',
      'assets/images/branding/bil_logo_registered_v8.webp',
      'assets/images/onboarding/bil_body_hologram_v8.webp',
    ]) {
      expect(pubspec, isNot(contains(legacyAsset)), reason: legacyAsset);
    }
  });
}
