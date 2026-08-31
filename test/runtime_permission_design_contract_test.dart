import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile manifests declare only feature-owned runtime permissions', () {
    final android = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final ios = File('ios/Runner/Info.plist').readAsStringSync();

    for (final permission in const [
      'android.permission.CAMERA',
      'android.permission.RECORD_AUDIO',
      'android.permission.POST_NOTIFICATIONS',
    ]) {
      expect(android, contains(permission));
    }
    expect(android, isNot(contains('android.permission.READ_MEDIA_IMAGES')));
    for (final legacyStoragePermission in const [
      'android.permission.READ_EXTERNAL_STORAGE',
      'android.permission.WRITE_EXTERNAL_STORAGE',
    ]) {
      expect(android, contains(legacyStoragePermission));
    }
    expect(android, contains('tools:node="remove"'));
    final topicsOptOut = RegExp(
      r'android\.permission\.ACCESS_ADSERVICES_TOPICS"\s*'
      r'tools:node="remove"',
    );
    expect(android, matches(topicsOptOut));
    final advertisingIdOptOut = RegExp(
      r'com\.google\.android\.gms\.permission\.AD_ID"\s*'
      r'tools:node="remove"',
    );
    expect(android, matches(advertisingIdOptOut));
    for (final privacySandboxPermission in const [
      'android.permission.ACCESS_ADSERVICES_AD_ID',
      'android.permission.ACCESS_ADSERVICES_ATTRIBUTION',
    ]) {
      expect(
        android,
        matches(
          RegExp(
            '${RegExp.escape(privacySandboxPermission)}"\\s*'
            'tools:node="remove"',
          ),
        ),
      );
    }
    expect(android, isNot(contains('android.permission.ACTIVITY_RECOGNITION')));

    for (final usage in const [
      'NSCameraUsageDescription',
      'NSPhotoLibraryUsageDescription',
      'NSMicrophoneUsageDescription',
      'NSSpeechRecognitionUsageDescription',
      'NSHealthShareUsageDescription',
      'NSBluetoothAlwaysUsageDescription',
    ]) {
      expect(ios, contains(usage));
    }
  });

  test('camera and microphone flows are just-in-time with recovery', () {
    final policy = File(
      'lib/app/services/runtime_permission_policy.dart',
    ).readAsStringSync();
    final mealCapture = File(
      'lib/features/daily_log/daily_log_capture_actions.dart',
    ).readAsStringSync();
    final voice = File(
      'lib/features/nutrition/services/meal_voice_input_service.dart',
    ).readAsStringSync();
    final coach = File(
      'lib/features/intelligence_center/presentation/intelligence_conversation_voice.dart',
    ).readAsStringSync();
    final weightVoice = File(
      'lib/features/weight/services/weight_voice_input_service.dart',
    ).readAsStringSync();
    final dashboard = File(
      'lib/features/dashboard/dashboard_page.dart',
    ).readAsStringSync();
    final foodPage = [
      'lib/features/nutrition/food_page.dart',
      'lib/features/nutrition/presentation/food_page_actions.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');

    expect(policy, contains('openAppSettings'));
    expect(policy, contains('Permission.speech'));
    expect(policy, isNot(contains('Permission.photos')));
    expect(mealCapture, contains('_ensureCameraPermission'));
    expect(mealCapture, contains('BIL does not request access at startup'));
    expect(voice, contains('_ensureMicrophonePermission'));
    expect(voice, contains('permanentlyDenied'));
    expect(coach, contains('_ensureCoachRuntimePermission'));
    expect(coach, contains('Open system settings'));
    expect(weightVoice, contains('BilRuntimeCapability.microphone'));
    expect(dashboard, contains('It never requests camera access at startup'));
    expect(foodPage, contains('Manual barcode entry remains available'));
  });
}
