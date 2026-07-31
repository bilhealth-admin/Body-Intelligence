import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('typed truth composition remains provider-neutral and offline-only', () {
    const files = [
      'lib/features/ai_platform/domain/truth_proposition.dart',
      'lib/features/ai_platform/domain/truth_rule.dart',
      'lib/features/ai_platform/services/truth_rule_composer.dart',
    ];

    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('dart:io')));
      expect(source, isNot(contains('http')));
      expect(source, isNot(contains('Firebase')));
      expect(source, isNot(contains('DateTime.now')));
      expect(source, isNot(contains('Random(')));
    }
  });

  test(
    'composition reuses TruthEngine instead of duplicating truth arithmetic',
    () {
      final source = File(
        'lib/features/ai_platform/services/truth_rule_composer.dart',
      ).readAsStringSync();

      expect(source, contains("import 'truth_engine.dart';"));
      expect(source, contains('truthEngine.assess('));
      expect(source, isNot(contains('supportThreshold')));
      expect(source, isNot(contains('contradictThreshold')));
    },
  );
}
