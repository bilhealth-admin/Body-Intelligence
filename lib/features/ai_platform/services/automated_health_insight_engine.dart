import '../domain/automated_health_insight_policy.dart';
import '../domain/automated_health_insight_summary.dart';

class AutomatedHealthInsightEngine {
  const AutomatedHealthInsightEngine({
    this.policy = const AutomatedHealthInsightPolicy(),
  });

  final AutomatedHealthInsightPolicy policy;

  AutomatedHealthInsightSummary summarize({
    required DateTime generatedAt,
    required Iterable<HealthInsightEvidence> evidence,
    required bool safetyApproved,
    Iterable<String> uncertaintyNotes = const [],
  }) {
    final accepted =
        evidence
            .where((item) => item.confidence >= policy.minimumConfidence)
            .toList()
          ..sort((left, right) {
            final time = right.observedAt.compareTo(left.observedAt);
            return time != 0 ? time : left.key.compareTo(right.key);
          });
    final bounded = accepted.take(policy.maximumEvidenceItems).toList();
    final notes =
        uncertaintyNotes
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    if (!safetyApproved || bounded.isEmpty) {
      return AutomatedHealthInsightSummary(
        generatedAt: generatedAt,
        title: 'No trusted health insight available',
        body:
            'BIL abstained because the available evidence was insufficient or did not pass the safety gate.',
        severity: HealthInsightSeverity.blocked,
        evidence: const [],
        uncertaintyNotes: notes,
        safetyApproved: safetyApproved,
        isAbstained: true,
      );
    }

    final body = bounded.map((item) => item.statement.trim()).join(' ');
    final boundedBody = body.length <= policy.maximumBodyCharacters
        ? body
        : '${body.substring(0, policy.maximumBodyCharacters - 1).trimRight()}…';
    return AutomatedHealthInsightSummary(
      generatedAt: generatedAt,
      title: 'Your current health pattern',
      body: boundedBody,
      severity: notes.isEmpty
          ? HealthInsightSeverity.information
          : HealthInsightSeverity.attention,
      evidence: bounded,
      uncertaintyNotes: notes,
      safetyApproved: true,
      isAbstained: false,
    );
  }
}
