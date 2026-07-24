import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy runtime remains a logic-free facade over Reality Runtime', () {
    final source = File(
      'lib/features/ai_platform/services/local_intelligence_runtime.dart',
    ).readAsStringSync();

    expect(source, contains('BilLocalIntelligenceRealityRuntime'));
    expect(source, contains('_delegate.run(asOf: asOf)'));
    expect(source, isNot(contains('integrateSignals(')));
    expect(source, isNot(contains('safetyEligible: true')));
    expect(source, isNot(contains('BilIntegrationSignal(')));
    expect(source, isNot(contains('0.85')));
    expect(source, isNot(contains('0.7')));
  });

  test('only one production orchestrator owns local intelligence logic', () {
    final services = Directory(
      'lib/features/ai_platform/services',
    ).listSync().whereType<File>().where((file) => file.path.endsWith('.dart'));
    final orchestrationOwners = <String>[];
    for (final file in services) {
      final source = file.readAsStringSync();
      if (source.contains('BilIntelligenceIntegrationEngine().integrate<')) {
        orchestrationOwners.add(file.path.replaceAll('\\', '/'));
      }
    }

    expect(orchestrationOwners, [
      'lib/features/ai_platform/services/local_intelligence_reality_runtime.dart',
    ]);
  });
}
