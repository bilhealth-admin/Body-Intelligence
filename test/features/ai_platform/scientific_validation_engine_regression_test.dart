import 'package:body_intelligence_log/features/ai_platform/domain/scientific_validation.dart';
import 'package:body_intelligence_log/features/ai_platform/services/scientific_validation_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('claim ordering and evidence ordering are deterministic', () {
    const engine = ScientificValidationEngine();
    ScientificValidationRequest request(List<ScientificClaim> claims) {
      return ScientificValidationRequest(
        generatedAt: DateTime.utc(2026, 7, 24),
        sourceSummary: 'Trusted local synthesis.',
        availableEvidenceIds: const ['a', 'b'],
        claims: claims,
      );
    }

    final first = engine.validate(
      request([
        ScientificClaim(
          id: 'b',
          statement: 'Second.',
          strength: ScientificClaimStrength.observed,
          confidence: 1,
          evidenceIds: const ['b', 'a'],
          assumptions: const [],
        ),
        ScientificClaim(
          id: 'a',
          statement: 'First.',
          strength: ScientificClaimStrength.observed,
          confidence: 1,
          evidenceIds: const ['a'],
          assumptions: const [],
        ),
      ]),
    );
    final second = engine.validate(
      request([
        ScientificClaim(
          id: 'a',
          statement: 'First.',
          strength: ScientificClaimStrength.observed,
          confidence: 1,
          evidenceIds: const ['a'],
          assumptions: const [],
        ),
        ScientificClaim(
          id: 'b',
          statement: 'Second.',
          strength: ScientificClaimStrength.observed,
          confidence: 1,
          evidenceIds: const ['a', 'b'],
          assumptions: const [],
        ),
      ]),
    );

    expect(first.records.map((record) => record.claimId), ['a', 'b']);
    expect(second.records.map((record) => record.claimId), ['a', 'b']);
    expect(first.records.last.evidenceIds, ['a', 'b']);
    expect(second.records.last.evidenceIds, ['a', 'b']);
  });

  test('invalid request is rejected and exposes no records', () {
    const engine = ScientificValidationEngine();
    final result = engine.validate(
      ScientificValidationRequest(
        generatedAt: DateTime.utc(2026, 7, 24),
        sourceSummary: '',
        availableEvidenceIds: const [],
        claims: const [],
      ),
    );

    expect(result.status, ScientificValidationStatus.rejected);
    expect(result.records, isEmpty);
    expect(result.issues, isNotEmpty);
  });
}
