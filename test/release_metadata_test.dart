import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release metadata uses BIL identity and privacy-safe local backup', () {
    final android = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(android, contains('android:label="@string/app_name"'));
    final androidDefaultStrings = File(
      'android/app/src/main/res/values/strings.xml',
    ).readAsStringSync();
    expect(
      androidDefaultStrings,
      contains('<string name="app_name">Body Intelligence Log</string>'),
    );
    expect(android, contains('android:allowBackup="false"'));
    expect(android, contains('android:fullBackupContent="false"'));

    final web =
        jsonDecode(File('web/manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(web['name'], startsWith('BIL'));
    expect(web['short_name'], 'BIL');
    expect(web, isNot(contains('orientation')));
    expect(web['description'], isNot(contains('new Flutter project')));

    final windows = File('windows/runner/Runner.rc').readAsStringSync();
    expect(windows, contains('BIL - Body Intelligence Log'));
    expect(windows, isNot(contains('com.example')));

    final masterIcon = File('assets/branding/bil_app_icon.png');
    expect(masterIcon.lengthSync(), greaterThan(100000));
    expect(masterIcon.readAsBytesSync().take(8).toList(), [
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
    ]);
    expect(
      sha256.convert(masterIcon.readAsBytesSync()).toString(),
      'f6a183d2fdfb0a27e44c9eedc368cf6437b9e45ca65c4054da75818b092d0b46',
      reason: 'The owner-approved app icon is immutable for this release.',
    );

    const rejectedBrandAssets = <String>[
      'assets/branding/bil_icon_master.png',
      'assets/branding/bil_splash_wordmark.png',
      'assets/branding/bil_wordmark_registered_blue.svg',
      'assets/branding/bil_wordmark_registered_white.svg',
      'assets/images/branding/bil_logo_registered_v8.webp',
      'assets/images/branding/bil_logo_silver_v10.webp',
      'assets/images/v9/v9_logo_registered.webp',
      'artifacts/brand/bil_launch_badge.svg',
      'artifacts/brand/bil_splash_preview_1080x2400.png',
      'store_assets/graphics/brand/bil_emblem_master.png',
      'store_assets/graphics/brand/bil_horizontal_dark.png',
      'store_assets/graphics/brand/bil_horizontal_light.png',
      'store_assets/graphics/google_play/feature_graphic.png',
      'store_assets/graphics/plans/free.png',
      'store_assets/graphics/plans/plus.png',
      'store_assets/graphics/plans/pro.png',
      'store_assets/source/BIL-Brand-Assets-v1/01-bil-app-icon.png',
      'store_assets/source/BIL-Brand-Assets-v1/02-bil-splash.png',
      'store_assets/source/BIL-Brand-Assets-v1/03-bil-horizontal-logo.png',
      'store_assets/source/BIL-Brand-Assets-v1/04-bil-onboarding-hero.png',
      'store_assets/source/BIL-Brand-Assets-v1/05-bil-store-feature-graphic.png',
      'store_assets/source/BIL-Brand-Assets-v1/06-bil-free-plus-pro.png',
    ];
    for (final path in rejectedBrandAssets) {
      expect(
        FileSystemEntity.typeSync(path),
        FileSystemEntityType.notFound,
        reason: 'Owner-rejected historical branding must not ship: $path',
      );
    }
  });
}
