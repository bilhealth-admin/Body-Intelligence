import '../domain/ai_safety.dart';

final class AiSafetyIntegrityValidator {
  const AiSafetyIntegrityValidator();

  List<String> validate(AiSafetyResult result) {
    final issues = <String>[];
    if (result.status == AiSafetyStatus.accepted &&
        result.actionResult.selected == null) {
      issues.add('accepted safety result requires a selected action');
    }
    if (result.status == AiSafetyStatus.accepted &&
        result.issues.any(
          (issue) => issue.severity == AiSafetySeverity.blocking,
        )) {
      issues.add('accepted safety result cannot contain blocking issues');
    }
    if (result.status != AiSafetyStatus.accepted &&
        result.acceptedAction != null) {
      issues.add('non-accepted safety result cannot expose an action');
    }
    return issues..sort();
  }
}
