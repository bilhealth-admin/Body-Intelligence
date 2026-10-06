import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/daily_log/presentation/daily_log_meals_list.dart';
import 'package:body_intelligence_log/features/daily_log/presentation/daily_log_summary_widgets.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/food_v2/coach_food_v2.dart';
import 'package:body_intelligence_log/features/settings/premium_meal_features_page.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../nutrition/food_basis_fixtures.dart';
import 'daily_log_nutrition_fixtures.dart';

DailyLogSnapshot _snapshot(List<MealWithItems> meals) => DailyLogSnapshot(
  arabic: false,
  meals: meals,
  water: const [],
  calorieGoal: 2000,
  carbsGoal: 250,
  proteinGoal: 100,
  fatGoal: 70,
);

DailyMealDetailItems _detail(MealWithItems meal) => DailyMealDetailItems(
  meal: meal,
  showFoodTimestamps: false,
  onEdit: (_, _) async {},
  onActions: (_, _) async {},
);

void main() {
  for (final language in ['en', 'ar']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        '$language $brightness calorie-only keeps 1905 and unknown macros at 200%',
        (tester) async {
          final meal = diaryMeal([calorieOnlyDiaryItem()]);
          await pumpDiaryEvidence(
            tester,
            _snapshot([meal]),
            language: language,
            brightness: brightness,
            scale: 2,
            width: 320,
          );
          expect(
            diaryText(tester, 'daily-summary-calories-value'),
            contains('1905'),
          );
          final unavailable = tester
              .element(find.byType(DailyLogSnapshot))
              .strings
              .text('Unavailable');
          for (final macro in ['carbs', 'protein', 'fat']) {
            expect(diaryText(tester, 'daily-summary-$macro-grams'), '—');
            expect(
              tester
                  .widget<Semantics>(
                    find.byKey(Key('daily-summary-$macro-percent')),
                  )
                  .properties
                  .value,
              unavailable,
            );
          }
          for (final goalText in [' / 250', ' / 100', ' / 70']) {
            expect(
              tester.widget<Text>(find.text(goalText)).textDirection,
              TextDirection.ltr,
            );
          }
        },
      );
    }
  }

  testWidgets(
    'one unknown row makes a partial total and remaining unavailable',
    (tester) async {
      final known = modernDiaryItem();
      final unknown = modernDiaryItem(id: 2, values: const {});
      await pumpDiaryEvidence(
        tester,
        _snapshot([
          diaryMeal([known, unknown]),
        ]),
      );
      expect(
        diaryText(tester, 'daily-summary-calories-value'),
        startsWith('—'),
      );
      expect(diaryText(tester, 'daily-summary-calories-status'), 'Unavailable');
      expect(diaryText(tester, 'daily-summary-protein-grams'), '—');
      expect(
        diaryText(tester, 'daily-summary-calories-value'),
        isNot(contains('123')),
      );
    },
  );

  testWidgets(
    'the meal detail ring and macro dials do not invent unknown nutrients',
    (tester) async {
      await pumpDiaryEvidence(
        tester,
        DailyMealDetailSummary(
          meal: diaryMeal([calorieOnlyDiaryItem()]),
          calorieGoal: 2000,
          carbsGoal: 250,
          proteinGoal: 100,
          fatGoal: 70,
        ),
      );
      final ring = tester.widget<DailyLogCalorieMacroRing>(
        find.byType(DailyLogCalorieMacroRing),
      );
      expect(ring.calories, 1905);
      expect(ring.carbs, isNull);
      expect(ring.protein, isNull);
      expect(ring.fat, isNull);
      final dials = find.byKey(const Key('daily-meal-detail-macros'));
      expect(
        find.descendant(of: dials, matching: find.text('—')),
        findsNWidgets(3),
      );
      expect(
        find.descendant(of: dials, matching: find.text('0 g')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'meal cards show unavailable total and percentages for missing rows',
    (tester) async {
      final meal = diaryMeal([modernDiaryItem(values: const {})]);
      await pumpDiaryEvidence(
        tester,
        DailyMealsList(
          arabic: false,
          meals: AsyncData([meal]),
          showEmptyMealSlots: false,
          mealMacroDisplay: const MealMacroDisplay(
            enabled: true,
            mode: MealMacroDisplayMode.grams,
          ),
          onAdd: (_) {},
          onEdit: (_, _) async {},
          onActions: (_, _) async {},
        ),
      );
      expect(diaryText(tester, 'daily-meal-totals-breakfast'), startsWith('—'));
      expect(
        diaryText(tester, 'daily-meal-macros-breakfast'),
        'C —   P —   F —',
      );
    },
  );

  testWidgets(
    'modern row names and nutrient values come from the immutable item',
    (tester) async {
      final item = modernDiaryItem();
      final changed = basisFood().copyWith(
        name: 'New catalog name',
        protein: 99,
      );
      await pumpDiaryEvidence(
        tester,
        _detail(diaryMeal([item], foods: {item.foodId: changed})),
      );
      expect(find.text('Cooked food'), findsOneWidget);
      expect(find.text('New catalog name'), findsNothing);
      expect(diaryText(tester, 'daily-food-insights-1'), contains('P 10 g'));
    },
  );

  testWidgets('a valid immutable name survives a missing catalog row', (
    tester,
  ) async {
    await pumpDiaryEvidence(tester, _detail(diaryMeal([modernDiaryItem()])));
    expect(find.text('Cooked food'), findsOneWidget);
    expect(find.text('Historical food'), findsNothing);
  });

  testWidgets('a malformed snapshot hides catalog name and misleading zeros', (
    tester,
  ) async {
    final item = modernDiaryItem(
      values: const {},
    ).copyWith(foodEvidenceJson: const Value('{invalid'));
    await pumpDiaryEvidence(
      tester,
      _detail(diaryMeal([item], foods: {item.foodId: basisFood()})),
    );
    expect(find.text('Historical food'), findsOneWidget);
    expect(find.text('Cooked food'), findsNothing);
    expect(diaryText(tester, 'daily-food-insights-1'), 'C —  P —  F —');
    final row = find.byKey(const Key('daily-food-row-1'));
    expect(find.descendant(of: row, matching: find.text('0')), findsNothing);
    expect(find.descendant(of: row, matching: find.text('—')), findsOneWidget);
  });

  testWidgets(
    'owner mismatch makes a fixed snapshot unavailable in totals and row',
    (tester) async {
      final item = modernDiaryItem(
        kind: CoachFoodSourceKind.userFixed,
        ownerKey: 'owner-a',
      );
      final meal = diaryMeal(
        [item],
        foods: {item.foodId: basisFood()},
        ownerKey: 'owner-b',
      );
      await pumpDiaryEvidence(
        tester,
        Column(
          children: [
            _snapshot([meal]),
            _detail(meal),
          ],
        ),
      );
      expect(
        diaryText(tester, 'daily-summary-calories-value'),
        startsWith('—'),
      );
      expect(diaryText(tester, 'daily-food-insights-1'), 'C —  P —  F —');
      expect(find.text('Cooked food'), findsNothing);
    },
  );

  testWidgets('a missing modern envelope is unavailable in the real row', (
    tester,
  ) async {
    final item = modernDiaryItem(
      values: const {},
    ).copyWith(foodEvidenceJson: const Value(null));
    final meal = diaryMeal([item], foods: {item.foodId: basisFood()});
    await pumpDiaryEvidence(
      tester,
      Column(
        children: [
          _snapshot([meal]),
          _detail(meal),
        ],
      ),
    );
    expect(diaryText(tester, 'daily-summary-calories-value'), startsWith('—'));
    expect(diaryText(tester, 'daily-food-insights-1'), 'C —  P —  F —');
    expect(find.text('Cooked food'), findsNothing);
  });

  testWidgets('explicit modern known zeros stay visible zeros', (tester) async {
    final item = modernDiaryItem(
      values: const {
        FoodNutrient.calories: 0,
        FoodNutrient.carbohydrates: 0,
        FoodNutrient.protein: 0,
        FoodNutrient.fat: 0,
      },
    );
    await pumpDiaryEvidence(
      tester,
      _snapshot([
        diaryMeal([item]),
      ]),
    );
    expect(diaryText(tester, 'daily-summary-calories-value'), startsWith('0 '));
    for (final macro in ['carbs', 'protein', 'fat']) {
      expect(diaryText(tester, 'daily-summary-$macro-grams'), '0 g');
      expect(
        tester
            .widget<Semantics>(find.byKey(Key('daily-summary-$macro-percent')))
            .properties
            .value,
        '0%',
      );
    }
  });

  testWidgets(
    'net carbohydrate rows need both carbohydrate and fiber evidence',
    (tester) async {
      final item = modernDiaryItem(values: const {FoodNutrient.fiber: 2});
      final meal = diaryMeal([item]);
      await pumpDiaryEvidence(
        tester,
        DailyMealDetailItems(
          meal: meal,
          useNetCarbs: true,
          showFoodTimestamps: false,
          onEdit: (_, _) async {},
          onActions: (_, _) async {},
        ),
      );
      expect(diaryText(tester, 'daily-food-insights-1'), 'NC —  P —  F —');
    },
  );
}
