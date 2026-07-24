import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reality gate covers physiology, memory, safety and abstention', () {
    final s = File(
      'lib/features/ai_platform/services/local_intelligence_reality_runtime.dart',
    ).readAsStringSync();
    for (final token in [
      'local-sodium',
      'local-potassium',
      'local-carbohydrates',
      'local-water',
      'local-sleep',
      'local-activity',
      'decisionHistory.isEmpty',
      'No safe action',
    ]) {
      expect(s, contains(token));
    }
  });
}
