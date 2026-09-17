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
      expect(
        source,
        contains('defaultTargetPlatform == TargetPlatform.iOS'),
        reason: '$path must branch to the native iOS permission flow',
      );
      expect(
        source,
        contains('await policy.openSettings();'),
        reason:
            '$path must recover permanently denied iOS access through Settings',
      );
    }
  });
}
