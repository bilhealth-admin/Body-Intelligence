import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile camera declarations and dependencies are complete', () {
    final android = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final ios = File('ios/Runner/Info.plist').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(android, contains('android.permission.CAMERA'));
    expect(ios, contains('NSCameraUsageDescription'));
    expect(pubspec, contains('mobile_scanner:'));
    expect(pubspec, contains('image_picker:'));
  });

  test('barcode scanner has camera, retry, and manual fallback paths', () {
    final scanner = File(
      'lib/features/nutrition/presentation/food_barcode_scanner_page.dart',
    ).readAsStringSync();

    expect(scanner, contains('MobileScanner('));
    expect(scanner, contains('onDetect: _onDetect'));
    expect(scanner, contains('onRetry: _startMobile'));
    expect(scanner, contains("Key('barcode-manual-entry-return')"));
    expect(scanner, contains('Enter barcode manually'));
    expect(scanner, contains('_WindowsScannerLauncher'));
  });

  test('Vision capture remains review-first and never auto logs', () {
    final coach =
        [
              'intelligence_center_page.dart',
              'intelligence_conversation_voice.dart',
            ]
            .map(
              (name) => File(
                'lib/features/intelligence_center/presentation/$name',
              ).readAsStringSync(),
            )
            .join('\n');
    final diaryCapture = File(
      'lib/features/daily_log/daily_log_capture_actions.dart',
    ).readAsStringSync();
    final gateway = File(
      'lib/features/nutrition/services/meal_image_analysis_service.dart',
    ).readAsStringSync();

    expect(coach, contains('ImageSource.camera'));
    expect(diaryCapture, contains('ImageSource.gallery'));
    expect(coach, contains('Nothing was logged'));
    expect(coach, contains('Review and confirm a verified BIL food match'));
    expect(gateway, contains("'x-idempotency-key': idempotencyKey"));
    expect(gateway, contains('maximumMealImageBytes'));
    expect(gateway, contains('timeout('));
  });

  test(
    'final webcam acceptance runner fixes the 31-case evidence contract',
    () {
      final runner = File(
        'artifacts/release/run_bil_webcam_acceptance.ps1',
      ).readAsStringSync();
      final protocol = File(
        'artifacts/release/BIL_WEBCAM_ACCEPTANCE_PROTOCOL.md',
      ).readAsStringSync();

      expect(runner, contains('hw.camera.back=webcam0'));
      expect(
        runner,
        contains("camera_input_source = 'android_emulator_host_webcam0'"),
      );
      expect(runner, contains('1..10'));
      expect(runner, contains("category = 'food_hard'"));
      expect(runner, contains("category = 'non_food'"));
      expect(runner, contains("category = 'barcode_food_known'"));
      expect(runner, contains("category = 'barcode_non_food'"));
      expect(runner, contains("category = 'barcode_cache_miss'"));
      expect(runner, contains('model = \$model'));
      expect(runner, contains('input_tokens = \$inputTokens'));
      expect(runner, contains('output_tokens = \$outputTokens'));
      expect(runner, contains('latency_ms = \$latency'));
      expect(runner, contains('cost_usd = \$cost'));
      expect(runner, contains('quota_consumed = \$quota'));
      expect(runner, contains('dedup_prevented = \$dedup'));
      expect(runner, contains('\$rows.Count -ne 31'));
      expect(protocol, contains('REAL_CAMERA_ACCEPTANCE=PASS'));
      expect(protocol, contains('must not be estimated from UI output'));
    },
  );
}
