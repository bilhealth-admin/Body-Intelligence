import 'package:body_intelligence_log/features/ai_platform/domain/automated_health_insight_summary.dart';
import 'package:body_intelligence_log/features/ai_platform/services/automated_health_insight_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('filters weak evidence and keeps ordering stable', () {
    final now = DateTime.utc(2026, 7, 24);
    final evidence = [
      HealthInsightEvidence(
        key: 'b',
        statement: 'Second.',
        provenance: 'local',
        observedAt: now,
        confidence: 0.9,
      ),
      HealthInsightEvidence(
        key: 'a',
        statement: 'First.',
        provenance: 'local',
        observedAt: now,
        confidence: 0.9,
      ),
      HealthInsightEvidence(
        key: 'weak',
        statement: 'Weak.',
        provenance: 'local',
        observedAt: now,
        confidence: 0.2,
      ),
    ];
    final result = const AutomatedHealthInsightEngine().summarize(
      generatedAt: now,
      evidence: evidence,
      safetyApproved: true,
    );
    expect(result.evidence.map((item) => item.key), ['a', 'b']);
  });

  test('returned collections are immutable', () {
    final result = const AutomatedHealthInsightEngine().summarize(
      generatedAt: DateTime.utc(2026, 7, 24),
      safetyApproved: true,
      uncertaintyNotes: const ['limited history'],
      evidence: [
        HealthInsightEvidence(
          key: 'a',
          statement: 'Evidence.',
          provenance: 'local',
          observedAt: DateTime.utc(2026, 7, 24),
          confidence: 1,
        ),
      ],
    );
    expect(
      () => result.evidence.add(result.evidence.first),
      throwsUnsupportedError,
    );
    expect(() => result.uncertaintyNotes.add('x'), throwsUnsupportedError);
  });
}
