import 'dart:io';

import 'package:body_intelligence_log/engine/one_best_action_engine.dart';
import 'package:body_intelligence_log/features/dashboard/domain/dashboard_decision_authority.dart';
import 'package:body_intelligence_log/features/dashboard/domain/dashboard_decision_authority_parity.dart';
import 'package:flutter_test/flutter_test.dart';

final class _DelegatingCandidateAuthority
    implements DashboardDecisionAuthority {
  const _DelegatingCandidateAuthority(this.delegate);

  final DashboardDecisionAuthority delegate;

  @override
  BestAction choose({
    required bool weighedToday,
    required bool loggingComplete,
    required double protein,
    required int proteinTarget,
    required int waterMl,
    required int waterTarget,
    required int trackedDays,
    Set<BestActionType> suppressedTypes = const {},
  }) {
    return delegate.choose(
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

final class _MutatedEvidenceAuthority implements DashboardDecisionAuthority {
  const _MutatedEvidenceAuthority(this.delegate);

  final DashboardDecisionAuthority delegate;

  @override
  BestAction choose({
    required bool weighedToday,
    required bool loggingComplete,
    required double protein,
    required int proteinTarget,
    required int waterMl,
    required int waterTarget,
    required int trackedDays,
    Set<BestActionType> suppressedTypes = const {},
  }) {
    final action = delegate.choose(
      weighedToday: weighedToday,
      loggingComplete: loggingComplete,
      protein: protein,
      proteinTarget: proteinTarget,
      waterMl: waterMl,
      waterTarget: waterTarget,
      trackedDays: trackedDays,
      suppressedTypes: suppressedTypes,
    );
    return BestAction(
      type: action.type,
      title: action.title,
      reason: action.reason,
      evidence: [...action.evidence, 'mutated evidence'],
    );
  }
}

const _legacy = LegacyDashboardDecisionAuthority();

final _canonicalCases = <DashboardDecisionAuthorityCase>[
  DashboardDecisionAuthorityCase(
    id: 'missing-weight-has-highest-priority',
    weighedToday: false,
    loggingComplete: false,
    protein: 0,
    proteinTarget: 120,
    waterMl: 0,
    waterTarget: 2500,
    trackedDays: 0,
  ),
  DashboardDecisionAuthorityCase(
    id: 'missing-logging-follows-weight',
    weighedToday: true,
    loggingComplete: false,
    protein: 0,
    proteinTarget: 120,
    waterMl: 0,
    waterTarget: 2500,
    trackedDays: 1,
  ),
  DashboardDecisionAuthorityCase(
    id: 'protein-gap-precedes-hydration',
    weighedToday: true,
    loggingComplete: true,
    protein: 70,
    proteinTarget: 120,
    waterMl: 500,
    waterTarget: 2500,
    trackedDays: 5,
  ),
  DashboardDecisionAuthorityCase(
    id: 'hydration-gap-after-protein',
    weighedToday: true,
    loggingComplete: true,
    protein: 120,
    proteinTarget: 120,
    waterMl: 1200,
    waterTarget: 2500,
    trackedDays: 5,
  ),
  DashboardDecisionAuthorityCase(
    id: 'hold-plan-before-fourteen-days',
    weighedToday: true,
    loggingComplete: true,
    protein: 120,
    proteinTarget: 120,
    waterMl: 2500,
    waterTarget: 2500,
    trackedDays: 13,
  ),
  DashboardDecisionAuthorityCase(
    id: 'fully-covered-day-needs-no-change',
    weighedToday: true,
    loggingComplete: true,
    protein: 120,
    proteinTarget: 120,
    waterMl: 2500,
    waterTarget: 2500,
    trackedDays: 14,
  ),
  DashboardDecisionAuthorityCase(
    id: 'suppressed-protein-falls-through-to-hydration',
    weighedToday: true,
    loggingComplete: true,
    protein: 70,
    proteinTarget: 120,
    waterMl: 1200,
    waterTarget: 2500,
    trackedDays: 20,
    suppressedTypes: const {BestActionType.protein},
  ),
  DashboardDecisionAuthorityCase(
    id: 'suppressed-hydration-explains-memory-decision',
    weighedToday: true,
    loggingComplete: true,
    protein: 120,
    proteinTarget: 120,
    waterMl: 1200,
    waterTarget: 2500,
    trackedDays: 20,
    suppressedTypes: const {BestActionType.hydration},
  ),
  DashboardDecisionAuthorityCase(
    id: 'suppressed-weight-falls-through-to-logging',
    weighedToday: false,
    loggingComplete: false,
    protein: 0,
    proteinTarget: 120,
    waterMl: 0,
    waterTarget: 2500,
    trackedDays: 0,
    suppressedTypes: const {BestActionType.weighIn},
  ),
  DashboardDecisionAuthorityCase(
    id: 'all-priorities-suppressed-yields-explicit-none',
    weighedToday: false,
    loggingComplete: false,
    protein: 0,
    proteinTarget: 120,
    waterMl: 0,
    waterTarget: 2500,
    trackedDays: 0,
    suppressedTypes: const {
      BestActionType.weighIn,
      BestActionType.completeLogging,
      BestActionType.protein,
      BestActionType.hydration,
      BestActionType.holdPlan,
    },
  ),
];

void main() {
  group('Dashboard decision authority retirement gate', () {
    test('allows retirement only after complete observable parity', () {
      final report = const DashboardDecisionAuthorityParityGate().compare(
        reference: _legacy,
        candidate: const TrustedDashboardDecisionAuthority(),
        cases: _canonicalCases,
      );

      expect(report.casesEvaluated, _canonicalCases.length);
      expect(
        report.casesEvaluated,
        DashboardDecisionAuthorityParityContract.requiredCaseIds.length,
      );
      expect(report.missingRequiredCaseIds, isEmpty);
      expect(report.mismatches, isEmpty);
      expect(report.hasParity, isTrue);
      expect(report.referenceCanBeRetired, isTrue);
    });

    test('blocks retirement when any observable field changes', () {
      final report = const DashboardDecisionAuthorityParityGate().compare(
        reference: _legacy,
        candidate: const _MutatedEvidenceAuthority(_legacy),
        cases: _canonicalCases,
      );

      expect(report.referenceCanBeRetired, isFalse);
      expect(report.mismatches, hasLength(_canonicalCases.length));
      expect(
        report.mismatches.every(
          (mismatch) => mismatch.differingFields.contains('evidence'),
        ),
        isTrue,
      );
    });

    test('blocks retirement when the approved matrix is incomplete', () {
      final report = const DashboardDecisionAuthorityParityGate().compare(
        reference: _legacy,
        candidate: const _DelegatingCandidateAuthority(_legacy),
        cases: [_canonicalCases.first],
      );

      expect(report.mismatches, isEmpty);
      expect(report.missingRequiredCaseIds, isNotEmpty);
      expect(report.referenceCanBeRetired, isFalse);
    });

    test('rejects an empty or ambiguous comparison matrix', () {
      const gate = DashboardDecisionAuthorityParityGate();

      expect(
        () => gate.compare(
          reference: _legacy,
          candidate: const _DelegatingCandidateAuthority(_legacy),
          cases: const [],
        ),
        throwsArgumentError,
      );

      final duplicateCase = _canonicalCases.first;
      expect(
        () => gate.compare(
          reference: _legacy,
          candidate: const _DelegatingCandidateAuthority(_legacy),
          cases: [duplicateCase, duplicateCase],
        ),
        throwsArgumentError,
      );
    });
  });

  test('Dashboard production code cannot bypass its decision authority', () {
    final dashboardFiles = Directory('lib/features/dashboard')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList(growable: false);
    final directLegacyCallers = <String>[];

    for (final file in dashboardFiles) {
      final source = file.readAsStringSync();
      if (source.contains('OneBestActionEngine.choose(')) {
        directLegacyCallers.add(file.path.replaceAll('\\', '/'));
      }
    }

    expect(directLegacyCallers, [
      'lib/features/dashboard/domain/dashboard_decision_authority.dart',
    ]);

    final composer = File(
      'lib/features/dashboard/domain/dashboard_intelligence_composer.dart',
    ).readAsStringSync();
    expect(composer, contains('_decisionAuthority.choose('));
    expect(composer, isNot(contains('OneBestActionEngine.choose(')));
  });

  test(
    'AI candidate ranking remains isolated until an adapter proves parity',
    () {
      final dashboardAuthority = File(
        'lib/features/dashboard/domain/dashboard_decision_authority.dart',
      ).readAsStringSync();
      final aiRankingEngine = File(
        'lib/features/ai_platform/services/one_best_action_engine.dart',
      ).readAsStringSync();

      expect(
        dashboardAuthority,
        isNot(contains('features/ai_platform/services/one_best_action_engine')),
      );
      expect(aiRankingEngine, contains('OneBestActionResult select<T>'));
      expect(
        aiRankingEngine,
        isNot(contains('implements DashboardDecisionAuthority')),
      );
    },
  );
}
