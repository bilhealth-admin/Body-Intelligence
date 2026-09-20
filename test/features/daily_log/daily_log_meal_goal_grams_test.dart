import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/nutrition_goal_schedule_repository.dart';
import 'package:body_intelligence_log/features/daily_log/presentation/daily_log_meals_list.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scheduled meal calories also drive the focused meal summary', () {
    final source = File(
      'lib/features/daily_log/daily_log_page.dart',
    ).readAsStringSync();
    expect(
      source,
      contains(
        'goalSchedule.mealTargets[mealType]?.calories ??\n'
        '                              mealCalorieGoals[mealType]',
      ),
    );
  });

  testWidgets('an empty meal card exposes its scheduled target in grams', (
    tester,
  ) async {
    const breakfast = NutritionGoalTarget(
      calories: 500,
      carbsPercent: 45,
      proteinPercent: 30,
      fatPercent: 25,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diaryMealNamesProvider.overrideWithValue(
            const AsyncData(<String?>[null, null, null, null]),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: SingleChildScrollView(
              child: DailyMealsList(
                arabic: false,
                meals: const AsyncData(<MealWithItems>[]),
                mealGoals: const {'breakfast': breakfast},
                onAdd: (_) {},
                onEdit: (_, _) async {},
                onActions: (_, _) async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('daily-meal-macro-goal-breakfast')),
      findsOneWidget,
    );
    expect(
      find.text('Meal goal: 500 cal  C 56 g  P 38 g  F 14 g'),
      findsOneWidget,
    );
    expect(find.textContaining('%'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
