import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/foods/providers/food_provider.dart';
import 'package:body_intelligence_log/features/nutrition/food_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('custom food can be created, edited, and tombstoned', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          seedCatalogProvider.overrideWith((ref) async {}),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: FoodPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Custom food'));
    await tester.pumpAndSettle();
    expect(find.text('Create custom food'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Serving size'),
          )
          .controller!
          .text,
      '100',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'English name'),
      'Personal yogurt',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Calories'),
      '120,5',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Personal yogurt'), findsOneWidget);
    var food = await database.select(database.foods).getSingle();
    expect(food.calories, 120.5);

    await tester.tap(find.text('Personal yogurt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit custom food'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Calories'),
      '130',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    food = await database.select(database.foods).getSingle();
    expect(food.calories, 130);
    expect(food.revision, 2);

    await tester.tap(find.text('Personal yogurt'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete custom food?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    food = await database.select(database.foods).getSingle();
    expect(food.deletedAt, isNotNull);
    expect(food.revision, 3);
    await tester.pumpAndSettle();
    expect(find.text('Personal yogurt'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });
}
