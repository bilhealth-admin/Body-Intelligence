import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/data/repositories/water_repository.dart';
import 'package:body_intelligence_log/features/ai_platform/services/local_intelligence_composition_root.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'profile without weight entries safely abstains without leaking forecast or action',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await _seedProfile(database);
      await _seedNonWeightEvidence(database);

      final output = await const BilLocalIntelligenceCompositionRoot()
          .create(database: database)
          .run(asOf: DateTime.utc(2026, 7, 20));

      expect(output.forecast, isEmpty);
      expect(output.canPresent, isFalse);
      expect(output.brainResult.selectedAction, isNull);
      expect(output.primaryMessage.toLowerCase(), contains('weight'));
      expect(
        output.explanation,
        contains(
          'Safe abstention: no local weight observation exists within the analysis window.',
        ),
      );
    },
  );
}

Future<void> _seedProfile(AppDatabase database) =>
    UserProfileRepository(database).save(
      gender: 'male',
      age: 36,
      height: 181,
      currentWeight: 95,
      targetWeight: 88,
      activityLevel: 'moderate',
      exercises: true,
      waist: 104,
      neck: 43,
    );

Future<void> _seedNonWeightEvidence(AppDatabase database) async {
  final foods = FoodRepository(database);
  final meals = MealRepository(database);
  final water = WaterRepository(database);
  final foodId = await foods.addFood(
    name: 'No-weight reality fixture',
    category: 'test',
    calories: 1800,
    protein: 140,
    carbs: 170,
    fats: 60,
    sodium: 2200,
    potassium: 3200,
    servingSize: 100,
  );
  final start = DateTime.utc(2026, 6, 15);
  for (var index = 0; index < 36; index++) {
    final day = start.add(Duration(days: index));
    await water.add(
      occurredAt: day.add(const Duration(hours: 12)),
      amountMl: 2300,
    );
    final mealId = await meals.createMeal(
      date: day.add(const Duration(hours: 13)),
      name: 'Complete intake without weight',
      type: 'lunch',
    );
    await meals.addMealItem(mealId: mealId, foodId: foodId, quantity: 100);
  }
}
