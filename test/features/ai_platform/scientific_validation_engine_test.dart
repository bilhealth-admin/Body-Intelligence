import 'package:body_intelligence_log/features/ai_platform/domain/scientific_validation.dart';
import 'package:body_intelligence_log/features/ai_platform/services/scientific_validation_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('validates reproducible claims with evidence and uncertainty', () {
    const engine = ScientificValidationEngine();
    final result = engine.validate(
      ScientificValidationRequest(
        generatedAt: DateTime.utc(2026, 7, 24),
        sourceSummary: 'Trusted local synthesis.',
        availableEvidenceIds: const ['weight-ledger', 'forecast-model'],
        claims: [
          ScientificClaim(
            id: 'claim-1',
            statement: 'Observed weight is 95.1 kg.',
            strength: ScientificClaimStrength.observed,
            confidence: 1,
            evidenceIds: const ['weight-ledger'],
            assumptions: const [],
          ),
          ScientificClaim(
            id: 'claim-2',
            statement: 'The current trend may continue.',
            strength: ScientificClaimStrength.forecast,
            confidence: 0.8,
            evidenceIds: const ['forecast-model'],
            assumptions: const ['Current adherence continues.'],
          ),
        ],
      ),
    );

    expect(result.canProceed, isTrue);
    expect(result.records, hasLength(2));
    expect(result.records.last.uncertaintyDisclosures, isNotEmpty);
  });

  test('abstains when a claim lacks available evidence', () {
    const engine = ScientificValidationEngine();
    final result = engine.validate(
      ScientificValidationRequest(
        generatedAt: DateTime.utc(2026, 7, 24),
        sourceSummary: 'Trusted local synthesis.',
        availableEvidenceIds: const [],
        claims: [
          ScientificClaim(
            id: 'claim-1',
            statement: 'Unsupported claim.',
            strength: ScientificClaimStrength.supportedInference,
            confidence: 0.9,
            evidenceIds: const ['missing'],
            assumptions: const [],
          ),
        ],
      ),
    );

    expect(result.status, ScientificValidationStatus.abstained);
    expect(result.records, isEmpty);
  });
}
