import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/data/repositories/goal_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/settings/settings_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('More uses latest measured weight and signs target deviation', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await UserProfileRepository(database).save(
      gender: 'male',
      age: 35,
      height: 181,
      currentWeight: 90,
      targetWeight: 90,
      activityLevel: 'light',
      exercises: true,
    );
    await WeightRepository(
      database,
    ).addWeight(89.2, date: DateTime(2026, 8, 20));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          verifiedSubscriptionStateProvider.overrideWithValue(
            AsyncData(FreePlan.createState()),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('89.2 kg'), findsOneWidget);
    expect(find.text('-0.8 kg'), findsOneWidget);
    expect(find.text('90.0 kg'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(Duration.zero);
    await tester.pump(Duration.zero);
  });

  testWidgets('More live-updates from goal and current-weight repositories', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final profiles = UserProfileRepository(database);
    final weights = WeightRepository(database);
    final goals = GoalRepository(database);
    await profiles.save(
      gender: 'male',
      age: 35,
      height: 181,
      currentWeight: 90,
      targetWeight: 80,
      activityLevel: 'light',
      exercises: true,
    );
    final profile = (await profiles.getProfile())!;
    final goalId = await goals.save(
      profileUuid: profile.uuid,
      type: 'lose',
      targetWeight: 80,
    );
    final activeGoal = await (database.select(
      database.goals,
    )..where((row) => row.id.equals(goalId))).getSingle();
    await weights.addWeight(90, date: DateTime(2026, 8, 20));

    await tester.pumpWidget(_moreApp(database));
    await tester.pumpAndSettle();
    expect(find.text('+10.0 kg'), findsOneWidget);

    await goals.save(
      uuid: activeGoal.uuid,
      profileUuid: profile.uuid,
      type: 'lose',
      targetWeight: 85,
    );
    await tester.pumpAndSettle();
    expect(find.text('90.0 kg'), findsOneWidget);
    expect(find.text('+5.0 kg'), findsOneWidget);
    expect(find.text('85.0 kg'), findsOneWidget);

    await weights.addWeight(84, date: DateTime(2026, 8, 29));
    await tester.pumpAndSettle();
    expect(find.text('84.0 kg'), findsOneWidget);
    expect(find.text('-1.0 kg'), findsOneWidget);
    expect(find.text('85.0 kg'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(Duration.zero);
    await tester.pump(Duration.zero);
  });

  testWidgets('signed target difference survives a provider session restore', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final profiles = UserProfileRepository(database);
    await profiles.save(
      gender: 'female',
      age: 31,
      height: 168,
      currentWeight: 79,
      targetWeight: 80,
      activityLevel: 'moderate',
      exercises: true,
    );
    final profile = (await profiles.getProfile())!;
    await GoalRepository(
      database,
    ).save(profileUuid: profile.uuid, type: 'lose', targetWeight: 80);
    await WeightRepository(database).addWeight(79, date: DateTime(2026, 8, 29));

    await tester.pumpWidget(_moreApp(database));
    await tester.pumpAndSettle();
    expect(find.text('-1.0 kg'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(Duration.zero);
    await tester.pump(Duration.zero);
    await tester.pumpWidget(_moreApp(database));
    await tester.pumpAndSettle();
    expect(find.text('-1.0 kg'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(Duration.zero);
    await tester.pump(Duration.zero);
  });

  testWidgets('More converts all three goal metrics to the selected lb unit', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final profiles = UserProfileRepository(database);
    await profiles.save(
      gender: 'male',
      age: 35,
      height: 181,
      currentWeight: 90,
      targetWeight: 80,
      activityLevel: 'light',
      exercises: true,
    );
    final profile = (await profiles.getProfile())!;
    await GoalRepository(
      database,
    ).save(profileUuid: profile.uuid, type: 'lose', targetWeight: 80);
    await WeightRepository(database).addWeight(90, date: DateTime(2026, 8, 29));
    await PreferencesRepository(database).set('units', 'imperial');

    await tester.pumpWidget(_moreApp(database));
    await tester.pumpAndSettle();

    expect(find.text('198.4 lb'), findsOneWidget);
    expect(find.text('+22.0 lb'), findsOneWidget);
    expect(find.text('176.4 lb'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(Duration.zero);
    await tester.pump(Duration.zero);
  });
}

Widget _moreApp(AppDatabase database) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(database),
    verifiedSubscriptionStateProvider.overrideWithValue(
      AsyncData(FreePlan.createState()),
    ),
  ],
  child: const MaterialApp(
    locale: Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: SettingsPage(),
  ),
);
