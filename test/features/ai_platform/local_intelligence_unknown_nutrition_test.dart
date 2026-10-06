import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_scope.dart';
import 'package:body_intelligence_log/data/database/meal_food_evidence.dart';
import 'package:body_intelligence_log/data/database/nutrient_evidence.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/data/repositories/water_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/features/ai_platform/adapters/local_intelligence_repository_adapter.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/local_intelligence_runtime.dart';
import 'package:body_intelligence_log/features/ai_platform/services/local_intelligence_composition_root.dart';
import 'package:body_intelligence_log/features/ai_platform/services/physiological_reality_model.dart';
import 'package:body_intelligence_log/features/ai_platform/services/product_intelligence_behavior_model.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/food_v2/coach_food_v2.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

part 'local_intelligence_unknown_nutrition_bridge_cases.dart';

final _start = DateTime.utc(2026, 8, 31);
final _asOf = DateTime.utc(2026, 10, 6, 18);

enum _DailyEvidence {
  calorieOnly,
  macroOnly,
  partialProtein,
  partialCalories,
  complete,
}

class _RuntimeNutritionFixture {
  _RuntimeNutritionFixture()
    : database = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'runtime-owner',
      ) {
    meals = MealRepository(database);
  }

  final AppDatabase database;
  late final MealRepository meals;

  Future<void> seed(_DailyEvidence evidence) async {
    await UserProfileRepository(database).save(
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
    final completeFood = await FoodRepository(database).addFood(
      name: 'Reviewed daily intake',
      category: 'test',
      calories: evidence == _DailyEvidence.partialProtein ? 100 : 1900,
      protein: evidence == _DailyEvidence.partialProtein ? 20 : 145,
      carbs: 180,
      fats: 65,
      sodium: 2100,
      potassium: 3200,
      servingSize: 100,
      servingUnit: 'g',
      source: 'label',
    );
    for (var index = 0; index < 36; index++) {
      final day = _start.add(Duration(days: index));
      if (index % 3 == 0) {
        await WeightRepository(
          database,
        ).addWeight(97 - index * .045, date: day);
      }
      await WaterRepository(
        database,
      ).add(occurredAt: day.add(const Duration(hours: 12)), amountMl: 2300);
      if (evidence == _DailyEvidence.complete ||
          evidence == _DailyEvidence.partialProtein ||
          evidence == _DailyEvidence.partialCalories) {
        final id = await meals.createMeal(
          date: day,
          name: 'lunch',
          type: 'lunch',
        );
        await meals.addMealItem(
          mealId: id,
          foodId: completeFood,
          quantity: 100,
        );
      }
      if (evidence != _DailyEvidence.complete) {
        final isCalories =
            evidence == _DailyEvidence.calorieOnly ||
            evidence == _DailyEvidence.partialProtein;
        await meals.commitCoachMeal(
          command: CoachMealCommand.quickMacros(
            operationId: 'intake-${evidence.name}-$index',
            date: day,
            mealType: 'dinner',
            calories: isCalories ? 1905 : null,
            protein: isCalories ? null : 20,
          ),
          scope: CoachMealOwnerScope(
            ownerId: 'runtime-owner',
            isCurrent: () => true,
          ),
        );
      }
    }
  }

  Future<LocalIntelligenceTimeline> timeline() =>
      LocalIntelligenceRepositoryAdapter(database).load(asOf: _asOf);

  Future<ProductIntelligenceOutput> runtime() =>
      const BilLocalIntelligenceCompositionRoot()
          .create(database: database)
          .run(asOf: _asOf);

  LocalDailyPhysiology firstRecorded(LocalIntelligenceTimeline timeline) =>
      timeline.days.singleWhere((day) => day.day == _start);
}

void main() {
  late _RuntimeNutritionFixture fixture;
  setUp(() => fixture = _RuntimeNutritionFixture());
  tearDown(() => fixture.database.close());

  _registerBridgeCases(() => fixture);

  test(
    'canonical database adapter preserves calorie-only unknown cores',
    () async {
      await fixture.seed(_DailyEvidence.calorieOnly);
      final before = await fixture.database
          .select(fixture.database.mealItems)
          .get();
      final timeline = await fixture.timeline();
      final day = fixture.firstRecorded(timeline);
      expect(day.caloriesKcal, 1905);
      expect(day.proteinG, isNull);
      expect(day.carbsG, isNull);
      expect(day.fatG, isNull);
      expect(day.sodiumMg, isNull);
      expect(day.potassiumMg, isNull);
      expect(
        await fixture.database.select(fixture.database.mealItems).get(),
        before,
      );
    },
  );

  test('canonical macro-only intake does not become zero calories', () async {
    await fixture.seed(_DailyEvidence.macroOnly);
    final timeline = await fixture.timeline();
    final day = fixture.firstRecorded(timeline);
    expect(day.proteinG, 20);
    expect(day.caloriesKcal, isNull);
    expect(day.carbsG, isNull);
    expect(day.fatG, isNull);
  });

  test(
    'calorie-only history cannot fabricate nutrient water-driver values',
    () async {
      await fixture.seed(_DailyEvidence.calorieOnly);
      final timeline = await fixture.timeline();
      final model = const PhysiologicalRealityModel();
      final result = model.analyze(
        timeline,
        tdeeKcal: model.adaptiveTdee(timeline),
      );
      expect(result.estimatedTissueChangeKg, isNotNull);
      expect(result.sodiumDriverKg, isNull);
      expect(result.potassiumDriverKg, isNull);
      expect(result.carbohydrateDriverKg, isNull);
      expect(result.waterAndGlycogenNoiseKg, isNull);
      expect(
        result.explanations,
        isNot(
          contains(
            'Sodium and potassium are modeled as opposing electrolyte water drivers.',
          ),
        ),
      );
    },
  );

  test(
    'macro-only history cannot fabricate energy-supported tissue change',
    () async {
      await fixture.seed(_DailyEvidence.macroOnly);
      final timeline = await fixture.timeline();
      final model = const PhysiologicalRealityModel();
      final result = model.analyze(
        timeline,
        tdeeKcal: model.adaptiveTdee(timeline),
      );
      expect(result.estimatedTissueChangeKg, isNull);
      expect(result.digestiveMassNoiseKg, isNull);
      final output = await fixture.runtime();
      expect(output.forecast, isEmpty);
      expect(output.brainResult.selectedAction, isNull);
      expect(output.plateauRisk, isNull);
    },
  );

  test(
    'partial protein cannot become a canonical protein-gap candidate',
    () async {
      await fixture.seed(_DailyEvidence.partialProtein);
      final timeline = await fixture.timeline();
      final model = const PhysiologicalRealityModel();
      final tdee = model.adaptiveTdee(timeline);
      final estimate = model.analyze(timeline, tdeeKcal: tdee);
      final candidates = const ProductIntelligenceBehaviorModel().candidates(
        timeline: timeline,
        estimate: estimate,
        adaptiveTdeeKcal: tdee,
        averageIntakeKcal: 2005,
        plateauRisk: .35,
      );
      expect(
        candidates.map((candidate) => candidate.id),
        isNot(contains('increase-protein')),
      );
      expect(fixture.firstRecorded(timeline).proteinG, isNull);
    },
  );

  test('partial calories cannot support a canonical energy forecast', () async {
    await fixture.seed(_DailyEvidence.partialCalories);
    final output = await fixture.runtime();
    expect(output.forecast, isEmpty);
    expect(output.brainResult.selectedAction, isNull);
    expect(output.noiseEstimate.estimatedTissueChangeKg, isNull);
    expect(output.plateauRisk, isNull);
  });

  test(
    'complete existing evidence still supports the original forecast',
    () async {
      await fixture.seed(_DailyEvidence.complete);
      final timeline = await fixture.timeline();
      final day = fixture.firstRecorded(timeline);
      expect(day.caloriesKcal, 1900);
      expect(day.proteinG, 145);
      expect(day.sodiumMg, 2100);
      final output = await fixture.runtime();
      expect(output.forecast.map((point) => point.days), [7, 14]);
      expect(output.adaptiveTdeeKcal, greaterThan(0));
      expect(output.noiseEstimate.sodiumDriverKg, 0);
      expect(output.noiseEstimate.potassiumDriverKg, 0);
    },
  );
}
