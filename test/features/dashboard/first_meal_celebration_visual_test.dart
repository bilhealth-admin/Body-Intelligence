import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/first_meal_milestone.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/first_meal_celebration.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
