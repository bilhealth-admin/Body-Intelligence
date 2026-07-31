import 'dart:collection';

import '../../../engine/one_best_action_engine.dart';
import 'dashboard_decision_authority.dart';

abstract final class DashboardDecisionAuthorityParityContract {
  static const requiredCaseIds = <String>{
    'missing-weight-has-highest-priority',
    'missing-logging-follows-weight',
    'protein-gap-precedes-hydration',
    'hydration-gap-after-protein',
    'hold-plan-before-fourteen-days',
    'fully-covered-day-needs-no-change',
    'suppressed-protein-falls-through-to-hydration',
    'suppressed-hydration-explains-memory-decision',
    'suppressed-weight-falls-through-to-logging',
    'all-priorities-suppressed-yields-explicit-none',
  };
}

final class DashboardDecisionAuthorityCase {
  DashboardDecisionAuthorityCase({
    required this.id,
    required this.weighedToday,
    required this.loggingComplete,
    required this.protein,
    required this.proteinTarget,
    required this.waterMl,
    required this.waterTarget,
    required this.trackedDays,
    Set<BestActionType> suppressedTypes = const {},
  }) : suppressedTypes = UnmodifiableSetView<BestActionType>(
         Set<BestActionType>.of(suppressedTypes),
       ) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
  }

  final String id;
  final bool weighedToday;
  final bool loggingComplete;
  final double protein;
  final int proteinTarget;
  final int waterMl;
  final int waterTarget;
  final int trackedDays;
  final Set<BestActionType> suppressedTypes;

  BestAction evaluate(DashboardDecisionAuthority authority) {
    return authority.choose(
      weighedToday: weighedToday,
      loggingComplete: loggingComplete,
      protein: protein,
      proteinTarget: proteinTarget,
      waterMl: waterMl,
      waterTarget: waterTarget,
      trackedDays: trackedDays,
      suppressedTypes: suppressedTypes,
    );
  }
}

final class DashboardDecisionParityMismatch {
  DashboardDecisionParityMismatch({
    required this.caseId,
    required this.reference,
    required this.candidate,
    required Iterable<String> differingFields,
  }) : differingFields = UnmodifiableListView<String>(
         differingFields.toList(growable: false),
       );

  final String caseId;
  final BestAction reference;
  final BestAction candidate;
  final List<String> differingFields;
}

final class DashboardDecisionParityReport {
  DashboardDecisionParityReport({
    required this.casesEvaluated,
    required Iterable<DashboardDecisionParityMismatch> mismatches,
    required Iterable<String> missingRequiredCaseIds,
  }) : mismatches = UnmodifiableListView<DashboardDecisionParityMismatch>(
         mismatches.toList(growable: false),
       ),
       missingRequiredCaseIds = UnmodifiableListView<String>(
         (missingRequiredCaseIds.toSet().toList()..sort()),
       );

  final int casesEvaluated;
  final List<DashboardDecisionParityMismatch> mismatches;
  final List<String> missingRequiredCaseIds;

  bool get hasParity =>
      casesEvaluated >=
          DashboardDecisionAuthorityParityContract.requiredCaseIds.length &&
      missingRequiredCaseIds.isEmpty &&
      mismatches.isEmpty;

  bool get referenceCanBeRetired => hasParity;
}

final class DashboardDecisionAuthorityParityGate {
  const DashboardDecisionAuthorityParityGate();

  DashboardDecisionParityReport compare({
    required DashboardDecisionAuthority reference,
    required DashboardDecisionAuthority candidate,
    required Iterable<DashboardDecisionAuthorityCase> cases,
  }) {
    final evaluatedCases = cases.toList(growable: false);
    if (evaluatedCases.isEmpty) {
      throw ArgumentError.value(cases, 'cases', 'must not be empty');
    }

    final caseIds = <String>{};
    final mismatches = <DashboardDecisionParityMismatch>[];
    for (final decisionCase in evaluatedCases) {
      if (!caseIds.add(decisionCase.id)) {
        throw ArgumentError.value(
          decisionCase.id,
          'cases',
          'case ids must be unique',
        );
      }

      final referenceAction = decisionCase.evaluate(reference);
      final candidateAction = decisionCase.evaluate(candidate);
      final differingFields = _differingFields(
        referenceAction,
        candidateAction,
      );
      if (differingFields.isNotEmpty) {
        mismatches.add(
          DashboardDecisionParityMismatch(
            caseId: decisionCase.id,
            reference: referenceAction,
            candidate: candidateAction,
            differingFields: differingFields,
          ),
        );
      }
    }

    return DashboardDecisionParityReport(
      casesEvaluated: evaluatedCases.length,
      mismatches: mismatches,
      missingRequiredCaseIds: DashboardDecisionAuthorityParityContract
          .requiredCaseIds
          .difference(caseIds),
    );
  }

  List<String> _differingFields(BestAction left, BestAction right) {
    return <String>[
      if (left.type != right.type) 'type',
      if (left.title != right.title) 'title',
      if (left.reason != right.reason) 'reason',
      if (!_orderedEquals(left.evidence, right.evidence)) 'evidence',
    ];
  }

  bool _orderedEquals(List<String> left, List<String> right) {
    if (identical(left, right)) return true;
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}
