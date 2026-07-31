import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/decision_memory_repository.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/data/repositories/water_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/engine/one_best_action_engine.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/bil_intelligence_integration.dart';
import 'package:body_intelligence_log/features/ai_platform/services/local_intelligence_composition_root.dart';
import 'package:body_intelligence_log/features/ai_platform/services/local_intelligence_reality_runtime.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'database to canonical Reality Runtime produces 7 and 14 day product forecast',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await _seedProfile(database);

      final weights = WeightRepository(database);
      final water = WaterRepository(database);
      final logs = DailyLogRepository(database);
      final foods = FoodRepository(database);
      final meals = MealRepository(database);
      final foodId = await foods.addFood(
        name: 'Reality fixture meal',
        category: 'test',
        calories: 1900,
        protein: 145,
        carbs: 180,
        fats: 65,
        sodium: 2100,
        potassium: 3200,
        servingSize: 100,
      );

      final start = DateTime.utc(2026, 6, 15);
      for (var index = 0; index < 36; index++) {
        final day = start.add(Duration(days: index));
        if (index % 3 == 0) {
          await weights.addWeight(97 - (index * 0.045), date: day);
        }
        await water.add(
          occurredAt: day.add(const Duration(hours: 12)),
          amountMl: 2300,
        );
        await logs.save(
          date: day,
          sleepHours: index.isEven ? 7.5 : 6.8,
          steps: 7000 + (index * 50),
          exerciseNotes: index % 3 == 0 ? 'resistance training' : null,
        );
        final mealId = await meals.createMeal(
          date: day.add(const Duration(hours: 13)),
          name: 'Complete daily intake',
          type: 'lunch',
        );
        await meals.addMealItem(mealId: mealId, foodId: foodId, quantity: 100);
      }
      await _seedDecisionMemory(database);

      final runtime = const BilLocalIntelligenceCompositionRoot().create(
        database: database,
      );
      expect(runtime, isA<BilLocalIntelligenceRealityRuntime>());

      final output = await runtime.run(asOf: DateTime.utc(2026, 7, 20));

      expect(output.forecast.map((point) => point.days), [7, 14]);
      expect(output.adaptiveTdeeKcal, greaterThan(0));
      expect(output.plateauRisk, inInclusiveRange(0, 1));
      expect(output.brainResult.decisionTrace, isNotEmpty);
      expect(output.primaryMessage, isNotEmpty);
      expect(
        output.brainResult.signals.map((signal) => signal.source),
        containsAll(<BilIntegrationSource>[
          BilIntegrationSource.decisionMemory,
          BilIntegrationSource.adaptiveForecast,
          BilIntegrationSource.safety,
          BilIntegrationSource.oneBestAction,
        ]),
      );
      expect(
        output.brainResult.signals
            .singleWhere(
              (signal) => signal.source == BilIntegrationSource.decisionMemory,
            )
            .evidenceIds,
        isNotEmpty,
      );
    },
  );

  test(
    'canonical Reality Runtime safely abstains and leaves forecast empty without energy evidence',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await _seedProfile(database);

      final weights = WeightRepository(database);
      final water = WaterRepository(database);
      final start = DateTime.utc(2026, 6, 15);
      for (var index = 0; index < 21; index++) {
        final day = start.add(Duration(days: index));
        if (index % 3 == 0) {
          await weights.addWeight(97 - (index * 0.03), date: day);
        }
        await water.add(
          occurredAt: day.add(const Duration(hours: 12)),
          amountMl: 2200,
        );
      }
      await _seedDecisionMemory(database);

      final output = await const BilLocalIntelligenceCompositionRoot()
          .create(database: database)
          .run(asOf: DateTime.utc(2026, 7, 5));

      expect(output.forecast, isEmpty);
      expect(output.canPresent, isFalse);
      final forecastSignal = output.brainResult.signals.singleWhere(
        (signal) => signal.source == BilIntegrationSource.adaptiveForecast,
      );
      expect(forecastSignal.accepted, isFalse);
      expect(output.brainResult.selectedAction, isNull);
      expect(
        output.brainResult.signals.map((signal) => signal.source),
        containsAll(<BilIntegrationSource>[
          BilIntegrationSource.decisionMemory,
          BilIntegrationSource.safety,
          BilIntegrationSource.oneBestAction,
        ]),
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

Future<void> _seedDecisionMemory(AppDatabase database) async {
  final memories = DecisionMemoryRepository(database);
  final memoryId = await memories.rememberAction(
    const BestAction(
      type: BestActionType.hydration,
      title: 'Stabilize hydration',
      reason: 'Hydration evidence was incomplete.',
      evidence: ['local-water'],
    ),
    date: DateTime.utc(2026, 7, 10),
  );
  await memories.respond(memoryId, 'done');
}
