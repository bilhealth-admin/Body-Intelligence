import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/daily_log/presentation/daily_log_meals_list.dart';
import 'package:body_intelligence_log/features/daily_log/presentation/daily_log_summary_widgets.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('meal planner remains a contextual action on each meal card', () {
    final source = File(
      'lib/features/daily_log/presentation/daily_log_meals_list.dart',
    ).readAsStringSync();
    expect(source, contains("Key('daily-meal-planner-\$type')"));
    expect(source, contains("context.push('/meal-planner')"));
  });

  testWidgets('previous and next keep date truth in LTR and RTL', (
    tester,
  ) async {
    var selected = DateTime(2026, 9, 20);

    Future<void> pumpNavigator(TextDirection direction) async {
      await tester.pumpWidget(
        _localizedApp(
          Directionality(
            textDirection: direction,
            child: Scaffold(
              body: DiaryDateNavigator(
                date: selected,
                arabic: direction == TextDirection.rtl,
                onPrevious: () =>
                    selected = selected.subtract(const Duration(days: 1)),
                onNext: () => selected = selected.add(const Duration(days: 1)),
                onPick: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pumpNavigator(TextDirection.ltr);
    await tester.tap(find.byKey(const Key('daily-log-previous')));
    expect(selected, DateTime(2026, 9, 19));
    await tester.tap(find.byKey(const Key('daily-log-next')));
    expect(selected, DateTime(2026, 9, 20));

    await pumpNavigator(TextDirection.rtl);
    await tester.tap(find.byKey(const Key('daily-log-previous')));
    expect(selected, DateTime(2026, 9, 19));
    await tester.tap(find.byKey(const Key('daily-log-next')));
    expect(selected, DateTime(2026, 9, 20));
  });

  testWidgets('date loading keeps a stable summary and meal shell', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diaryMealNamesProvider.overrideWithValue(
            const AsyncData(<String?>[null, null, null, null]),
          ),
        ],
        child: _localizedApp(
          Scaffold(
            body: ListView(
              children: [
                const DailyLogSnapshot(
                  arabic: false,
                  meals: [],
                  water: [],
                  loading: true,
                  calorieGoal: 2000,
                ),
                DailyMealsList(
                  arabic: false,
                  meals: const AsyncLoading(),
                  onAdd: (_) {},
                  onEdit: (_, _) async {},
                  onActions: (_, _) async {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('daily-summary-calories-loading')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('daily-meal-loading-skeleton')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('empty day still exposes all four meal entry points', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diaryMealNamesProvider.overrideWithValue(
            const AsyncData(<String?>[null, null, null, null]),
          ),
        ],
        child: _localizedApp(
          Scaffold(
            body: DailyMealsList(
              arabic: false,
              meals: const AsyncData([]),
              onAdd: (_) {},
              onEdit: (_, _) async {},
              onActions: (_, _) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    for (final type in const ['breakfast', 'lunch', 'dinner', 'snack']) {
      expect(find.byKey(Key('daily-meal-card-$type')), findsOneWidget);
      expect(find.byKey(Key('daily-meal-log-$type')), findsOneWidget);
    }
  });
}

MaterialApp _localizedApp(Widget home) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: home,
);
