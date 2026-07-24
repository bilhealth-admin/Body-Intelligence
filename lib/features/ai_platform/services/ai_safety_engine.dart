import '../domain/ai_safety.dart';
import '../domain/ai_safety_policy.dart';
import '../domain/one_best_action.dart';
import 'ai_safety_integrity_validator.dart';

/// Deterministic local safety boundary over One Best Action output.
///
/// Policy ownership remains with the caller. This engine does not diagnose,
/// generate emergency advice, contact services, or mutate user state.
final class AiSafetyEngine {
  const AiSafetyEngine({
    this.integrityValidator = const AiSafetyIntegrityValidator(),
  });

  final AiSafetyIntegrityValidator integrityValidator;

  AiSafetyResult evaluate({
    required OneBestActionResult actionResult,
    required AiSafetyPolicy policy,
  }) {
    if (policy.requireAcceptedAction && !actionResult.canProceed) {
      return _result(
        status: AiSafetyStatus.rejected,
        actionResult: actionResult,
        issues: const <AiSafetyIssue>[],
        reasons: const <String>['accepted One Best Action output is required'],
      );
    }

    final selected = actionResult.selected;
    if (selected == null) {
      return _result(
        status: AiSafetyStatus.abstained,
        actionResult: actionResult,
        issues: const <AiSafetyIssue>[],
        reasons: const <String>[
          'no selected action is available for safety review',
        ],
      );
    }

    final issues = <AiSafetyIssue>[
      for (final rule in policy.rules)
        if (rule.matches(selected))
          AiSafetyIssue(
            ruleId: rule.id,
            description: rule.description,
            severity: rule.severity,
          ),
    ];
    final hasBlocking = issues.any(
      (issue) => issue.severity == AiSafetySeverity.blocking,
    );
    if (hasBlocking) {
      return _result(
        status: AiSafetyStatus.rejected,
        actionResult: actionResult,
        issues: issues,
        reasons: const <String>[
          'one or more caller-owned hard safety rules blocked the action',
        ],
      );
    }
    if (policy.abstainOnAdvisory && issues.isNotEmpty) {
      return _result(
        status: AiSafetyStatus.abstained,
        actionResult: actionResult,
        issues: issues,
        reasons: const <String>[
          'caller policy requires abstention on advisory safety issues',
        ],
      );
    }
    return _result(
      status: AiSafetyStatus.accepted,
      actionResult: actionResult,
      issues: issues,
      reasons: const <String>[
        'selected action passed all caller-owned blocking safety rules',
      ],
    );
  }

  AiSafetyResult _result({
    required AiSafetyStatus status,
    required OneBestActionResult actionResult,
    required Iterable<AiSafetyIssue> issues,
    required Iterable<String> reasons,
  }) {
    final result = AiSafetyResult(
      status: status,
      asOf: actionResult.asOf,
      actionResult: actionResult,
      issues: issues,
      reasons: reasons,
    );
    final integrityIssues = integrityValidator.validate(result);
    if (integrityIssues.isNotEmpty) {
      return AiSafetyResult(
        status: AiSafetyStatus.rejected,
        asOf: actionResult.asOf,
        actionResult: actionResult,
        issues: <AiSafetyIssue>[
          ...issues,
          for (final issue in integrityIssues)
            AiSafetyIssue(
              ruleId: 'integrity',
              description: issue,
              severity: AiSafetySeverity.blocking,
            ),
        ],
        reasons: const <String>['AI Safety integrity validation failed'],
      );
    }
    return result;
  }
}
