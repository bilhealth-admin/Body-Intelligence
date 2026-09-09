import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/analytics/weekly_report_engine.dart';
import 'package:body_intelligence_log/features/analytics/weekly_report_page.dart';
import 'package:body_intelligence_log/features/analytics/weekly_report_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/nutrition/domain/dietary_preferences.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  test(
    'historical weekly report selection starts today and persists a week',
    () {
      final today = DateTime(2026, 8, 11, 18, 30);
      final container = ProviderContainer(
        overrides: [weeklyReportClockProvider.overrideWithValue(() => today)],
      );
      addTearDown(container.dispose);

      expect(container.read(selectedWeeklyReportDateProvider), today);
      container.read(selectedWeeklyReportDateProvider.notifier).state = today
          .subtract(const Duration(days: 7));
      expect(
        container.read(selectedWeeklyReportDateProvider),
        DateTime(2026, 8, 4, 18, 30),
      );
    },
  );

  testWidgets('previous-week action changes the report repository window', (
    tester,
  ) async {
    final today = DateTime(2026, 8, 11);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final report = const WeeklyReportEngine().build(
      asOf: DateTime(2026, 8, 11),
      nutrition: const [],
      water: const [],
      weights: const [],
      mealCount: 0,
    );
    final container = ProviderContainer(
      overrides: [
        weeklyReportClockProvider.overrideWithValue(() => today),
        weeklyReportProvider.overrideWith((ref) async => report),
        accountCreatedAtProvider.overrideWithValue(null),
        userProfileProvider.overrideWith((ref) => Stream.value(null)),
        preferencesRepositoryProvider.overrideWithValue(
          PreferencesRepository(database),
        ),
        dietaryPreferencesProvider.overrideWith(
          (ref) => Stream.value(const DietaryPreferences()),
        ),
        verifiedSubscriptionStateProvider.overrideWithValue(
          AsyncData(FreePlan.createState()),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: WeeklyReportPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('weekly-report-previous')));
    await tester.pump();
    expect(
      container.read(selectedWeeklyReportDateProvider),
      DateTime(2026, 8, 4),
    );
  });

  testWidgets('first opening moves from loading to the digest without reopen', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final report = _emptyReport();
    final pending = Completer<WeeklyReportSnapshot>();

    await tester.pumpWidget(
      _weeklyApp(database: database, load: () => pending.future),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('weekly-pulse-hero')), findsNothing);

    pending.complete(report);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('weekly-pulse-hero')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('failed first load exposes a retry that renders the digest', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    var attempts = 0;

    await tester.pumpWidget(
      _weeklyApp(
        database: database,
        load: () async {
          attempts++;
          if (attempts == 1) throw StateError('read failed');
          return _emptyReport();
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('weekly-report-retry')), findsOneWidget);
    expect(find.byKey(const Key('weekly-pulse-hero')), findsNothing);

    await tester.tap(find.byKey(const Key('weekly-report-retry')));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.byKey(const Key('weekly-pulse-hero')), findsOneWidget);
  });
}

WeeklyReportSnapshot _emptyReport() => const WeeklyReportEngine().build(
  asOf: DateTime(2026, 8, 11),
  nutrition: const [],
  water: const [],
  weights: const [],
  mealCount: 0,
);

Widget _weeklyApp({
  required AppDatabase database,
  required Future<WeeklyReportSnapshot> Function() load,
}) => ProviderScope(
  overrides: [
    weeklyReportProvider.overrideWith((ref) => load()),
    accountCreatedAtProvider.overrideWithValue(null),
    userProfileProvider.overrideWith((ref) => Stream.value(null)),
    preferencesRepositoryProvider.overrideWithValue(
      PreferencesRepository(database),
    ),
    dietaryPreferencesProvider.overrideWith(
      (ref) => Stream.value(const DietaryPreferences()),
    ),
    verifiedSubscriptionStateProvider.overrideWithValue(
      AsyncData(FreePlan.createState()),
    ),
  ],
  child: const MaterialApp(
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: WeeklyReportPage(),
  ),
);
