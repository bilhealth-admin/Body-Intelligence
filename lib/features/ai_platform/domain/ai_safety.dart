import 'dart:collection';

import 'one_best_action.dart';

enum AiSafetyStatus { accepted, abstained, rejected }

enum AiSafetySeverity { advisory, blocking }

final class AiSafetyRule {
  AiSafetyRule({
    required this.id,
    required this.description,
    required this.severity,
    required this.matches,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
    if (description.trim().isEmpty) {
      throw ArgumentError.value(
        description,
        'description',
        'must not be empty',
      );
    }
  }

  final String id;
  final String description;
  final AiSafetySeverity severity;
  final bool Function(OneBestActionCandidate candidate) matches;
}

final class AiSafetyIssue {
  const AiSafetyIssue({
    required this.ruleId,
    required this.description,
    required this.severity,
  });

  final String ruleId;
  final String description;
  final AiSafetySeverity severity;
}

final class AiSafetyResult {
  AiSafetyResult({
    required this.status,
    required DateTime asOf,
    required this.actionResult,
    required Iterable<AiSafetyIssue> issues,
    required Iterable<String> reasons,
  }) : asOf = asOf.toUtc(),
       issues = UnmodifiableListView<AiSafetyIssue>(
         (issues.toList()
           ..sort((left, right) => left.ruleId.compareTo(right.ruleId))),
       ),
       reasons = UnmodifiableListView<String>(
         (reasons.toSet().toList()..sort()),
       );

  final AiSafetyStatus status;
  final DateTime asOf;
  final OneBestActionResult actionResult;
  final List<AiSafetyIssue> issues;
  final List<String> reasons;

  OneBestActionCandidate? get acceptedAction =>
      status == AiSafetyStatus.accepted ? actionResult.selected : null;

  bool get canProceed =>
      status == AiSafetyStatus.accepted &&
      acceptedAction != null &&
      issues.every((issue) => issue.severity != AiSafetySeverity.blocking);
}
