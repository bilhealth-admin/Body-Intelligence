import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/analytics/weekly_report_engine.dart';
import 'package:body_intelligence_log/features/analytics/weekly_report_page.dart';
import 'package:body_intelligence_log/features/analytics/weekly_report_provider.dart';
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
}
