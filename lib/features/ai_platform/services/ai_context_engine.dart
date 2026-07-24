import '../domain/ai_context.dart';
import '../domain/body_twin_engine_result.dart';
import '../domain/decision_memory_history.dart';
import '../domain/truth_explain_foundation_result.dart';
import 'ai_context_integrity_validator.dart';

/// Complete deterministic local AI Context Engine.
///
/// It admits only already accepted local engine outputs, preserves explicit
/// missing-context evidence, bounds Decision Memory projection, and performs
/// no prompting, provider access, persistence, recommendation, forecasting,
/// diagnosis, or UI mutation.
final class AiContextEngine {
  const AiContextEngine({
    this.integrityValidator = const AiContextIntegrityValidator(),
  });

  static const String truthDecisionKey = 'truth.decision';
  static const String bodySnapshotKey = 'body.snapshot';
  static const String bodyTrendsKey = 'body.trends';
  static const String decisionMemoryKey = 'decision.memory';

  final AiContextIntegrityValidator integrityValidator;

  AiContextEngineResult<T> build<T>({
    required DateTime asOf,
    required TruthExplainFoundationResult<T> truthResult,
    required BodyTwinEngineResult bodyTwinResult,
    required Iterable<DecisionMemoryHistory> decisionHistory,
    Iterable<String> requiredContextKeys = const <String>[
      truthDecisionKey,
      bodySnapshotKey,
      bodyTrendsKey,
      decisionMemoryKey,
    ],
    int maxDecisionHistory = 20,
  }) {
    if (maxDecisionHistory < 0) {
      throw ArgumentError.value(
        maxDecisionHistory,
        'maxDecisionHistory',
        'must not be negative',
      );
    }
    final normalizedAsOf = asOf.toUtc();
    final allowedKeys = <String>{
      truthDecisionKey,
      bodySnapshotKey,
      bodyTrendsKey,
      decisionMemoryKey,
    };
    final requiredKeys = requiredContextKeys.map((key) => key.trim()).toSet();
    if (requiredKeys.any((key) => key.isEmpty || !allowedKeys.contains(key))) {
      throw ArgumentError.value(
        requiredContextKeys,
        'requiredContextKeys',
        'contains an unknown or empty context key',
      );
    }

    final eligibleHistory =
        decisionHistory
            .where(
              (item) => !item.record.createdAt.toUtc().isAfter(normalizedAsOf),
            )
            .toList(growable: false)
          ..sort((left, right) {
            final time = right.record.createdAt.compareTo(
              left.record.createdAt,
            );
            if (time != 0) {
              return time;
            }
            return left.record.id.compareTo(right.record.id);
          });
    final boundedHistory = eligibleHistory.take(maxDecisionHistory).toList();

    final acceptedBody = bodyTwinResult.canProceed;
    final hasTruthDecision =
        truthResult.hasAction && truthResult.decision != null;
    final available = <String>{
      if (hasTruthDecision) truthDecisionKey,
      if (acceptedBody && bodyTwinResult.acceptedSnapshot != null)
        bodySnapshotKey,
      if (acceptedBody) bodyTrendsKey,
      if (boundedHistory.isNotEmpty) decisionMemoryKey,
    };
    final missing = requiredKeys.difference(available);
    final provenance = <AiContextProvenance>[
      if (hasTruthDecision)
        AiContextProvenance(
          contextKey: truthDecisionKey,
          source: AiContextSource.truthExplain,
          evidenceIds: const <String>['truth-explain:accepted'],
        ),
      if (acceptedBody && bodyTwinResult.acceptedSnapshot != null)
        AiContextProvenance(
          contextKey: bodySnapshotKey,
          source: AiContextSource.bodyTwin,
          evidenceIds: bodyTwinResult
              .acceptedSnapshot!
              .observationsByMetric
              .values
              .map(
                (item) =>
                    '${item.metricKey}:${item.observedAt.toUtc().toIso8601String()}',
              ),
        ),
      if (acceptedBody)
        AiContextProvenance(
          contextKey: bodyTrendsKey,
          source: AiContextSource.bodyTwin,
          evidenceIds: bodyTwinResult.trendState.trendsByMetric.keys,
        ),
      if (boundedHistory.isNotEmpty)
        AiContextProvenance(
          contextKey: decisionMemoryKey,
          source: AiContextSource.decisionMemory,
          evidenceIds: boundedHistory.map((item) => item.record.id),
        ),
    ];

    final context = AiContext<T>(
      asOf: normalizedAsOf,
      truthStatus: truthResult.status,
      truthDecision: hasTruthDecision ? truthResult.decision : null,
      bodySnapshot: acceptedBody ? bodyTwinResult.acceptedSnapshot : null,
      bodyTrends: acceptedBody ? bodyTwinResult.trendState : null,
      decisionHistory: boundedHistory,
      missingContextKeys: missing,
      provenance: provenance,
    );
    return AiContextEngineResult<T>(
      context: context,
      integrityIssues: integrityValidator.validate(context),
      upstreamRejected:
          truthResult.isRejected ||
          bodyTwinResult.status == BodyTwinEngineStatus.rejected,
    );
  }
}
