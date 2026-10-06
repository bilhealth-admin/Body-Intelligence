import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/database/nutrient_evidence.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/engine/one_best_action_engine.dart';
import 'package:body_intelligence_log/engine/nutrient_evidence_engine.dart';
import 'package:body_intelligence_log/features/dashboard/composition/dashboard_intelligence_input_adapter.dart';
import 'package:body_intelligence_log/features/dashboard/domain/dashboard_intelligence_composer.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_preferences_provider.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_provider.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_grid.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/premium_dashboard_benchmark.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/nutrition/domain/daily_nutrition_intelligence.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'dashboard_unknown_nutrition_widget_cases.dart';

final _today = DateTime(2026, 10, 6, 12);
const _targets = DailyNutritionTargets(
  calories: 2100,
  protein: 140,
  carbohydrates: 250,
  fat: 70,
  fiber: 30,
  sodium: 2300,
  potassium: 3500,
  waterMl: 2500,
);

class _NutritionFixture {
  _NutritionFixture()
    : database = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'nutrition-owner',
      ) {
    meals = MealRepository(database);
  }

  final AppDatabase database;
  late final MealRepository meals;

  Future<void> seedProfile() async {
    await UserProfileRepository(database).save(
      gender: 'male',
      age: 35,
      height: 181,
      currentWeight: 87,
      targetWeight: 82,
      activityLevel: 'light',
      exercises: true,
    );
    await WeightRepository(database).addWeight(87, date: _today);
  }

  Future<CoachMealCommit> quick({
    required String operation,
    double? calories,
    double? protein,
    double? carbohydrates,
    double? fat,
    String mealType = 'lunch',
  }) => meals.commitCoachMeal(
    command: CoachMealCommand.quickMacros(
      operationId: operation,
      date: _today,
      mealType: mealType,
      calories: calories,
      protein: protein,
      carbohydrates: carbohydrates,
      fat: fat,
    ),
    scope: CoachMealOwnerScope(
      ownerId: 'nutrition-owner',
      isCurrent: () => true,
    ),
  );

  Future<DashboardIntelligenceSnapshot> dashboard() async {
    final profile = (await UserProfileRepository(database).getProfile())!;
    final weights = await database.select(database.weightEntries).get();
    final recorded = await meals.watchMealsForDate(_today).first;
    return const DashboardIntelligenceComposer().compose(
      const DashboardIntelligenceInputAdapter().adapt(
        now: _today,
        profile: profile,
        weights: weights,
        todayMeals: recorded,
        todayWater: const [],
        allMeals: await meals.watchAll().first,
        allWater: const [],
        dailyLogs: const [],
        todayContexts: const [],
        allContexts: const [],
        memories: const [],
        skippedWeightToday: false,
        planSetting: null,
      ),
    );
  }

  Future<DailyNutritionReport> analyze() =>
      meals.analyzeDay(date: _today, waterMl: 2500, targets: _targets);

  Future<MealItem> label({required String source, int? mask}) async {
    final foodId = await FoodRepository(database).addFood(
      name: 'Saved label',
      category: 'grain',
      servingSize: 100,
      servingUnit: 'g',
      calories: 100,
      protein: 0,
      carbs: 25,
      fats: 0,
      source: source,
    );
    final mealId = await meals.createMeal(
      date: _today,
      name: 'breakfast',
      type: 'breakfast',
    );
    await meals.addMealItem(mealId: mealId, foodId: foodId, quantity: 100);
    final item = (await (database.select(
      database.mealItems,
    )..where((row) => row.mealId.equals(mealId))).get()).single;
    if (mask != null) {
      await (database.update(database.mealItems)
            ..where((row) => row.id.equals(item.id)))
          .write(MealItemsCompanion(nutrientEvidenceMask: Value(mask)));
    }
    return meals.getMealItem(item.id);
  }
}

void main() {
  late _NutritionFixture fixture;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fixture = _NutritionFixture();
    await fixture.seedProfile();
  });
  tearDown(() => fixture.database.close());

  _dashboardUnknownNutritionWidgetCases(() => fixture);

  test('1905 committed calories do not become zero Dashboard macros', () async {
    final commit = await fixture.quick(operation: 'calories', calories: 1905);
    final before = await fixture.database
        .select(fixture.database.mealItems)
        .get();
    final snapshot = await fixture.dashboard();

    expect(commit.after.single.toReceiptPayload()['protein'], isNull);
    expect(snapshot.calories, 1905);
    expect(snapshot.protein, isNull);
    expect(snapshot.fats, isNull);
    expect(snapshot.sodium, isNull);
    expect(snapshot.intelligence.score, isNull);
    expect(snapshot.bil.score, isNull);
    expect(snapshot.bestAction.type, isNot(BestActionType.protein));
    expect(snapshot.bestAction.type, BestActionType.hydration);
    expect(
      snapshot.bil.recommendations,
      isNot(contains('Add one banana or potato.')),
    );
    expect(
      snapshot.intelligence.insights.map((insight) => insight.title),
      isNot(contains('Protein below target')),
    );
    expect(
      await fixture.database.select(fixture.database.mealItems).get(),
      before,
      reason: 'Evidence composition must never rewrite the committed ledger.',
    );
  });

  test(
    'macro-only commit keeps Dashboard and historical calories unknown',
    () async {
      final commit = await fixture.quick(operation: 'protein', protein: 20);
      final snapshot = await fixture.dashboard();

      expect(commit.after.single.toReceiptPayload()['calories'], isNull);
      expect(snapshot.protein, 20);
      expect(snapshot.calories, isNull);
      expect(snapshot.fats, isNull);
      expect(snapshot.calorieByDay[DateTime(2026, 10, 6)], isNull);
      expect(snapshot.intelligence.score, isNull);
      expect(snapshot.bil.score, isNull);
    },
  );

  for (final knownFirst in [false, true]) {
    test(
      'mixed history stays unknown when known meal is ${knownFirst ? 'first' : 'last'}',
      () async {
        if (knownFirst) {
          await fixture.label(source: 'label');
        }
        await fixture.quick(operation: 'unknown-calories', protein: 20);
        if (!knownFirst) {
          await fixture.label(source: 'label');
        }
        final snapshot = await fixture.dashboard();
        expect(snapshot.calories, isNull);
        expect(snapshot.calorieByDay[DateTime(2026, 10, 6)], isNull);
      },
    );
  }

  test(
    'legacy source core zeros remain known without modern evidence bits',
    () async {
      final item = await fixture.label(source: 'local', mask: 0);
      expect(item.foodSourceSnapshot, 'local');
      final snapshot = await fixture.dashboard();
      final report = await fixture.analyze();

      expect(snapshot.calories, 100);
      expect(snapshot.protein, 0);
      expect(snapshot.fats, 0);
      expect(report.protein, 0);
      expect(report.fat, 0);
      expect(report.carbohydrateEnergyShare, 1);
    },
  );

  test(
    'modern explicitly known zero remains distinct from an omitted value',
    () async {
      final result = await fixture.quick(
        operation: 'known-zero',
        calories: 100,
        protein: 0,
        carbohydrates: 25,
        fat: 0,
      );
      expect(
        NutrientEvidenceMask.contains(
          result.after.single.item.nutrientEvidenceMask,
          TrackedNutrient.protein,
        ),
        isTrue,
      );
      final snapshot = await fixture.dashboard();
      final report = await fixture.analyze();
      expect(snapshot.protein, 0);
      expect(snapshot.fats, 0);
      expect(snapshot.intelligence.score, isNotNull);
      expect(report.protein, 0);
      expect(report.fatEnergyShare, 0);
    },
  );

  test(
    'repository day analysis abstains from unknown calorie and macro ratios',
    () async {
      await fixture.quick(operation: 'protein-analysis', protein: 20);
      final report = await fixture.analyze();

      expect(report.calories, isNull);
      expect(report.protein, 20);
      expect(report.carbohydrates, isNull);
      expect(report.fat, isNull);
      expect(report.proteinEnergyShare, isNull);
      expect(report.carbohydrateEnergyShare, isNull);
      expect(report.fatEnergyShare, isNull);
      expect(
        report.insights.map((insight) => insight.kind),
        isNot(contains(DailyNutritionInsightKind.caloriesBelowTarget)),
      );
    },
  );

  test(
    'repository day analysis never reports a fabricated protein deficit',
    () async {
      await fixture.quick(operation: 'calories-analysis', calories: 1905);
      final report = await fixture.analyze();

      expect(report.calories, 1905);
      expect(report.protein, isNull);
      expect(report.carbohydrates, isNull);
      expect(report.fat, isNull);
      expect(report.proteinEnergyShare, isNull);
      expect(
        report.insights.map((insight) => insight.kind),
        isNot(contains(DailyNutritionInsightKind.proteinBelowTarget)),
      );
    },
  );

  test(
    'partial core evidence exposes its subtotal only through the report',
    () async {
      await fixture.quick(operation: 'known-protein', protein: 20);
      await fixture.quick(operation: 'unknown-protein', calories: 500);
      final snapshot = await fixture.dashboard();
      final report = await fixture.analyze();
      final evidence = snapshot.nutrition.report(TrackedNutrient.protein);

      expect(evidence.state, NutrientEvidenceState.partial);
      expect(evidence.total, 20);
      expect(evidence.completeTotal, isNull);
      expect(snapshot.protein, isNull);
      expect(report.protein, isNull);
      expect(report.proteinEvidence.state, NutrientEvidenceState.partial);
      expect(report.proteinEvidence.total, 20);
      expect(report.proteinEnergyShare, isNull);
      expect(snapshot.bestAction.type, isNot(BestActionType.protein));
    },
  );

  test(
    'unmarked downloaded zero is unknown while nonzero legacy cores remain known',
    () async {
      await fixture.label(source: 'bil-mobile-catalog', mask: 0);
      final snapshot = await fixture.dashboard();
      final report = await fixture.analyze();
      expect(snapshot.calories, 100);
      expect(snapshot.carbohydrates, 25);
      expect(snapshot.protein, isNull);
      expect(snapshot.fats, isNull);
      expect(report.calories, 100);
      expect(report.protein, isNull);
      expect(report.fat, isNull);
      expect(report.carbohydrateEnergyShare, isNull);
    },
  );
}
