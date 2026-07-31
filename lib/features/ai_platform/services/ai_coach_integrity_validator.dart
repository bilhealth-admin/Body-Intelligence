import '../domain/ai_coach_response.dart';

final class AiCoachIntegrityValidator {
  const AiCoachIntegrityValidator();

  List<String> validate(AiCoachResponse response) {
    final issues = <String>[];
    if (response.headline.trim().isEmpty) {
      issues.add('coach_headline_missing');
    }
    if (response.message.trim().isEmpty) {
      issues.add('coach_message_missing');
    }
    if (response.status == AiCoachStatus.accepted &&
        response.actionId == null) {
      issues.add('accepted_coach_action_missing');
    }
    if (response.status != AiCoachStatus.accepted &&
        response.actionId != null) {
      issues.add('non_accepted_coach_action_exposed');
    }
    if (response.status == AiCoachStatus.accepted &&
        response.evidenceIds.isEmpty) {
      issues.add('accepted_coach_evidence_missing');
    }
    return List.unmodifiable(issues..sort());
  }
}
