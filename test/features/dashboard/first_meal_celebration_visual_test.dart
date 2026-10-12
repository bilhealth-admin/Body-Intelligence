import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/first_meal_milestone.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/first_meal_celebration.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'retired route before first painted frame preserves ready for retry',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final preferences = PreferencesRepository(database);
      await preferences.set(firstMealCelebrationPreferenceKey, 'ready');
      addTearDown(database.close);
      late BuildContext surface;
      var visitCurrent = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              surface = context;
              return const Scaffold(body: Text('Food remains committed'));
            },
          ),
        ),
      );
      expect(
        await FirstMealCelebration.showIfPending(
          surface,
          preferences,
          ownerIsCurrent: () => visitCurrent,
        ),
        isTrue,
      );
      // A concurrent caller cannot claim the same presentation before paint.
      expect(
        await FirstMealCelebration.showIfPending(surface, preferences),
        isFalse,
      );
      expect(await preferences.get(firstMealCelebrationPreferenceKey), 'ready');
      visitCurrent = false;
      await tester.pump();
      await tester.pump();
      expect(await preferences.get(firstMealCelebrationPreferenceKey), 'ready');
      expect(
        find.byKey(const Key('dashboard-first-food-celebration')),
        findsNothing,
      );
      visitCurrent = true;
      expect(
        await FirstMealCelebration.showIfPending(
          surface,
          preferences,
          ownerIsCurrent: () => visitCurrent,
        ),
        isTrue,
      );
      await tester.pump();
      expect(await preferences.get(firstMealCelebrationPreferenceKey), 'done');
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('first successful marker celebrates once and arms streak tip', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final preferences = PreferencesRepository(database);
    await preferences.set(firstMealCelebrationPreferenceKey, 'ready');
    late BuildContext homeContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            homeContext = context;
            return const Scaffold(
              body: Center(child: Text('Home stays clickable')),
            );
          },
        ),
      ),
    );

    expect(
      await FirstMealCelebration.showIfPending(homeContext, preferences),
      isTrue,
    );
    await tester.pump();
    expect(
      find.byKey(const Key('dashboard-first-food-celebration')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.celebration_rounded), findsOneWidget);
    expect(await preferences.get(firstMealCelebrationPreferenceKey), 'done');
    expect(await preferences.get(firstMealStreakGuidePreferenceKey), 'ready');
    expect(
      await FirstMealCelebration.showIfPending(homeContext, preferences),
      isFalse,
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(
      find.byKey(const Key('dashboard-first-food-celebration')),
      findsNothing,
    );
    expect(find.text('Home stays clickable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
