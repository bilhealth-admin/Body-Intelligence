import 'dart:async';
import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/daily_log/daily_log_page.dart';
import 'package:body_intelligence_log/features/foods/providers/food_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:drift/native.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/daily_log/presentation/daily_log_meals_list.dart';
import 'package:body_intelligence_log/features/daily_log/presentation/daily_log_summary_widgets.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in ['en', 'ar']) {
    for (final width in [320.0, 430.0]) {
      testWidgets('Today shell at $width with large text in $locale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              verifiedSubscriptionAccessProvider.overrideWithValue(
                AsyncData(FreePlan.createState()),
              ),
              diaryMealNamesProvider.overrideWithValue(
                const AsyncData([null, null, null, null]),
              ),
            ],
            child: MaterialApp(
              locale: Locale(locale),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: Scaffold(
                body: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    DiaryDateNavigator(
                      date: DateTime(2026, 9, 20),
                      arabic: locale == 'ar',
                      onPrevious: () {},
                      onNext: () {},
                      onPick: () {},
                    ),
                    DailyLogSnapshot(
                      arabic: locale == 'ar',
                      meals: const [],
                      water: const [],
                      calorieGoal: 2000,
                    ),
                    DailyMealsList(
                      arabic: locale == 'ar',
                      meals: const AsyncData([]),
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
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('rapid date taps retain shell and reject a late old-day result', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final initialDate = DateTime(2026, 8, 14);
    final requests = <DateTime, StreamController<List<MealWithItems>>>{};
    addTearDown(() async {
      for (final controller in requests.values) {
        await controller.close();
      }
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          seedCatalogProvider.overrideWith((ref) async {}),
          foodsProvider.overrideWithValue(const AsyncData([])),
          userProfileProvider.overrideWithValue(const AsyncData(null)),
          verifiedSubscriptionAccessProvider.overrideWithValue(
            AsyncData(FreePlan.createState()),
          ),
          verifiedSubscriptionStateProvider.overrideWithValue(
            AsyncData(FreePlan.createState()),
          ),
          selectedLogDateProvider.overrideWith((ref) => initialDate),
          dailyMealsProvider.overrideWith((ref) {
            final date = ref.watch(selectedLogDateProvider);
            final controller = StreamController<List<MealWithItems>>();
            requests[date] = controller;
            return controller.stream;
          }),
          dailyWaterProvider.overrideWithValue(const AsyncData([])),
          selectedDailyLogProvider.overrideWithValue(const AsyncData(null)),
          diaryMealNamesProvider.overrideWithValue(
            const AsyncData([null, null, null, null]),
          ),
        ],
        child: _localizedApp(const DailyLogPage()),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DailyLogPage)),
    );
    requests[initialDate]!.add([]);
    await tester.pumpAndSettle();
    final pageState = tester.state(find.byType(DailyLogPage));
    final previous = find.byKey(const Key('daily-log-previous'));
    await tester.tap(previous);
    await tester.pump();
    final intermediate = initialDate.subtract(const Duration(days: 1));
    final oldRequest = requests[intermediate]!;
    // Deliberately no intervening frame: callbacks must read the current date.
    await tester.tap(previous);
    await tester.tap(previous);
    await tester.pumpAndSettle();
    final finalDate = initialDate.subtract(const Duration(days: 3));
    expect(container.read(selectedLogDateProvider), finalDate);
    expect(
      identical(pageState, tester.state(find.byType(DailyLogPage))),
      isTrue,
    );
    expect(find.byType(DiaryDateNavigator), findsOneWidget);
    final summary = tester.widget<DailyLogSnapshot>(
      find.byKey(const Key('daily-log-today-summary')),
    );
    expect(summary.loading, isTrue);
    expect(
      summary.meals,
      isEmpty,
      reason: 'Never label old totals as new date',
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    requests[finalDate]!.add([]);
    await tester.pumpAndSettle();
    oldRequest.addError(StateError('late abandoned date'));
    await tester.pumpAndSettle();
    expect(container.read(selectedLogDateProvider), finalDate);
    expect(container.read(dailyMealsProvider).hasError, isFalse);
    expect(container.read(dailyMealsProvider).isLoading, isFalse);
    expect(find.byKey(const Key('daily-meal-card-breakfast')), findsOneWidget);
    final headerTop = tester.getTopLeft(find.byType(DiaryDateNavigator));
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byType(DiaryDateNavigator)),
      headerTop,
      reason: 'The reference date header stays visible while Today scrolls',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
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
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(const Key('daily-log-previous')),
              matching: find.byType(Icon),
            ),
          )
          .icon,
      Icons.chevron_left_rounded,
    );
    await tester.tap(find.byKey(const Key('daily-log-previous')));
    expect(selected, DateTime(2026, 9, 19));
    await tester.tap(find.byKey(const Key('daily-log-next')));
    expect(selected, DateTime(2026, 9, 20));

    await pumpNavigator(TextDirection.rtl);
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(const Key('daily-log-previous')),
              matching: find.byType(Icon),
            ),
          )
          .icon,
      Icons.chevron_left_rounded,
    );
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(const Key('daily-log-next')),
              matching: find.byType(Icon),
            ),
          )
          .icon,
      Icons.chevron_right_rounded,
      reason: 'Material mirrors both glyphs once for RTL',
    );
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
          verifiedSubscriptionAccessProvider.overrideWithValue(
            AsyncData(FreePlan.createState()),
          ),
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
