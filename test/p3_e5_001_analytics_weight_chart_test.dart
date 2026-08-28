import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/features/analytics/analytics_page.dart';
import 'package:body_intelligence_log/features/analytics/widgets/analytics_range_selector.dart';
import 'package:body_intelligence_log/features/analytics/widgets/analytics_weight_trend_chart.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_provider.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/life_context/providers/life_context_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/weight/providers/weight_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget analyticsApp({List<WeightEntry> weights = const []}) => ProviderScope(
    overrides: [
      weightHistoryProvider.overrideWith((ref) => Stream.value(weights)),
      allMealsProvider.overrideWith(
        (ref) => Stream.value(const <MealWithItems>[]),
      ),
      allWaterProvider.overrideWith((ref) => Stream.value(<WaterEntry>[])),
      dashboardDailyLogsProvider.overrideWith(
        (ref) => Stream.value(<DailyLog>[]),
      ),
      insightLifeContextProvider.overrideWith(
        (ref) => Stream.value(<LifeContextEntry>[]),
      ),
      measurementSystemProvider.overrideWith(
        (ref) => Stream.value(MeasurementSystem.metric),
      ),
      userProfileProvider.overrideWith((ref) => Stream.value(null)),
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
      home: AnalyticsPage(),
    ),
  );

  testWidgets(
    'P3-E5-001 weight chart explains measured scope, trend sufficiency, and safe limits',
    (tester) async {
      await tester.pumpWidget(analyticsApp());
      await tester.pumpAndSettle();

      expect(find.text('Analytics overview'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining(
          'A personal comparison needs at least 7 earlier and 3 recent days',
        ),
        420,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining(
          'A personal comparison needs at least 7 earlier and 3 recent days',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'No population average is substituted for your missing data.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('P3-E7-002 analytics range change keeps premium continuity', (
    tester,
  ) async {
    await tester.pumpWidget(analyticsApp());
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        ValueKey<String>('analytics-range-${AnalyticsRange.thirtyDays.name}'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('7 days'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        ValueKey<String>('analytics-range-${AnalyticsRange.sevenDays.name}'),
      ),
      findsOneWidget,
    );
    expect(find.text('Analytics overview'), findsOneWidget);
  });

  testWidgets('all-time weight chart keeps the real first measurement', (
    tester,
  ) async {
    final now = DateTime(2026, 8, 23);
    final chronological = List<WeightEntry>.generate(40, (index) {
      final date = now.subtract(Duration(days: 39 - index));
      return WeightEntry(
        id: index + 1,
        uuid: 'weight-${index + 1}',
        date: date,
        dayKey: date.toIso8601String().split('T').first,
        weight: 123 - index.toDouble(),
        measurementContext: 'morning',
        createdAt: date,
        updatedAt: date,
        revision: 1,
        syncStatus: 'synced',
      );
    });

    // The repository contract is newest first.
    await tester.pumpWidget(
      analyticsApp(weights: chronological.reversed.toList()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    expect(find.text('123.0 kg'), findsWidgets);
    expect(find.text('84.0 kg'), findsWidgets);
    expect(find.text('Change'), findsOneWidget);
    expect(
      find.textContaining('40 measurements across 39 days'),
      findsOneWidget,
    );
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets(
      'premium weight chart fits ${locale.toLanguageTag()} at 390x844 and 160%',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final dates = [
          DateTime(2026, 2, 9),
          DateTime(2026, 5, 22),
          DateTime(2026, 8, 20),
        ];
        final entries = <WeightEntry>[
          for (var index = 0; index < dates.length; index++)
            WeightEntry(
              id: index + 1,
              uuid: 'visual-weight-$index',
              date: dates[index],
              dayKey: dates[index].toIso8601String().split('T').first,
              weight: [123.0, 98.9, 89.2][index],
              measurementContext: 'morning',
              createdAt: dates[index],
              updatedAt: dates[index],
              revision: 1,
              syncStatus: 'synced',
            ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(
                  size: Size(390, 844),
                  textScaler: TextScaler.linear(1.6),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AnalyticsWeightTrendChart(
                    weights: entries,
                    system: MeasurementSystem.metric,
                    rangeLabel: '09/02/2026 – 20/08/2026',
                    targetWeightKg: 75,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnalyticsWeightTrendChart), findsOneWidget);
      },
    );
  }
}
