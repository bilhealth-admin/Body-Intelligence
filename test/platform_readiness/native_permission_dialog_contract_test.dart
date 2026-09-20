import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('permission explainers adapt to iOS and Android presentation', () {
    const files = <String>[
      'lib/features/dashboard/dashboard_page.dart',
      'lib/features/daily_log/daily_log_capture_actions.dart',
      'lib/features/intelligence_center/presentation/intelligence_conversation_voice.dart',
      'lib/features/nutrition/services/meal_voice_input_service.dart',
      'lib/features/weight/services/weight_voice_input_service.dart',
    ];

    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        contains('AlertDialog.adaptive('),
        reason: '$path must not force a Material permission explainer on iOS',
      );
    }
  });
}
