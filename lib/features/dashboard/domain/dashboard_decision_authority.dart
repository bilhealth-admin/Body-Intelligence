import '../../../engine/one_best_action_engine.dart';
import 'dashboard_decision_release_boundary.dart';
import 'dashboard_trusted_truth_decision_adapter.dart';

abstract interface class DashboardDecisionAuthority {
  const DashboardDecisionAuthority();

  BestAction choose({
    required bool weighedToday,
    required bool loggingComplete,
    required double protein,
    required int proteinTarget,
    required int waterMl,
    required int waterTarget,
    required int trackedDays,
    Set<BestActionType> suppressedTypes = const {},
  });
}

class LegacyDashboardDecisionAuthority implements DashboardDecisionAuthority {
  const LegacyDashboardDecisionAuthority();

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
    return OneBestActionEngine.choose(
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

final class TrustedDashboardDecisionAuthority
    implements DashboardDecisionAuthority {
  const TrustedDashboardDecisionAuthority({
    this.source = const LegacyDashboardDecisionAuthority(),
    this.adapter = const DashboardTrustedTruthDecisionAdapter(),
    this.releaseBoundary = const DashboardDecisionReleaseBoundary(),
  });

  final DashboardDecisionAuthority source;
  final DashboardTrustedTruthDecisionAdapter adapter;
  final DashboardDecisionReleaseBoundary releaseBoundary;

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
    if (!DashboardTrustedTruthDecisionAdapter.inputsAreValid(
      protein: protein,
      proteinTarget: proteinTarget,
      waterMl: waterMl,
      waterTarget: waterTarget,
      trackedDays: trackedDays,
    )) {
      return DashboardTrustedTruthDecisionAdapter.abstentionAction;
    }
    final proposed = source.choose(
      weighedToday: weighedToday,
      loggingComplete: loggingComplete,
      protein: protein,
      proteinTarget: proteinTarget,
      waterMl: waterMl,
      waterTarget: waterTarget,
      trackedDays: trackedDays,
      suppressedTypes: suppressedTypes,
    );
    final trusted = adapter.evaluate(
      DashboardTruthDecisionContext(
        weighedToday: weighedToday,
        loggingComplete: loggingComplete,
        protein: protein,
        proteinTarget: proteinTarget,
        waterMl: waterMl,
        waterTarget: waterTarget,
        trackedDays: trackedDays,
        proposedAction: proposed,
      ),
    );
    final trustedAction = trusted.action;
    if (trustedAction == null) {
      return DashboardTrustedTruthDecisionAdapter.abstentionAction;
    }
    return releaseBoundary.evaluate(trustedAction).exposedAction;
  }
}
