import 'dart:collection';

import '../../ai_platform/domain/body_twin_consistency_result.dart';
import '../../ai_platform/domain/body_twin_freshness_result.dart';
import '../../ai_platform/domain/body_twin_observation.dart';
import '../../ai_platform/services/trusted_body_twin_snapshot_pipeline.dart';

final class DashboardBodyTwinWeightObservation {
  const DashboardBodyTwinWeightObservation({
    required this.kg,
    required this.observedAt,
    required this.source,
  });

  final double kg;
  final DateTime observedAt;
  final String source;
}

enum DashboardBodyTwinTrustStatus { trusted, stale, inconsistent, unavailable }

final class DashboardTrustedBodyTwinSnapshot {
  DashboardTrustedBodyTwinSnapshot({
    required this.status,
    required this.engineVersion,
    required Iterable<String> reasons,
    this.weightKg,
    this.observedAt,
    this.source,
  }) : reasons = UnmodifiableListView<String>(
         reasons
             .map((value) => value.trim())
             .where((value) => value.isNotEmpty)
             .toList(),
       );

  final DashboardBodyTwinTrustStatus status;
  final String engineVersion;
  final List<String> reasons;
  final double? weightKg;
  final DateTime? observedAt;
  final String? source;

  bool get canExposeBodyTwin => status == DashboardBodyTwinTrustStatus.trusted;
}

/// Dashboard-owned policy adapter for the local trusted Body Twin pipeline.
/// It validates recorded weight only and never predicts, repairs, or normalizes.
final class DashboardTrustedBodyTwinAdapter {
  const DashboardTrustedBodyTwinAdapter({
    this.pipeline = const TrustedBodyTwinSnapshotPipeline(),
  });

  static const engineVersion = 'dashboard-body-twin-trust-v1';
  static const maximumWeightAge = Duration(days: 3);
  static const requiredMetricKeys = <String>['weight'];

  final TrustedBodyTwinSnapshotPipeline pipeline;

  DashboardTrustedBodyTwinSnapshot build({
    required DateTime asOf,
    required Iterable<DashboardBodyTwinWeightObservation> weights,
  }) {
    final observations = weights.map(
      (weight) => BodyTwinObservation(
        metricKey: 'weight',
        value: weight.kg,
        unit: 'kg',
        observedAt: weight.observedAt,
        source: weight.source.trim().isEmpty
            ? 'local-weight-log'
            : 'local-weight-log:${weight.source.trim()}',
      ),
    );
    final result = pipeline.build(
      asOf: asOf,
      observations: observations,
      requiredMetricKeys: requiredMetricKeys,
      freshnessPolicy: BodyTwinFreshnessPolicy(
        maxAgeByMetric: const {'weight': maximumWeightAge},
      ),
      consistencyPolicy: BodyTwinConsistencyPolicy(
        rulesByMetric: {
          'weight': BodyTwinMetricConsistencyRule(
            expectedUnit: 'kg',
            minimum: 30,
            maximum: 300,
          ),
        },
      ),
    );

    final foundation = result.foundationResult.acceptedSnapshot;
    final weight = foundation?.observationFor('weight');
    if (!result.foundationResult.isAccepted || foundation == null) {
      return DashboardTrustedBodyTwinSnapshot(
        status: DashboardBodyTwinTrustStatus.unavailable,
        engineVersion: engineVersion,
        reasons: const ['Body Twin integrity validation rejected local input.'],
      );
    }
    if (!result.hasCompleteFoundation || weight == null) {
      return DashboardTrustedBodyTwinSnapshot(
        status: DashboardBodyTwinTrustStatus.unavailable,
        engineVersion: engineVersion,
        reasons: const ['A recorded weight is required for Body Twin.'],
      );
    }
    if (result.freshnessResult.staleMetricKeys.isNotEmpty) {
      return DashboardTrustedBodyTwinSnapshot(
        status: DashboardBodyTwinTrustStatus.stale,
        engineVersion: engineVersion,
        reasons: const ['The latest recorded weight is older than 3 days.'],
        weightKg: weight.value,
        observedAt: weight.observedAt,
        source: weight.source,
      );
    }
    if (!result.consistencyResult.canProceed) {
      return DashboardTrustedBodyTwinSnapshot(
        status: DashboardBodyTwinTrustStatus.inconsistent,
        engineVersion: engineVersion,
        reasons: result.consistencyResult.inconsistentMetricKeys.map(
          (key) => 'The $key observation failed the local consistency gate.',
        ),
        weightKg: weight.value,
        observedAt: weight.observedAt,
        source: weight.source,
      );
    }

    final accepted = result.acceptedSnapshot!.observationFor('weight')!;
    return DashboardTrustedBodyTwinSnapshot(
      status: DashboardBodyTwinTrustStatus.trusted,
      engineVersion: engineVersion,
      reasons: const [
        'Local weight passed integrity, freshness, and consistency gates.',
      ],
      weightKg: accepted.value,
      observedAt: accepted.observedAt,
      source: accepted.source,
    );
  }
}
