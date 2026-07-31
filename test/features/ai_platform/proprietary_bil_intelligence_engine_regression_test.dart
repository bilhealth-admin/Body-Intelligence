import 'package:body_intelligence_log/features/ai_platform/domain/proprietary_bil_intelligence.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/proprietary_bil_intelligence_policy.dart';
import 'package:body_intelligence_log/features/ai_platform/services/proprietary_bil_intelligence_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('abstains when required local engine evidence is missing', () {
    const engine = ProprietaryBilIntelligenceEngine();
    final result = engine.synthesize(
      ProprietaryBilIntelligenceRequest(
        generatedAt: DateTime.utc(2026, 7, 24),
        requiredSignalIds: const ['safety'],
        signals: const [],
      ),
    );
    expect(result.status, BilIntelligenceStatus.abstained);
    expect(result.issues.single, contains('safety'));
  });

  test('abstains rather than using low-confidence signals', () {
    const engine = ProprietaryBilIntelligenceEngine(
      policy: ProprietaryBilIntelligencePolicy(minimumSignalConfidence: 0.8),
    );
    final result = engine.synthesize(
      ProprietaryBilIntelligenceRequest(
        generatedAt: DateTime.utc(2026, 7, 24),
        requiredSignalIds: const ['state'],
        signals: [
          BilIntelligenceSignal(
            id: 'state',
            kind: BilIntelligenceSignalKind.factualState,
            statement: 'Uncertain state.',
            confidence: 0.79,
            evidenceIds: const ['e1'],
          ),
        ],
      ),
    );
    expect(result.canProceed, isFalse);
  });

  test('request and result collections are immutable', () {
    final request = ProprietaryBilIntelligenceRequest(
      generatedAt: DateTime.utc(2026, 7, 24),
      requiredSignalIds: const [],
      signals: const [],
    );
    expect(() => request.requiredSignalIds.add('x'), throwsUnsupportedError);
  });
}
