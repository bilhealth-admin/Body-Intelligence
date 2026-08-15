import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/settings/reference_preferences_pages.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
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

    await _pumpGoals(tester, database, repository);

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
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 300));
    expect(await repository.get('goal.calories'), '2000');
    expect(find.text('2000'), findsOneWidget);

    await tester.tap(find.text('Calories'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 300));
    expect(await repository.get('goal.calories'), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
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
    await tester.pump(const Duration(milliseconds: 500));

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

  testWidgets('failed clear keeps empty draft and stored goal', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    await PreferencesRepository(database).set('goal.calories', '1900');
    final repository = _FailingNutritionPreferences(database);
    await _pumpGoals(tester, database, repository);

    await tester.tap(find.text('Calories'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Could not save changes.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, '');
    expect(await repository.get('goal.calories'), '1900');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await database.close();
  });
}

Future<void> _pumpGoals(
  WidgetTester tester,
  AppDatabase database,
  PreferencesRepository repository,
  ) async {
  // Keep setup deterministic: the page owns several independent preference
  // reads, so advance exactly one frame and one async completion window.
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        preferencesRepositoryProvider.overrideWithValue(repository),
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
  Future<void> set(String key, String value) {
    throw StateError('Injected write failure');
  }

  @override
  Future<void> remove(String key) {
    throw StateError('Injected remove failure');
  }
}
