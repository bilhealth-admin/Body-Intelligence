import 'package:body_intelligence_log/features/ai_platform/domain/bil_intelligence_integration.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/one_best_action.dart';
import 'package:body_intelligence_log/features/ai_platform/services/bil_intelligence_integration_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Unified Health Brain preserves evidence, confidence, explanation and one decision',
    () {
      const engine = BilIntelligenceIntegrationEngine();
      final action = OneBestActionCandidate(
        id: 'hydrate',
        title: 'Follow the accepted hydration action',
        rationale: 'Unified evidence supports the selected action.',
        expectedBenefit: 0.75,
        confidence: 0.85,
        burden: 0.1,
        safetyEligible: true,
        evidenceIds: const ['action'],
      );
      final result = engine.integrateSignals(
        generatedAt: DateTime.utc(2026, 7, 24),
        candidateAction: action,
        signals: [
          for (final source in BilIntegrationSource.values)
            BilIntegrationSignal(
              source: source,
              confidence: 0.92,
              accepted: true,
              critical: false,
              evidenceIds: ['evidence:${source.name}'],
              reasons: const [],
            ),
        ],
      );

      expect(result.canProceed, isTrue);
      expect(result.selectedAction, same(action));
      expect(result.confidence, greaterThan(0.8));
      expect(result.explanation, isNotEmpty);
      expect(result.decisionTrace.length, 5);
      expect(result.evidenceIds, isNotEmpty);
    },
  );
}
