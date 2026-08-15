import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/nutrient_evidence.dart';
import 'package:body_intelligence_log/features/daily_log/presentation/daily_log_meals_list.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MealItem item({
    required int id,
    required double carbs,
    required double fiber,
    required bool fiberKnown,
  }) {
    final now = DateTime(2026, 8, 10, 12);
    return MealItem(
      id: id,
      uuid: 'meal-item-$id',
      mealId: 1,
      foodId: id,
      quantity: 100,
      position: id,
      calories: 100,
      protein: 10,
      carbs: carbs,
      fats: 2,
      fiber: fiber,
      sodium: 20,
      potassium: 40,
      calcium: 30,
      magnesium: 10,
      phosphorus: 15,
      sugar: 4,
      nutrientEvidenceMask: fiberKnown
          ? NutrientEvidenceMask.bit(TrackedNutrient.fiber)
          : 0,
      foodSourceSnapshot: 'catalog',
      foodVerifiedSnapshot: true,
      servingSizeSnapshot: 100,
      servingUnitSnapshot: 'g',
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      syncStatus: 'pending',
      revision: 0,
    );
  }

  test('net carbohydrates require fibre evidence for every item', () {
    final total = knownNetCarbohydrateTotal([
      item(id: 1, carbs: 20, fiber: 5, fiberKnown: true),
      item(id: 2, carbs: 12, fiber: 2, fiberKnown: true),
    ]);

    expect(total, 25);
    expect(
      knownNetCarbohydrateTotal([
        item(id: 1, carbs: 20, fiber: 5, fiberKnown: true),
        item(id: 2, carbs: 12, fiber: 0, fiberKnown: false),
      ]),
      isNull,
    );
  });

  test('net carbohydrates never become negative per food row', () {
    expect(
      knownNetCarbohydrateTotal([
        item(id: 1, carbs: 3, fiber: 5, fiberKnown: true),
      ]),
      0,
    );
    expect(knownNetCarbohydrateTotal(const []), isNull);
  });
}
