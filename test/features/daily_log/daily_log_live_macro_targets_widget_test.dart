import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/nutrient_evidence.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/nutrition_goal_schedule_repository.dart';
import 'package:body_intelligence_log/features/daily_log/presentation/daily_log_meals_list.dart';
import 'package:body_intelligence_log/features/daily_log/presentation/daily_log_summary_widgets.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/settings/premium_meal_features_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'default nutrition goal prefers stored grams over legacy percentages',
    () {
      final target = defaultNutritionGoalTargetFromPreferences(const {
        'goal.calories': '1000',
        'goal.carbsGrams': '100',
        'goal.proteinGrams': '75',
        'goal.fatGrams': '33.333',
        'goal.carbsPercent': '90',
        'goal.proteinPercent': '5',
        'goal.fatPercent': '5',
      });

      expect(target, isNotNull);
      expect(target!.calories, 1000);
      expect(target.carbsGrams, closeTo(100, 0.01));
      expect(target.proteinGrams, closeTo(75, 0.01));
      expect(target.fatGrams, closeTo(33.333, 0.01));
    },
  );

  test(
    'default nutrition goal falls back to a valid legacy percentage split',
    () {
      final target = defaultNutritionGoalTargetFromPreferences(const {
        'goal.calories': '1000',
        'goal.carbsPercent': '40',
        'goal.proteinPercent': '30',
        'goal.fatPercent': '30',
      });

      expect(target, isNotNull);
      expect(target!.carbsGrams, closeTo(100, 0.01));
      expect(target.proteinGrams, closeTo(75, 0.01));
      expect(target.fatGrams, closeTo(33.333, 0.01));
    },
  );

  test(
    'Today resolves scheduled goal before default and otherwise falls back',
    () {
      final date = DateTime(2026, 9, 4);
      final defaultGoal = NutritionGoalTarget.fromGrams(
        calories: 745,
        carbsGrams: 80,
        proteinGrams: 50,
        fatGrams: 25,
      );
      final scheduledGoal = NutritionGoalTarget.fromGrams(
        calories: 1000,
        carbsGrams: 100,
        proteinGrams: 75,
        fatGrams: 100 / 3,
      );

      expect(
        resolveDailyNutritionGoal(
          schedule: NutritionGoalSchedule(
            dayTargets: <int, NutritionGoalTarget>{date.weekday: scheduledGoal},
          ),
          date: date,
          defaultGoal: defaultGoal,
        ),
        same(scheduledGoal),
      );
      expect(
        resolveDailyNutritionGoal(
          schedule: const NutritionGoalSchedule(),
          date: date,
          defaultGoal: defaultGoal,
        ),
        same(defaultGoal),
      );
    },
  );

  testWidgets(
    'live meal card renders food and honors grams, net carbs, time, insights, and callbacks',
    (tester) async {
      final meal = _mealFixture(carbs: 50, fiber: 10);
      final mealGoal = NutritionGoalTarget.fromGrams(
        calories: 745,
        carbsGrams: 80,
        proteinGrams: 50,
        fatGrams: 25,
      );
      MealItem? editedItem;
      MealItem? actionItem;

      await _pumpMealList(
        tester,
        meal: meal,
        mealGoal: mealGoal,
        macroDisplay: const MealMacroDisplay(
          enabled: true,
          mode: MealMacroDisplayMode.grams,
        ),
        showFoodInsights: true,
        showFoodTimestamps: true,
        useNetCarbs: true,
        onEdit: (item, _) async => editedItem = item,
        onActions: (item, _) async => actionItem = item,
      );

      expect(
        find.byKey(const Key('daily-meal-card-breakfast')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('daily-food-row-7')), findsOneWidget);
      expect(find.text('Evidence yogurt'), findsOneWidget);
      expect(find.textContaining('Logged at'), findsOneWidget);
      expect(find.byKey(const Key('daily-food-insights-7')), findsOneWidget);
      expect(
        _textBelow(tester, const Key('daily-meal-macros-breakfast')),
        allOf(
          contains('C 40 / 80 g'),
          contains('P 25 / 50 g'),
          contains('F 10 / 25 g'),
        ),
      );

      await tester.tap(find.byKey(const Key('daily-food-row-7')));
      await tester.pump();
      expect(editedItem?.id, 7);

      await tester.tap(find.byKey(const Key('daily-food-actions-7')));
      await tester.pump();
      expect(actionItem?.id, 7);
    },
  );

  testWidgets(
    'live meal card honors percent mode and hides disabled optional details',
    (tester) async {
      final meal = _mealFixture(carbs: 50, fiber: 10);
      final mealGoal = NutritionGoalTarget.fromGrams(
        calories: 745,
        carbsGrams: 80,
        proteinGrams: 50,
        fatGrams: 25,
      );

      await _pumpMealList(
        tester,
        meal: meal,
        mealGoal: mealGoal,
        macroDisplay: const MealMacroDisplay(
          enabled: true,
          mode: MealMacroDisplayMode.percent,
        ),
        showFoodInsights: false,
        showFoodTimestamps: false,
        useNetCarbs: false,
        includeMealGoal: false,
      );

      expect(find.byKey(const Key('daily-food-row-7')), findsOneWidget);
      expect(find.textContaining('Logged at'), findsNothing);
      expect(find.byKey(const Key('daily-food-insights-7')), findsNothing);
      expect(
        _textBelow(tester, const Key('daily-meal-macros-breakfast')),
        allOf(contains('C 63%'), contains('P 50%'), contains('F 40%')),
      );
    },
  );

  testWidgets('disabled per-meal macro display removes the macro surface', (
    tester,
  ) async {
    await _pumpMealList(
      tester,
      meal: _mealFixture(carbs: 50, fiber: 10),
      mealGoal: NutritionGoalTarget.fromGrams(
        calories: 745,
        carbsGrams: 80,
        proteinGrams: 50,
        fatGrams: 25,
      ),
      macroDisplay: const MealMacroDisplay(
        enabled: false,
        mode: MealMacroDisplayMode.grams,
      ),
    );

    expect(find.byKey(const Key('daily-meal-macros-breakfast')), findsNothing);
  });

  testWidgets('Today snapshot reports consumed grams against resolved goals', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: _localizedApp(
          Scaffold(
            body: DailyLogSnapshot(
              arabic: false,
              meals: [_mealFixture(carbs: 40, fiber: 0)],
              water: const <WaterEntry>[],
              calorieGoal: 745,
              carbsGoal: 80,
              proteinGoal: 50,
              fatGoal: 25,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(_textBelow(tester, const Key('daily-summary-carbs-percent')), '50%');
    expect(
      _textBelow(tester, const Key('daily-summary-protein-percent')),
      '50%',
    );
    expect(_textBelow(tester, const Key('daily-summary-fat-percent')), '40%');
    expect(
      _textBelow(tester, const Key('daily-summary-carbs-grams')),
      '40 / 80 g',
    );
    expect(
      _textBelow(tester, const Key('daily-summary-protein-grams')),
      '25 / 50 g',
    );
    expect(
      _textBelow(tester, const Key('daily-summary-fat-grams')),
      '10 / 25 g',
    );
  });
}

Future<void> _pumpMealList(
  WidgetTester tester, {
  required MealWithItems meal,
  required NutritionGoalTarget mealGoal,
  required MealMacroDisplay macroDisplay,
  bool showFoodInsights = true,
  bool showFoodTimestamps = false,
  bool useNetCarbs = false,
  bool includeMealGoal = true,
  Future<void> Function(MealItem item, Food food)? onEdit,
  Future<void> Function(MealItem item, Food? food)? onActions,
}) async {
  tester.view.physicalSize = const Size(600, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        diaryMealNamesProvider.overrideWithValue(
          const AsyncData(<String?>[null, null, null, null]),
        ),
      ],
      child: _localizedApp(
        Scaffold(
          body: SingleChildScrollView(
            child: DailyMealsList(
              arabic: false,
              meals: AsyncData(<MealWithItems>[meal]),
              showEmptyMealSlots: false,
              showFoodInsights: showFoodInsights,
              showFoodTimestamps: showFoodTimestamps,
              useNetCarbs: useNetCarbs,
              dailyGoal: mealGoal,
              mealGoals: includeMealGoal
                  ? <String, NutritionGoalTarget>{'breakfast': mealGoal}
                  : const <String, NutritionGoalTarget>{},
              mealMacroDisplay: macroDisplay,
              onAdd: (_) {},
              onEdit: onEdit ?? (_, _) async {},
              onActions: onActions ?? (_, _) async {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  expect(tester.takeException(), isNull);
}

MaterialApp _localizedApp(Widget home) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: home,
);

String _textBelow(WidgetTester tester, Key key) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byKey(key),
        matching: find.byType(Text),
        matchRoot: true,
      ),
    )
    .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
    .join(' ');

MealWithItems _mealFixture({required double carbs, required double fiber}) {
  final recordedAt = DateTime(2026, 9, 4, 8, 15);
  final mask = NutrientEvidenceMask.fromValues(
    calories: 350,
    protein: 25,
    carbohydrates: carbs,
    fat: 10,
    fiber: fiber,
  );
  final food = Food(
    id: 11,
    uuid: 'evidence-yogurt',
    name: 'Evidence yogurt',
    keywords: 'evidence yogurt',
    servingSize: 100,
    servingUnit: 'g',
    calories: 350,
    protein: 25,
    carbs: carbs,
    fats: 10,
    fiber: fiber,
    sugar: 4,
    potassium: 120,
    sodium: 30,
    calcium: 100,
    iron: 0,
    magnesium: 12,
    phosphorus: 80,
    vitaminC: 0,
    nutrientEvidenceMask: mask,
    verified: true,
    isCustom: false,
    source: 'Widget test evidence',
    createdAt: recordedAt,
    updatedAt: recordedAt,
    revision: 1,
    syncStatus: 'local',
  );
  final item = MealItem(
    id: 7,
    uuid: 'meal-item-7',
    mealId: 3,
    foodId: food.id,
    quantity: 100,
    position: 0,
    calories: 350,
    protein: 25,
    carbs: carbs,
    fats: 10,
    fiber: fiber,
    sodium: 30,
    potassium: 120,
    calcium: 100,
    magnesium: 12,
    phosphorus: 80,
    sugar: 4,
    nutrientEvidenceMask: mask,
    foodSourceSnapshot: food.source,
    foodVerifiedSnapshot: true,
    servingSizeSnapshot: 100,
    servingUnitSnapshot: 'g',
    createdAt: recordedAt,
    updatedAt: recordedAt,
    revision: 1,
    syncStatus: 'local',
  );
  return MealWithItems(
    meal: Meal(
      id: 3,
      uuid: 'breakfast-3',
      date: DateTime(2026, 9, 4),
      dayKey: '2026-09-04',
      name: 'Breakfast',
      type: 'breakfast',
      createdAt: recordedAt,
      updatedAt: recordedAt,
      revision: 1,
      syncStatus: 'local',
    ),
    items: <MealItem>[item],
    foodsById: <int, Food>{food.id: food},
  );
}
