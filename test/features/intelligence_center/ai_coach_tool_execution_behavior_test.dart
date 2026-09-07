import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/services/app_settings_provider.dart';
import 'package:body_intelligence_log/app/services/app_settings_service.dart';
import 'package:body_intelligence_log/app/services/settings_store.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/body_measurement_repository.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/goal_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/data/repositories/water_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/intelligence_action.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/intelligence_center_page.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/intelligence_health_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'measurement merge is opt-in and ordinary saves retain replacement semantics',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = BodyMeasurementRepository(database);
      final day = DateTime(2026, 9, 5);

      await repository.saveForDay(date: day, waistCm: 91, chestCm: 102);
      await repository.saveForDay(
        date: day,
        neckCm: 39,
        preserveExistingValues: true,
      );

      var saved = await repository.getLatest();
      expect(saved?.neckCm, 39);
      expect(saved?.waistCm, 91);
      expect(saved?.chestCm, 102);

      await repository.saveForDay(date: day, armCm: 34);
      saved = await repository.getLatest();
      expect(saved?.armCm, 34);
      expect(saved?.neckCm, isNull);
      expect(saved?.waistCm, isNull);
      expect(saved?.chestCm, isNull);
    },
  );

  test(
    'concurrent partial measurement patches do not erase each other',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = BodyMeasurementRepository(database);
      final day = DateTime(2026, 9, 5);

      await repository.saveForDay(date: day, waistCm: 91, chestCm: 102);
      await Future.wait(<Future<void>>[
        repository.saveForDay(
          date: day,
          neckCm: 39,
          preserveExistingValues: true,
        ),
        repository.saveForDay(
          date: day,
          armCm: 34,
          preserveExistingValues: true,
        ),
      ]);

      final saved = await repository.getLatest();
      expect(saved?.neckCm, 39);
      expect(saved?.armCm, 34);
      expect(saved?.waistCm, 91);
      expect(saved?.chestCm, 102);
    },
  );

  testWidgets(
    'water and weight execute after confirmation, invalidate context, and restore receipts without replay',
    (tester) async {
      await _setPhoneSurface(tester);
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final gateway = _QueuedToolGateway(<Map<String, Object?>>[
        _tool('log_water', <String, Object?>{'amountMl': 375}),
        _tool('log_weight', <String, Object?>{
          'weightKg': 82.4,
          'date': '2026-09-05',
        }),
      ]);
      var contextBuilds = 0;
      final settingsService = AppSettingsService(store: _MemorySettingsStore());

      await tester.pumpWidget(
        _coachApp(
          database: database,
          gateway: gateway,
          settingsService: settingsService,
          onContextBuild: () => contextBuilds += 1,
        ),
      );
      await tester.pumpAndSettle();
      final beforeWater = contextBuilds;

      await _submitNextTool(
        tester,
        type: IntelligenceActionType.addWater,
        id: 'log_water',
        expectedReceipt: 'Logged 375 ml of water.',
      );
      expect(await WaterRepository(database).totalForDay(DateTime.now()), 375);
      expect(contextBuilds, greaterThan(beforeWater));

      final beforeWeight = contextBuilds;
      await _submitNextTool(
        tester,
        type: IntelligenceActionType.addWeight,
        id: 'log_weight',
        expectedReceipt: 'Logged weight: 82.4 kg.',
      );
      final weights = await WeightRepository(database).getAll();
      expect(weights, hasLength(1));
      expect(weights.single.weight, 82.4);
      expect(weights.single.dayKey, '2026-09-05');
      expect(contextBuilds, greaterThan(beforeWeight));

      final preferences = PreferencesRepository(database);
      final receipts = await _waitForStoredReceipts(
        tester,
        preferences,
        minimumCount: 2,
      );
      expect(receipts, contains('Logged 375 ml of water.'));
      expect(receipts, contains('Logged weight: 82.4 kg.'));
      expect(gateway.calls, 2);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _coachApp(
          database: database,
          gateway: gateway,
          settingsService: settingsService,
          onContextBuild: () => contextBuilds += 1,
        ),
      );
      await tester.pumpAndSettle();

      final restoredWeightReceipt = find.text('Logged weight: 82.4 kg.');
      for (
        var attempt = 0;
        attempt < 12 && restoredWeightReceipt.evaluate().isEmpty;
        attempt += 1
      ) {
        await tester.drag(find.byType(ListView).last, const Offset(0, -240));
        await tester.pumpAndSettle();
      }
      expect(restoredWeightReceipt, findsOneWidget);
      expect(await WaterRepository(database).totalForDay(DateTime.now()), 375);
      expect(await WeightRepository(database).getAll(), hasLength(1));
      expect(gateway.calls, 2, reason: 'restoring receipts must be read-only');
      await _disposeCoach(tester);
    },
  );

  testWidgets(
    'confirmed measurement and weight-goal tools commit through real repositories',
    (tester) async {
      await _setPhoneSurface(tester);
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final day = DateTime(2026, 9, 5);
      await BodyMeasurementRepository(
        database,
      ).saveForDay(date: day, waistCm: 90, chestCm: 101);
      await UserProfileRepository(database).save(
        gender: 'male',
        age: 35,
        height: 180,
        currentWeight: 88,
        targetWeight: 82,
        activityLevel: 'moderate',
        exercises: true,
      );
      final gateway = _QueuedToolGateway(<Map<String, Object?>>[
        _tool('save_measurements', <String, Object?>{
          'date': '2026-09-05',
          'neckCm': 39,
        }),
        _tool('update_goal', <String, Object?>{
          'targetWeightKg': 80,
          'targetDate': '2026-12-15',
        }),
      ]);

      await tester.pumpWidget(
        _coachApp(
          database: database,
          gateway: gateway,
          settingsService: AppSettingsService(store: _MemorySettingsStore()),
        ),
      );
      await tester.pumpAndSettle();

      await _submitNextTool(
        tester,
        type: IntelligenceActionType.saveMeasurements,
        id: 'save_measurements',
        expectedReceipt: 'Body measurements saved for 2026-09-05.',
      );
      final measurements = await BodyMeasurementRepository(
        database,
      ).getLatest();
      expect(measurements?.neckCm, 39);
      expect(measurements?.waistCm, 90);
      expect(measurements?.chestCm, 101);

      await _submitNextTool(
        tester,
        type: IntelligenceActionType.updateGoal,
        id: 'update_goal',
        expectedReceipt: 'Target weight updated to 80.0 kg.',
      );
      final profile = await UserProfileRepository(database).getProfile();
      final goal = await GoalRepository(database).getActive();
      expect(profile?.targetWeight, 80);
      expect(goal?.targetWeight, 80);
      expect(goal?.type, 'lose');
      expect(goal?.targetDate, DateTime(2026, 12, 15));
      await _disposeCoach(tester);
    },
  );

  testWidgets('goal classification reads the latest committed weight', (
    tester,
  ) async {
    await _setPhoneSurface(tester);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await UserProfileRepository(database).save(
      gender: 'male',
      age: 35,
      height: 180,
      currentWeight: 88,
      targetWeight: 82,
      activityLevel: 'moderate',
      exercises: true,
    );
    await WeightRepository(database).addWeight(70, date: DateTime(2026, 9, 5));
    final gateway = _QueuedToolGateway(<Map<String, Object?>>[
      _tool('update_goal', <String, Object?>{'targetWeightKg': 75}),
    ]);

    await tester.pumpWidget(
      _coachApp(
        database: database,
        gateway: gateway,
        settingsService: AppSettingsService(store: _MemorySettingsStore()),
      ),
    );
    await tester.pumpAndSettle();

    await _submitNextTool(
      tester,
      type: IntelligenceActionType.updateGoal,
      id: 'update_goal',
      expectedReceipt: 'Target weight updated to 75.0 kg.',
    );

    expect((await GoalRepository(database).getActive())?.type, 'gain');
    await _disposeCoach(tester);
  });

  testWidgets(
    'failed goal persistence rolls back profile and adds no receipt',
    (tester) async {
      await _setPhoneSurface(tester);
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await UserProfileRepository(database).save(
        gender: 'male',
        age: 35,
        height: 180,
        currentWeight: 88,
        targetWeight: 82,
        activityLevel: 'moderate',
        exercises: true,
      );
      final gateway = _QueuedToolGateway(<Map<String, Object?>>[
        _tool('update_goal', <String, Object?>{'targetWeightKg': 80}),
      ]);
      final preferences = PreferencesRepository(database);

      await tester.pumpWidget(
        _coachApp(
          database: database,
          gateway: gateway,
          goalRepository: _FailingGoalRepository(database),
          settingsService: AppSettingsService(store: _MemorySettingsStore()),
        ),
      );
      await tester.pumpAndSettle();

      await _submitNextTool(
        tester,
        type: IntelligenceActionType.updateGoal,
        id: 'update_goal',
      );
      final failure = find.textContaining('The action was not completed.');
      await _pumpUntil(tester, () => failure.evaluate().isNotEmpty);
      final profile = await UserProfileRepository(database).getProfile();

      expect(failure, findsOneWidget);
      expect(profile?.targetWeight, 82);
      expect(profile?.revision, 1);
      expect(await database.select(database.goals).get(), isEmpty);
      expect(await _storedReceipts(preferences), isEmpty);
      await _disposeCoach(tester);
    },
  );

  testWidgets(
    'typed and chip confirmation cannot execute one durable goal twice',
    (tester) async {
      await _setPhoneSurface(tester);
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await UserProfileRepository(database).save(
        gender: 'male',
        age: 35,
        height: 180,
        currentWeight: 88,
        targetWeight: 82,
        activityLevel: 'moderate',
        exercises: true,
      );
      final blockingGoals = _BlockingGoalRepository(database);
      final gateway = _QueuedToolGateway(<Map<String, Object?>>[
        _tool('update_goal', <String, Object?>{'targetWeightKg': 80}),
      ]);
      final preferences = PreferencesRepository(database);

      await tester.pumpWidget(
        _coachApp(
          database: database,
          gateway: gateway,
          goalRepository: blockingGoals,
          settingsService: AppSettingsService(store: _MemorySettingsStore()),
        ),
      );
      await tester.pumpAndSettle();

      await _openNextToolAction(
        tester,
        type: IntelligenceActionType.updateGoal,
        id: 'update_goal',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      final chip = find.byKey(
        const Key('ai-coach-action-updateGoal-update_goal'),
      );
      expect(chip, findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('ai-coach-question-field')),
        'confirm',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      tester.testTextInput.hide();
      await tester.pump();
      await tester.tap(find.byKey(const Key('ai-coach-send-button')));
      await tester.pump();
      await blockingGoals.entered.future.timeout(const Duration(seconds: 2));

      await Scrollable.ensureVisible(tester.element(chip), alignment: .5);
      await tester.pump();
      await tester.tap(chip);
      await tester.pump();
      final duplicateDialogShown = find
          .byType(AlertDialog)
          .evaluate()
          .isNotEmpty;
      if (duplicateDialogShown) {
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pump(const Duration(milliseconds: 300));
      }
      blockingGoals.release.complete();
      await tester.pumpAndSettle();

      final goals = await database.select(database.goals).get();
      final profile = await UserProfileRepository(database).getProfile();
      final receipts = await _waitForStoredReceipts(
        tester,
        preferences,
        minimumCount: 1,
      );
      await _disposeCoach(tester);

      expect(duplicateDialogShown, isFalse);
      expect(goals, hasLength(1));
      expect(profile?.revision, 2);
      expect(
        receipts.where((text) => text == 'Target weight updated to 80.0 kg.'),
        hasLength(1),
      );
    },
  );

  testWidgets(
    'a goal committed while the page closes is retired before restore',
    (tester) async {
      await _setPhoneSurface(tester);
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await UserProfileRepository(database).save(
        gender: 'male',
        age: 35,
        height: 180,
        currentWeight: 88,
        targetWeight: 82,
        activityLevel: 'moderate',
        exercises: true,
      );
      final blockingGoals = _BlockingGoalRepository(database);
      final gateway = _QueuedToolGateway(<Map<String, Object?>>[
        _tool('update_goal', <String, Object?>{'targetWeightKg': 80}),
      ]);
      final preferences = PreferencesRepository(database);

      await tester.pumpWidget(
        _coachApp(
          database: database,
          gateway: gateway,
          goalRepository: blockingGoals,
          settingsService: AppSettingsService(store: _MemorySettingsStore()),
        ),
      );
      await tester.pumpAndSettle();
      await _openNextToolAction(
        tester,
        type: IntelligenceActionType.updateGoal,
        id: 'update_goal',
      );
      expect(
        await _waitForStoredAction(
          tester,
          preferences,
          type: IntelligenceActionType.updateGoal,
          id: 'update_goal',
        ),
        isTrue,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pump();
      await blockingGoals.entered.future.timeout(const Duration(seconds: 2));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      blockingGoals.release.complete();

      expect(
        await _waitForStoredAction(
          tester,
          preferences,
          type: IntelligenceActionType.updateGoal,
          id: 'update_goal',
          expected: false,
        ),
        isFalse,
      );
      expect(await GoalRepository(database).getActive(), isNotNull);

      await tester.pumpWidget(
        _coachApp(
          database: database,
          gateway: gateway,
          settingsService: AppSettingsService(store: _MemorySettingsStore()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('ai-coach-action-updateGoal-update_goal')),
        findsNothing,
      );
      expect(gateway.calls, 1);
      await _disposeCoach(tester);
    },
  );

  testWidgets(
    'quick add, update, move, and delete mutate meal data and failed writes add no receipt',
    (tester) async {
      await _setPhoneSurface(tester);
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final day = DateTime(2026, 9, 5);
      final foods = FoodRepository(database);
      final meals = MealRepository(database);
      final foodId = await foods.addFood(
        name: 'Behavior oats',
        category: 'grain',
        calories: 380,
        protein: 13,
        carbs: 68,
        fats: 7,
        servingSize: 100,
        servingUnit: 'g',
      );
      final breakfastId = await meals.createMeal(
        date: day,
        name: 'breakfast',
        type: 'breakfast',
      );
      await meals.addMealItem(
        mealId: breakfastId,
        foodId: foodId,
        quantity: 100,
      );
      final original = await meals.watchMealsForDate(day).first;
      final itemId = original.single.items.single.id;
      final gateway = _QueuedToolGateway(<Map<String, Object?>>[
        _tool('quick_add_macros', <String, Object?>{
          'date': '2026-09-05',
          'mealType': 'lunch',
          'calories': 420,
          'protein': 35,
          'carbohydrates': 40,
          'fat': 12,
        }),
        _tool('update_meal_item', <String, Object?>{
          'itemId': itemId,
          'quantityGrams': 150,
        }),
        _tool('move_meal_item', <String, Object?>{
          'itemId': itemId,
          'mealType': 'dinner',
        }),
        _tool('delete_meal_item', <String, Object?>{'itemId': itemId}),
        _tool('delete_meal_item', const <String, Object?>{'itemId': 999999}),
      ]);
      final preferences = PreferencesRepository(database);

      await tester.pumpWidget(
        _coachApp(
          database: database,
          gateway: gateway,
          settingsService: AppSettingsService(store: _MemorySettingsStore()),
        ),
      );
      await tester.pumpAndSettle();

      await _submitNextTool(
        tester,
        type: IntelligenceActionType.quickAddMacros,
        id: 'quick_add_macros',
        expectedReceipt: 'Quick macros added to lunch: 420 kcal.',
      );
      var snapshot = await meals.watchMealsForDate(day).first;
      expect(snapshot.where((meal) => meal.meal.type == 'lunch'), isNotEmpty);

      await _submitNextTool(
        tester,
        type: IntelligenceActionType.updateMealItem,
        id: 'update_meal_item',
        expectedReceipt: 'Meal item $itemId updated to 150.0 g.',
      );
      snapshot = await meals.watchMealsForDate(day).first;
      expect(_activeItem(snapshot, itemId).quantity, 150);

      await _submitNextTool(
        tester,
        type: IntelligenceActionType.moveMealItem,
        id: 'move_meal_item',
        expectedReceipt: 'Meal item $itemId moved to dinner.',
      );
      snapshot = await meals.watchMealsForDate(day).first;
      expect(
        snapshot
            .singleWhere((meal) => meal.meal.type == 'dinner')
            .items
            .map((item) => item.id),
        contains(itemId),
      );

      await _submitNextTool(
        tester,
        type: IntelligenceActionType.deleteMealItem,
        id: 'delete_meal_item',
        expectedReceipt: 'Meal item $itemId deleted.',
      );
      snapshot = await meals.watchMealsForDate(day).first;
      expect(
        snapshot.expand((meal) => meal.items).map((item) => item.id),
        isNot(contains(itemId)),
      );
      final receiptsBeforeFailure = await _waitForStoredReceipts(
        tester,
        preferences,
        minimumCount: 4,
      );

      await _submitNextTool(
        tester,
        type: IntelligenceActionType.deleteMealItem,
        id: 'delete_meal_item',
      );
      final failure = find.textContaining('The action was not completed.');
      await _pumpUntil(tester, () => failure.evaluate().isNotEmpty);
      expect(failure, findsOneWidget);
      final receiptsAfterFailure = await _storedReceipts(preferences);
      expect(receiptsAfterFailure, receiptsBeforeFailure);
      await _disposeCoach(tester);
    },
  );

  testWidgets('memory, theme, and language update durable application state', (
    tester,
  ) async {
    await _setPhoneSurface(tester);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final settingsStore = _MemorySettingsStore();
    final gateway = _QueuedToolGateway(<Map<String, Object?>>[
      _tool('set_theme_mode', const <String, Object?>{'mode': 'dark'}),
      _tool('set_language', const <String, Object?>{'locale': 'ar'}),
      _tool('save_memory', const <String, Object?>{
        'text': 'I prefer evening workouts',
        'kind': 'preference',
      }),
    ]);

    await tester.pumpWidget(
      _coachApp(
        database: database,
        gateway: gateway,
        settingsService: AppSettingsService(store: settingsStore),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(IntelligenceCenterPage)),
    );

    await _submitNextTool(
      tester,
      type: IntelligenceActionType.setThemeMode,
      id: 'set_theme_mode',
      confirmation: false,
      expectedReceipt: 'App appearance updated.',
    );
    await tester.pump();
    expect(container.read(appSettingsProvider).themeMode, 'dark');
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );

    await _submitNextTool(
      tester,
      type: IntelligenceActionType.setLanguage,
      id: 'set_language',
      confirmation: false,
    );
    await tester.pump();
    expect(container.read(appSettingsProvider).localeCode, 'ar');
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
      const Locale('ar'),
    );

    await _submitNextTool(
      tester,
      type: IntelligenceActionType.saveMemory,
      id: 'save_memory',
    );
    final storedMemory =
        jsonDecode(
              (await PreferencesRepository(
                database,
              ).get('coachExplicitMemoriesV1'))!,
            )
            as List<Object?>;
    expect(storedMemory, hasLength(1));
    expect((storedMemory.single as Map)['text'], 'I prefer evening workouts');
    expect((storedMemory.single as Map)['kind'], 'preference');

    final persistedSettings = AppSettings.fromJson(
      jsonDecode(settingsStore.value!) as Map<String, dynamic>,
    );
    expect(persistedSettings.themeMode, 'dark');
    expect(persistedSettings.localeCode, 'ar');
    expect(
      await _waitForStoredReceipts(
        tester,
        PreferencesRepository(database),
        minimumCount: 3,
      ),
      hasLength(3),
    );
    await _disposeCoach(tester);
  });
}

Map<String, Object?> _tool(String name, Map<String, Object?> arguments) =>
    <String, Object?>{'name': name, 'arguments': arguments};

MealItem _activeItem(List<MealWithItems> meals, int id) =>
    meals.expand((meal) => meal.items).singleWhere((item) => item.id == id);

Future<void> _setPhoneSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(430, 932));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _disposeCoach(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  // Drift closes stream-query bookkeeping on a zero-duration timer after the
  // Riverpod container is disposed. Advance one more frame before the test
  // binding checks for leaked timers.
  await tester.pump(Duration.zero);
}

Widget _coachApp({
  required AppDatabase database,
  required LocalModelGateway gateway,
  required AppSettingsService settingsService,
  GoalRepository? goalRepository,
  VoidCallback? onContextBuild,
}) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(database),
    goalRepositoryProvider.overrideWithValue(
      goalRepository ?? GoalRepository(database),
    ),
    appSettingsServiceProvider.overrideWithValue(settingsService),
    intelligenceCenterModelGatewayProvider.overrideWithValue(gateway),
    coachContextSnapshotProvider.overrideWith((ref) async {
      onContextBuild?.call();
      return CoachContextSnapshot.empty();
    }),
    intelligenceHealthContextProvider.overrideWith(
      (ref) async => const IntelligenceHealthContext(
        primaryMessage: '',
        explanation: <String>[],
        confidence: 1,
        evidence: <String>[],
        missingData: <String>[],
      ),
    ),
  ],
  child: const _SettingsAwareCoachApp(),
);

class _SettingsAwareCoachApp extends ConsumerWidget {
  const _SettingsAwareCoachApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final themeMode = switch (settings.themeMode) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
    return MaterialApp(
      locale: Locale(settings.localeCode),
      themeMode: themeMode,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const IntelligenceCenterPage(),
    );
  }
}

Future<void> _submitNextTool(
  WidgetTester tester, {
  required IntelligenceActionType type,
  required String id,
  bool confirmation = true,
  String? expectedReceipt,
}) async {
  await _openNextToolAction(tester, type: type, id: id);

  if (confirmation) {
    final confirmationButton = find.byType(FilledButton);
    await _pumpUntil(tester, () => confirmationButton.evaluate().isNotEmpty);
    expect(confirmationButton, findsOneWidget);
    await tester.tap(confirmationButton);
    await tester.pump(const Duration(milliseconds: 300));
  }

  if (expectedReceipt != null) {
    final receipt = find.text(expectedReceipt);
    await _pumpUntil(tester, () => receipt.evaluate().isNotEmpty);
    expect(receipt, findsOneWidget);
  } else {
    await _pumpUntil(tester, () => find.byType(AlertDialog).evaluate().isEmpty);
  }
}

Future<void> _openNextToolAction(
  WidgetTester tester, {
  required IntelligenceActionType type,
  required String id,
}) async {
  final page = find.byType(IntelligenceCenterPage);
  if (page.evaluate().isNotEmpty) {
    ScaffoldMessenger.of(tester.element(page)).clearSnackBars();
    await tester.pump();
  }
  final prompt =
      'Proceed with prepared BIL operation ${DateTime.now().microsecondsSinceEpoch}';
  await tester.enterText(
    find.byKey(const Key('ai-coach-question-field')),
    prompt,
  );
  FocusManager.instance.primaryFocus?.unfocus();
  tester.testTextInput.hide();
  await tester.pump();
  await tester.tap(find.byKey(const Key('ai-coach-send-button')));
  final action = find.byKey(Key('ai-coach-action-sheet-${type.name}-$id'));
  await _pumpUntil(tester, () => action.evaluate().isNotEmpty);
  expect(action, findsOneWidget);
  await Scrollable.ensureVisible(tester.element(action), alignment: .5);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(action);
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 80 && !condition(); attempt += 1) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<List<String>> _waitForStoredReceipts(
  WidgetTester tester,
  PreferencesRepository preferences, {
  required int minimumCount,
}) async {
  var receipts = <String>[];
  for (var attempt = 0; attempt < 80; attempt += 1) {
    receipts = await _storedReceipts(preferences);
    if (receipts.length >= minimumCount) return receipts;
    await tester.pump(const Duration(milliseconds: 50));
  }
  return receipts;
}

Future<List<String>> _storedReceipts(PreferencesRepository preferences) async {
  final raw = await preferences.get('intelligenceConversationV1');
  if (raw == null || raw.isEmpty) return <String>[];
  final messages = jsonDecode(raw) as List<Object?>;
  return messages
      .whereType<Map>()
      .where((message) {
        final evidence = message['evidence'];
        return evidence is List &&
            evidence.contains('BIL verified tool result');
      })
      .map((message) => message['text']?.toString() ?? '')
      .where((text) => text.isNotEmpty)
      .toList(growable: false);
}

Future<bool> _waitForStoredAction(
  WidgetTester tester,
  PreferencesRepository preferences, {
  required IntelligenceActionType type,
  required String id,
  bool expected = true,
}) async {
  var exists = false;
  for (var attempt = 0; attempt < 80; attempt += 1) {
    final raw = await preferences.get('intelligenceConversationV1');
    if (raw != null && raw.isNotEmpty) {
      final messages = jsonDecode(raw) as List<Object?>;
      exists = messages.whereType<Map>().any((message) {
        final actions = message['actionLinks'];
        return actions is List &&
            actions.whereType<Map>().any(
              (action) => action['type'] == type.name && action['id'] == id,
            );
      });
    } else {
      exists = false;
    }
    if (exists == expected) return exists;
    await tester.pump(const Duration(milliseconds: 50));
  }
  return exists;
}

final class _FailingGoalRepository extends GoalRepository {
  _FailingGoalRepository(super.database);

  @override
  Future<int> save({
    String? uuid,
    required String profileUuid,
    required String type,
    required double targetWeight,
    DateTime? targetDate,
  }) => throw StateError('simulated_goal_write_failure');
}

final class _BlockingGoalRepository extends GoalRepository {
  _BlockingGoalRepository(super.database);

  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<int> save({
    String? uuid,
    required String profileUuid,
    required String type,
    required double targetWeight,
    DateTime? targetDate,
  }) async {
    if (!entered.isCompleted) entered.complete();
    await release.future;
    return super.save(
      uuid: uuid,
      profileUuid: profileUuid,
      type: type,
      targetWeight: targetWeight,
      targetDate: targetDate,
    );
  }
}

class _QueuedToolGateway implements LocalModelGateway {
  _QueuedToolGateway(this._tools);

  final List<Map<String, Object?>> _tools;
  int calls = 0;

  @override
  Future<LocalModelResult> answer({
    required String question,
    required String locale,
    required CoachContextSnapshot context,
    bool languageDetected = false,
    List<CoachConversationTurn> conversation = const <CoachConversationTurn>[],
  }) async {
    if (calls >= _tools.length) {
      throw StateError('Unexpected model call ${calls + 1}');
    }
    final tool = _tools[calls++];
    return LocalModelResult.answer(
      LocalModelAnswer(
        text: 'The prepared action is ready for your review.',
        action: tool,
        processedOnDevice: false,
      ),
    );
  }
}

class _MemorySettingsStore implements SettingsStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}
