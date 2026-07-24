import 'dart:collection';

import 'body_twin_foundation_result.dart';
import 'body_twin_snapshot.dart';

/// Per-metric freshness classification under an explicit caller-owned policy.
enum BodyTwinMetricFreshnessStatus { fresh, stale, unconfigured }

/// Immutable maximum-age policy for locally produced Body Twin metrics.
///
/// Policy ownership remains outside the AI Platform. This contract only makes
/// caller-supplied limits explicit, normalized, deterministic, and testable.
final class BodyTwinFreshnessPolicy {
  BodyTwinFreshnessPolicy({required Map<String, Duration> maxAgeByMetric})
    : maxAgeByMetric = UnmodifiableMapView<String, Duration>(
        SplayTreeMap<String, Duration>.from(_validate(maxAgeByMetric)),
      );

  final Map<String, Duration> maxAgeByMetric;

  Duration? maxAgeFor(String metricKey) => maxAgeByMetric[metricKey.trim()];

  static Map<String, Duration> _validate(Map<String, Duration> source) {
    final validated = <String, Duration>{};
    for (final entry in source.entries) {
      final metricKey = entry.key.trim();
      if (metricKey.isEmpty) {
        throw ArgumentError.value(
          entry.key,
          'maxAgeByMetric',
          'metric key must not be empty',
        );
      }
      if (entry.value <= Duration.zero) {
        throw ArgumentError.value(
          entry.value,
          'maxAgeByMetric[$metricKey]',
          'maximum age must be greater than zero',
        );
      }
      if (validated.containsKey(metricKey)) {
        throw ArgumentError.value(
          entry.key,
          'maxAgeByMetric',
          'duplicate normalized metric key: $metricKey',
        );
      }
      validated[metricKey] = entry.value;
    }
    return validated;
  }
}

/// Explainable freshness evidence for one metric in an accepted snapshot.
final class BodyTwinMetricFreshnessAssessment {
  const BodyTwinMetricFreshnessAssessment({
    required this.metricKey,
    required this.observedAt,
    required this.asOf,
    required this.age,
    required this.maximumAge,
    required this.status,
  });

  final String metricKey;
  final DateTime observedAt;
  final DateTime asOf;
  final Duration age;
  final Duration? maximumAge;
  final BodyTwinMetricFreshnessStatus status;
}

/// Immutable freshness gate over the already integrity-gated Body Twin result.
///
/// Upstream rejection is preserved. A snapshot is consumable only when every
/// available metric has an explicit policy and is within its maximum age.
final class BodyTwinFreshnessResult {
  BodyTwinFreshnessResult({
    required this.foundationResult,
    required Map<String, BodyTwinMetricFreshnessAssessment> assessmentsByMetric,
  }) : assessmentsByMetric = UnmodifiableMapView(
         SplayTreeMap<String, BodyTwinMetricFreshnessAssessment>.from(
           assessmentsByMetric,
         ),
       );

  final BodyTwinFoundationResult foundationResult;
  final Map<String, BodyTwinMetricFreshnessAssessment> assessmentsByMetric;

  bool get upstreamAccepted => foundationResult.isAccepted;

  List<String> get staleMetricKeys => List<String>.unmodifiable(
    assessmentsByMetric.entries
        .where(
          (entry) =>
              entry.value.status == BodyTwinMetricFreshnessStatus.stale,
        )
        .map((entry) => entry.key),
  );

  List<String> get unconfiguredMetricKeys => List<String>.unmodifiable(
    assessmentsByMetric.entries
        .where(
          (entry) =>
              entry.value.status == BodyTwinMetricFreshnessStatus.unconfigured,
        )
        .map((entry) => entry.key),
  );

  bool get canProceed =>
      upstreamAccepted &&
      staleMetricKeys.isEmpty &&
      unconfiguredMetricKeys.isEmpty;

  BodyTwinSnapshot? get acceptedFreshSnapshot =>
      canProceed ? foundationResult.acceptedSnapshot : null;
}
