import 'dart:convert';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_scope.dart';
import 'package:body_intelligence_log/data/database/meal_food_evidence.dart';
import 'package:body_intelligence_log/data/database/nutrient_evidence.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/first_meal_milestone.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/features/dashboard/composition/dashboard_intelligence_input_adapter.dart';
import 'package:body_intelligence_log/features/dashboard/domain/dashboard_intelligence_composer.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/food_v2/coach_food_v2.dart';
import 'package:body_intelligence_log/features/nutrition/domain/meal_template.dart';
import 'package:body_intelligence_log/features/nutrition/domain/meal_builder.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

part 'coach_food_journal_cases.dart';
part 'coach_food_evidence_cases.dart';
part 'coach_food_template_cases.dart';
part 'coach_food_reselection_cases.dart';

final _foodDate = DateTime(2026, 10, 6, 12);

CoachFoodPortion _portion({
  String name = 'Synthetic label food',
  double grams = 150,
  Map<FoodNutrient, double?>? nutrients,
  String? fixedOwner,
}) => CoachFoodPortion(
  food: CoachFoodSnapshot(
    identity: 'fixture:$name',
    name: name,
    preparedState: 'ready',
    basisGrams: 100,
    nutrients: CoachFoodNutrients(
      nutrients ??
          {
            FoodNutrient.calories: 160,
            FoodNutrient.protein: 12,
            FoodNutrient.carbohydrates: 18,
            FoodNutrient.fat: 5,
            FoodNutrient.fiber: 3,
            FoodNutrient.sugar: 4,
            FoodNutrient.sodium: 120,
            FoodNutrient.potassium: 180,
            FoodNutrient.calcium: 40,
            FoodNutrient.magnesium: 25,
            FoodNutrient.phosphorus: 50,
            FoodNutrient.iron: 2,
            FoodNutrient.vitaminC: null,
          },
    ),
    source: CoachFoodSourceEvidence(
      kind: fixedOwner == null
          ? CoachFoodSourceKind.label
          : CoachFoodSourceKind.userFixed,
      ref: 'synthetic-label:$name',
      revision: 'fixture-revision-1',
      ownerKey: fixedOwner,
      confidence: CoachFoodConfidence(
        score: .9,
        basis: 'Synthetic source assertion',
      ),
    ),
  ),
  quantity: CoachFoodQuantity(
    grams: grams,
    evidence: CoachFoodQuantityEvidence(
      kind: CoachFoodQuantityKind.userDeclared,
      description: 'Reported grams in this test',
      confidence: CoachFoodConfidence(score: .8, basis: 'Reported mass'),
    ),
  ),
  identityConfidence: CoachFoodConfidence(
    score: .7,
    basis: 'Synthetic identity match',
  ),
);

class _FoodFixture {
  _FoodFixture()
    : db = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'food-owner',
      );
  final AppDatabase db;
  MealRepository get meals => MealRepository(db);
  CoachMealOwnerScope scope() =>
      CoachMealOwnerScope(ownerId: 'food-owner', isCurrent: () => true);
  CoachMealCommand command(String operation, List<CoachFoodPortion> portions) =>
      CoachMealCommand.foods(
        operationId: operation,
        date: _foodDate,
        mealType: 'lunch',
        review: CoachFoodReview(portions),
      );
  Future<CoachMealCommit> commit(
    String operation,
    List<CoachFoodPortion> portions,
  ) => meals.commitCoachMeal(
    command: command(operation, portions),
    scope: scope(),
  );
  Future<List<MealItem>> active() =>
      (db.select(db.mealItems)..where((row) => row.deletedAt.isNull())).get();
  Future<CoachMealCommit> undo(CoachMealCommit result) => meals.undoCoachMeal(
    operationId: result.operationId,
    toolId: result.toolId,
    argumentsDigest: result.argumentsDigest,
    scope: scope(),
  );
  Future<DashboardIntelligenceSnapshot> dashboard() async {
    await UserProfileRepository(db).save(
      gender: 'male',
      age: 35,
      height: 180,
      currentWeight: 85,
      targetWeight: 80,
      activityLevel: 'light',
      exercises: true,
    );
    final profile = (await UserProfileRepository(db).getProfile())!;
    final recorded = await meals.watchMealsForDate(_foodDate).first;
    return const DashboardIntelligenceComposer().compose(
      const DashboardIntelligenceInputAdapter().adapt(
        now: _foodDate,
        profile: profile,
        weights: const [],
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
}

_FoodFixture _fixture() {
  final fixture = _FoodFixture();
  addTearDown(fixture.db.close);
  return fixture;
}

Matcher _conflict(CoachMealConflictReason reason) => throwsA(
  isA<CoachMealConflict>().having((error) => error.reason, 'reason', reason),
);

Future<void> _expectSavedFoodJournalAndMilestone(
  _FoodFixture fixture,
  String operationId,
) async {
  final entries = await fixture.db.select(fixture.db.preferences).get();
  final owner = LocalDatabaseScope.keyForOwner(fixture.db.localOwnerId);
  expect(entries.map((entry) => entry.key).toSet(), {
    'coachMealOperationV1.$owner.$operationId',
    firstMealCelebrationPreferenceKey,
  });
  final milestone = entries.singleWhere(
    (entry) => entry.key == firstMealCelebrationPreferenceKey,
  );
  expect(milestone.value, 'ready');
}

void main() {
  group('Food committed storage', _foodEvidenceCases);
  group('Food operation journal', _foodJournalCases);
  group('Food templates', _foodTemplateCases);
  group('Food reselection', _foodReselectionCases);

  test(
    'four foods commit complete immutable evidence and replay after repository recreation',
    () async {
      final f = _fixture();
      final reviewed = [
        for (var i = 1; i <= 4; i++) _portion(name: 'Food $i', grams: i * 50),
      ];
      final result = await f.commit('four-foods', reviewed);
      expect(result.after, hasLength(4));
      expect(await f.active(), hasLength(4));
      for (var i = 0; i < 4; i++) {
        final saved = result.after[i];
        final evidence = MealFoodEvidence.read(saved.item);
        expect(evidence.portion!.toJson(), reviewed[i].toJson());
        expect(evidence.fullValue(FoodNutrient.iron), i + 1);
        expect(evidence.fullValue(FoodNutrient.vitaminC), isNull);
        final receipt = saved.toReceiptPayload();
        expect(receipt['iron_mg'], i + 1);
        expect(receipt['vitamin_c_mg'], isNull);
        expect(receipt['food_evidence'], reviewed[i].toJson());
        expect(receipt['source_verified'], false);
        final serialized = jsonDecode(saved.item.foodEvidenceJson!) as Map;
        expect(
          ((serialized['portion'] as Map)['food'] as Map)['nutrients'],
          hasLength(13),
        );
      }
      final replay = await MealRepository(f.db).commitCoachMeal(
        command: f.command('four-foods', reviewed),
        scope: f.scope(),
      );
      expect(replay.replayed, true);
      expect(
        replay.after.map((row) => row.item.uuid),
        result.after.map((row) => row.item.uuid),
      );
      expect(await f.active(), hasLength(4));
      expect(await f.db.select(f.db.foods).get(), hasLength(4));
      await _expectSavedFoodJournalAndMilestone(f, 'four-foods');
    },
  );

  test(
    'quantity uses original thirteen-nutrient basis after catalog changes',
    () async {
      final f = _fixture();
      final first = (await f.commit('original', [_portion()])).after.single;
      await (f.db.update(
        f.db.foods,
      )..where((row) => row.id.equals(first.item.foodId))).write(
        const FoodsCompanion(
          name: Value('Later catalog name'),
          calories: Value(900),
          iron: Value(99),
          vitaminC: Value(99),
        ),
      );
      final corrected = await f.meals.commitCoachMeal(
        command: CoachMealCommand.updateQuantity(
          operationId: 'half',
          expected: CoachMealItemVersion.fromItem(first.item),
          quantity: 75,
        ),
        scope: f.scope(),
      );
      final saved = corrected.after.single;
      expect(saved.item.id, first.item.id);
      expect(saved.item.uuid, first.item.uuid);
      expect(saved.item.revision, first.item.revision + 1);
      expect(saved.foodName, 'Synthetic label food');
      expect(saved.item.calories, 120);
      expect(saved.toReceiptPayload()['iron_mg'], 1.5);
      expect(saved.toReceiptPayload()['vitamin_c_mg'], isNull);
      final evidence = MealFoodEvidence.read(saved.item).portion!;
      expect(evidence.food.toJson(), _portion().food.toJson());
      expect(evidence.quantity.evidence.confidence, isNull);
      expect(evidence.identityConfidence!.score, .7);
      final restored = await f.undo(corrected);
      expect(
        restored.current.single!.item.foodEvidenceJson,
        first.item.foodEvidenceJson,
      );
      expect(restored.current.single!.item.quantity, 150);
    },
  );

  test(
    'replacement changes the existing entry and Undo restores full prior evidence',
    () async {
      final f = _fixture();
      final original = (await f.commit('original', [_portion()])).after.single;
      final replacement = _portion(
        name: 'Correct food',
        grams: 80,
        nutrients: {
          FoodNutrient.calories: 210,
          FoodNutrient.protein: 8,
          FoodNutrient.iron: 0,
        },
      );
      final changed = await f.meals.commitCoachMeal(
        command: CoachMealCommand.replaceFood(
          operationId: 'replace',
          expected: CoachMealItemVersion.fromItem(original.item),
          replacement: replacement,
        ),
        scope: f.scope(),
      );
      final row = changed.after.single;
      expect(await f.active(), hasLength(1));
      expect(row.item.id, original.item.id);
      expect(row.item.uuid, original.item.uuid);
      expect(row.foodName, 'Correct food');
      expect(row.toReceiptPayload()['calories'], 168);
      expect(row.toReceiptPayload()['fat'], isNull);
      expect(row.toReceiptPayload()['iron_mg'], 0);
      expect(row.item.revision, original.item.revision + 1);
      final undone = await f.undo(changed);
      expect(undone.current.single!.item.foodId, original.item.foodId);
      expect(
        undone.current.single!.item.foodEvidenceJson,
        original.item.foodEvidenceJson,
      );
      expect(undone.current.single!.item.revision, row.item.revision + 1);
      expect(await f.active(), hasLength(1));
    },
  );
}
