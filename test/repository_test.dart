import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/data/repositories/decision_memory_repository.dart';
import 'package:body_intelligence_log/data/repositories/experiment_repository.dart';
import 'package:body_intelligence_log/data/repositories/challenge_repository.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/plan_repository.dart';
import 'package:body_intelligence_log/data/repositories/life_context_repository.dart';
import 'package:body_intelligence_log/data/repositories/water_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/engine/one_best_action_engine.dart';
import 'package:body_intelligence_log/engine/daily_targets.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('daily repository keeps one record per local day', () async {
    final repository = DailyLogRepository(database);
    await repository.save(date: DateTime(2026, 7, 18, 8), notes: 'morning');
    await repository.save(date: DateTime(2026, 7, 18, 20), notes: 'evening');

    final rows = await repository.getAll();
    expect(rows, hasLength(1));
    expect(rows.single.notes, 'evening');
    expect(rows.single.dayKey, '2026-07-18');
  });

  test('personal experiments preserve cautious evidence states', () async {
    final repository = ExperimentRepository(database);
    final id = await repository.create(
      hypothesis: 'Protein breakfast may improve reported satiety',
      changedVariable: 'Breakfast protein',
      controlledFactors: 'Meal time',
      requiredData: 'Meal log and satiety note',
      startedAt: DateTime(2026, 7, 1),
      durationDays: 14,
    );
    await repository.complete(
      id: id,
      adherence: 75,
      result: 'Satiety notes were somewhat higher',
      limitations: 'Four days were missing',
      confidence: 'low',
    );
    final row = await database.select(database.personalExperiments).getSingle();
    expect(row.status, 'completed');
    expect(row.confidence, 'low');
    expect(row.limitations, isNotEmpty);
    expect(row.adherence, 75);
    expect(row.revision, 2);
    await repository.delete(id);
    final deleted = await database
        .select(database.personalExperiments)
        .getSingle();
    expect(deleted.revision, 3);
    expect(deleted.syncStatus, 'pendingDelete');
  });

  test(
    'private challenges persist and shared audiences fail honestly',
    () async {
      final repository = ChallengeRepository(database);
      final id = await repository.start(
        type: 'water',
        title: 'Hydration',
        targetDays: 14,
        startedAt: DateTime(2026, 7, 1),
      );
      final challenge = await database.select(database.challenges).getSingle();
      expect(challenge.audience, 'private');
      expect(challenge.endsAt, DateTime(2026, 7, 15));
      await repository.markComplete(id);
      await repository.delete(id);
      final deleted = await database.select(database.challenges).getSingle();
      expect(deleted.revision, 3);
      expect(deleted.syncStatus, 'pendingDelete');
      expect(
        () => repository.start(
          type: 'water',
          title: 'Friends hydration',
          targetDays: 14,
          audience: 'friends',
        ),
        throwsStateError,
      );
    },
  );

  test('meal items enforce references and cascade with their meal', () async {
    final foods = FoodRepository(database);
    final meals = MealRepository(database);
    final foodId = await foods.addFood(
      name: 'Oats',
      category: 'grain',
      calories: 389,
      protein: 16.9,
      carbs: 66.3,
      fats: 6.9,
    );
    final mealId = await meals.createMeal(
      date: DateTime(2026, 7, 18),
      name: 'Breakfast',
      type: 'breakfast',
    );
    await meals.addMealItem(
      mealId: mealId,
      foodId: foodId,
      quantity: 50,
      calories: 194.5,
      protein: 8.45,
      carbs: 33.15,
      fats: 3.45,
      fiber: 4.2,
      sodium: 120,
      potassium: 310,
      calcium: 45,
      magnesium: 80,
      sugar: 1.5,
    );

    final storedItem = await database.select(database.mealItems).getSingle();
    expect(storedItem.calcium, 45);
    expect(storedItem.magnesium, 80);
    expect(storedItem.sugar, 1.5);

    await meals.updateMealItem(
      id: storedItem.id,
      quantity: 60,
      calories: 233.4,
      protein: 10.14,
      carbs: 39.78,
      fats: 4.14,
    );
    await meals.deleteMealItem(storedItem.id);
    final deletedItem = await database.select(database.mealItems).getSingle();
    expect(deletedItem.revision, 3);
    expect(deletedItem.syncStatus, 'pendingDelete');

    await (database.delete(
      database.meals,
    )..where((row) => row.id.equals(mealId))).go();
    expect(await database.select(database.mealItems).get(), isEmpty);
  });

  test(
    'usual meals require repetition and copy only after confirmation',
    () async {
      final foods = FoodRepository(database);
      final meals = MealRepository(database);
      final foodId = await foods.addFood(
        name: 'Repeat oats',
        category: 'grain',
        calories: 380,
        protein: 15,
        carbs: 65,
        fats: 7,
      );
      for (final day in [1, 3]) {
        final mealId = await meals.createMeal(
          date: DateTime(2026, 7, day),
          name: 'Breakfast',
          type: 'breakfast',
        );
        await meals.addMealItem(
          mealId: mealId,
          foodId: foodId,
          quantity: 50,
          calories: 190,
          protein: 7.5,
          carbs: 32.5,
          fats: 3.5,
        );
      }

      final suggestions = await meals.usualMeals(
        type: 'breakfast',
        before: DateTime(2026, 7, 10),
      );
      expect(suggestions, hasLength(1));
      expect(suggestions.single.occurrences, 2);
      expect(await database.select(database.meals).get(), hasLength(2));

      await meals.repeatMeal(
        candidate: suggestions.single,
        date: DateTime(2026, 7, 10),
      );
      expect(await database.select(database.meals).get(), hasLength(3));
      expect(await database.select(database.mealItems).get(), hasLength(3));
    },
  );

  test('food search matches Arabic names and favorites are unique', () async {
    final foods = FoodRepository(database);
    final id = await foods.addFood(
      name: 'Lentils',
      arabicName: 'عدس',
      category: 'legume',
      calories: 116,
      protein: 9,
      carbs: 20,
      fats: 0.4,
    );
    expect((await foods.search('عدس')).single.id, id);
    await foods.setFavorite(id, true);
    await foods.setFavorite(id, true);
    expect(await database.select(database.favorites).get(), hasLength(1));
    await foods.recordRecent(id);
    await foods.recordRecent(id);
    expect(
      (await database.select(database.recentFoods).getSingle()).useCount,
      2,
    );
  });

  test(
    'food search ranks personal frequency and supports barcode fallback',
    () async {
      final foods = FoodRepository(database);
      final frequent = await foods.addFood(
        name: 'Frequent oats',
        category: 'grain',
        barcode: '123456789',
        calories: 380,
        protein: 15,
        carbs: 65,
        fats: 7,
      );
      await foods.addFood(
        name: 'Alphabetical apple',
        category: 'fruit',
        calories: 52,
        protein: 0.3,
        carbs: 14,
        fats: 0.2,
      );
      await foods.recordRecent(frequent);
      await foods.recordRecent(frequent);

      expect((await foods.search('')).first.id, frequent);
      expect((await foods.search('123456789')).single.id, frequent);
    },
  );

  test(
    'plan overrides preserve recommendation snapshot and reset safely',
    () async {
      final profiles = UserProfileRepository(database);
      await profiles.save(
        gender: 'male',
        age: 35,
        height: 180,
        currentWeight: 85,
        targetWeight: 78,
        activityLevel: 'moderate',
        exercises: true,
      );
      final profile = (await profiles.getProfile())!;
      final plans = PlanRepository(database);
      const recommended = DailyTargets(
        calories: 2300,
        protein: 150,
        carbs: 250,
        fats: 75,
        potassium: 4700,
        sodium: 2300,
        fiber: 35,
        water: 3200,
      );
      await plans.save(
        profileUuid: profile.uuid,
        recommended: recommended,
        calories: 2400,
        protein: 160,
      );
      var plan = (await plans.getForProfile(profile.uuid))!;
      expect(plan.recommendedCalories, 2300);
      expect(plan.overrideCalories, 2400);

      await plans.reset(profileUuid: profile.uuid, recommended: recommended);
      plan = (await plans.getForProfile(profile.uuid))!;
      expect(plan.uuid, isNotEmpty);
      expect(plan.overrideCalories, isNull);
      expect(plan.overrideProtein, isNull);
    },
  );

  test('weight supports add update and soft delete', () async {
    final weights = WeightRepository(database);
    final id = await weights.addWeight(80, date: DateTime(2026, 7, 1));
    await weights.updateWeight(
      id: id,
      weight: 79.5,
      date: DateTime(2026, 7, 1),
    );
    expect((await weights.getAll()).single.weight, 79.5);
    await weights.updateWeight(
      id: id,
      weight: 79.2,
      date: DateTime(2026, 7, 1),
    );
    expect((await weights.getAll()).single.revision, 3);
    await weights.deleteWeight(id);
    expect(await weights.getAll(), isEmpty);
    expect(
      (await database.select(database.weightEntries).getSingle()).revision,
      4,
    );
  });

  test(
    'daily weight check-in preserves one active entry and durable id',
    () async {
      final weights = WeightRepository(database);
      final morning = DateTime(2026, 7, 18, 7);
      final firstId = await weights.addWeight(
        80,
        date: morning,
        measurementContext: 'morning',
      );
      final firstUuid = (await weights.getForDay(morning))!.uuid;

      final secondId = await weights.addWeight(
        79.8,
        date: morning.add(const Duration(hours: 8)),
        measurementContext: 'afterBathroom',
      );

      final entry = await weights.getForDay(morning);
      expect(secondId, firstId);
      expect(entry!.uuid, firstUuid);
      expect(entry.weight, 79.8);
      expect(entry.measurementContext, 'afterBathroom');
      expect(await weights.getAll(), hasLength(1));
    },
  );

  test(
    'deleted daily weight can be recorded again without resurrection',
    () async {
      final weights = WeightRepository(database);
      final date = DateTime(2026, 7, 18);
      final deletedId = await weights.addWeight(80, date: date);
      await weights.deleteWeight(deletedId);

      final replacementId = await weights.addWeight(79.9, date: date);

      expect(replacementId, isNot(deletedId));
      expect((await weights.getForDay(date))!.weight, 79.9);
      expect(await weights.getAll(), hasLength(1));
    },
  );

  test('water totals are calculated from individual entries', () async {
    final water = WaterRepository(database);
    final date = DateTime(2026, 7, 18);
    final firstId = await water.add(
      occurredAt: date.add(const Duration(hours: 8)),
      amountMl: 250,
    );
    await water.add(
      occurredAt: date.add(const Duration(hours: 12)),
      amountMl: 400,
    );
    expect(await water.totalForDay(date), 650);
    await water.delete(firstId);
    expect(await water.totalForDay(date), 400);
    final deleted = await (database.select(
      database.waterEntries,
    )..where((row) => row.id.equals(firstId))).getSingle();
    expect(deleted.revision, 2);
    expect(deleted.syncStatus, 'pendingDelete');
  });

  test('profile edits update the singleton row', () async {
    final profiles = UserProfileRepository(database);
    Future<void> save(double weight) => profiles.save(
      gender: 'female',
      age: 32,
      height: 168,
      currentWeight: weight,
      targetWeight: 65,
      activityLevel: 'moderate',
      exercises: true,
    );
    await save(72);
    await save(71);
    expect(await database.select(database.userProfile).get(), hasLength(1));
    expect((await profiles.getProfile())!.currentWeight, 71);
  });

  test('meal type is reused for the same day', () async {
    final meals = MealRepository(database);
    final first = await meals.createMeal(
      date: DateTime(2026, 7, 18, 8),
      name: 'Breakfast',
      type: 'breakfast',
    );
    final second = await meals.createMeal(
      date: DateTime(2026, 7, 18, 10),
      name: 'Breakfast',
      type: 'breakfast',
    );
    expect(second, first);
    expect(await database.select(database.meals).get(), hasLength(1));
  });

  test('life context consent controls intelligence visibility', () async {
    final contexts = LifeContextRepository(database);
    final id = await contexts.add(
      occurredAt: DateTime(2026, 7, 18),
      type: 'poorSleep',
      details: 'Short night',
      useInInsights: true,
    );
    expect(await contexts.watchAllForInsights().first, hasLength(1));

    await contexts.setInsightConsent(id, false);
    await contexts.setInsightConsent(id, true);
    await contexts.setInsightConsent(id, false);

    expect(await contexts.watchAllForInsights().first, isEmpty);
    expect(
      await contexts.watchForDay(DateTime(2026, 7, 18)).first,
      hasLength(1),
    );
    expect(
      (await database.select(database.lifeContextEntries).getSingle()).revision,
      4,
    );
  });

  test(
    'decision memory records response and evaluation without duplicates',
    () async {
      final memories = DecisionMemoryRepository(database);
      const action = BestAction(
        type: BestActionType.hydration,
        title: 'Drink 500 ml gradually',
        reason: 'Hydration is below target.',
        evidence: ['1000 ml recorded'],
      );
      final date = DateTime(2026, 7, 18);
      final firstId = await memories.rememberAction(action, date: date);
      final secondId = await memories.rememberAction(action, date: date);
      await memories.respond(firstId, 'done');
      await memories.evaluate(id: firstId, helpfulness: 4, outcome: 'Helpful');

      final rows = await memories.watchAll().first;
      expect(secondId, firstId);
      expect(rows, hasLength(1));
      expect(rows.single.response, 'done');
      expect(rows.single.helpfulness, 4);
      expect(rows.single.revision, 4);
    },
  );
}
