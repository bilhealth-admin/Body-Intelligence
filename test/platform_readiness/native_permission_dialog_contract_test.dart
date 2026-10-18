import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS permission recovery never inserts a custom permission dialog', () {
    const files = <String>[
      'lib/features/dashboard/dashboard_page.dart',
      'lib/features/daily_log/daily_log_capture_actions.dart',
      'lib/features/intelligence_center/presentation/intelligence_conversation_voice.dart',
      'lib/features/nutrition/services/meal_voice_input_service.dart',
      'lib/features/weight/services/weight_voice_input_service.dart',
      'lib/features/nutrition/presentation/food_page_actions.dart',
      'lib/features/profile/premium_profile_actions.dart',
    ];

    for (final path in files) {
      final source = File(path).readAsStringSync();
      if (source.contains('defaultTargetPlatform == TargetPlatform.iOS')) {
        expect(source, contains('policy.request('));
      } else {
        // Unified native request flow: the optional recovery card is reached
        // only when the OS will not present a new permission prompt.
        expect(source, contains('BilRuntimePermissionState.permanentlyDenied'));
        final recovery = source.indexOf(
          'await showBilPearlPermissionDecision(',
        );
        final nativeRequest = source.indexOf('await policy.request(');
        expect(recovery, greaterThanOrEqualTo(0));
        expect(nativeRequest, greaterThan(recovery));
        expect(
          source.substring(recovery, nativeRequest),
          contains('return false;'),
        );
      }
      expect(
        source,
        contains('await policy.openSettings();'),
        reason:
            '$path must recover permanently denied iOS access through Settings',
      );
    }
  });
}
