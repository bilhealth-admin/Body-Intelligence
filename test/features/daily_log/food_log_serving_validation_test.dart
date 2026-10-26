import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/features/daily_log/food_log_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets(
      'invalid serving stays editable and saves once after correction '
      '${locale.languageCode}',
      (tester) async {
        final database = AppDatabase.forTesting(
          NativeDatabase.memory(),
          localOwnerId: 'serving-validation-owner',
        );
        addTearDown(database.close);
        final foods = FoodRepository(database);
        final foodId = await foods.addFood(
          name: 'Validation apple',
          category: 'fruit',
          calories: 52,
          protein: 0.3,
          carbs: 14,
          fats: 0.2,
          servingSize: 100,
          servingUnit: 'g',
        );
        for (var count = 0; count < 4; count++) {
          await foods.recordRecent(foodId);
        }
        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(database)],
            child: MaterialApp(
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const FoodLogPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(Key('food-log-add-$foodId')));
        await tester.tap(find.byKey(Key('food-log-add-$foodId')));
        await tester.pumpAndSettle();
        final field = find.byKey(const Key('food-log-serving-quantity-field'));
        final confirm = find.byKey(const Key('food-log-serving-confirm'));
        for (final invalid in ['', '0', '-1', 'NaN', 'Infinity', '100001']) {
          await tester.enterText(field, invalid);
          await tester.tap(confirm);
          await tester.pumpAndSettle();
          expect(
            field,
            findsOneWidget,
            reason: 'Invalid quantity $invalid must not dismiss the dialog',
          );
          expect(
            find.byKey(const Key('food-log-serving-error')),
            findsOneWidget,
          );
          expect(await database.select(database.mealItems).get(), isEmpty);
        }
        await tester.enterText(
          field,
          locale.languageCode == 'ar' ? '١٠٠٫٠' : '100,0',
        );
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(field, findsNothing);
        final rows = await database.select(database.mealItems).get();
        expect(rows, hasLength(1));
        expect(rows.single.quantity, 100);
        expect(rows.single.foodId, foodId);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 10));
      },
    );
  }
}
