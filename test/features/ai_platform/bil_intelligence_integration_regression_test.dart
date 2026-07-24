import 'package:body_intelligence_log/features/ai_platform/domain/bil_intelligence_integration.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/one_best_action.dart';
import 'package:body_intelligence_log/features/ai_platform/services/bil_intelligence_integration_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = BilIntelligenceIntegrationEngine();
  final action = OneBestActionCandidate(
    id: 'a',
    title: 'Action',
    rationale: 'Evidence-backed action.',
    expectedBenefit: 0.8,
    confidence: 0.8,
    burden: 0.2,
    safetyEligible: true,
    evidenceIds: const ['z', 'a'],
  );

  BilIntegrationSignal signal(BilIntegrationSource source, double confidence) =>
      BilIntegrationSignal(
        source: source,
        confidence: confidence,
        accepted: true,
        critical: false,
        evidenceIds: ['${source.name}:2', '${source.name}:1'],
        reasons: const [],
      );

  test('fusion and trace are deterministic independent of input order', () {
    final forward = [
      signal(BilIntegrationSource.aiContext, 0.8),
      signal(BilIntegrationSource.bodyTwin, 0.9),
      signal(BilIntegrationSource.safety, 1),
    ];
    final reverse = forward.reversed.toList();

    final first = engine.integrateSignals(
      generatedAt: DateTime.utc(2026, 7, 24),
      signals: forward,
      candidateAction: action,
    );
    final second = engine.integrateSignals(
      generatedAt: DateTime.utc(2026, 7, 24),
      signals: reverse,
      candidateAction: action,
    );

    expect(second.confidence, first.confidence);
    expect(second.evidenceIds, first.evidenceIds);
    expect(
      second.decisionTrace.map((entry) => entry.code),
      first.decisionTrace.map((entry) => entry.code),
    );
  });

  test('hard reconciliation conflict cannot be averaged away', () {
    final result = engine.integrateSignals(
      generatedAt: DateTime.utc(2026, 7, 24),
      signals: [
        signal(BilIntegrationSource.aiContext, 1),
        signal(BilIntegrationSource.safety, 1),
      ],
      candidateAction: action,
      reconciliationIssues: const ['hard: contradictory action identities.'],
    );

    expect(result.status, BilIntegrationStatus.rejected);
    expect(result.reconciliationIssues, [
      'hard: contradictory action identities.',
    ]);
  });
}
