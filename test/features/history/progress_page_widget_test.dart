import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/body_measurement_repository.dart';
import 'package:body_intelligence_log/features/history/progress_page.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/weight/providers/weight_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

void main() {
  test('verified connected step history feeds progress without daily logs', () {
    final day = DateTime(2026, 9, 27, 23, 15);
    final values = progressMergedStepValues(
      const <DailyLog>[],
      ConnectedHealthSnapshot(
        status: ConnectedHealthStatus.synchronized,
        platformSource: 'Apple Health',
        availableSources: const ['Apple Health'],
        signals: const [],
        importedCount: 1,
        lastSyncAt: day,
        failureCode: null,
        deviceVerified: true,
        stepHistory: [
          ConnectedHealthSignalView(
            key: 'steps',
            value: 4321,
            unit: 'count',
            source: 'Apple Health',
            observedAt: day,
            confidence: 1,
          ),
        ],
      ),
    );

    expect(values[DateTime(2026, 9, 27)], 4321);
  });

  testWidgets('metric and date range use accessible bottom pickers', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressDailyLogsProvider.overrideWith((_) => Stream.value([])),
          weightHistoryProvider.overrideWith((_) => Stream.value([])),
          bodyMeasurementHistoryProvider.overrideWith((_) => Stream.value([])),
          measurementSystemProvider.overrideWith(
            (_) => Stream.value(MeasurementSystem.metric),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: ProgressPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('progress-metric-selector')));
    await tester.pumpAndSettle();
    expect(find.text('Select a measurement'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Waist'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Waist'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('progress-empty-add')), findsOneWidget);

    await tester.tap(find.byKey(const Key('progress-range-selector')));
    await tester.pumpAndSettle();
    expect(find.text('Select a date range'), findsOneWidget);
    expect(find.text('1m'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('All'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('All'), findsOneWidget);
  });

  testWidgets('each circumference is entered in analytics and keeps the day', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final today = DateTime(2026, 9, 27);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          progressDailyLogsProvider.overrideWith((_) => Stream.value([])),
          weightHistoryProvider.overrideWith((_) => Stream.value([])),
          measurementSystemProvider.overrideWith(
            (_) => Stream.value(MeasurementSystem.metric),
          ),
          progressClockProvider.overrideWithValue(() => today),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: ProgressPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> chooseMetric(String label) async {
      await tester.tap(find.byKey(const Key('progress-metric-selector')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(label),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    Future<void> addValue(String value) async {
      await tester.tap(find.byKey(const Key('progress-empty-add')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('measurement-entry-value')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('measurement-entry-value')),
        value,
      );
      await tester.tap(find.byKey(const Key('measurement-entry-save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
    }

    await chooseMetric('Waist');
    await addValue('88.4');
    expect(find.byKey(const Key('progress-real-series-chart')), findsOneWidget);
    expect(find.text('88.4 cm'), findsWidgets);

    await chooseMetric('Neck');
    await addValue('37.2');
    final saved = await BodyMeasurementRepository(database).getForDay(today);
    expect(saved?.waistCm, 88.4);
    expect(saved?.neckCm, 37.2);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await database.close();
    await tester.pump(const Duration(milliseconds: 1));
  });
}
