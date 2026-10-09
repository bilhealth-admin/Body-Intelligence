import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/first_meal_milestone.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_first_use_experience.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'empty meal bucket shows optional steps and Skip dismisses them',
    (tester) async {
      final database = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'owner-a',
      );
      addTearDown(database.close);
      final preferences = PreferencesRepository(database);
      await MealRepository(database).createMeal(
        date: DateTime(2026, 10, 10),
        name: 'breakfast',
        type: 'breakfast',
      );
      var underlayTapped = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(database)],
          child: MaterialApp(
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar'), Locale('en')],
            home: Scaffold(
              body: DashboardFirstUseExperience(
                ownerScope: 'owner-a',
                ownerReady: true,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: TextButton(
                    onPressed: () => underlayTapped = true,
                    child: const Text('Underlying action'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('dashboard-food-guide-step-0')),
        findsOneWidget,
      );
      await tester.tap(find.text('Underlying action'));
      expect(underlayTapped, isTrue);
      await tester.tap(find.byKey(const Key('dashboard-guide-next')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('dashboard-food-guide-step-1')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('dashboard-guide-skip')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dashboard-guide-skip')), findsNothing);
      expect(
        await preferences.get('experience.dashboard_food_guide.v1.owner-a'),
        'dismissed',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('completed first food does not reopen the tutorial', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: 'owner-a',
    );
    addTearDown(database.close);
    await PreferencesRepository(
      database,
    ).set(firstMealCelebrationPreferenceKey, 'done');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(
          home: Scaffold(
            body: DashboardFirstUseExperience(
              ownerScope: 'owner-a',
              ownerReady: true,
              child: Center(child: Text('Home remains available')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard-guide-skip')), findsNothing);
    expect(find.text('Home remains available'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
