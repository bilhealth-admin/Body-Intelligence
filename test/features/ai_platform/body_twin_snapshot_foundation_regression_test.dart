import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_observation.dart';
import 'package:body_intelligence_log/features/ai_platform/services/body_twin_snapshot_foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps latest eligible observation and excludes future data', () {
    const foundation = BodyTwinSnapshotFoundation();
    final asOf = DateTime.utc(2026, 7, 24, 12);

    final result = foundation.build(
      asOf: asOf,
      observations: <BodyTwinObservation>[
        BodyTwinObservation(
          metricKey: 'body.weight.kg',
          value: 96,
          unit: 'kg',
          observedAt: DateTime.utc(2026, 7, 23, 8),
          source: 'local.daily_log',
          reliability: 1,
        ),
        BodyTwinObservation(
          metricKey: 'body.weight.kg',
          value: 95.1,
          unit: 'kg',
          observedAt: DateTime.utc(2026, 7, 24, 8),
          source: 'local.daily_log',
          reliability: 1,
        ),
        BodyTwinObservation(
          metricKey: 'body.weight.kg',
          value: 94.8,
          unit: 'kg',
          observedAt: DateTime.utc(2026, 7, 25, 8),
          source: 'local.daily_log',
          reliability: 1,
        ),
      ],
    );

    expect(result.isAccepted, isTrue);
    expect(
      result.acceptedSnapshot!.observationsByMetric['body.weight.kg']!.value,
      95.1,
    );
  });

  test('continues to reject conflicting equal-time observations', () {
    const foundation = BodyTwinSnapshotFoundation();
    final observedAt = DateTime.utc(2026, 7, 24, 8);

    expect(
      () => foundation.build(
        asOf: DateTime.utc(2026, 7, 24, 12),
        observations: <BodyTwinObservation>[
          BodyTwinObservation(
            metricKey: 'body.weight.kg',
            value: 95.1,
            unit: 'kg',
            observedAt: observedAt,
            source: 'local.daily_log',
            reliability: 1,
          ),
          BodyTwinObservation(
            metricKey: 'body.weight.kg',
            value: 95.2,
            unit: 'kg',
            observedAt: observedAt,
            source: 'local.daily_log',
            reliability: 1,
          ),
        ],
      ),
      throwsStateError,
    );
  });
}
