import 'package:body_intelligence_log/engine/one_best_action_engine.dart';
import 'package:body_intelligence_log/features/dashboard/domain/dashboard_decision_authority.dart';
import 'package:body_intelligence_log/features/dashboard/domain/dashboard_decision_release_boundary.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FixedAuthority implements DashboardDecisionAuthority {
  const _FixedAuthority(this.action);

  final BestAction action;

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
  }) => action;
}

void main() {
  const boundary = DashboardDecisionReleaseBoundary();

  test('releases a reviewed action with explicit evidence unchanged', () {
    const action = BestAction(
      type: BestActionType.hydration,
      title: 'Drink 500 ml gradually',
      reason: 'Recorded hydration remains below the local target.',
      evidence: <String>['500 ml recorded', '2500 ml target'],
    );

    final result = boundary.evaluate(action);

    expect(result.status, DashboardDecisionReleaseStatus.released);
    expect(result.canRecommend, isTrue);
    expect(result.exposedAction, same(action));
  });

  test('preserves an intentional no-recommendation result unchanged', () {
    const action = BestAction(
      type: BestActionType.none,
      title: 'No plan change needed',
      reason: 'Today’s recorded priorities are broadly covered.',
      evidence: <String>['Local priorities are covered'],
    );

    final result = boundary.evaluate(action);

    expect(result.status, DashboardDecisionReleaseStatus.noRecommendation);
    expect(result.canRecommend, isFalse);
    expect(result.exposedAction, same(action));
  });

  test('abstains explicitly when evidence is missing', () {
    const candidate = BestAction(
      type: BestActionType.protein,
      title: 'Add protein',
      reason: 'A protein gap exists.',
      evidence: <String>[],
    );

    final result = boundary.evaluate(candidate);

    expect(result.status, DashboardDecisionReleaseStatus.insufficientEvidence);
    expect(result.exposedAction.type, BestActionType.none);
    expect(result.exposedAction.title, 'More evidence is needed');
  });

  test('blocks unsupported medical language before presentation', () {
    const candidate = BestAction(
      type: BestActionType.holdPlan,
      title: 'Change medication now',
      reason: 'This will treat disease.',
      evidence: <String>['Unreviewed statement'],
    );

    final result = boundary.evaluate(candidate);

    expect(result.status, DashboardDecisionReleaseStatus.safetyBlocked);
    expect(result.exposedAction.type, BestActionType.none);
    expect(result.reasons, contains('Blocked term: change medication'));
  });

  test('production authority applies the release boundary after Truth', () {
    const unsafe = BestAction(
      type: BestActionType.hydration,
      title: 'Medical emergency diagnosis',
      reason: 'Unsafe candidate.',
      evidence: <String>['local value'],
    );
    const authority = TrustedDashboardDecisionAuthority(
      source: _FixedAuthority(unsafe),
    );

    final action = authority.choose(
      weighedToday: true,
      loggingComplete: true,
      protein: 100,
      proteinTarget: 120,
      waterMl: 1500,
      waterTarget: 2500,
      trackedDays: 20,
    );

    expect(action.type, BestActionType.none);
    expect(action.title, 'No safe action is available');
  });

  test('production authority retains deterministic observable parity', () {
    const legacy = LegacyDashboardDecisionAuthority();
    const trusted = TrustedDashboardDecisionAuthority();
    final expected = legacy.choose(
      weighedToday: true,
      loggingComplete: true,
      protein: 70,
      proteinTarget: 120,
      waterMl: 500,
      waterTarget: 2500,
      trackedDays: 5,
    );
    final actual = trusted.choose(
      weighedToday: true,
      loggingComplete: true,
      protein: 70,
      proteinTarget: 120,
      waterMl: 500,
      waterTarget: 2500,
      trackedDays: 5,
    );

    expect(actual.type, expected.type);
    expect(actual.title, expected.title);
    expect(actual.reason, expected.reason);
    expect(actual.evidence, expected.evidence);
  });
}
