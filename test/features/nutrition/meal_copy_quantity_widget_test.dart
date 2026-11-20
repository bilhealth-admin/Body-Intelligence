import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/foods/providers/food_provider.dart';
import 'package:body_intelligence_log/features/nutrition/presentation/meal_copy_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../daily_log/daily_log_nutrition_fixtures.dart';

void main() {
  for (final language in ['en', 'ar']) {
    testWidgets('copy preview preserves saved portion units in $language', (
      tester,
    ) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final source = diaryMeal([
        modernDiaryItem(
          id: 1,
        ).copyWith(quantity: 2, servingUnitSnapshot: 'piece'),
        modernDiaryItem(
          id: 2,
        ).copyWith(quantity: 150, servingUnitSnapshot: 'g'),
        modernDiaryItem(
          id: 3,
        ).copyWith(quantity: 250, servingUnitSnapshot: 'ml'),
        modernDiaryItem(
          id: 4,
        ).copyWith(quantity: 1.5, servingUnitSnapshot: 'serving'),
      ]);
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mealRepositoryProvider.overrideWithValue(
                MealRepository(database),
              ),
            ],
            child: MaterialApp(
              locale: Locale(language),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: MealCopyPage(
                source: source,
                initialDate: DateTime(2026, 11, 20),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(language == 'ar' ? '2 قطعة' : '2 piece'),
          findsOneWidget,
        );
        expect(
          find.text(language == 'ar' ? '150 غم' : '150 g'),
          findsOneWidget,
        );
        expect(
          find.text(language == 'ar' ? '250 مل' : '250 ml'),
          findsOneWidget,
        );
        expect(
          find.text(language == 'ar' ? '1.5 حصة' : '1.5 serving'),
          findsOneWidget,
        );
        expect(find.textContaining('2.0 g'), findsNothing);
        expect(tester.takeException(), isNull);
        // Merely reviewing a copy must never write to the diary.
        expect(await database.select(database.meals).get(), isEmpty);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await database.close();
      }
    });
  }
}
