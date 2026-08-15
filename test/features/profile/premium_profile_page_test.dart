import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/features/profile/premium_profile_page.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
