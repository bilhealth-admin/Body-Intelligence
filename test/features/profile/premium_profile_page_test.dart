import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/goal_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/features/nutrition/domain/dietary_preferences.dart';
import 'package:body_intelligence_log/features/nutrition/repositories/dietary_preferences_repository.dart';
import 'package:body_intelligence_log/features/profile/premium_profile_page.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('profile save persists profile goal and preferences together', (
    tester,
  ) async {
    final database = await _seedDatabase();
    await _pumpProfile(tester, database);

    await tester.drag(
      find.byKey(const Key('premium-profile-list')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-settings-save')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Your health profile is updated.'), findsWidgets);
    expect(await PreferencesRepository(database).get('displayName'), 'BIL');
    final goal = await (database.select(
      database.goals,
    )..limit(1)).getSingleOrNull();
    expect(goal?.type, 'lose');
    expect(goal?.targetWeight, 85);
    final profile = await UserProfileRepository(database).getProfile();
    expect(profile?.currentWeight, 93.4);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await database.close();
  });

  testWidgets('failed profile transaction rolls back and exposes retry error', (
    tester,
  ) async {
    final database = await _seedDatabase();
    await _pumpProfile(
      tester,
      database,
      preferences: _FailingPreferencesRepository(database),
    );

    await tester.drag(
      find.byKey(const Key('premium-profile-list')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-settings-save')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.text('Your health profile could not be saved. Try again.'),
      findsWidgets,
    );
    expect(
      await (database.select(database.goals)..limit(1)).getSingleOrNull(),
      isNull,
    );
    expect(await PreferencesRepository(database).get('displayName'), isNull);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('profile-settings-save')))
          .onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await database.close();
  });

  testWidgets(
    'dietary summary row shows saved choice and opens profile origin',
    (tester) async {
      final database = await _seedDatabase();
      await DietaryPreferencesRepository(PreferencesRepository(database)).save(
        const DietaryPreferences(
          pattern: DietaryPattern.vegan,
          approach: 'high_protein',
        ),
      );
      final router = GoRouter(
        initialLocation: '/profile-settings',
        routes: [
          GoRoute(
            path: '/profile-settings',
            builder: (_, _) => const PremiumProfilePage(),
          ),
          GoRoute(
            path: '/plan',
            builder: (_, state) => Scaffold(
              body: Text(
                'plan-origin:${state.uri.queryParameters['origin']}',
                key: const Key('plan-origin-probe'),
              ),
            ),
          ),
        ],
      );
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(database)],
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
      await tester.pumpAndSettle();

      final row = find.byKey(const Key('profile-dietary-system-row'));
      await tester.ensureVisible(row);
      expect(find.text('Dietary system'), findsOneWidget);
      expect(find.text('Vegan · High protein'), findsOneWidget);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('plan-origin-probe')), findsOneWidget);
      expect(find.text('plan-origin:profile'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      router.dispose();
      await database.close();
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets(
    'goal timeline reacts live to a changed goal and remains after save',
    (tester) async {
      final database = await _seedDatabase();
      await _pumpProfile(tester, database);

      final timeline = find.byKey(const Key('estimated-time-to-goal-value'));
      await tester.scrollUntilVisible(
        timeline,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      final before = tester.widget<Text>(timeline).data;
      final goalRow = find.text('Goal weight');
      await tester.ensureVisible(goalRow);
      await tester.tap(goalRow);
      await tester.pumpAndSettle();
      final editor = find.byType(TextField).last;
      await tester.enterText(editor, '92');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(timeline);
      final live = tester.widget<Text>(timeline).data;
      expect(live, isNot(before));
      final save = find.byKey(const Key('profile-settings-save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(
        (await UserProfileRepository(database).getProfile())?.targetWeight,
        92,
      );
      expect(tester.widget<Text>(timeline).data, live);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await database.close();
    },
  );

  testWidgets(
    'health-goal weight edit writes the authoritative measurement and preserves direction',
    (tester) async {
      final database = await _seedDatabase();
      final profiles = UserProfileRepository(database);
      final profile = (await profiles.getProfile())!;
      await WeightRepository(
        database,
      ).addWeight(93.4, date: DateTime(2026, 8, 20));
      await GoalRepository(
        database,
      ).save(profileUuid: profile.uuid, type: 'lose', targetWeight: 85);
      await _pumpProfile(tester, database);

      final currentWeightRow = find.text('Current weight');
      await tester.scrollUntilVisible(
        currentWeightRow,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(currentWeightRow);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '84');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      final save = find.byKey(const Key('profile-settings-save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect((await profiles.getProfile())?.currentWeight, 84);
      expect((await WeightRepository(database).getAll()).first.weight, 84);
      expect(
        (await (database.select(database.goals)..limit(1)).getSingle()).type,
        'lose',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await database.close();
    },
  );
}

Future<AppDatabase> _seedDatabase() async {
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
  return database;
}

Future<void> _pumpProfile(
  WidgetTester tester,
  AppDatabase database, {
  PreferencesRepository? preferences,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        if (preferences != null)
          preferencesRepositoryProvider.overrideWithValue(preferences),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: PremiumProfilePage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _FailingPreferencesRepository extends PreferencesRepository {
  _FailingPreferencesRepository(super.database);

  @override
  Future<void> setManyInCurrentTransaction(Map<String, String> values) {
    throw StateError('Injected preference failure');
  }
}
