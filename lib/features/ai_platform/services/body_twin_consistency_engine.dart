import '../domain/body_twin_consistency_result.dart';
import '../domain/body_twin_freshness_result.dart';

/// Pure local consistency gate for an already integrity- and freshness-gated
/// Body Twin snapshot.
///
/// All units and bounds are caller supplied. This engine performs no unit
/// conversion, estimation, diagnosis, repair, persistence, networking,
/// provider access, recommendation, forecasting, or clock access.
final class BodyTwinConsistencyEngine {
  const BodyTwinConsistencyEngine();

  BodyTwinConsistencyResult evaluate({
    required BodyTwinFreshnessResult freshnessResult,
    required BodyTwinConsistencyPolicy policy,
  }) {
    final snapshot = freshnessResult.acceptedFreshSnapshot;
    if (snapshot == null) {
      return BodyTwinConsistencyResult(
        freshnessResult: freshnessResult,
        assessmentsByMetric: const {},
      );
    }

    final assessments = <String, BodyTwinMetricConsistencyAssessment>{};
    for (final entry in snapshot.observationsByMetric.entries) {
      final metricKey = entry.key;
      final observation = entry.value;
      final rule = policy.ruleFor(metricKey);
      final status = _classify(
        value: observation.value,
        unit: observation.unit,
        rule: rule,
      );
      assessments[metricKey] = BodyTwinMetricConsistencyAssessment(
        metricKey: metricKey,
        value: observation.value,
        unit: observation.unit,
        rule: rule,
        status: status,
      );
    }

    return BodyTwinConsistencyResult(
      freshnessResult: freshnessResult,
      assessmentsByMetric: assessments,
    );
  }

  static BodyTwinMetricConsistencyStatus _classify({
    required double value,
    required String unit,
    required BodyTwinMetricConsistencyRule? rule,
  }) {
    if (rule == null) {
      return BodyTwinMetricConsistencyStatus.unconfigured;
    }
    if (unit != rule.expectedUnit) {
      return BodyTwinMetricConsistencyStatus.unitMismatch;
    }
    final minimum = rule.minimum;
    if (minimum != null && value < minimum) {
      return BodyTwinMetricConsistencyStatus.belowMinimum;
    }
    final maximum = rule.maximum;
    if (maximum != null && value > maximum) {
      return BodyTwinMetricConsistencyStatus.aboveMaximum;
    }
    return BodyTwinMetricConsistencyStatus.consistent;
  }
}
