import 'package:body_intelligence_log/features/ai_platform/domain/bil_intelligence_integration.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/one_best_action.dart';
import 'package:body_intelligence_log/features/ai_platform/services/bil_intelligence_integration_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = BilIntelligenceIntegrationEngine();
  final action = OneBestActionCandidate(
    id: 'walk-10',
    title: 'Walk for ten minutes',
    rationale: 'Low burden and supported by the accepted decision chain.',
    expectedBenefit: 0.8,
    confidence: 0.9,
    burden: 0.1,
    safetyEligible: true,
    evidenceIds: const ['action-evidence'],
  );

  test(
    'accepts one explainable decision when every critical signal is accepted',
    () {
      final result = engine.integrateSignals(
        generatedAt: DateTime.utc(2026, 7, 24),
        candidateAction: action,
        signals: [
          for (final source in BilIntegrationSource.values)
            BilIntegrationSignal(
              source: source,
              confidence: 0.9,
              accepted: true,
              critical:
                  source == BilIntegrationSource.aiContext ||
                  source == BilIntegrationSource.bodyTwin ||
                  source == BilIntegrationSource.oneBestAction ||
                  source == BilIntegrationSource.safety ||
                  source == BilIntegrationSource.proprietaryIntelligence ||
                  source == BilIntegrationSource.scientificValidation,
              evidenceIds: ['${source.name}-evidence'],
              reasons: const [],
            ),
        ],
      );

      expect(result.status, BilIntegrationStatus.accepted);
      expect(result.canProceed, isTrue);
      expect(result.selectedAction?.id, 'walk-10');
      expect(result.decisionTrace.map((entry) => entry.code), [
        'collect',
        'reconcile',
        'fuse',
        'gate',
        'decision',
      ]);
      expect(result.evidenceIds.length, BilIntegrationSource.values.length);
    },
  );

  test(
    'rejects when a critical engine fails even if auxiliary confidence is high',
    () {
      final signals = [
        for (final source in BilIntegrationSource.values)
          BilIntegrationSignal(
            source: source,
            confidence: source == BilIntegrationSource.safety ? 0 : 1,
            accepted: source != BilIntegrationSource.safety,
            critical: source == BilIntegrationSource.safety,
            evidenceIds: const ['e'],
            reasons: const [],
          ),
      ];

      final result = engine.integrateSignals(
        generatedAt: DateTime.utc(2026, 7, 24),
        signals: signals,
        candidateAction: action,
      );

      expect(result.status, BilIntegrationStatus.rejected);
      expect(result.selectedAction, isNull);
      expect(result.canProceed, isFalse);
    },
  );
}
