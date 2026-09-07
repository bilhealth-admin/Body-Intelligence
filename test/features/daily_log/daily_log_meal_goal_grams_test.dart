import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
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

  testWidgets('an empty Today meal card stays free of goal summaries', (
    tester,
  ) async {
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
                meals: const AsyncData(<MealWithItems>[]),
                onAdd: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('daily-meal-macro-goal-breakfast')),
      findsNothing,
    );
    expect(find.text('Plan meal'), findsNWidgets(4));
    expect(find.textContaining('%'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
