import 'dart:collection';

import 'body_twin_freshness_result.dart';
import 'body_twin_snapshot.dart';

/// Stable deterministic consistency classifications for one Body Twin metric.
enum BodyTwinMetricConsistencyStatus {
  consistent,
  unitMismatch,
  belowMinimum,
  aboveMaximum,
  unconfigured,
}

/// Caller-owned deterministic plausibility envelope for a single metric.
///
/// This is a structural consistency contract, not a medical diagnosis. The AI
/// Platform does not invent ranges or normalize units.
final class BodyTwinMetricConsistencyRule {
  BodyTwinMetricConsistencyRule({
    required String expectedUnit,
    this.minimum,
    this.maximum,
  }) : expectedUnit = _normalized(expectedUnit) {
    if (minimum != null && !minimum!.isFinite) {
      throw ArgumentError.value(minimum, 'minimum', 'must be finite');
    }
    if (maximum != null && !maximum!.isFinite) {
      throw ArgumentError.value(maximum, 'maximum', 'must be finite');
    }
    if (minimum != null && maximum != null && minimum! > maximum!) {
      throw ArgumentError('minimum must not exceed maximum');
    }
  }

  final String expectedUnit;
  final double? minimum;
  final double? maximum;

  static String _normalized(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'expectedUnit', 'must not be empty');
    }
    return normalized;
  }
}

/// Immutable caller-owned consistency policy keyed by normalized metric key.
final class BodyTwinConsistencyPolicy {
  BodyTwinConsistencyPolicy({
    required Map<String, BodyTwinMetricConsistencyRule> rulesByMetric,
  }) : rulesByMetric = UnmodifiableMapView(
         SplayTreeMap<String, BodyTwinMetricConsistencyRule>.from(
           _validate(rulesByMetric),
         ),
       );

  final Map<String, BodyTwinMetricConsistencyRule> rulesByMetric;

  BodyTwinMetricConsistencyRule? ruleFor(String metricKey) =>
      rulesByMetric[metricKey.trim()];

  static Map<String, BodyTwinMetricConsistencyRule> _validate(
    Map<String, BodyTwinMetricConsistencyRule> source,
  ) {
    final result = <String, BodyTwinMetricConsistencyRule>{};
    for (final entry in source.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) {
        throw ArgumentError.value(entry.key, 'rulesByMetric', 'empty key');
      }
      if (result.containsKey(key)) {
        throw ArgumentError.value(
          entry.key,
          'rulesByMetric',
          'duplicate normalized metric key: $key',
        );
      }
      result[key] = entry.value;
    }
    return result;
  }
}

/// Explainable consistency evidence for one available metric.
final class BodyTwinMetricConsistencyAssessment {
  const BodyTwinMetricConsistencyAssessment({
    required this.metricKey,
    required this.value,
    required this.unit,
    required this.rule,
    required this.status,
  });

  final String metricKey;
  final double value;
  final String unit;
  final BodyTwinMetricConsistencyRule? rule;
  final BodyTwinMetricConsistencyStatus status;
}

/// Immutable consistency gate layered over the accepted freshness result.
final class BodyTwinConsistencyResult {
  BodyTwinConsistencyResult({
    required this.freshnessResult,
    required Map<String, BodyTwinMetricConsistencyAssessment>
    assessmentsByMetric,
  }) : assessmentsByMetric = UnmodifiableMapView(
         SplayTreeMap<String, BodyTwinMetricConsistencyAssessment>.from(
           assessmentsByMetric,
         ),
       );

  final BodyTwinFreshnessResult freshnessResult;
  final Map<String, BodyTwinMetricConsistencyAssessment> assessmentsByMetric;

  bool get upstreamAccepted => freshnessResult.canProceed;

  List<String> get inconsistentMetricKeys => List<String>.unmodifiable(
    assessmentsByMetric.entries
        .where(
          (entry) =>
              entry.value.status != BodyTwinMetricConsistencyStatus.consistent,
        )
        .map((entry) => entry.key),
  );

  bool get canProceed => upstreamAccepted && inconsistentMetricKeys.isEmpty;

  BodyTwinSnapshot? get acceptedConsistentSnapshot =>
      canProceed ? freshnessResult.acceptedFreshSnapshot : null;
}
