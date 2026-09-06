import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android optional hardware does not filter usable large-screen devices',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      for (final feature in <String>[
        'android.hardware.camera.any',
        'android.hardware.camera',
        'android.hardware.camera.autofocus',
        'android.hardware.camera.flash',
        'android.hardware.microphone',
        'android.hardware.location',
        'android.hardware.location.gps',
        'android.hardware.location.network',
        'android.hardware.bluetooth',
        'android.hardware.bluetooth_le',
      ]) {
        expect(
          manifest,
          matches(
            RegExp(
              'android:name="${RegExp.escape(feature)}"\\s+'
              'android:required="false"',
            ),
          ),
          reason: '$feature must remain an optional enhancement feature.',
        );
      }

      // Camera plugins commonly contribute the same feature with the Android
      // default `required=true`. Android's manifest merger otherwise promotes
      // the final APK back to required even though this app-level declaration
      // says false, which filters camera-less tablets and Chromebooks.
      for (final feature in <String>[
        'android.hardware.camera.any',
        'android.hardware.camera',
      ]) {
        expect(
          manifest,
          matches(
            RegExp(
              'android:name="${RegExp.escape(feature)}"\\s+'
              'android:required="false"\\s+'
              'tools:replace="android:required"',
            ),
          ),
          reason: '$feature must override transitive plugin requirements.',
        );
      }

      expect(manifest, contains('android:resizeableActivity="true"'));
      expect(manifest, isNot(contains('android:screenOrientation=')));
      expect(manifest, isNot(contains('android:required="true"')));
    },
  );

  test('Android build tools match the Flutter 3.44 compatibility matrix', () {
    final settings = File('android/settings.gradle.kts').readAsStringSync();
    final wrapper = File(
      'android/gradle/wrapper/gradle-wrapper.properties',
    ).readAsStringSync();
    final properties = File('android/gradle.properties').readAsStringSync();

    expect(
      settings,
      contains('id("com.android.application") version "9.0.1" apply false'),
    );
    expect(
      settings,
      contains(
        'id("org.jetbrains.kotlin.android") version "2.3.20" apply false',
      ),
    );
    expect(wrapper, contains('gradle-9.1.0-all.zip'));
    expect(properties, contains('android.builtInKotlin=false'));
    expect(properties, contains('android.newDsl=false'));
  });

  test('Apple release supports iPhone and iPad with native capabilities', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final info = File('ios/Runner/Info.plist').readAsStringSync();
    final releaseEntitlements = File(
      'ios/Runner/Runner.entitlements',
    ).readAsStringSync();
    final debugEntitlements = File(
      'ios/Runner/RunnerDebug.entitlements',
    ).readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(project, contains('TARGETED_DEVICE_FAMILY = "1,2"'));
    expect(project, contains('com.apple.InAppPurchase'));
    expect(project, contains('com.apple.HealthKit'));
    expect(project, contains('com.apple.SignInWithApple'));
    expect(info, contains('UISupportedInterfaceOrientations~ipad'));
    for (final orientation in <String>[
      'UIInterfaceOrientationPortrait',
      'UIInterfaceOrientationLandscapeLeft',
      'UIInterfaceOrientationLandscapeRight',
    ]) {
      expect(info, contains('<string>$orientation</string>'));
    }
    expect(info, isNot(contains('<key>UIRequiredDeviceCapabilities</key>')));

    for (final key in <String>[
      'NSCameraUsageDescription',
      'NSPhotoLibraryUsageDescription',
      'NSMicrophoneUsageDescription',
      'NSSpeechRecognitionUsageDescription',
      'NSBluetoothAlwaysUsageDescription',
      'NSHealthShareUsageDescription',
      'NSHealthUpdateUsageDescription',
    ]) {
      expect(info, contains('<key>$key</key>'), reason: 'Missing $key');
    }

    expect(releaseEntitlements, contains('<string>production</string>'));
    expect(debugEntitlements, contains('<string>development</string>'));
    for (final entitlements in <String>[
      releaseEntitlements,
      debugEntitlements,
    ]) {
      expect(entitlements, contains('com.apple.developer.applesignin'));
      expect(entitlements, contains('com.apple.developer.healthkit'));
      expect(
        entitlements,
        contains('com.apple.developer.devicecheck.appattest-environment'),
      );
    }

    for (final package in <String>[
      'camera:',
      'image_picker:',
      'permission_handler:',
      'sign_in_with_apple:',
      'in_app_purchase:',
      'in_app_purchase_storekit:',
    ]) {
      expect(pubspec, contains(package), reason: 'Missing $package');
    }
  });

  test('mobile release avoids broad media and tracking declarations', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final info = File('ios/Runner/Info.plist').readAsStringSync();
    final privacy = File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();

    expect(manifest, isNot(contains('android.permission.READ_MEDIA_IMAGES')));
    expect(manifest, isNot(contains('android.permission.READ_MEDIA_VIDEO')));
    expect(manifest, isNot(contains('android.permission.READ_CONTACTS')));
    expect(
      manifest,
      matches(
        RegExp(
          r'com\.google\.android\.gms\.permission\.AD_ID"\s*'
          r'tools:node="remove"',
        ),
      ),
    );
    expect(info, isNot(contains('NSUserTrackingUsageDescription')));
    expect(privacy, contains('<key>NSPrivacyTracking</key><false/>'));
  });
}
