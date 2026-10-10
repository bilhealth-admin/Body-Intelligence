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

  test(
    '80 g reviewed vision amount is really committed and readable',
    () async {
      final foodId = await verifiedFood();
      final food = await (db.select(db.foods)..limit(1)).getSingle();
      final grams = mealImageAmountInGrams(
        amount: 80,
        unit: 'g',
        servingSize: food.servingSize,
        servingUnit: food.servingUnit,
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
          saved.single.nutrientEvidenceMask,
          TrackedNutrient.potassium,
        ),
        isTrue,
      );
      expect(
        NutrientEvidenceMask.contains(
          saved.single.nutrientEvidenceMask,
          TrackedNutrient.sodium,
        ),
        isFalse,
      );
    },
  );

  test(
    'same Vision request replays its durable receipt without a duplicate',
    () async {
      final foodId = await verifiedFood();
      final date = DateTime(2026, 10, 10);
      final first = await meals.addReviewedMealItemsAtomically(
        date: date,
        mealType: 'breakfast',
        items: [(foodId: foodId, quantity: 80)],
        visionRequestId: 'vision-request-one',
      );
      final replay = await MealRepository(db).addReviewedMealItemsAtomically(
        date: date,
        mealType: 'breakfast',
        items: [(foodId: foodId, quantity: 80)],
        visionRequestId: 'vision-request-one',
      );
      expect(replay, first);
      final saved = await db.select(db.mealItems).get();
      expect(saved, hasLength(1));
      expect(saved.single.quantity, 80);
      final preferences = await db.select(db.preferences).get();
      expect(
        preferences.where((row) => row.key.startsWith('visionMealCommitV1.')),
        hasLength(1),
      );
    },
  );

  test('two concurrent identical Vision commits persist one item', () async {
    final foodId = await verifiedFood();
    final attempts = await Future.wait([
      meals.addReviewedMealItemsAtomically(
        date: DateTime(2026, 10, 10),
        mealType: 'lunch',
        items: [(foodId: foodId, quantity: 80)],
        visionRequestId: 'vision-concurrent',
      ),
      MealRepository(db).addReviewedMealItemsAtomically(
        date: DateTime(2026, 10, 10),
        mealType: 'lunch',
        items: [(foodId: foodId, quantity: 80)],
        visionRequestId: 'vision-concurrent',
      ),
    ]);
    expect(attempts[0], attempts[1]);
    expect(await db.select(db.mealItems).get(), hasLength(1));
  });

  test(
    'reused Vision request with different food amount fails closed',
    () async {
      final foodId = await verifiedFood();
      await meals.addReviewedMealItemsAtomically(
        date: DateTime(2026, 10, 10),
        mealType: 'dinner',
        items: [(foodId: foodId, quantity: 80)],
        visionRequestId: 'vision-conflict',
      );
      await expectLater(
        meals.addReviewedMealItemsAtomically(
          date: DateTime(2026, 10, 10),
          mealType: 'dinner',
          items: [(foodId: foodId, quantity: 90)],
          visionRequestId: 'vision-conflict',
        ),
        throwsStateError,
      );
      final saved = await db.select(db.mealItems).get();
      expect(saved, hasLength(1));
      expect(saved.single.quantity, 80);
    },
  );

  test('failed Vision batch rolls back item and idempotency receipt', () async {
    final foodId = await verifiedFood();
    await expectLater(
      meals.addReviewedMealItemsAtomically(
        date: DateTime(2026, 10, 10),
        mealType: 'snack',
        items: [
          (foodId: foodId, quantity: 80),
          (foodId: 99999999, quantity: 40),
        ],
        visionRequestId: 'vision-rollback',
      ),
      throwsStateError,
    );
    expect(await db.select(db.mealItems).get(), isEmpty);
    expect(await db.select(db.meals).get(), isEmpty);
    expect(
      (await db.select(db.preferences).get()).where(
        (row) => row.key.startsWith('visionMealCommitV1.'),
      ),
      isEmpty,
    );
  });

  test('Vision mixed grams, pieces and milliliters commit actual quantities', () async {
    final grams = await verifiedFood();
    final piece = await foods.addFood(
      name: 'Verified eggs per 2 pieces',
      category: 'test',
      servingSize: 2,
      servingUnit: 'piece',
      calories: 200,
      protein: 14,
      carbs: 2,
      fats: 12,
      source: 'label',
      verified: true,
    );
    final liquid = await foods.addFood(
      name: 'Verified milk per 100 ml',
      category: 'test',
      servingSize: 100,
      servingUnit: 'ml',
      calories: 60,
      protein: 3.4,
      carbs: 5,
      fats: 1,
      source: 'label',
      verified: true,
    );

    const request = 'vision-mixed-units';
    const dayType = 'lunch';
    final day = DateTime(2026, 10, 10);
    final items = [
      (foodId: grams, quantity: 80.0, quantityInGrams: true),
      (foodId: piece, quantity: 1.0, quantityInGrams: false),
      (foodId: liquid, quantity: 250.0, quantityInGrams: false),
    ];
    final mealId = await meals.addReviewedVisionItemsAtomically(
      date: day,
      mealType: dayType,
      visionRequestId: request,
      items: items,
    );
    final saved = await db.select(db.mealItems).get();
    expect(saved, hasLength(3));
    final byFood = {for (final row in saved) row.foodId: row};
    expect(byFood[grams]!.quantity, 80);
    expect(byFood[grams]!.servingUnitSnapshot, 'g');
    expect(byFood[grams]!.calories, closeTo(76, .001));
    expect(byFood[piece]!.quantity, 1);
    expect(byFood[piece]!.servingUnitSnapshot, 'piece');
    expect(byFood[piece]!.calories, closeTo(100, .001));
    expect(byFood[liquid]!.quantity, 250);
    expect(byFood[liquid]!.servingUnitSnapshot, 'ml');
    expect(byFood[liquid]!.calories, closeTo(150, .001));
    expect(byFood[grams]!.nutrientEvidenceMask, isNot(0));
    final replay = await MealRepository(db).addReviewedVisionItemsAtomically(
      date: day,
      mealType: dayType,
      visionRequestId: request,
      items: items,
    );
    expect(replay, mealId);
    expect(await db.select(db.mealItems).get(), hasLength(3));
    await expectLater(
      meals.addReviewedVisionItemsAtomically(
        date: day,
        mealType: dayType,
        visionRequestId: request,
        items: [
          (foodId: grams, quantity: 80, quantityInGrams: true),
          (foodId: piece, quantity: 1, quantityInGrams: true),
          (foodId: liquid, quantity: 250, quantityInGrams: false),
        ],
      ),
      throwsStateError,
    );
    expect(await db.select(db.mealItems).get(), hasLength(3));
  });

  test('mixed-unit Vision partial failure leaves neither rows nor receipt', () async {
    final grams = await verifiedFood();
    await expectLater(
      meals.addReviewedVisionItemsAtomically(
        date: DateTime(2026, 10, 10),
        mealType: 'snack',
        visionRequestId: 'vision-mixed-rollback',
        items: [
          (foodId: grams, quantity: 40, quantityInGrams: true),
          (foodId: 99999999, quantity: 1, quantityInGrams: false),
        ],
      ),
      throwsStateError,
    );
    expect(await db.select(db.mealItems).get(), isEmpty);
    expect(await db.select(db.meals).get(), isEmpty);
    expect(
      (await db.select(db.preferences).get())
          .where((row) => row.key.startsWith('visionMealCommitV1.')),
      isEmpty,
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
