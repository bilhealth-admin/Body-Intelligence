import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android launch configuration is explicit and store-safe', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final rationale = File(
      'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/PermissionsRationaleActivity.kt',
    ).readAsStringSync();
    final strings = File(
      'android/app/src/main/res/values/strings.xml',
    ).readAsStringSync();
    final android12Launch = File(
      'android/app/src/main/res/values-v31/styles.xml',
    ).readAsStringSync();
    final android12NightLaunch = File(
      'android/app/src/main/res/values-night-v31/styles.xml',
    ).readAsStringSync();
    final launchColors = File(
      'android/app/src/main/res/values/bil_colors.xml',
    ).readAsStringSync();
    final legacyLaunch = File(
      'android/app/src/main/res/drawable/launch_background.xml',
    ).readAsStringSync();
    final legacyLaunchV21 = File(
      'android/app/src/main/res/drawable-v21/launch_background.xml',
    ).readAsStringSync();
    final transparentIcon = File(
      'android/app/src/main/res/drawable/bil_splash_transparent_icon.xml',
    ).readAsStringSync();

    expect(gradle, contains('compileSdk = 36'));
    expect(gradle, contains('targetSdk = 36'));
    expect(
      gradle,
      contains('applicationId = "com.bilhealth.bodyintelligencelog"'),
    );
    expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));

    expect(manifest, contains('android:usesCleartextTraffic="false"'));
    expect(
      manifest,
      contains('androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE'),
    );
    expect(manifest, contains('android.intent.action.VIEW_PERMISSION_USAGE'));
    expect(manifest, contains('android.intent.category.HEALTH_PERMISSIONS'));
    expect(
      manifest,
      contains('android.permission.START_VIEW_PERMISSION_USAGE'),
    );
    expect(manifest, contains('android.hardware.bluetooth_le'));
    expect(manifest, contains('android:required="false"'));

    expect(rationale, contains('class PermissionsRationaleActivity'));
    expect(rationale, isNot(contains('http://')));
    expect(rationale, isNot(contains('https://')));
    expect(rationale, contains('Intent.ACTION_VIEW'));
    expect(rationale, contains('health_privacy_policy_url'));
    expect(strings, contains('https://www.bilhealth.com/privacy'));
    for (final launch in [android12Launch, android12NightLaunch]) {
      expect(
        launch,
        contains(
          '<item name="android:windowSplashScreenAnimatedIcon">'
          '@drawable/bil_splash_transparent_icon</item>',
        ),
      );
      expect(
        launch,
        isNot(contains('android:windowSplashScreenIconBackgroundColor')),
      );
      expect(
        launch,
        contains(
          '<item name="android:windowBackground">'
          '@color/bil_launch_background</item>',
        ),
      );
    }
    expect(launchColors, contains('#0877F9'));
    for (final launch in [legacyLaunch, legacyLaunchV21]) {
      expect(launch, contains('@color/bil_launch_background'));
      expect(launch, isNot(contains('bil_splash_identity')));
      expect(launch, isNot(contains('bil_launch_badge')));
      expect(launch, isNot(contains('<bitmap')));
      expect(launch, isNot(contains('<inset')));
    }
    expect(transparentIcon, contains('android:fillColor="#00000000"'));
    expect(transparentIcon, contains('android:width="1dp"'));
    expect(android12Launch, contains('windowSplashScreenAnimationDuration'));
    expect(android12Launch, contains('>0</item>'));
    expect(
      android12NightLaunch,
      contains('windowSplashScreenAnimationDuration'),
    );
    expect(android12NightLaunch, contains('>0</item>'));
  });

  test('Flutter hands native blue to the local 2026 splash video', () {
    final storyboard = File(
      'ios/Runner/Base.lproj/LaunchScreen.storyboard',
    ).readAsStringSync();
    final assetCatalog = File(
      'ios/Runner/Assets.xcassets/BILLaunchWordmark.imageset/Contents.json',
    ).readAsStringSync();
    final flutterSplash = File(
      'lib/features/startup/premium_splash_experience.dart',
    ).readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(storyboard, contains('image="BILLaunchWordmark"'));
    expect(storyboard, contains('red="0.031372549"'));
    expect(storyboard, contains('green="0.48627451"'));
    expect(assetCatalog, contains('BILLaunchWordmark.png'));
    expect(flutterSplash, contains('bil_splash_identity.png'));
    expect(flutterSplash, contains('bil_splash_motion.mp4'));
    expect(flutterSplash, contains('VideoPlayerController.asset('));
    expect(flutterSplash, contains('VideoViewType.textureView'));
    expect(flutterSplash, isNot(contains('CircularProgressIndicator(')));
    expect(flutterSplash, isNot(contains('Loading...')));
    expect(flutterSplash, isNot(contains('Download')));
    expect(flutterSplash, isNot(contains("'BIL'")));
    expect(pubspec, contains('assets/branding/bil_splash_motion.mp4'));
    expect(
      File('assets/branding/bil_splash_motion.mp4').lengthSync(),
      lessThan(512 * 1024),
    );

    final flutterIdentity = File(
      'assets/branding/bil_splash_identity.png',
    ).readAsBytesSync();
    final androidIdentity = File(
      'android/app/src/main/res/drawable-nodpi/bil_splash_identity.png',
    ).readAsBytesSync();
    final iosIdentity = File(
      'ios/Runner/Assets.xcassets/BILLaunchWordmark.imageset/'
      'BILLaunchWordmark.png',
    ).readAsBytesSync();
    expect(androidIdentity, orderedEquals(flutterIdentity));
    expect(iosIdentity, orderedEquals(flutterIdentity));

    for (final legacy in <String>[
      'android/app/src/main/res/drawable-nodpi/bil_launch_static_v2.png',
      'android/app/src/main/res/drawable-nodpi/bil_launch_badge.png',
      'android/app/src/main/res/drawable-nodpi/'
          'bil_splash_wordmark_safe_v2.png',
      'ios/Runner/Assets.xcassets/LaunchImage.imageset',
    ]) {
      expect(FileSystemEntity.typeSync(legacy), FileSystemEntityType.notFound);
    }
  });

  test('Health rationale is localized in English and Arabic', () {
    final english = File(
      'android/app/src/main/res/values/strings.xml',
    ).readAsStringSync();
    final arabic = File(
      'android/app/src/main/res/values-ar/strings.xml',
    ).readAsStringSync();

    for (final key in <String>[
      'health_permissions_rationale_title',
      'health_permissions_rationale_body',
    ]) {
      expect(english, contains('name="$key"'));
      expect(arabic, contains('name="$key"'));
    }
  });
}
