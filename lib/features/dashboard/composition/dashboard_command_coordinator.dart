import '../../../data/repositories/meal_repository.dart';
import '../../../engine/one_best_action_engine.dart';

typedef RememberDashboardAction = Future<int> Function(BestAction action);
typedef RespondToDashboardAction =
    Future<void> Function(int memoryId, String response);
typedef AddDashboardWater =
    Future<void> Function(DateTime occurredAt, int amountMl);
typedef RepeatUsualDashboardMeal =
    Future<void> Function(UsualMealCandidate candidate, DateTime date);
typedef RepeatHistoricalDashboardMeal =
    Future<void> Function(MealWithItems meal, DateTime date);

/// Coordinates dashboard write commands without owning any visual feedback.
///
/// Confirmation dialogs, localized messages, navigation, and provider
/// invalidation remain presentation concerns in [DashboardGrid]. Repository
/// sequencing and clock use live here as a testable application boundary.
final class DashboardCommandCoordinator {
  const DashboardCommandCoordinator({
    required this.onRememberAction,
    required this.onRespondToAction,
    required this.onAddWater,
    required this.onRepeatUsualMeal,
    required this.onRepeatHistoricalMeal,
    required this.clock,
  });

  final RememberDashboardAction onRememberAction;
  final RespondToDashboardAction onRespondToAction;
  final AddDashboardWater onAddWater;
  final RepeatUsualDashboardMeal onRepeatUsualMeal;
  final RepeatHistoricalDashboardMeal onRepeatHistoricalMeal;
  final DateTime Function() clock;

  Future<void> recordActionResponse({
    required BestAction action,
    required String response,
  }) async {
    final memoryId = await onRememberAction(action);
    await onRespondToAction(memoryId, response);
  }

  Future<void> addWater(int amountMl) => onAddWater(clock(), amountMl);

  Future<void> repeatUsualBreakfast(UsualMealCandidate candidate) =>
      onRepeatUsualMeal(candidate, clock());

  Future<void> repeatRecentBreakfast(MealWithItems meal) =>
      onRepeatHistoricalMeal(meal, clock());
}
