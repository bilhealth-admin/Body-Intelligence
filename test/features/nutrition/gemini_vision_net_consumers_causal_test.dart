import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/features/daily_log/presentation/daily_log_nutrition_evidence.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/coach_message_nutrition_reader.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/coach_meal_read_parser.dart';
import 'package:body_intelligence_log/features/nutrition/domain/gemini_vision_estimate.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const owner = '11111111-1111-4111-8111-111111111111';
final day = DateTime(2026, 11, 18);
Future<void> seedGemini(AppDatabase db, double? net) async {
  final estimate = GeminiVisionEstimate(
    requestId: 'net-photo',
    index: 0,
    name: 'Photo meal',
    modelRevision: 'gemini-test',
    promptRevision: 'photo-test',
    basis: GeminiEstimateBasis(quantity: 100, unit: 'g'),
    picturedAmount: 100,
    picturedUnit: 'g',
    nutrients: GeminiEstimateNutrients({
      FoodNutrient.calories: 160,
      FoodNutrient.protein: 10,
      FoodNutrient.carbohydrates: net == 0 ? 3 : 20,
      FoodNutrient.fat: 3,
      FoodNutrient.fiber: 3,
      FoodNutrient.sugar: 0,
      FoodNutrient.sodium: 0,
      FoodNutrient.vitaminA: 7,
    }, netCarbohydrates: net),
  );
  await MealRepository(db).addGeminiVisionMealAtomically(
    date: day,
    mealType: 'lunch',
    ownerId: owner,
    requestId: 'net-photo',
    items: [
      ReviewedGeminiVisionEstimate(estimate: estimate, amount: 100, unit: 'g'),
    ],
    isCurrentOwner: () => true,
  );
}

/// Compatible with the applied client/evidence stage, before this consumer
/// amendment. It deliberately references no new closed-snapshot/column API.
void main() {
  for (final net in <double?>[null, 16.9, 0]) {
    test(
      'real daily display/ledger/Coach retain provided nullable Gemini net $net',
      () async {
        final db = AppDatabase.forTesting(
          NativeDatabase.memory(),
          localOwnerId: owner,
        );
        try {
          await seedGemini(db, net);
          final rows = await db.select(db.mealItems).get();
          expect(DailyLogNutritionEvidence.forItems(rows).netCarbs, net);
          expect(
            (await DailyLogRepository(db).readLedger(day)).netCarbohydrates,
            net,
          );
          final reader = CoachMessageNutritionReader(
            db,
            clock: () => DateTime.utc(2026, 11, 18),
          );
          for (final visual in [
            (await reader.readMeals(
              CoachMealReadRequest([CoachMealReadColumnRequest(day, 'lunch')]),
              checkAccess: () {},
            ))!,
            await reader.readDay(day, checkAccess: () {}),
          ]) {
            final metric = visual.columns.single.metrics.singleWhere(
              (m) => m.id == 'netCarbohydrates',
            );
            expect(metric.completeValue, net);
            expect(
              visual.columns.single.sourceKinds,
              contains('gemini_photo_estimate'),
            );
            expect(
              visual.columns.single.metrics
                  .firstWhere((m) => m.id == 'calories')
                  .estimated,
              isTrue,
            );
          }
        } finally {
          await db.close();
        }
      },
    );
  }
}
