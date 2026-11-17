part of 'dashboard_grid.dart';

Widget _dashboardNutrientGoalSection({
  required Set<String> visibleNutrientGoalCards,
  required double? Function(TrackedNutrient) evidenced,
  required Map<String, double?> cardNutrientGoals,
}) => Padding(
  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
  child: _DashboardNutrientGoalCards(
    selected: visibleNutrientGoalCards,
    values: {
      DashboardNutrientGoalIds.protein: evidenced(TrackedNutrient.protein),
      DashboardNutrientGoalIds.carbohydrates: evidenced(
        TrackedNutrient.carbohydrates,
      ),
      DashboardNutrientGoalIds.fat: evidenced(TrackedNutrient.fat),
      DashboardNutrientGoalIds.fiber: evidenced(TrackedNutrient.fiber),
      DashboardNutrientGoalIds.sodium: evidenced(TrackedNutrient.sodium),
      DashboardNutrientGoalIds.potassium: evidenced(TrackedNutrient.potassium),
    },
    goals: cardNutrientGoals,
  ),
);
