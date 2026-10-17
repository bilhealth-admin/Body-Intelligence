import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('camera access prompts through native policy, with optional settings only on prior denial', () {
    const files = <String>[
      'lib/features/dashboard/dashboard_page.dart',
      'lib/features/daily_log/daily_log_capture_actions.dart',
      'lib/features/daily_log/food_log_actions.dart',
      'lib/features/nutrition/presentation/food_page_actions.dart',
      'lib/features/profile/premium_profile_actions.dart',
    ];
    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(source, contains('BilRuntimePermissionState.permanentlyDenied'),
          reason: '$path must distinguish previously blocked requests');
      expect(source, contains('showBilPearlPermissionDecision('),
          reason: '$path must offer cancelable settings recovery');
      expect(source, contains('policy.request(BilRuntimeCapability.camera)'),
          reason: '$path must still call the native OS permission API');
      expect(
        source,
        matches(RegExp(r'if \([^\n]*(?:openSettings|open)[^\n]*\) await policy\.openSettings\(\);')),
        reason: '$path must not launch Settings without explicit user approval',
      );
    }
  });

  test('voice permission flows retain native microphone/speech authorization on iOS', () {
    const files = <String>[
      'lib/features/intelligence_center/presentation/intelligence_conversation_voice.dart',
      'lib/features/nutrition/services/meal_voice_input_service.dart',
      'lib/features/weight/services/weight_voice_input_service.dart',
    ];
    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(source, contains('TargetPlatform.iOS'),
          reason: '$path must preserve iOS native microphone/speech admission');
      expect(source, contains('showBilPearlPermissionDecision('),
          reason: '$path must offer optional recovery for permanently denied access');
      expect(source, contains('BilRuntimeCapability.microphone'));
      expect(source, contains('BilRuntimeCapability.speechRecognition'));
      expect(source, contains('policy.request('),
          reason: '$path cannot replace the system sheet with a fake dialog');
      expect(source, isNot(contains('if (defaultTargetPlatform == TargetPlatform.iOS) {\n        await policy.openSettings();')),
          reason: '$path cannot navigate to settings without consent');
    }
  });
}
