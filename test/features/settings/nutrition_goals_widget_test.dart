import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/settings/reference_preferences_pages.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/nutrition/providers/nutrition_goal_defaults_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('corrupt persisted nutrition goal fails closed', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = PreferencesRepository(database);
    await repository.set('goal.calories', 'NaN');

    await _pumpGoals(tester, database, repository, withPlan: false);

    expect(find.text('NaN'), findsNothing);
    final calories = find.ancestor(
      of: find.text('Calories'),
      matching: find.byType(ListTile),
    );
    expect(find.descendant(of: calories, matching: find.text('—')), findsOne);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await database.close();
  });

  testWidgets('nutrition goal saves and clears through repository', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = PreferencesRepository(database);
    await _pumpGoals(tester, database, repository);

    await tester.tap(find.text('Calories'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), '2000');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await _waitFor(
      tester,
      () async =>
          await repository.get('goal.calories') == '2000.0' &&
          find.byType(AlertDialog).evaluate().isEmpty &&
          find.text('2000').evaluate().isNotEmpty,
    );
    expect(await repository.get('goal.calories'), '2000.0');
    expect(await repository.get('goal.carbsPercent'), '45.0');
    expect(await repository.get('goal.proteinPercent'), '30.0');
    expect(await repository.get('goal.fatPercent'), '25.0');
    expect(await repository.get('goal.carbsGrams'), '225.0');
    expect(await repository.get('goal.proteinGrams'), '150.0');
    expect(
      double.parse((await repository.get('goal.fatGrams'))!),
      closeTo(2000 * .25 / 9, .000001),
    );
    expect(find.text('2000'), findsOneWidget);

    await tester.tap(find.text('Calories'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(
      find.byKey(const ValueKey('restore-suggested-goal.calories')),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('confirm-goal-restore')), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-goal-restore')));
    await _waitFor(
      tester,
      () async =>
          await repository.get('goal.calories') == null &&
          find.byType(AlertDialog).evaluate().isEmpty,
    );
    expect(await repository.get('goal.calories'), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    // Finish the production editor's 250ms input-detach retirement window.
    await tester.pump(const Duration(milliseconds: 300));
    await database.close();
  });

  testWidgets('failed write keeps nutrition editor and draft open', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = _FailingNutritionPreferences(database);
    await _pumpGoals(tester, database, repository);

    await tester.tap(find.text('Calories'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), '2100');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await _waitFor(
      tester,
      () async => find.text('Could not save changes.').evaluate().isNotEmpty,
    );

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Could not save changes.'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '2100',
    );
    expect(await repository.get('goal.calories'), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await database.close();
  });

  testWidgets('failed explicit restore keeps draft and stored goal', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    await PreferencesRepository(database).set('goal.calories', '1900');
    final repository = _FailingNutritionPreferences(database);
    await _pumpGoals(tester, database, repository);

    await tester.tap(find.text('Calories'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(
      find.byKey(const ValueKey('restore-suggested-goal.calories')),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('confirm-goal-restore')), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-goal-restore')));
    await _waitFor(
      tester,
      () async => find.text('Could not save changes.').evaluate().isNotEmpty,
    );

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Could not save changes.'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '1900',
    );
    expect(await repository.get('goal.calories'), '1900');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await database.close();
  });
}

Future<void> _pumpGoals(
  WidgetTester tester,
  AppDatabase database,
  PreferencesRepository repository, {
  bool withPlan = true,
}) async {
  // Keep setup deterministic: the page owns several independent preference
  // reads, so advance exactly one frame and one async completion window.
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        preferencesRepositoryProvider.overrideWithValue(repository),
        if (withPlan)
          nutritionGoalDefaultsProvider.overrideWithValue(const {
            'goal.calories': 2000,
            'goal.carbsPercent': 45,
            'goal.proteinPercent': 30,
            'goal.fatPercent': 25,
          }),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: ReferenceNutritionGoalsPage(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

final class _FailingNutritionPreferences extends PreferencesRepository {
  _FailingNutritionPreferences(super.database);

  @override
  Future<bool> mutateIfUnchanged({
    required Map<String, String?> expected,
    Map<String, String> set = const {},
    Iterable<String> remove = const [],
    bool Function()? isCurrent,
  }) => throw StateError('Injected compare-and-swap storage failure');

  @override
  Future<void> setMany(Map<String, String> values) {
    throw StateError('Injected atomic write failure');
  }

  @override
  Future<void> mutate({
    Map<String, String> set = const {},
    Iterable<String> remove = const [],
  }) {
    throw StateError('Injected atomic mutation failure');
  }

  @override
  Future<void> set(String key, String value) {
    throw StateError('Injected write failure');
  }

  @override
  Future<void> remove(String key) {
    throw StateError('Injected remove failure');
  }
}

Future<void> _waitFor(
  WidgetTester tester,
  Future<bool> Function() ready,
) async {
  for (var frame = 0; frame < 100; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (await tester.runAsync(ready) == true) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  fail('The genuine SQLite save/error did not reach the expected UI state.');
}
