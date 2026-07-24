import '../domain/automated_health_insight_summary.dart';

class AutomatedHealthInsightIntegrityValidator {
  const AutomatedHealthInsightIntegrityValidator();

  List<String> validate(AutomatedHealthInsightSummary summary) {
    final issues = <String>[];
    if (summary.title.trim().isEmpty) {
      issues.add('summary_title_missing');
    }
    if (summary.body.trim().isEmpty) {
      issues.add('summary_body_missing');
    }
    if (!summary.isAbstained && summary.evidence.isEmpty) {
      issues.add('summary_evidence_missing');
    }
    if (!summary.safetyApproved && !summary.isAbstained) {
      issues.add('unsafe_summary_must_abstain');
    }
    return List.unmodifiable(issues..sort());
  }
}
