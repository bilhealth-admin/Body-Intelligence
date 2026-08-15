import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/nutrient_evidence.dart';
import 'package:body_intelligence_log/features/analytics/nutrition_analytics_page.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('totals include only evidence-backed finite nonnegative values', () {
    final known = _item(
      id: 1,
      calories: 120,
      protein: 9,
      mask: NutrientEvidenceMask.fromValues(calories: 120, protein: 9),
    );
    final unknown = _item(id: 2, calories: 900, protein: 30, mask: 0);
    final totals = NutritionAnalyticsTotals.fromMeals([
      _meal([known, unknown]),
    ]);

    expect(totals.calories, 120);
    expect(totals.protein, 9);
    expect(totals.knownCounts[TrackedNutrient.calories], 1);
    expect(totals.unknownCounts[TrackedNutrient.calories], 1);
    expect(totals.isComplete(TrackedNutrient.calories), isFalse);
    expect(totals.isKnown(TrackedNutrient.carbohydrates), isFalse);
  });
}

MealWithItems _meal(List<MealItem> items) => MealWithItems(
  meal: Meal(
    id: 1,
    uuid: 'meal',
    date: DateTime(2026, 8, 14),
    dayKey: '2026-08-14',
    name: 'Breakfast',
    type: 'breakfast',
    createdAt: DateTime(2026, 8, 14),
    updatedAt: DateTime(2026, 8, 14),
    deletedAt: null,
    revision: 1,
    syncStatus: 'local',
  ),
  items: items,
  foodsById: const {},
);

MealItem _item({
  required int id,
  required double calories,
  required double protein,
  required int mask,
}) => MealItem(
  id: id,
  uuid: 'item-$id',
  mealId: 1,
  foodId: id,
  quantity: 1,
  position: id,
  calories: calories,
  protein: protein,
  carbs: 25,
  fats: 4,
  fiber: 0,
  sodium: 0,
  potassium: 0,
  calcium: 0,
  magnesium: 0,
  phosphorus: 0,
  sugar: 0,
  nutrientEvidenceMask: mask,
  foodSourceSnapshot: 'test',
  foodVerifiedSnapshot: false,
  servingSizeSnapshot: 1,
  servingUnitSnapshot: 'serving',
  createdAt: DateTime(2026, 8, 14),
  updatedAt: DateTime(2026, 8, 14),
  deletedAt: null,
  revision: 1,
  syncStatus: 'local',
);
