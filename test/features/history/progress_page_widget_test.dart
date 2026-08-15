import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/features/history/progress_page.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/weight/providers/weight_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
