import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/daily_log/presentation/daily_log_meals_list.dart';

void main() {
  testWidgets('empty Foods in this meal plus invokes the add-food callback', (
    tester,
  ) async {
    var called = 0;
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
          body: DailyMealDetailItems(
            meal: null,
            onEdit: (_, _) async {},
            onActions: (_, _) async {},
            onAddFood: () => called++,
          ),
        ),
      ),
    );
    // MaterialApp's localization delegate resolves asynchronously.
    await tester.pumpAndSettle();
    final plus = find.byKey(const Key('daily-meal-empty-add-food'));
    expect(plus, findsOneWidget);
    expect(tester.widget<IconButton>(plus).onPressed, isNotNull);
    await tester.tap(plus);
    await tester.pump();
    expect(called, 1);
    expect(tester.takeException(), isNull);
  });
}
