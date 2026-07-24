import 'package:body_intelligence_log/features/ai_platform/domain/proprietary_bil_intelligence.dart';
import 'package:body_intelligence_log/features/ai_platform/services/proprietary_bil_intelligence_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('synthesizes accepted signals deterministically with provenance', () {
    const engine = ProprietaryBilIntelligenceEngine();
    final result = engine.synthesize(
      ProprietaryBilIntelligenceRequest(
        generatedAt: DateTime.utc(2026, 7, 24),
        requiredSignalIds: const ['state', 'action'],
        signals: [
          BilIntelligenceSignal(
            id: 'action',
            kind: BilIntelligenceSignalKind.action,
            statement: 'Keep the approved action bounded.',
            confidence: 0.91,
            evidenceIds: const ['e2'],
          ),
          BilIntelligenceSignal(
            id: 'state',
            kind: BilIntelligenceSignalKind.factualState,
            statement: 'Trusted local state is accepted.',
            confidence: 0.95,
            evidenceIds: const ['e1', 'e2'],
          ),
        ],
      ),
    );

    expect(result.canProceed, isTrue);
    expect(
      result.summary,
      'Trusted local state is accepted. Keep the approved action bounded.',
    );
    expect(result.signalIds, ['state', 'action']);
    expect(result.evidenceIds, ['e1', 'e2']);
  });

  test('rejects malformed evidence instead of repairing it', () {
    const engine = ProprietaryBilIntelligenceEngine();
    final result = engine.synthesize(
      ProprietaryBilIntelligenceRequest(
        generatedAt: DateTime.utc(2026, 7, 24),
        requiredSignalIds: const [],
        signals: [
          BilIntelligenceSignal(
            id: 'state',
            kind: BilIntelligenceSignalKind.factualState,
            statement: 'State.',
            confidence: 0.9,
            evidenceIds: const [],
          ),
        ],
      ),
    );
    expect(result.status, BilIntelligenceStatus.rejected);
    expect(result.canProceed, isFalse);
  });
}
