import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  test('release typography does not fetch Google Fonts at runtime', () {
    final pubspec = read('pubspec.yaml');
    final theme = read('lib/app/theme/bil_flagship_theme.dart');
    final typography = read('lib/app/theme/bil_typography.dart');

    expect(pubspec, isNot(contains('google_fonts:')));
    expect(theme, isNot(contains("package:google_fonts/google_fonts.dart")));
    expect(theme, isNot(contains('GoogleFonts.')));
    // Noto remains an embedded report/PDF asset, but must never be registered
    // as the application UI family. Native platform typography is canonical.
    expect(pubspec, isNot(contains('family: NotoNaskhArabic')));
    expect(pubspec, contains('assets/fonts/NotoNaskhArabic-Regular.ttf'));
    expect(pubspec, contains('assets/fonts/NotoNaskhArabic-Bold.ttf'));
    expect(typography, contains('const String? displayFamily = null;'));
    expect(typography, contains('const String? bodyFamily = null;'));
    expect(typography, isNot(contains("fontFamily: 'BILArabic'")));
    expect(typography, isNot(contains('GoogleFonts.')));
  });

  test('Google Play preparation preserves truthful Android boundaries', () {
    final gradle = read('android/app/build.gradle.kts');
    final manifest = read('android/app/src/main/AndroidManifest.xml');
    final settings = read('lib/features/settings/settings_page.dart');
    final onboarding = read(
      'lib/features/onboarding/widgets/profile_step.dart',
    );

    expect(
      gradle,
      contains('applicationId = "com.bilhealth.bodyintelligencelog"'),
    );
    expect(gradle, contains('targetSdk = 36'));
    expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
    expect(manifest, contains('android:usesCleartextTraffic="false"'));
    expect(manifest, contains('ACTION_SHOW_PERMISSIONS_RATIONALE'));
    expect(settings, contains("copy('Privacy')"));
    expect(onboarding, contains('not individual medical advice'));
  });

  test('store purchases require real billing and server verification', () {
    final pubspec = read('pubspec.yaml');
    final environment = read('lib/app/environment/app_environment.dart');
    final purchaseService = read(
      'lib/features/commerce/services/verified_store_purchase_service.dart',
    );

    expect(pubspec, contains('in_app_purchase:'));
    expect(pubspec, isNot(contains('google_play_integrity:')));
    expect(purchaseService, contains("'verify-store-purchase'"));
    expect(purchaseService, contains('serverVerificationData'));
    expect(environment, contains('static const bool useSupabase'));
    expect(environment, contains("'BIL_USE_SUPABASE'"));
    expect(environment, contains('defaultValue: false'));
  });
}
