import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_freshness_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_observation.dart';
import 'package:body_intelligence_log/features/ai_platform/services/body_twin_freshness_gate.dart';
import 'package:body_intelligence_log/features/ai_platform/services/body_twin_snapshot_foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'accepts a snapshot only when every available metric is configured and fresh',
    () {
      const foundation = BodyTwinSnapshotFoundation();
      const gate = BodyTwinFreshnessGate();
      final result = gate.evaluate(
        foundationResult: foundation.build(
          asOf: DateTime.utc(2026, 7, 24, 12),
          observations: <BodyTwinObservation>[
            BodyTwinObservation(
              metricKey: 'body.weight.kg',
              value: 95.1,
              unit: 'kg',
              observedAt: DateTime.utc(2026, 7, 24, 8),
              source: 'local.daily_log',
            ),
          ],
        ),
        policy: BodyTwinFreshnessPolicy(
          maxAgeByMetric: const {'body.weight.kg': Duration(hours: 24)},
        ),
      );

      expect(result.canProceed, isTrue);
      expect(result.acceptedFreshSnapshot, isNotNull);
      expect(
        result.assessmentsByMetric['body.weight.kg']!.status,
        BodyTwinMetricFreshnessStatus.fresh,
      );
      expect(result.staleMetricKeys, isEmpty);
      expect(result.unconfiguredMetricKeys, isEmpty);
    },
  );

  test('rejects stale evidence while preserving exact age evidence', () {
    const foundation = BodyTwinSnapshotFoundation();
    const gate = BodyTwinFreshnessGate();
    final result = gate.evaluate(
      foundationResult: foundation.build(
        asOf: DateTime.utc(2026, 7, 24, 12),
        observations: <BodyTwinObservation>[
          BodyTwinObservation(
            metricKey: 'body.weight.kg',
            value: 95.1,
            unit: 'kg',
            observedAt: DateTime.utc(2026, 7, 22, 12),
            source: 'local.daily_log',
          ),
        ],
      ),
      policy: BodyTwinFreshnessPolicy(
        maxAgeByMetric: const {'body.weight.kg': Duration(hours: 24)},
      ),
    );

    expect(result.canProceed, isFalse);
    expect(result.acceptedFreshSnapshot, isNull);
    expect(result.staleMetricKeys, const ['body.weight.kg']);
    expect(
      result.assessmentsByMetric['body.weight.kg']!.age,
      const Duration(hours: 48),
    );
  });

  test('treats an exact maximum-age boundary as fresh', () {
    const foundation = BodyTwinSnapshotFoundation();
    const gate = BodyTwinFreshnessGate();
    final result = gate.evaluate(
      foundationResult: foundation.build(
        asOf: DateTime.utc(2026, 7, 24, 12),
        observations: <BodyTwinObservation>[
          BodyTwinObservation(
            metricKey: 'body.waist.cm',
            value: 104,
            unit: 'cm',
            observedAt: DateTime.utc(2026, 7, 17, 12),
            source: 'local.profile',
          ),
        ],
      ),
      policy: BodyTwinFreshnessPolicy(
        maxAgeByMetric: const {'body.waist.cm': Duration(days: 7)},
      ),
    );

    expect(result.canProceed, isTrue);
    expect(
      result.assessmentsByMetric['body.waist.cm']!.status,
      BodyTwinMetricFreshnessStatus.fresh,
    );
  });

  test('keeps missing policy explicit and blocks consumption', () {
    const foundation = BodyTwinSnapshotFoundation();
    const gate = BodyTwinFreshnessGate();
    final result = gate.evaluate(
      foundationResult: foundation.build(
        asOf: DateTime.utc(2026, 7, 24, 12),
        observations: <BodyTwinObservation>[
          BodyTwinObservation(
            metricKey: 'body.weight.kg',
            value: 95.1,
            unit: 'kg',
            observedAt: DateTime.utc(2026, 7, 24, 8),
            source: 'local.daily_log',
          ),
        ],
      ),
      policy: BodyTwinFreshnessPolicy(maxAgeByMetric: const {}),
    );

    expect(result.canProceed, isFalse);
    expect(result.unconfiguredMetricKeys, const ['body.weight.kg']);
    expect(
      result.assessmentsByMetric['body.weight.kg']!.status,
      BodyTwinMetricFreshnessStatus.unconfigured,
    );
  });
}
