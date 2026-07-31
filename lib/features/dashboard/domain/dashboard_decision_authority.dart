import '../../../engine/one_best_action_engine.dart';

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

class LegacyDashboardDecisionAuthority
    implements DashboardDecisionAuthority {
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
