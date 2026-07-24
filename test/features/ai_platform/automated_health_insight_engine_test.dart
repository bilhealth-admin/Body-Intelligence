import 'package:body_intelligence_log/features/ai_platform/domain/automated_health_insight_policy.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/automated_health_insight_summary.dart';
import 'package:body_intelligence_log/features/ai_platform/services/automated_health_insight_engine.dart';
import 'package:body_intelligence_log/features/ai_platform/services/automated_health_insight_integrity_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates a bounded deterministic summary with provenance', () {
    final now = DateTime.utc(2026, 7, 24, 6);
    final engine = AutomatedHealthInsightEngine(
      policy: const AutomatedHealthInsightPolicy(maximumEvidenceItems: 2),
    );
    final result = engine.summarize(
      generatedAt: now,
      safetyApproved: true,
      evidence: [
        HealthInsightEvidence(
          key: 'weight',
          statement: 'Weight trend is stable.',
          provenance: 'body_twin',
          observedAt: now,
          confidence: 0.9,
        ),
        HealthInsightEvidence(
          key: 'forecast',
          statement: 'The local forecast remains within its trusted range.',
          provenance: 'metabolic_forecast',
          observedAt: now.subtract(const Duration(minutes: 1)),
          confidence: 0.8,
        ),
      ],
    );
    expect(result.isAbstained, isFalse);
    expect(result.evidence, hasLength(2));
    expect(
      const AutomatedHealthInsightIntegrityValidator().validate(result),
      isEmpty,
    );
  });

  test('abstains when safety has not approved output', () {
    final result = const AutomatedHealthInsightEngine().summarize(
      generatedAt: DateTime.utc(2026, 7, 24),
      safetyApproved: false,
      evidence: [
        HealthInsightEvidence(
          key: 'x',
          statement: 'Unsafe statement.',
          provenance: 'test',
          observedAt: DateTime.utc(2026, 7, 24),
          confidence: 1,
        ),
      ],
    );
    expect(result.isAbstained, isTrue);
    expect(result.evidence, isEmpty);
  });
}
