import 'package:body_intelligence_log/engine/one_best_action_engine.dart';
import 'package:body_intelligence_log/features/dashboard/domain/dashboard_decision_authority.dart';
import 'package:body_intelligence_log/features/dashboard/domain/dashboard_trusted_truth_decision_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const legacy = LegacyDashboardDecisionAuthority();
  const trusted = TrustedDashboardDecisionAuthority();

  test('preserves the deterministic action through the trusted Truth gate', () {
    final proposed = legacy.choose(
      weighedToday: true,
      loggingComplete: true,
      protein: 70,
      proteinTarget: 120,
      waterMl: 500,
      waterTarget: 2500,
      trackedDays: 5,
    );
    final decision = const DashboardTrustedTruthDecisionAdapter().evaluate(
      DashboardTruthDecisionContext(
        weighedToday: true,
        loggingComplete: true,
        protein: 70,
        proteinTarget: 120,
        waterMl: 500,
        waterTarget: 2500,
        trackedDays: 5,
        proposedAction: proposed,
      ),
    );

    expect(decision.action, same(proposed));
    expect(decision.result.canExposeDecision, isTrue);
    expect(decision.result.isSafeAbstention, isFalse);
    expect(decision.engineVersion, 'dashboard-truth-adapter-v1');
    expect(
      decision.inputEvidenceKeys,
      containsAll(<String>['protein', 'waterMl', 'trackedDays']),
    );
  });

  test('safely abstains when deterministic inputs are invalid', () {
    const proposed = BestAction(
      type: BestActionType.hydration,
      title: 'Unsafe proposal',
      reason: 'Must not be exposed.',
      evidence: ['invalid target'],
    );
    final decision = const DashboardTrustedTruthDecisionAdapter().evaluate(
      const DashboardTruthDecisionContext(
        weighedToday: true,
        loggingComplete: true,
        protein: 70,
        proteinTarget: 0,
        waterMl: 500,
        waterTarget: 0,
        trackedDays: 5,
        proposedAction: proposed,
      ),
    );

    expect(decision.action, isNull);
    expect(decision.result.isSafeAbstention, isTrue);
  });

  test('trusted production authority retains legacy observable parity', () {
    final expected = legacy.choose(
      weighedToday: false,
      loggingComplete: false,
      protein: 0,
      proteinTarget: 120,
      waterMl: 0,
      waterTarget: 2500,
      trackedDays: 0,
    );
    final actual = trusted.choose(
      weighedToday: false,
      loggingComplete: false,
      protein: 0,
      proteinTarget: 120,
      waterMl: 0,
      waterTarget: 2500,
      trackedDays: 0,
    );

    expect(actual.type, expected.type);
    expect(actual.title, expected.title);
    expect(actual.reason, expected.reason);
    expect(actual.evidence, expected.evidence);
  });

  test(
    'trusted authority never exposes a source action from invalid inputs',
    () {
      final actual = trusted.choose(
        weighedToday: true,
        loggingComplete: true,
        protein: double.nan,
        proteinTarget: 0,
        waterMl: -1,
        waterTarget: 0,
        trackedDays: -1,
      );

      expect(actual.type, BestActionType.none);
      expect(actual.title, 'No trusted action is available yet');
      expect(actual.reason, contains('withheld'));
    },
  );
}
