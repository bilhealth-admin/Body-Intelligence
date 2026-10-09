import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/first_meal_milestone.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_first_use_experience.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
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
      final guideBounds = tester.getRect(
        find.byKey(const Key('dashboard-food-guide-step-0')),
      );
      final underlyingBounds = tester.getRect(find.text('Underlying action'));
      expect(
        guideBounds.bottom,
        lessThanOrEqualTo(underlyingBounds.top),
        reason: 'Tutorial must not float over regular Home controls.',
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
      // Unmount Riverpod streams before Drift's zero-delay close timer.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));
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
    // Bounded frames avoid treating asynchronous SQLite stream disposal as
    // an endless pumpAndSettle animation during a widget test.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(const Key('dashboard-guide-skip')), findsNothing);
    expect(find.text('Home remains available'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  });
}
