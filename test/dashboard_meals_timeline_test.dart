import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_meals_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Today meal timeline exposes all meal types and fast entry', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SingleChildScrollView(
            child: DashboardMealsTimeline(
              meals: const [],
              onOpenDiary: () => opened++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final meal in ['Breakfast', 'Lunch', 'Dinner', 'Snack']) {
      expect(find.text(meal), findsOneWidget);
    }
    await tester.tap(find.text('Breakfast'));
    await tester.pumpAndSettle();
    expect(find.text('Add food'), findsOneWidget);
    await tester.tap(find.text('Add food'));
    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });
}
