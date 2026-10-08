import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_scope.dart';
import 'package:body_intelligence_log/data/database/food_basis_evidence.dart';
import 'package:body_intelligence_log/data/database/meal_food_evidence.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/food_v2/coach_food_v2.dart';
import 'package:body_intelligence_log/features/intelligence_center/food_flow/coach_food_flow.dart';
import 'package:body_intelligence_log/features/recipe_import/domain/trusted_recipe.dart';
import 'package:body_intelligence_log/features/recipe_import/repositories/trusted_recipe_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  group('BIL-01 native Food host + Drift', () {
    test(
      'multi-food freezes review and retry replays without duplicates',
      () async {
        final f = _Fixture();
        addTearDown(f.close);
        await f.seedModern(
          'Rice',
          calories: 130,
          protein: 2.5,
          carbs: 28,
          fat: .3,
        );
        await f.seedModern(
          'Chicken',
          calories: 165,
          protein: 31,
          carbs: 0,
          fat: 3.6,
          sodium: 74,
          potassium: 256,
        );

        final result = await f.host.prepare(
          input: 'اكلت 100غ Rice و 200غ Chicken غداء اليوم',
          referenceLocal: DateTime(2026, 10, 7, 13, 15),
          localeTag: 'ar',
          ownerScope: f.foodScope(),
        );
        expect(result, isA<CoachFoodActionDraft>());
        final draft = result as CoachFoodActionDraft;
        expect(draft.kind, CoachFoodDraftKind.logFoods);
        expect(draft.mealType, 'lunch');
        expect(draft.review.items, hasLength(2));
        final command = _commandFromDraft(draft);
        final first = await f.meals.commitCoachMeal(
          command: command,
          scope: f.mealScope(),
        );
        final replay = await f.meals.commitCoachMeal(
          command: command,
          scope: f.mealScope(),
        );
        expect(first.after, hasLength(2));
        expect(replay.replayed, isTrue);
        expect(await f.activeItems(), hasLength(2));
        final payloads = first.after
            .map((row) => row.toReceiptPayload())
            .toList();
        expect(payloads[1]['sodium_mg'], 148);
        expect(payloads[1]['potassium_mg'], 512);
        expect(payloads[1]['vitamin_c_mg'], isNull);
      },
    );

    test(
      'only one useful clarification is returned for a missing amount',
      () async {
        final f = _Fixture();
        addTearDown(f.close);
        await f.seedModern(
          'Rice',
          calories: 130,
          protein: 2.5,
          carbs: 28,
          fat: .3,
        );
        final result = await f.host.prepare(
          input: 'اكلت Rice',
          referenceLocal: DateTime(2026, 10, 7, 12),
          localeTag: 'ar',
          ownerScope: f.foodScope(),
        );
        expect(result, isA<CoachFoodHostClarification>());
        final clarification = result as CoachFoodHostClarification;
        expect(clarification.code, 'quantity_missing');
        expect(clarification.message, contains('كم'));
      },
    );

    test('body weight is never interpreted as food grams', () async {
      final f = _Fixture();
      addTearDown(f.close);
      final result = await f.host.prepare(
        input: 'وزني اليوم 90 كيلو',
        referenceLocal: DateTime(2026, 10, 7, 9),
        localeTag: 'ar',
        ownerScope: f.foodScope(),
      );
      expect(result, isA<CoachFoodHostIgnored>());
    });

    test(
      'absolute correction, half, double and replacement target only one saved item',
      () async {
        final f = _Fixture();
        addTearDown(f.close);
        await f.seedModern(
          'Rice',
          calories: 130,
          protein: 2.5,
          carbs: 28,
          fat: .3,
        );
        await f.seedModern(
          'Chicken',
          calories: 165,
          protein: 31,
          carbs: 0,
          fat: 3.6,
        );
        final logged = await f.prepareAndCommit(
          'اكلت 100غ Rice و 200غ Chicken',
          DateTime(2026, 10, 7, 13),
        );
        final rice = logged.after.firstWhere((row) => row.foodName == 'Rice');
        final chicken = logged.after.firstWhere(
          (row) => row.foodName == 'Chicken',
        );

        final absolute =
            await f.host.prepare(
                  input: 'لا قصدي 80غ',
                  referenceLocal: DateTime(2026, 10, 7, 13, 1),
                  localeTag: 'ar',
                  ownerScope: f.foodScope(),
                  preferredTargetItemId: rice.item.id,
                )
                as CoachFoodActionDraft;
        final corrected = await f.commitDraft(absolute);
        expect(corrected.after.single.item.id, rice.item.id);
        expect(corrected.after.single.item.quantity, 80);
        expect((await f.meals.getMealItem(chicken.item.id)).quantity, 200);

        final half =
            await f.host.prepare(
                  input: 'نصها',
                  referenceLocal: DateTime(2026, 10, 7, 13, 2),
                  localeTag: 'ar',
                  ownerScope: f.foodScope(),
                  preferredTargetItemId: rice.item.id,
                )
                as CoachFoodActionDraft;
        final halved = await f.commitDraft(half);
        expect(halved.after.single.item.quantity, 40);

        final doubled =
            await f.host.prepare(
                  input: 'ضعفها',
                  referenceLocal: DateTime(2026, 10, 7, 13, 3),
                  localeTag: 'ar',
                  ownerScope: f.foodScope(),
                  preferredTargetItemId: rice.item.id,
                )
                as CoachFoodActionDraft;
        final doubledCommit = await f.commitDraft(doubled);
        expect(doubledCommit.after.single.item.quantity, 80);

        final replacement =
            await f.host.prepare(
                  input: 'بدل Rice ب 50غ Chicken',
                  referenceLocal: DateTime(2026, 10, 7, 13, 4),
                  localeTag: 'ar',
                  ownerScope: f.foodScope(),
                )
                as CoachFoodActionDraft;
        final replaced = await f.commitDraft(replacement);
        expect(replaced.after.single.item.id, rice.item.id);
        expect(replaced.after.single.item.uuid, rice.item.uuid);
        expect(replaced.after.single.foodName, 'Chicken');
        expect(replaced.after.single.item.quantity, 50);
        expect((await f.meals.getMealItem(chicken.item.id)).quantity, 200);
      },
    );

    test(
      'stale correction fails closed and never changes the newer item',
      () async {
        final f = _Fixture();
        addTearDown(f.close);
        await f.seedModern(
          'Rice',
          calories: 130,
          protein: 2.5,
          carbs: 28,
          fat: .3,
        );
        final logged = await f.prepareAndCommit(
          'اكلت 100غ Rice',
          DateTime(2026, 10, 7, 13),
        );
        final original = logged.after.single;
        final staleDraft =
            await f.host.prepare(
                  input: 'لا قصدي 80غ',
                  referenceLocal: DateTime(2026, 10, 7, 13, 1),
                  localeTag: 'ar',
                  ownerScope: f.foodScope(),
                  preferredTargetItemId: original.item.id,
                )
                as CoachFoodActionDraft;
        await f.meals.commitCoachMeal(
          command: CoachMealCommand.updateQuantity(
            operationId: 'newer-edit',
            expected: CoachMealItemVersion.fromItem(original.item),
            quantity: 90,
          ),
          scope: f.mealScope(),
        );
        await expectLater(
          f.commitDraft(staleDraft),
          throwsA(
            isA<CoachMealConflict>().having(
              (error) => error.reason,
              'reason',
              CoachMealConflictReason.staleItem,
            ),
          ),
        );
        expect((await f.meals.getMealItem(original.item.id)).quantity, 90);
      },
    );

    test(
      'correction follows the same UUID/revision after day+type move',
      () async {
        final f = _Fixture();
        addTearDown(f.close);
        await f.seedModern(
          'Rice',
          calories: 130,
          protein: 2.5,
          carbs: 28,
          fat: .3,
        );
        final logged = await f.prepareAndCommit(
          'اكلت 100غ Rice',
          DateTime(2026, 10, 7, 13),
        );
        final original = logged.after.single;
        final moved = await f.meals.commitCoachMeal(
          command: CoachMealCommand.moveItem(
            operationId: 'move-food',
            expected: CoachMealItemVersion.fromItem(original.item),
            mealType: 'dinner',
            date: DateTime(2026, 10, 8),
          ),
          scope: f.mealScope(),
        );
        expect(moved.after.single.item.id, original.item.id);
        expect(moved.after.single.item.uuid, original.item.uuid);
        expect(moved.after.single.meal.type, 'dinner');
        expect(moved.after.single.meal.dayKey, '2026-10-08');

        final draft =
            await f.host.prepare(
                  input: 'نصها',
                  referenceLocal: DateTime(2026, 10, 8, 20),
                  localeTag: 'ar',
                  ownerScope: f.foodScope(),
                  preferredTargetItemId: original.item.id,
                )
                as CoachFoodActionDraft;
        expect(draft.day, DateTime(2026, 10, 8));
        expect(draft.mealType, 'dinner');
        final changed = await f.commitDraft(draft);
        expect(changed.after.single.item.id, original.item.id);
        expect(changed.after.single.item.uuid, original.item.uuid);
        expect(changed.after.single.item.quantity, 50);
        expect(changed.after.single.meal.dayKey, '2026-10-08');
        expect(changed.after.single.meal.type, 'dinner');
      },
    );

    test(
      'like yesterday copies frozen historical snapshot, not changed catalog',
      () async {
        final f = _Fixture();
        addTearDown(f.close);
        final foodId = await f.seedModern(
          'Rice',
          calories: 130,
          protein: 2.5,
          carbs: 28,
          fat: .3,
        );
        final yesterday = await f.prepareAndCommit(
          'اكلت 120غ Rice غداء 2026-10-06',
          DateTime(2026, 10, 6, 13),
        );
        final frozen = MealFoodEvidence.read(
          yesterday.after.single.item,
          ownerKey: f.ownerKey,
        ).portion!;
        await (f.db.update(f.db.foods)..where((row) => row.id.equals(foodId)))
            .write(const FoodsCompanion(calories: Value(999)));

        final result =
            await f.host.prepare(
                  input: 'مثل امس غداء',
                  referenceLocal: DateTime(2026, 10, 7, 13),
                  localeTag: 'ar',
                  ownerScope: f.foodScope(),
                )
                as CoachFoodActionDraft;
        expect(result.day, DateTime(2026, 10, 7));
        expect(result.review.items.single.toJson(), frozen.toJson());
        final copied = await f.commitDraft(result);
        expect(
          copied.after.single.item.calories,
          yesterday.after.single.item.calories,
        );
        expect(
          copied.after.single.item.uuid,
          isNot(yesterday.after.single.item.uuid),
        );
      },
    );

    test(
      'explicit date wins over yesterday and meal type is inferred from local clock',
      () {
        const parser = CoachFoodTurnParser();
        final explicit = parser.parse(
          'اكلت 100غ Rice امس 2026-10-05',
          referenceLocal: DateTime(2026, 10, 7, 20),
        );
        expect(explicit.date, DateTime(2026, 10, 5));
        expect(explicit.mealType, isNull);
        expect(
          CoachFoodTurnParser.inferMealType(DateTime(2026, 10, 7, 8)),
          'breakfast',
        );
        expect(
          CoachFoodTurnParser.inferMealType(DateTime(2026, 10, 7, 13)),
          'lunch',
        );
        expect(
          CoachFoodTurnParser.inferMealType(DateTime(2026, 10, 7, 19)),
          'dinner',
        );
        expect(
          CoachFoodTurnParser.inferMealType(DateTime(2026, 10, 7, 23)),
          'snack',
        );
        final yesterday = parser.parse(
          'اكلت 100غ Rice امس',
          referenceLocal: DateTime(2026, 4, 24, 0, 30),
        );
        expect(yesterday.date, DateTime(2026, 4, 23));
      },
    );

    test(
      'today/yesterday preserve the supplied local civil clock across DST',
      () {
        tz_data.initializeTimeZones();
        final newYork = tz.getLocation('America/New_York');
        final lateFallbackDay = tz.TZDateTime(newYork, 2026, 11, 1, 23, 30);
        const parser = CoachFoodTurnParser();
        final today = parser.parse(
          'اكلت 100غ Rice اليوم',
          referenceLocal: lateFallbackDay,
        );
        final yesterday = parser.parse(
          'اكلت 100غ Rice امس',
          referenceLocal: lateFallbackDay,
        );
        expect(today.date, DateTime(2026, 11, 1));
        expect(yesterday.date, DateTime(2026, 10, 31));
        expect(CoachFoodTurnParser.inferMealType(lateFallbackDay), 'snack');
      },
    );

    test(
      'calorie-only Food V2 stays calorie-only after log/readback',
      () async {
        final f = _Fixture();
        addTearDown(f.close);
        await f.seedModern(
          'Calorie only',
          calories: 190,
          protein: null,
          carbs: null,
          fat: null,
        );
        final commit = await f.prepareAndCommit(
          'اكلت 100غ Calorie only',
          DateTime(2026, 10, 7, 12),
        );
        final payload = commit.after.single.toReceiptPayload();
        expect(payload['calories'], 190);
        expect(payload['protein'], isNull);
        expect(payload['carbohydrates'], isNull);
        expect(payload['fat'], isNull);
      },
    );

    test(
      'Personal BIL fixed product is owner scoped, revisioned and old log is frozen',
      () async {
        final f = _Fixture();
        addTearDown(f.close);
        await f.seedModern(
          'Egg',
          calories: 140,
          protein: 12,
          carbs: 1,
          fat: 10,
        );
        final approved1 =
            await f.host.prepare(
                  input: 'اعتمد Egg 50غ',
                  referenceLocal: DateTime(2026, 10, 7, 9),
                  localeTag: 'ar',
                  ownerScope: f.foodScope(),
                )
                as CoachFoodPersonalRuleSaved;
        expect(approved1.rule.revision, 1);
        final firstLog = await f.prepareAndCommit(
          'اكلت 1 Egg',
          DateTime(2026, 10, 7, 9, 5),
        );
        expect(firstLog.after.single.item.quantity, 50);
        final firstEvidence = MealFoodEvidence.read(
          firstLog.after.single.item,
          ownerKey: f.ownerKey,
        ).portion!;
        expect(firstEvidence.food.source.kind, CoachFoodSourceKind.userFixed);
        expect(firstEvidence.food.source.revision, 'r1');

        final approved2 =
            await f.host.prepare(
                  input: 'اعتمد Egg 55غ',
                  referenceLocal: DateTime(2026, 10, 7, 10),
                  localeTag: 'ar',
                  ownerScope: f.foodScope(),
                )
                as CoachFoodPersonalRuleSaved;
        expect(approved2.rule.revision, 2);
        final secondLog = await f.prepareAndCommit(
          'اكلت 1 Egg',
          DateTime(2026, 10, 7, 10, 5),
        );
        expect(secondLog.after.single.item.quantity, 55);
        expect(
          MealFoodEvidence.read(
            firstLog.after.single.item,
            ownerKey: f.ownerKey,
          ).portion!.toJson(),
          firstEvidence.toJson(),
        );

        final other = _Fixture(ownerId: 'other-owner');
        addTearDown(other.close);
        await other.seedModern(
          'Egg',
          calories: 140,
          protein: 12,
          carbs: 1,
          fat: 10,
        );
        final unresolved = await other.host.prepare(
          input: 'اكلت 1 Egg',
          referenceLocal: DateTime(2026, 10, 7, 10),
          localeTag: 'ar',
          ownerScope: other.foodScope(),
        );
        expect(unresolved, isA<CoachFoodHostClarification>());
        expect(
          (unresolved as CoachFoodHostClarification).code,
          'quantity_unit_missing',
        );
      },
    );

    test(
      'Personal BIL fixed volume conversion is explicit, revisioned and frozen',
      () async {
        final f = _Fixture();
        addTearDown(f.close);
        await f.seedModern(
          'Fixture milk',
          calories: 45,
          protein: 3.2,
          carbs: 4.8,
          fat: 1.5,
        );
        final approved =
            await f.host.prepare(
                  input: 'اعتمد Fixture milk 200ml = 206غ',
                  referenceLocal: DateTime(2026, 10, 7, 9),
                  localeTag: 'ar',
                  ownerScope: f.foodScope(),
                )
                as CoachFoodPersonalRuleSaved;
        expect(approved.rule.inputUnit, 'ml');
        expect(approved.rule.gramsPerUnit, closeTo(1.03, 1e-9));
        expect(approved.rule.revision, 1);

        final logged = await f.prepareAndCommit(
          'اكلت 200ml Fixture milk',
          DateTime(2026, 10, 7, 9, 5),
        );
        expect(logged.after.single.item.quantity, closeTo(206, 1e-9));
        final frozen = MealFoodEvidence.read(
          logged.after.single.item,
          ownerKey: f.ownerKey,
        ).portion!;
        expect(frozen.quantity.grams, closeTo(206, 1e-9));
        expect(frozen.food.source.kind, CoachFoodSourceKind.userFixed);
        expect(frozen.food.source.revision, 'r1');
      },
    );

    test(
      'Personal BIL recipe rule freezes reviewed serving snapshot and revision',
      () async {
        final f = _Fixture();
        addTearDown(f.close);
        final recipes = TrustedRecipeRepository(PreferencesRepository(f.db));
        final saved = await recipes.saveReviewed(
          _recipe(calories: 420, protein: 28),
        );
        final approved =
            await f.host.prepare(
                  input: 'اعتمد وصفة Verified bowl الحصة 250غ',
                  referenceLocal: DateTime(2026, 10, 7, 11),
                  localeTag: 'ar',
                  ownerScope: f.foodScope(),
                )
                as CoachFoodPersonalRecipeRuleSaved;
        expect(approved.rule.revision, 1);
        expect(
          approved.rule.savedRecipe.recipe.fingerprint,
          saved.recipe.fingerprint,
        );
        expect(
          approved.rule.portion.food.source.kind,
          CoachFoodSourceKind.calculatedRecipe,
        );
        expect(approved.rule.portion.quantity.grams, 250);
        expect(
          approved.rule.portion.food.nutrients[FoodNutrient.sodium],
          isNull,
        );

        final first = await f.prepareAndCommit(
          'اكلت 1 حصة Verified bowl',
          DateTime(2026, 10, 7, 12),
        );
        expect(first.after.single.item.calories, 420);
        expect(first.after.single.item.protein, 28);
        expect(first.after.single.toReceiptPayload()['sodium_mg'], isNull);

        await recipes.replaceReviewed(
          saved.id,
          _recipe(calories: 999, protein: 1),
        );
        final second = await f.prepareAndCommit(
          'اكلت 1 حصة Verified bowl',
          DateTime(2026, 10, 7, 12, 5),
        );
        expect(second.after.single.item.calories, 420);
        expect(second.after.single.item.protein, 28);
        final evidence = MealFoodEvidence.read(
          second.after.single.item,
          ownerKey: f.ownerKey,
        ).portion!;
        expect(evidence.food.digest, approved.rule.portion.food.digest);
      },
    );

    test(
      'owner ABA cancels permanently once a different owner is observed',
      () {
        final a0 = CoachFoodOwnerStamp(ownerKey: 'owner-a', epoch: 0);
        var current = a0;
        final scope = CoachFoodOwnerScope(
          captured: a0,
          readCurrent: () => current,
        );
        scope.check();
        current = CoachFoodOwnerStamp(ownerKey: 'owner-b', epoch: 1);
        expect(() => scope.check(), throwsA(isA<CoachFoodContractError>()));
        current = CoachFoodOwnerStamp(ownerKey: 'owner-a', epoch: 2);
        expect(
          () => scope.check(),
          throwsA(
            isA<CoachFoodContractError>().having(
              (error) => error.code,
              'code',
              'owner_changed',
            ),
          ),
        );
      },
    );
  });
}

final class _Fixture {
  _Fixture({String ownerId = 'food-owner'})
    : db = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: ownerId,
      );

  final AppDatabase db;
  late final MealRepository meals = MealRepository(db);
  late final FoodRepository foods = FoodRepository(db);
  late final PreferencesRepository preferences = PreferencesRepository(db);
  late final CoachFoodHost host = CoachFoodHost(
    foods: foods,
    meals: meals,
    preferences: preferences,
  );

  String get ownerKey => LocalDatabaseScope.keyForOwner(db.localOwnerId);

  CoachFoodOwnerScope foodScope() {
    final stamp = CoachFoodOwnerStamp(ownerKey: ownerKey, epoch: 0);
    return CoachFoodOwnerScope(captured: stamp, readCurrent: () => stamp);
  }

  CoachMealOwnerScope mealScope() =>
      CoachMealOwnerScope(ownerId: db.localOwnerId, isCurrent: () => true);

  Future<int> seedModern(
    String name, {
    required double? calories,
    required double? protein,
    required double? carbs,
    required double? fat,
    double? sodium,
    double? potassium,
  }) async {
    final snapshot = CoachFoodSnapshot(
      identity: 'fixture:${normalizeFoodConcept(name)}',
      name: name,
      preparedState: 'as-recorded',
      basisGrams: 100,
      nutrients: CoachFoodNutrients({
        FoodNutrient.calories: calories,
        FoodNutrient.protein: protein,
        FoodNutrient.carbohydrates: carbs,
        FoodNutrient.fat: fat,
        FoodNutrient.fiber: null,
        FoodNutrient.sugar: null,
        FoodNutrient.sodium: sodium,
        FoodNutrient.potassium: potassium,
        FoodNutrient.calcium: null,
        FoodNutrient.magnesium: null,
        FoodNutrient.phosphorus: null,
        FoodNutrient.iron: null,
        FoodNutrient.vitaminC: null,
      }),
      source: CoachFoodSourceEvidence(
        kind: CoachFoodSourceKind.label,
        ref: 'synthetic-label:$name',
        revision: 'fixture-v1',
      ),
    );
    final id = await foods.addFood(
      name: name,
      category: 'fixture',
      servingSize: 100,
      servingUnit: 'g',
      calories: calories ?? 0,
      protein: protein ?? 0,
      carbs: carbs ?? 0,
      fats: fat ?? 0,
      sodium: sodium,
      potassium: potassium,
      source: FoodBasisEvidence.sourceLabel(snapshot),
      verified: false,
      caloriesKnown: calories != null,
      proteinKnown: protein != null,
      carbsKnown: carbs != null,
      fatsKnown: fat != null,
    );
    await (db.update(db.foods)..where((row) => row.id.equals(id))).write(
      FoodsCompanion(
        category: const Value('coach_snapshot'),
        servingSize: const Value(100),
        servingUnit: const Value('g'),
        calories: Value(calories ?? 0),
        protein: Value(protein ?? 0),
        carbs: Value(carbs ?? 0),
        fats: Value(fat ?? 0),
        sodium: Value(sodium ?? 0),
        potassium: Value(potassium ?? 0),
        source: Value(FoodBasisEvidence.sourceLabel(snapshot)),
        verified: const Value(false),
        nutrientEvidenceMask: Value(FoodBasisEvidence.mask(snapshot)),
        foodEvidenceJson: Value(FoodBasisEvidence.encode(snapshot)),
      ),
    );
    return id;
  }

  Future<CoachMealCommit> prepareAndCommit(String input, DateTime now) async {
    final result = await host.prepare(
      input: input,
      referenceLocal: now,
      localeTag: 'ar',
      ownerScope: foodScope(),
    );
    if (result is! CoachFoodActionDraft) {
      throw StateError('Expected draft, got ${result.runtimeType}');
    }
    return commitDraft(result);
  }

  Future<CoachMealCommit> commitDraft(CoachFoodActionDraft draft) => meals
      .commitCoachMeal(command: _commandFromDraft(draft), scope: mealScope());

  Future<List<MealItem>> activeItems() =>
      (db.select(db.mealItems)..where((row) => row.deletedAt.isNull())).get();

  Future<void> close() => db.close();
}

CoachMealCommand _commandFromDraft(CoachFoodActionDraft draft) {
  switch (draft.kind) {
    case CoachFoodDraftKind.logFoods:
      return CoachMealCommand.foods(
        operationId: draft.operationId,
        date: draft.day,
        mealType: draft.mealType,
        review: draft.review,
        occurredAt: DateTime.parse(draft.payload['occurredAt']! as String),
      );
    case CoachFoodDraftKind.replaceMealItem:
      final expected = Map<String, Object?>.from(
        draft.payload['expected']! as Map,
      );
      return CoachMealCommand.replaceFood(
        operationId: draft.operationId,
        expected: CoachMealItemVersion(
          id: expected['id']! as int,
          uuid: expected['uuid']! as String,
          revision: expected['revision']! as int,
        ),
        replacement: CoachFoodPortion.fromJson(draft.payload['replacement']),
      );
  }
}

TrustedRecipeDraft _recipe({
  required double calories,
  required double protein,
}) => TrustedRecipeDraft(
  name: 'Verified bowl',
  servings: 2,
  prepMinutes: 5,
  cookMinutes: 10,
  ingredients: const [
    TrustedRecipeIngredient(
      name: 'Synthetic beans',
      quantity: 100,
      unit: 'g',
      sourceRecordId: 'usda:1',
    ),
  ],
  steps: const ['Cook and serve.'],
  sourceUrl: null,
  nutrition: TrustedRecipeNutrition(
    caloriesKcal: calories,
    proteinG: protein,
    carbohydrateG: 50,
    fatG: 12,
    provenance: RecipeNutritionProvenance(
      source: 'synthetic-test-reference',
      recordId: 'fixture-1',
      verifiedAt: DateTime.utc(2026, 10, 1),
    ),
  ),
);
