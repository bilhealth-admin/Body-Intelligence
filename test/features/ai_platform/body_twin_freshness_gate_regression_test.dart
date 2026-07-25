import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_freshness_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_observation.dart';
import 'package:body_intelligence_log/features/ai_platform/services/body_twin_freshness_gate.dart';
import 'package:body_intelligence_log/features/ai_platform/services/body_twin_snapshot_foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preserves upstream rejection without exposing a snapshot', () {
    const foundation = BodyTwinSnapshotFoundation();
    const gate = BodyTwinFreshnessGate();

    final upstream = foundation.build(
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
    );

    final result = gate.evaluate(
      foundationResult: upstream,
      policy: BodyTwinFreshnessPolicy(
        maxAgeByMetric: const {'body.weight.kg': Duration(days: 1)},
      ),
    );

    expect(result.foundationResult, same(upstream));
    expect(result.foundationResult.gateResult.integrity.isValid, isTrue);
  });

  test('policy normalizes ordering and rejects invalid maximum ages', () {
    final policy = BodyTwinFreshnessPolicy(
      maxAgeByMetric: const {
        'z.metric': Duration(days: 2),
        'a.metric': Duration(days: 1),
      },
    );

    expect(policy.maxAgeByMetric.keys, const ['a.metric', 'z.metric']);
    expect(
      () => BodyTwinFreshnessPolicy(
        maxAgeByMetric: const {'body.weight.kg': Duration.zero},
      ),
      throwsArgumentError,
    );
  });

  test('freshness assessment does not alter snapshot completeness', () {
    const foundation = BodyTwinSnapshotFoundation();
    const gate = BodyTwinFreshnessGate();
    final upstream = foundation.build(
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
      requiredMetricKeys: const ['body.weight.kg', 'body.waist.cm'],
    );

    final result = gate.evaluate(
      foundationResult: upstream,
      policy: BodyTwinFreshnessPolicy(
        maxAgeByMetric: const {'body.weight.kg': Duration(days: 1)},
      ),
    );

    expect(result.canProceed, isTrue);
    expect(result.acceptedFreshSnapshot!.missingRequiredMetricKeys, const [
      'body.waist.cm',
    ]);
    expect(result.acceptedFreshSnapshot!.completeness, 0.5);
  });
}
