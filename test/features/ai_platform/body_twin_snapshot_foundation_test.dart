import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_foundation_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_observation.dart';
import 'package:body_intelligence_log/features/ai_platform/services/body_twin_snapshot_foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds and exposes an accepted deterministic snapshot', () {
    const foundation = BodyTwinSnapshotFoundation();
    final asOf = DateTime.utc(2026, 7, 24, 12);

    final result = foundation.build(
      asOf: asOf,
      observations: <BodyTwinObservation>[
        BodyTwinObservation(
          metricKey: 'body.weight.kg',
          value: 95.1,
          unit: 'kg',
          observedAt: DateTime.utc(2026, 7, 24, 8),
          source: 'local.daily_log',
          reliability: 1,
        ),
      ],
      requiredMetricKeys: const <String>['body.weight.kg'],
    );

    expect(result.status, BodyTwinFoundationStatus.accepted);
    expect(result.isAccepted, isTrue);
    expect(result.isRejected, isFalse);
    expect(result.acceptedSnapshot, isNotNull);
    expect(
      result.acceptedSnapshot!.observationsByMetric['body.weight.kg']!.value,
      95.1,
    );
    expect(result.gateResult.integrity.isValid, isTrue);
  });

  test('preserves deterministic missing-required-metric completeness', () {
    const foundation = BodyTwinSnapshotFoundation();

    final result = foundation.build(
      asOf: DateTime.utc(2026, 7, 24, 12),
      observations: const <BodyTwinObservation>[],
      requiredMetricKeys: const <String>[
        'body.weight.kg',
        'body.waist.cm',
      ],
    );

    expect(result.isAccepted, isTrue);
    expect(
      result.acceptedSnapshot!.missingRequiredMetricKeys,
      const <String>['body.waist.cm', 'body.weight.kg'],
    );
    expect(result.acceptedSnapshot!.completeness, 0);
  });
}
