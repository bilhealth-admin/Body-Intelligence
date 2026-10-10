import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/daily_log/food_log_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Food Log search guide can be skipped without blocking food', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: 'owner-a',
    );
    addTearDown(database.close);
    final preferences = PreferencesRepository(database);
    await preferences.set(
      'experience.dashboard_food_guide.v1.owner-a',
      'started',
    );
    final foodId = await FoodRepository(database).addFood(
      name: 'First apple',
      category: 'fruit',
      calories: 52,
      protein: 0.3,
      carbs: 14,
      fats: 0.2,
      servingSize: 100,
      servingUnit: 'g',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(
          locale: Locale('ar'),
          supportedLocales: [Locale('ar'), Locale('en')],
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: FoodLogPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('food-log-search-guide')), findsOneWidget);
    expect(find.byKey(const Key('food-log-search')), findsOneWidget);
    await tester.tap(find.byKey(const Key('food-log-search-guide-skip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('food-log-search-guide')), findsNothing);
    expect(
      await preferences.get('experience.dashboard_food_guide.v1.owner-a'),
      'dismissed',
    );
    expect(find.byKey(const Key('food-log-search')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(Key('food-log-add-$foodId')),
      160,
    );
    expect(find.byKey(Key('food-log-add-$foodId')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('quantity coachmark Skip leaves editable serving dialog open', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: 'owner-b',
    );
    addTearDown(database.close);
    final preferences = PreferencesRepository(database);
    await preferences.set(
      'experience.dashboard_food_guide.v1.owner-b',
      'started',
    );
    final foodId = await FoodRepository(database).addFood(
      name: 'First banana',
      category: 'fruit',
      calories: 89,
      protein: 1,
      carbs: 23,
      fats: 0.3,
      servingSize: 100,
      servingUnit: 'g',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: FoodLogPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(Key('food-log-add-$foodId')),
      160,
    );
    await tester.tap(find.byKey(Key('food-log-add-$foodId')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('food-log-quantity-guide')), findsOneWidget);
    expect(
      find.byKey(const Key('food-log-serving-quantity-field')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('food-log-quantity-guide-skip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('food-log-quantity-guide')), findsNothing);
    expect(
      find.byKey(const Key('food-log-serving-quantity-field')),
      findsOneWidget,
    );
    expect(
      await preferences.get('experience.dashboard_food_guide.v1.owner-b'),
      'dismissed',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  });
}
