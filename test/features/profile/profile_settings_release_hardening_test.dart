import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/features/profile/profile_settings_page.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  _hardeningWidgets(
    'advanced age accepts only adult integers and finite measurements',
    (tester) async {
      await _pump(tester);
      final age = tester.widget<TextFormField>(
        find.byKey(const Key('profile-settings-age')),
      );
      for (final invalid in [
        '13',
        '17',
        '35.5',
        'NaN',
        'Infinity',
        '121',
        '',
        '0x12',
      ]) {
        expect(age.validator!(invalid), isNotNull, reason: invalid);
      }
      for (final valid in ['18', '35', '120', '١٨', '۳۵']) {
        expect(age.validator!(valid), isNull, reason: valid);
      }
      final weight = tester.widget<TextFormField>(
        find.byKey(const Key('profile-settings-weight')),
      );
      expect(weight.validator!('NaN'), isNotNull);
      expect(weight.validator!('Infinity'), isNotNull);
      expect(weight.validator!('٩٢٫٥'), isNull);
    },
  );

  _hardeningWidgets(
    'disabled exercise sentinel and unknown legacy exercise type cannot crash dropdowns',
    (tester) async {
      await _pump(tester, preferences: _LegacyExercisePreferences.new);
      await tester.drag(find.byType(ListView), const Offset(0, -1100));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
      expect(
        tester
            .widget<DropdownButtonFormField<int>>(
              find.byType(DropdownButtonFormField<int>),
            )
            .initialValue,
        3,
      );
    },
  );

  _hardeningWidgets(
    'failed hydration is caught and retry reads a fresh snapshot',
    (tester) async {
      final fixture = await _pump(tester, preferences: _ReadFailure.new);
      expect(
        find.byKey(const Key('profile-settings-hydration-retry')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.byKey(const Key('profile-settings-hydration-retry')),
      );
      await _settleHydration(tester);
      expect(find.byKey(const Key('profile-settings-age')), findsOneWidget);
      expect(
        fixture.router.routeInformationProvider.value.uri.path,
        '/advanced-body-measurements',
      );
    },
  );

  _hardeningWidgets(
    'timed out hydration cannot overwrite the successful retry',
    (tester) async {
      late _DelayedRead preferences;
      await _pump(
        tester,
        preferences: (db) => preferences = _DelayedRead(db),
        hydrationTimeout: const Duration(milliseconds: 500),
      );
      expect(
        find.byKey(const Key('profile-settings-hydration-retry')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('profile-settings-hydration-retry')),
      );
      await _settleHydration(tester);
      final name = tester.widget<TextFormField>(
        find.byType(TextFormField).first,
      );
      expect(name.controller!.text, 'Fresh name');
      preferences.stalled.complete('Stale name');
      await tester.pumpAndSettle();
      expect(name.controller!.text, 'Fresh name');
      expect(tester.takeException(), isNull);
    },
  );

  _hardeningWidgets(
    'save failure rolls back every repository and preserves user input',
    (tester) async {
      final fixture = await _pump(tester);
      await fixture.database.customStatement(
        "CREATE TRIGGER reject_profile_preferences BEFORE INSERT ON preferences WHEN NEW.key = 'nutrition.dietaryPreferences.v1' BEGIN SELECT RAISE(ABORT, 'injected durable write failure'); END",
      );
      await tester.enterText(
        find.byKey(const Key('profile-settings-weight')),
        '92.0',
      );
      await _save(tester);
      expect(
        find.text('Could not save. Your changes are still here. Try again.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      expect(
        (await UserProfileRepository(
          fixture.database,
        ).getProfile())!.currentWeight,
        93.4,
      );
      expect(
        await fixture.database.select(fixture.database.weightEntries).get(),
        isEmpty,
      );
      expect(
        await fixture.database.select(fixture.database.goals).get(),
        isEmpty,
      );
      expect(
        await PreferencesRepository(fixture.database).get('displayName'),
        isNull,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('profile-settings-weight')),
        -450,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('profile-settings-weight')),
            )
            .controller!
            .text,
        '92.0',
      );
      expect(
        fixture.router.routeInformationProvider.value.uri.path,
        '/advanced-body-measurements',
      );
    },
  );

  _hardeningWidgets(
    'current weight hydrates and saves through the authoritative ledger',
    (tester) async {
      final fixture = await _pump(tester, ledgerWeight: 91.2);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('profile-settings-weight')),
            )
            .controller!
            .text,
        '91.2',
      );
      await tester.enterText(
        find.byKey(const Key('profile-settings-weight')),
        '90.5',
      );
      await _save(tester);
      expect((await _latestWeight(fixture.database))!.weight, 90.5);
      expect(
        (await UserProfileRepository(
          fixture.database,
        ).getProfile())!.currentWeight,
        90.5,
      );
      expect(
        fixture.router.routeInformationProvider.value.uri.path,
        '/settings',
      );
    },
  );

  _hardeningWidgets(
    'double invocation commits exactly one save and unchanged weight is not fabricated',
    (tester) async {
      final fixture = await _pump(tester);
      final button = find.byKey(const Key('profile-settings-save'));
      await tester.scrollUntilVisible(
        button,
        450,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      final callback = tester.widget<FilledButton>(button).onPressed!;
      callback();
      callback();
      await tester.pumpAndSettle();
      expect(
        await fixture.database.select(fixture.database.goals).get(),
        hasLength(1),
      );
      expect(
        await fixture.database.select(fixture.database.weightEntries).get(),
        isEmpty,
      );
      expect(
        (await UserProfileRepository(fixture.database).getProfile())!.revision,
        2,
      );
    },
  );

  _hardeningWidgets(
    'a newer ledger measurement is not overwritten by unchanged editor state',
    (tester) async {
      final fixture = await _pump(tester, ledgerWeight: 91.2);
      await WeightRepository(fixture.database).addWeight(90.25);
      await _save(tester);
      expect((await _latestWeight(fixture.database))!.weight, 90.25);
      expect(
        (await UserProfileRepository(
          fixture.database,
        ).getProfile())!.currentWeight,
        90.25,
      );
    },
  );
}

Future<void> _save(WidgetTester tester) async {
  final button = find.byKey(const Key('profile-settings-save'));
  await tester.scrollUntilVisible(
    button,
    450,
    scrollable: find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<_Fixture> _pump(
  WidgetTester tester, {
  PreferencesRepository Function(AppDatabase)? preferences,
  Duration hydrationTimeout = const Duration(seconds: 8),
  double? ledgerWeight,
}) async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  await UserProfileRepository(database).save(
    gender: 'male',
    age: 35,
    height: 181,
    currentWeight: 93.4,
    targetWeight: 85,
    activityLevel: 'light',
    exercises: true,
  );
  if (ledgerWeight != null) {
    await WeightRepository(database).addWeight(ledgerWeight);
  }
  final router = GoRouter(
    initialLocation: '/advanced-body-measurements',
    routes: [
      GoRoute(
        path: '/advanced-body-measurements',
        builder: (_, _) =>
            ProfileSettingsPage(hydrationTimeout: hydrationTimeout),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const Scaffold(body: Text('Settings')),
      ),
    ],
  );
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        if (preferences != null)
          preferencesRepositoryProvider.overrideWithValue(
            preferences(database),
          ),
      ],
      child: MaterialApp.router(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
      ),
    ),
  );
  _activeFixture = _Fixture(database, router);
  await _settleHydration(tester);
  return _Fixture(database, router);
}

Future<void> _settleHydration(WidgetTester tester) async {
  await tester.pump();
  for (
    var attempt = 0;
    attempt < 100 &&
        find.byKey(const Key('profile-settings-age')).evaluate().isEmpty &&
        find
            .byKey(const Key('profile-settings-hydration-retry'))
            .evaluate()
            .isEmpty;
    attempt++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

class _Fixture {
  const _Fixture(this.database, this.router);
  final AppDatabase database;
  final GoRouter router;
}

_Fixture? _activeFixture;
Future<WeightEntry?> _latestWeight(AppDatabase database) =>
    (database.select(database.weightEntries)
          ..where((row) => row.deletedAt.isNull())
          ..orderBy([(row) => OrderingTerm.desc(row.date)])
          ..limit(1))
        .getSingleOrNull();

void _hardeningWidgets(String name, WidgetTesterCallback body) {
  testWidgets(name, (tester) async {
    try {
      await body(tester);
    } finally {
      final fixture = _activeFixture;
      _activeFixture = null;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      fixture?.router.dispose();
      await fixture?.database.close();
      await tester.pump();
      await tester.binding.setSurfaceSize(null);
    }
  });
}

class _ReadFailure extends PreferencesRepository {
  _ReadFailure(super.database);
  bool fail = true;
  @override
  Future<String?> get(String key) {
    if (key == 'weeklyExerciseSessions' && fail) {
      fail = false;
      return Future.error(StateError('injected hydration failure'));
    }
    return super.get(key);
  }
}

class _DelayedRead extends PreferencesRepository {
  _DelayedRead(super.database);
  final stalled = Completer<String?>();
  bool first = true;
  @override
  Future<String?> get(String key) {
    if (key == 'displayName') {
      if (first) {
        first = false;
        return stalled.future;
      }
      return Future.value('Fresh name');
    }
    return super.get(key);
  }
}

class _LegacyExercisePreferences extends PreferencesRepository {
  _LegacyExercisePreferences(super.database);
  @override
  Future<String?> get(String key) {
    if (key == 'weeklyExerciseSessions') return Future.value('0');
    if (key == 'exerciseType') return Future.value('unknown_legacy_type');
    return super.get(key);
  }
}
