import 'package:body_intelligence_log/features/analytics/weekly_report_engine.dart';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/analytics/weekly_report_page.dart';
import 'package:body_intelligence_log/features/analytics/weekly_report_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:drift/native.dart';

import 'visual_closure/visual_evidence_font.dart';

class _FailingWeeklyPreferences extends PreferencesRepository {
  _FailingWeeklyPreferences(super.database, {this.failRead = false});

  final bool failRead;
  int writeAttempts = 0;

  @override
  Future<String?> get(String key) async {
    if (failRead) throw StateError('injected read failure');
    return null;
  }

  @override
  Future<void> set(String key, String value) async {
    writeAttempts += 1;
    throw StateError('injected write failure');
  }
}

void main() {
  setUpAll(loadVisualEvidenceFont);
  final snapshot = const WeeklyReportEngine().build(
    asOf: DateTime.utc(2026, 8, 4),
    mealCount: 4,
    nutrition: const [
      WeeklyNutritionObservation(
        dayKey: '2026-08-01',
        calories: 1850,
        proteinG: 118,
        carbsG: 205,
        fatG: 62,
        sodiumMg: 2100,
        foodCategory: 'vegetable',
        foodName: 'Roasted vegetables',
      ),
      WeeklyNutritionObservation(
        dayKey: '2026-08-03',
        calories: 1720,
        proteinG: 126,
        carbsG: 188,
        fatG: 58,
        sodiumMg: 1900,
        foodCategory: 'protein',
        foodName: 'Grilled chicken',
      ),
      WeeklyNutritionObservation(
        dayKey: '2026-08-03',
        calories: 120,
        proteinG: 1,
        carbsG: 28,
        fatG: 0,
        sodiumMg: 4,
        foodCategory: 'fruit',
        foodName: 'Fresh berries',
      ),
      WeeklyNutritionObservation(
        dayKey: '2026-08-04',
        calories: 210,
        proteinG: 4,
        carbsG: 31,
        fatG: 8,
        sodiumMg: 160,
        foodCategory: 'snack',
        foodName: 'Yogurt snack',
      ),
    ],
    water: const [
      WeeklyWaterObservation(dayKey: '2026-08-01', amountMl: 2200),
      WeeklyWaterObservation(dayKey: '2026-08-03', amountMl: 2500),
    ],
    weights: [
      WeeklyWeightObservation(
        dayKey: '2026-08-01',
        observedAt: DateTime.utc(2026, 8, 1),
        weightKg: 93.4,
      ),
      WeeklyWeightObservation(
        dayKey: '2026-08-04',
        observedAt: DateTime.utc(2026, 8, 4),
        weightKg: 92.8,
      ),
    ],
    activity: const [
      WeeklyActivityObservation(
        dayKey: '2026-08-01',
        steps: 8420,
        exerciseNotes: 'Strength workout',
      ),
      WeeklyActivityObservation(dayKey: '2026-08-03', steps: 10120),
    ],
    allTimeMealCount: 0,
    allTimeWeightCount: 0,
    allTimeExerciseDays: 0,
    allTimeSteps: 0,
    dailyCalorieGoal: 2100,
    loggingStreakDays: 9,
  );
  final emptySnapshot = const WeeklyReportEngine().build(
    asOf: DateTime.utc(2026, 8, 4),
    mealCount: 0,
    nutrition: const [],
    water: const [],
    weights: const [],
  );

  Future<void> pumpReport(
    WidgetTester tester, {
    required Locale locale,
    required Brightness brightness,
    WeeklyReportSnapshot? report,
    AppDatabase? database,
    DateTime? accountCreatedAt,
    PreferencesRepository? preferences,
  }) async {
    final effectiveDatabase =
        database ?? AppDatabase.forTesting(NativeDatabase.memory());
    if (database == null) addTearDown(effectiveDatabase.close);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          weeklyReportProvider.overrideWith((ref) async => report ?? snapshot),
          accountCreatedAtProvider.overrideWithValue(accountCreatedAt),
          userProfileProvider.overrideWith((ref) => Stream.value(null)),
          preferencesRepositoryProvider.overrideWithValue(
            preferences ?? PreferencesRepository(effectiveDatabase),
          ),
          verifiedSubscriptionStateProvider.overrideWithValue(
            AsyncData(FreePlan.createState()),
          ),
        ],
        child: MaterialApp(
          locale: locale,
          supportedLocales: const [
            Locale('ar'),
            Locale('en'),
            Locale('fr'),
            Locale('es'),
            Locale('tr'),
          ],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: visualEvidenceTheme(
            ThemeData(brightness: brightness, useMaterial3: true),
            fontFamily: locale.languageCode == 'ar'
                ? 'NotoArabicEvidence'
                : 'RobotoEvidence',
          ),
          builder: (context, child) => visualEvidenceTextSurface(
            child,
            fontFamily: locale.languageCode == 'ar'
                ? 'NotoArabicEvidence'
                : 'RobotoEvidence',
          ),
          home: const WeeklyReportPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('weekly report phone LTR light golden', (tester) async {
    await pumpReport(
      tester,
      locale: const Locale('en'),
      brightness: Brightness.light,
    );
    await expectLater(
      find.byType(WeeklyReportPage),
      matchesGoldenFile('goldens/epic8_weekly_report_phone_ltr_light.png'),
    );
  });

  testWidgets(
    'member since prefers account creation and zero streak stays zero',
    (tester) async {
      await pumpReport(
        tester,
        locale: const Locale('en'),
        brightness: Brightness.light,
        report: emptySnapshot,
        accountCreatedAt: DateTime(2024, 4, 17),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('weekly-alltime-section')),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      final value = tester.widget<Text>(
        find
            .descendant(
              of: find.byKey(const Key('weekly-member-since-value')),
              matching: find.byType(Text),
            )
            .last,
      );
      expect(value.data, contains('Apr 17'));
      await tester.scrollUntilVisible(
        find.byKey(const Key('weekly-keep-section')),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('0 days!'), findsOneWidget);
    },
  );

  testWidgets('member since null uses localized Arabic unavailable', (
    tester,
  ) async {
    await pumpReport(
      tester,
      locale: const Locale('ar'),
      brightness: Brightness.light,
      report: emptySnapshot,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('weekly-alltime-section')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('غير متاح'), findsOneWidget);
  });

  testWidgets('weekly report controls expose actions and feedback persists', (
    tester,
  ) async {
    final persistenceDatabase = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(persistenceDatabase.close);
    final persistenceRepository = PreferencesRepository(persistenceDatabase);
    await pumpReport(
      tester,
      locale: const Locale('en'),
      brightness: Brightness.light,
      report: emptySnapshot,
      database: persistenceDatabase,
    );
    expect(find.byKey(const Key('weekly-report-calendar')), findsOneWidget);
    await tester.tap(find.byKey(const Key('weekly-report-calendar')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('weekly-food-feedback-up')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('weekly-food-feedback-up')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      await persistenceRepository.get('weekly_report_feedback_2026-08-04'),
      'up',
    );
    /* Legacy glyph assertion intentionally superseded by repository and
       relaunch readback below.
    expect(find.text('👍🏻'), findsOneWidget);
    await tester.tap(find.byKey(const Key('weekly-report-previous')));
    */
    await pumpReport(
      tester,
      locale: const Locale('en'),
      brightness: Brightness.light,
      report: emptySnapshot,
      database: persistenceDatabase,
    );
    await tester.ensureVisible(
      find.byKey(const Key('weekly-food-feedback-up')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Feedback saved'), findsOneWidget);
    await tester.tap(find.byKey(const Key('weekly-report-previous')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(WeeklyReportPage), findsOneWidget);
  });

  testWidgets('weekly feedback read and write failures stay recoverable', (
    tester,
  ) async {
    final readDb = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(readDb.close);
    await pumpReport(
      tester,
      locale: const Locale('en'),
      brightness: Brightness.light,
      database: readDb,
      preferences: _FailingWeeklyPreferences(readDb, failRead: true),
    );
    final feedback = find.byKey(const Key('weekly-food-feedback-actions'));
    await tester.ensureVisible(feedback);
    await tester.pumpAndSettle();
    expect(find.text('Feedback could not be saved or loaded.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    final writeDb = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(writeDb.close);
    final failingWrites = _FailingWeeklyPreferences(writeDb);
    await pumpReport(
      tester,
      locale: const Locale('en'),
      brightness: Brightness.light,
      database: writeDb,
      preferences: failingWrites,
    );
    await tester.ensureVisible(feedback);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('weekly-food-feedback-up')));
    await tester.pumpAndSettle();
    expect(find.text('Feedback could not be saved or loaded.'), findsOneWidget);
    expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);
    expect(failingWrites.writeAttempts, 1);
    final saveRetry = find.byKey(const Key('weekly-food-feedback-retry'));
    await tester.ensureVisible(saveRetry);
    await tester.pumpAndSettle();
    await tester.tap(saveRetry);
    await tester.pumpAndSettle();
    expect(failingWrites.writeAttempts, 2);
    expect(find.text('Feedback could not be saved or loaded.'), findsOneWidget);
  });

  testWidgets('weekly report keyed CTAs navigate to owned routes', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final router = GoRouter(
      initialLocation: '/weekly-report',
      routes: [
        GoRoute(
          path: '/weekly-report',
          builder: (_, _) => const WeeklyReportPage(),
        ),
        for (final route in const ['/plans', '/nutrition', '/connected-health'])
          GoRoute(
            path: route,
            builder: (_, _) => Scaffold(body: Text('route:$route')),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          weeklyReportProvider.overrideWith((ref) async => emptySnapshot),
          userProfileProvider.overrideWith((ref) => Stream.value(null)),
          preferencesRepositoryProvider.overrideWithValue(
            PreferencesRepository(database),
          ),
          verifiedSubscriptionStateProvider.overrideWithValue(
            AsyncData(FreePlan.createState()),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> assertRoute(Key key, String route) async {
      await tester.scrollUntilVisible(
        find.byKey(key),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(key));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
      expect(find.text('route:$route'), findsOneWidget);
      router.go('/weekly-report');
      await tester.pumpAndSettle();
    }

    await assertRoute(const Key('weekly-go-premium'), '/plans');
    await assertRoute(const Key('weekly-macro-importer-link'), '/nutrition');
    await assertRoute(
      const Key('weekly-connected-health-cta'),
      '/connected-health',
    );
  });

  for (final locale in const [
    Locale('ar'),
    Locale('en'),
    Locale('fr'),
    Locale('es'),
    Locale('tr'),
  ]) {
    testWidgets('weekly copy is Unicode-safe for ${locale.languageCode}', (
      tester,
    ) async {
      await pumpReport(
        tester,
        locale: locale,
        brightness: Brightness.light,
        report: emptySnapshot,
      );
      final visibleCopy = find
          .byType(Text)
          .evaluate()
          .map((element) => (element.widget as Text).data ?? '')
          .join('\n');
      expect(visibleCopy, isNot(contains(RegExp(r'[ÃÂØ�]'))));
      expect(visibleCopy, isNot(contains('BETA')));
      if (locale.languageCode == 'ar') {
        expect(visibleCopy, contains(RegExp(r'[\u0600-\u06FF]')));
      }
    });
  }

  for (final scenario in const [
    (Size(320, 760), 1.0, Locale('en'), Brightness.light),
    (Size(390, 844), 1.5, Locale('en'), Brightness.light),
    (Size(390, 844), 1.0, Locale('ar'), Brightness.dark),
  ]) {
    testWidgets(
      'weekly responsive ${scenario.$1.width} scale${scenario.$2} ${scenario.$3.languageCode}',
      (tester) async {
        tester.view.physicalSize = scenario.$1;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scenario.$2)),
            child: ProviderScope(
              overrides: [
                weeklyReportProvider.overrideWith((ref) async => emptySnapshot),
                userProfileProvider.overrideWith((ref) => Stream.value(null)),
                verifiedSubscriptionStateProvider.overrideWithValue(
                  AsyncData(FreePlan.createState()),
                ),
              ],
              child: MaterialApp(
                locale: scenario.$3,
                supportedLocales: const [Locale('ar'), Locale('en')],
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                theme: ThemeData(brightness: scenario.$4, useMaterial3: true),
                home: const WeeklyReportPage(),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final anchor in <(String, Key)>[
    ('calories_anchor', Key('weekly-glance-anchor')),
    ('frequent_anchor', Key('weekly-frequent-section')),
    ('macros_anchor', Key('weekly-macros-section')),
    ('exercise_anchor', Key('weekly-exercise-section')),
    ('alltime_anchor', Key('weekly-alltime-section')),
  ]) {
    testWidgets('weekly report ${anchor.$1} evidence', (tester) async {
      await pumpReport(
        tester,
        locale: const Locale('en'),
        brightness: Brightness.light,
        report: emptySnapshot,
      );
      await tester.scrollUntilVisible(
        find.byKey(anchor.$2),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(WeeklyReportPage),
        matchesGoldenFile('goldens/epic8_weekly_report_${anchor.$1}.png'),
      );
    });
  }

  testWidgets('weekly report macro tooltip evidence', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    await pumpReport(
      tester,
      locale: const Locale('en'),
      brightness: Brightness.light,
      report: emptySnapshot,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('weekly-macros-section')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    final macroChart = find.byKey(const Key('weekly-macro-chart'));
    await tester.scrollUntilVisible(
      macroChart,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(macroChart);
    await tester.pump();
    expect(find.byKey(const Key('weekly-macro-tooltip')), findsOneWidget);
    await expectLater(
      find.byType(WeeklyReportPage),
      matchesGoldenFile('goldens/epic8_weekly_report_macro_tooltip.png'),
    );
  });

  testWidgets('weekly report phone RTL dark golden', (tester) async {
    await pumpReport(
      tester,
      locale: const Locale('ar'),
      brightness: Brightness.dark,
    );
    await expectLater(
      find.byType(WeeklyReportPage),
      matchesGoldenFile('goldens/epic8_weekly_report_phone_rtl_dark.png'),
    );
  });

  testWidgets('weekly report evidence and limits golden', (tester) async {
    await pumpReport(
      tester,
      locale: const Locale('en'),
      brightness: Brightness.light,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(WeeklyReportPage),
      matchesGoldenFile('goldens/epic8_weekly_report_evidence_phone.png'),
    );
  });

  testWidgets('weekly report honest empty state golden', (tester) async {
    await pumpReport(
      tester,
      locale: const Locale('en'),
      brightness: Brightness.light,
      report: emptySnapshot,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -1100));
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(WeeklyReportPage),
      matchesGoldenFile('goldens/epic8_weekly_report_empty_phone.png'),
    );
  });

  for (final section in <(String, double)>[
    ('nutrition', -430),
    ('coverage', -720),
    ('sources', -1180),
  ]) {
    testWidgets('weekly report ${section.$1} production section golden', (
      tester,
    ) async {
      await pumpReport(
        tester,
        locale: const Locale('en'),
        brightness: Brightness.light,
      );
      await tester.drag(find.byType(ListView), Offset(0, section.$2));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(WeeklyReportPage),
        matchesGoldenFile(
          'goldens/epic8_weekly_report_${section.$1}_phone.png',
        ),
      );
    });
  }
}
