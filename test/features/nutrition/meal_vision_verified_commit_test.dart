import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/nutrient_evidence.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_image_gateway_contract.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Proves that the unchanged production atomic diary API persists reviewed
/// grams and food source/evidence, and the committed item can be read back.
void main() {
  late AppDatabase db;
  late FoodRepository foods;
  late MealRepository meals;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    foods = FoodRepository(db);
    meals = MealRepository(db);
  });
  tearDown(() => db.close());

  Future<int> verifiedFood() => foods.addFood(
    name: 'Verified ful',
    category: 'legumes',
    servingSize: 100,
    servingUnit: 'g',
    calories: 95,
    protein: 5.1,
    carbs: 11.9,
    fats: 3.4,
    fiber: 3.5,
    potassium: 170,
    sodium: null,
    source: 'foundation',
    verified: true,
    isCustom: false,
  );

  test('80 g reviewed vision amount is really committed and readable', () async {
    final foodId = await verifiedFood();
    final food = await (db.select(db.foods)..limit(1)).getSingle();
    final grams = mealImageAmountInGrams(
      amount: 80, unit: 'g',
      servingSize: food.servingSize, servingUnit: food.servingUnit,
    );
    expect(grams, 80);
    await meals.addReviewedMealItemsAtomically(
      date: DateTime(2026, 10, 10),
      mealType: 'breakfast',
      items: [(foodId: foodId, quantity: grams!)],
    );
    final saved = await db.select(db.mealItems).get();
    expect(saved, hasLength(1));
    expect(saved.single.foodId, foodId);
    expect(saved.single.quantity, 80);
    expect(saved.single.foodSourceSnapshot, 'foundation');
    expect(saved.single.foodVerifiedSnapshot, isTrue);
    expect(saved.single.calories, closeTo(76, 0.0001));
    expect(saved.single.potassium, closeTo(136, 0.0001));
    expect(
      NutrientEvidenceMask.contains(
        saved.single.nutrientEvidenceMask, TrackedNutrient.potassium,
      ),
      isTrue,
    );
    expect(
      NutrientEvidenceMask.contains(
        saved.single.nutrientEvidenceMask, TrackedNutrient.sodium,
      ),
      isFalse,
    );
  });

  test('zero reviewed amount cannot write a partial meal', () async {
    final foodId = await verifiedFood();
    await expectLater(
      meals.addReviewedMealItemsAtomically(
        date: DateTime(2026, 10, 10),
        mealType: 'lunch',
        items: [(foodId: foodId, quantity: 0)],
      ),
      throwsArgumentError,
    );
    expect(await db.select(db.mealItems).get(), isEmpty);
    expect(await db.select(db.meals).get(), isEmpty);
  });
}
