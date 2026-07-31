import '../domain/body_twin_foundation_result.dart';
import '../domain/body_twin_freshness_result.dart';

/// Pure local freshness gate for an already integrity-gated Body Twin result.
///
/// The caller supplies the complete metric freshness policy and the snapshot
/// supplies the explicit `asOf` clock. The gate performs no inference, repair,
/// persistence, provider access, recommendation, or medical interpretation.
final class BodyTwinFreshnessGate {
  const BodyTwinFreshnessGate();

  BodyTwinFreshnessResult evaluate({
    required BodyTwinFoundationResult foundationResult,
    required BodyTwinFreshnessPolicy policy,
  }) {
    final snapshot = foundationResult.acceptedSnapshot;
    if (snapshot == null) {
      return BodyTwinFreshnessResult(
        foundationResult: foundationResult,
        assessmentsByMetric: const {},
      );
    }

    final assessments = <String, BodyTwinMetricFreshnessAssessment>{};
    for (final entry in snapshot.observationsByMetric.entries) {
      final metricKey = entry.key;
      final observation = entry.value;
      final maximumAge = policy.maxAgeFor(metricKey);
      final age = snapshot.asOf.difference(observation.observedAt);
      final status = maximumAge == null
          ? BodyTwinMetricFreshnessStatus.unconfigured
          : age <= maximumAge
          ? BodyTwinMetricFreshnessStatus.fresh
          : BodyTwinMetricFreshnessStatus.stale;

      assessments[metricKey] = BodyTwinMetricFreshnessAssessment(
        metricKey: metricKey,
        observedAt: observation.observedAt,
        asOf: snapshot.asOf,
        age: age,
        maximumAge: maximumAge,
        status: status,
      );
    }

    return BodyTwinFreshnessResult(
      foundationResult: foundationResult,
      assessmentsByMetric: assessments,
    );
  }
}
