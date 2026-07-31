import '../domain/body_twin_outcome.dart';
import '../domain/body_twin_trend_state.dart';

/// Validates closure invariants between the trusted snapshot and trend state.
final class BodyTwinEngineIntegrityValidator {
  const BodyTwinEngineIntegrityValidator();

  List<String> validate({
    required BodyTwinOutcome outcome,
    required BodyTwinTrendState trendState,
  }) {
    final issues = <String>[];
    final snapshot = outcome.acceptedSnapshot;

    if (!trendState.asOf.isAtSameMomentAs(
      outcome.trustedResult.foundationResult.gateResult.snapshot.asOf,
    )) {
      issues.add('as_of_mismatch');
    }

    if (snapshot == null) {
      return List<String>.unmodifiable(issues..sort());
    }

    for (final entry in snapshot.observationsByMetric.entries) {
      final trend = trendState.trendFor(entry.key);
      if (trend == null) {
        issues.add('missing_trend:${entry.key}');
        continue;
      }
      final latest = trend.latest;
      final observation = entry.value;
      if (!latest.observedAt.isAtSameMomentAs(observation.observedAt) ||
          latest.value != observation.value ||
          latest.unit != observation.unit ||
          latest.source != observation.source ||
          latest.reliability != observation.reliability) {
        issues.add('latest_observation_mismatch:${entry.key}');
      }
    }

    for (final metricKey in trendState.trendsByMetric.keys) {
      if (!snapshot.observationsByMetric.containsKey(metricKey)) {
        issues.add('unexpected_trend:$metricKey');
      }
    }

    issues.sort();
    return List<String>.unmodifiable(issues);
  }
}
