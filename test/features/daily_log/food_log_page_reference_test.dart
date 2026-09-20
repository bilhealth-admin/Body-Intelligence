import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/features/daily_log/food_log_page.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/foods/providers/food_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Food Log shows the all-foods surface without tabs', (
    tester,
  ) async {
    final food = Food(
      id: 1,
      uuid: 'food-1',
      name: 'Boiled Eggs',
      arabicName: 'بيض مسلوق',
      category: 'Breakfast',
      keywords: 'boiled, eggs, breakfast',
      servingSize: 1,
      servingUnit: 'egg',
      calories: 72,
      protein: 6,
      carbs: 0.4,
      fats: 5,
      fiber: 0,
      sugar: 0,
      sodium: 62,
      potassium: 63,
      calcium: 25,
      magnesium: 5,
      phosphorus: 86,
      iron: 1,
      vitaminC: 0,
      nutrientEvidenceMask: 0,
      source: 'test',
      verified: true,
      isCustom: false,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
      revision: 1,
      syncStatus: 'local',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          foodsProvider.overrideWithValue(AsyncData([food])),
          foodLogPopularFoodsProvider.overrideWithValue(AsyncData([food])),
          selectedLogDateProvider.overrideWith((ref) => DateTime(2026, 9, 11)),
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
          home: const FoodLogPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('food-log-reference-page')), findsOneWidget);
    expect(find.byKey(const Key('food-log-select-meal')), findsOneWidget);
    expect(find.byKey(const Key('food-log-search')), findsOneWidget);
    expect(find.byKey(const Key('food-log-tab-all')), findsNothing);
    expect(find.byKey(const Key('food-log-tab-meals')), findsNothing);
    expect(find.byKey(const Key('food-log-tab-recipes')), findsNothing);
    expect(find.byKey(const Key('food-log-tab-foods')), findsNothing);
    expect(find.text('All'), findsNothing);
    expect(find.text('My meals'), findsNothing);
    expect(find.text('My recipes'), findsNothing);
    expect(find.text('My foods'), findsNothing);
    expect(find.text('Most popular'), findsOneWidget);
    expect(
      find.byKey(const Key('food-log-action-Barcode scan')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('food-log-action-Voice log')), findsOneWidget);
    expect(find.byKey(const Key('food-log-action-Quick add')), findsOneWidget);
    expect(find.text('Meal scan'), findsNothing);
    expect(find.text('Boiled Eggs'), findsOneWidget);

    await tester.tap(find.byKey(const Key('food-log-select-meal')));
    await tester.pumpAndSettle();
    expect(find.text('Lunch'), findsOneWidget);
  });
}
