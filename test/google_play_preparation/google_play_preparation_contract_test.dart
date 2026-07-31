import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  test('release typography does not fetch Google Fonts at runtime', () {
    final pubspec = read('pubspec.yaml');
    final theme = read('lib/app/theme/bil_flagship_theme.dart');

    expect(pubspec, isNot(contains('google_fonts:')));
    expect(theme, isNot(contains("package:google_fonts/google_fonts.dart")));
    expect(theme, isNot(contains('GoogleFonts.')));
    expect(pubspec, contains('family: NotoNaskhArabic'));
    expect(pubspec, contains('assets/fonts/NotoNaskhArabic-Regular.ttf'));
    expect(pubspec, contains('assets/fonts/NotoNaskhArabic-Bold.ttf'));
    expect(theme, contains("fontFamily: 'NotoNaskhArabic'"));
  });

  test('Google Play preparation preserves truthful Android boundaries', () {
    final gradle = read('android/app/build.gradle.kts');
    final manifest = read('android/app/src/main/AndroidManifest.xml');
    final settings = read('lib/features/settings/settings_page.dart');
    final onboarding = read(
      'lib/features/onboarding/widgets/profile_step.dart',
    );

    expect(gradle, contains('applicationId = "com.kadem.bil"'));
    expect(gradle, contains('targetSdk = 36'));
    expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
    expect(manifest, contains('android:usesCleartextTraffic="false"'));
    expect(manifest, contains('ACTION_SHOW_PERMISSIONS_RATIONALE'));
    expect(settings, contains("context.strings.text('Privacy')"));
    expect(settings, contains("context.strings.text('Health disclaimer')"));
    expect(onboarding, contains('not individual medical advice'));
  });

  test('store integrations remain inactive until external setup', () {
    final pubspec = read('pubspec.yaml');
    final environment = read('lib/app/environment/app_environment.dart');

    expect(pubspec, isNot(contains('in_app_purchase:')));
    expect(pubspec, isNot(contains('google_play_integrity:')));
    expect(environment, contains('static const bool useSupabase'));
    expect(environment, contains("'BIL_USE_SUPABASE'"));
    expect(environment, contains('defaultValue: false'));
  });
}
