import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/analytics/weekly_report_engine.dart';
import 'package:body_intelligence_log/features/analytics/weekly_report_page.dart';
import 'package:body_intelligence_log/features/analytics/weekly_report_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
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

  testWidgets('weekly report arrows use RTL direction without changing dates', (
    tester,
  ) async {
    final today = DateTime(2026, 8, 11);
    final report = const WeeklyReportEngine().build(
      asOf: today,
      nutrition: const [],
      water: const [],
      weights: const [],
      mealCount: 0,
    );

    Future<ProviderContainer> pump(Locale locale) async {
      final container = ProviderContainer(
        overrides: [
          weeklyReportClockProvider.overrideWithValue(() => today),
          weeklyReportProvider.overrideWith((ref) async => report),
          accountCreatedAtProvider.overrideWithValue(null),
          userProfileProvider.overrideWith((ref) => Stream.value(null)),
          verifiedSubscriptionStateProvider.overrideWithValue(
            AsyncData(FreePlan.createState()),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const WeeklyReportPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    final ltr = await pump(const Locale('en'));
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(const Key('weekly-report-previous')),
              matching: find.byType(Icon),
            ),
          )
          .icon,
      Icons.chevron_left_rounded,
    );
    await tester.tap(find.byKey(const Key('weekly-report-previous')));
    expect(ltr.read(selectedWeeklyReportDateProvider), DateTime(2026, 8, 4));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final rtl = await pump(const Locale('ar'));
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(const Key('weekly-report-previous')),
              matching: find.byType(Icon),
            ),
          )
          .icon,
      Icons.chevron_right_rounded,
    );
    await tester.tap(find.byKey(const Key('weekly-report-previous')));
    expect(rtl.read(selectedWeeklyReportDateProvider), DateTime(2026, 8, 4));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('weekly report error exposes a working retry action', (
    tester,
  ) async {
    final today = DateTime(2026, 8, 11);
    final report = const WeeklyReportEngine().build(
      asOf: today,
      nutrition: const [],
      water: const [],
      weights: const [],
      mealCount: 0,
    );
    var attempts = 0;
    final container = ProviderContainer(
      overrides: [
        weeklyReportClockProvider.overrideWithValue(() => today),
        weeklyReportProvider.overrideWith((ref) async {
          attempts += 1;
          if (attempts == 1) throw StateError('temporary read failure');
          return report;
        }),
        accountCreatedAtProvider.overrideWithValue(null),
        userProfileProvider.overrideWith((ref) => Stream.value(null)),
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
    expect(find.byKey(const Key('weekly-report-retry')), findsOneWidget);
    await tester.tap(find.byKey(const Key('weekly-report-retry')));
    await tester.pumpAndSettle();
    expect(attempts, greaterThanOrEqualTo(2));
    expect(find.byKey(const Key('weekly-report-retry')), findsNothing);
  });
}
