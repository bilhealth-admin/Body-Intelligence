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
    String? openedType;
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
              onOpenMeal: (type) {
                opened++;
                openedType = type;
              },
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
    expect(openedType, 'breakfast');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'usual breakfast requires one action plus explicit confirmation',
    (tester) async {
      var requested = 0;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: DashboardMealsTimeline(
            meals: const [],
            onOpenMeal: (_) {},
            usualBreakfastAvailable: true,
            onRepeatBreakfast: () => requested++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Repeat usual breakfast'));
      expect(requested, 1);
    },
  );

  testWidgets('recent breakfast action is shown when usual is unavailable', (
    tester,
  ) async {
    var recentRequested = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: DashboardMealsTimeline(
          meals: const [],
          onOpenMeal: (_) {},
          recentBreakfastAvailable: true,
          onRepeatRecentBreakfast: () => recentRequested++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Repeat last breakfast'), findsOneWidget);
    await tester.tap(find.text('Repeat last breakfast'));
    expect(recentRequested, 1);
  });
}
