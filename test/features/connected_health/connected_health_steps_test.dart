import 'package:flutter_test/flutter_test.dart';

import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/global_platform/core/global_platform_core.dart';

GlobalHealthSignal _step(double value, DateTime observedAt, String id) {
  return GlobalHealthSignal(
    key: 'steps',
    canonicalValue: value,
    canonicalUnit: 'count',
    provenance: GlobalProvenance(
      providerId: 'native-test',
      sourceId: 'watch-test',
      recordId: id,
      observedAt: observedAt,
      confidence: .9,
    ),
  );
}

void main() {
  test('connected step samples become one daily total', () {
    final totals = aggregateConnectedStepSignals([
      _step(1200, DateTime(2026, 9, 1, 8), 'a'),
      _step(800, DateTime(2026, 9, 1, 18), 'b'),
      _step(4500, DateTime(2026, 9, 2, 12), 'c'),
    ]);

    expect(totals, hasLength(2));
    expect(totals[0].canonicalValue, 2000);
    expect(totals[0].attributes['aggregation'], 'daily');
    expect(totals[1].canonicalValue, 4500);
  });

  test('dashboard receives 30 ordered values from connected step history', () {
    final snapshot = ConnectedHealthSnapshot(
      status: ConnectedHealthStatus.synchronized,
      platformSource: 'Health Connect',
      availableSources: const ['Health Connect'],
      signals: const [],
      stepHistory: [
        ConnectedHealthSignalView(
          key: 'steps',
          value: 3200,
          unit: 'count',
          source: 'watch-test',
          observedAt: DateTime(2026, 9, 2, 12),
          confidence: .9,
        ),
      ],
      importedCount: 1,
      lastSyncAt: DateTime(2026, 9, 2),
      failureCode: null,
    );

    final values = connectedHealthStepTrendValues(
      snapshot,
      DateTime(2026, 9, 2, 20),
    );
    expect(values, hasLength(30));
    expect(values.last, 3200);
    expect(values.take(29).every((value) => value == 0), isTrue);
  });
}
