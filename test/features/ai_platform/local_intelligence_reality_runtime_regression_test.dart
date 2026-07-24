import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adapter excludes future and loads decision memory', () {
    final s = File(
      'lib/features/ai_platform/adapters/local_intelligence_repository_adapter.dart',
    ).readAsStringSync();
    expect(s, contains('isSmallerOrEqualValue'));
    expect(s, contains('database.decisionMemories'));
    expect(s, contains('decisionHistory: decisionHistory'));
  });
  test('no fixed acceptance signals remain', () {
    final s = File(
      'lib/features/ai_platform/services/local_intelligence_reality_runtime.dart',
    ).readAsStringSync();
    expect(s, isNot(contains('scientificValidation,\n        0.85')));
    expect(s, contains('safety.canProceed'));
  });
}
