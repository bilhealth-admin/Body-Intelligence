import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/nutrition_goal_schedule_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/daily_log/daily_log_page.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/foods/providers/food_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

// Delay only completion of the real SQLite transaction. Recognition, copying,
// rollback, ownership and the public widget actions still use production code.
class _HeldCommit extends QueryInterceptor {
  bool holdNext = false;
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    if (holdNext) {
      holdNext = false;
      entered.complete();
      await release.future;
    }
    await super.commitTransaction(inner);
  }
}

final _repository = StateProvider<MealRepository>(
  (ref) => throw UnimplementedError(),
);
final _chosenDay = DateTime(2026, 1, 1, 23, 30);
DateTime _day(DateTime day, int offset) =>
    DateTime(day.year, day.month, day.day + offset);

const _closedCopy = {
  'en': 'Reopen the completed diary before copying meals.',
  'ar': 'أعد فتح اليوميات المكتملة قبل نسخ الوجبات.',
  'fr': 'Rouvrez le journal terminé avant de copier les repas.',
  'es': 'Vuelve a abrir el diario completado antes de copiar las comidas.',
  'tr': 'Öğünleri kopyalamadan önce tamamlanan günlüğü yeniden açın.',
};
const _failedCopy = {
  'en': 'Meals could not be copied. Nothing was changed.',
  'ar': 'تعذر نسخ الوجبات. لم يتغير شيء.',
  'fr': 'Les repas n’ont pas pu être copiés. Rien n’a été modifié.',
  'es': 'No se pudieron copiar las comidas. No se cambió nada.',
  'tr': 'Öğünler kopyalanamadı. Hiçbir şey değiştirilmedi.',
};

const _emptyCopy = {
  'en': 'There were no meals to copy.',
  'ar': 'لا توجد وجبات لنسخها.',
  'fr': 'Il n’y avait aucun repas à copier.',
  'es': 'No había comidas para copiar.',
  'tr': 'Kopyalanacak öğün yoktu.',
};

Future<void> _drain(WidgetTester tester) async {
  for (var frame = 0; frame < 10; frame++) {
    await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _seed(AppDatabase database, DateTime day) async {
  await MealRepository(database).addQuickMacroEntry(
    date: day,
    mealType: 'breakfast',
    calories: 174,
    protein: 10,
    carbohydrates: 20,
    fat: 6,
    caloriesKnown: true,
    proteinKnown: true,
    carbohydratesKnown: true,
    fatKnown: true,
  );
}

Future<List<Object?>> _rows(AppDatabase database) async => [
  for (final row in await database.select(database.meals).get()) row.toJson(),
  for (final row in await database.select(database.mealItems).get())
    row.toJson(),
];

Future<ProviderContainer> _mount(
  WidgetTester tester,
  AppDatabase database, {
  String locale = 'en',
}) async {
  tester.view.physicalSize = const Size(1000, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repository = MealRepository(database);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        _repository.overrideWith((ref) => repository),
        mealRepositoryProvider.overrideWith((ref) => ref.watch(_repository)),
        selectedLogDateProvider.overrideWith((ref) => _chosenDay),
        seedCatalogProvider.overrideWith((ref) async {}),
        foodsProvider.overrideWithValue(const AsyncData([])),
        userProfileProvider.overrideWithValue(const AsyncData(null)),
        verifiedSubscriptionAccessProvider.overrideWithValue(
          AsyncData(FreePlan.createState()),
        ),
        verifiedSubscriptionStateProvider.overrideWithValue(
          AsyncData(FreePlan.createState()),
        ),
        dailyMealsProvider.overrideWithValue(const AsyncData([])),
        dailyWaterProvider.overrideWithValue(const AsyncData([])),
        selectedDailyLogProvider.overrideWithValue(const AsyncData(null)),
        diaryMealNamesProvider.overrideWithValue(
          const AsyncData([null, null, null, null]),
        ),
        nutritionGoalScheduleProvider.overrideWithValue(
          const AsyncData(NutritionGoalSchedule()),
        ),
        for (final key in const [
          'diary.foodInsights',
          'diary.showAllMeals',
          'diary.showFoodTimestamps',
          'diary.useNetCarbs',
          'diary.alwaysShowWater',
        ])
          dailyLogPreferenceProvider(
            key,
          ).overrideWithValue(const AsyncData(false)),
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
        home: const DailyLogPage(),
      ),
    ),
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await _drain(tester);
  });
  await _drain(tester);
  return ProviderScope.containerOf(tester.element(find.byType(DailyLogPage)));
}

Future<void> _openConfirm(WidgetTester tester, {required bool multiple}) async {
  final copy = find.byKey(const Key('daily-log-action-copy'));
  await tester.ensureVisible(copy);
  await tester.tap(copy);
  await _drain(tester);
  final sheet = find.byType(BottomSheet);
  expect(sheet, findsOneWidget);
  final options = find.descendant(of: sheet, matching: find.byType(ListTile));
  expect(options, findsNWidgets(2));
  await tester.tap(options.at(multiple ? 1 : 0));
  for (
    var attempt = 0;
    attempt < 20 && find.bySubtype<AlertDialog>().evaluate().isEmpty;
    attempt++
  ) {
    await _drain(tester);
  }
  expect(find.bySubtype<AlertDialog>(), findsOneWidget);
}

Future<void> _confirm(WidgetTester tester) async {
  await tester.tap(
    find
        .descendant(
          of: find.bySubtype<AlertDialog>(),
          matching: find.byType(FilledButton),
        )
        .first,
  );
  await _drain(tester);
}

void _copyTest(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await _drain(tester);
    }
  });
}

void main() {
  for (final locale in _closedCopy.keys) {
    _copyTest('Copy from shows real closed-day refusal in $locale', (
      tester,
    ) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await _seed(database, _day(_chosenDay, -1));
      final daily = DailyLogRepository(database);
      await daily.startDay(_day(_chosenDay, 0));
      await daily.closeDay(_day(_chosenDay, 0));
      final before = await _rows(database);
      await _mount(tester, database, locale: locale);
      await _openConfirm(tester, multiple: false);
      await _confirm(tester);
      expect(find.text(_closedCopy[locale]!), findsOneWidget);
      expect(await _rows(database), before);
      expect(tester.takeException(), isNull);
    });
    _copyTest(
      'Choose days classifies actual invalid-food StateError in $locale',
      (tester) async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);
        await _seed(database, _chosenDay);
        final source = (await database.select(database.mealItems).get()).single;
        await (database.update(database.foods)
              ..where((food) => food.id.equals(source.foodId)))
            .write(FoodsCompanion(deletedAt: Value(DateTime(2026, 1, 2))));
        final before = await _rows(database);
        await _mount(tester, database, locale: locale);
        await _openConfirm(tester, multiple: true);
        await _confirm(tester);
        expect(find.text(_failedCopy[locale]!), findsOneWidget);
        expect(find.textContaining('already has meals'), findsNothing);
        expect(await _rows(database), before);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final locale in _emptyCopy.keys) {
    _copyTest(
      'Choose days reports an empty source instead of false success in $locale',
      (tester) async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);
        await MealRepository(database).createMeal(
          date: _chosenDay,
          name: 'Visited empty breakfast',
          type: 'breakfast',
        );
        final before = await _rows(database);
        await _mount(tester, database, locale: locale);
        await _openConfirm(tester, multiple: true);
        await _confirm(tester);
        expect(find.text(_emptyCopy[locale]!), findsOneWidget);
        expect(find.textContaining('Diary copied'), findsNothing);
        expect(await _rows(database), before);
        expect(tester.takeException(), isNull);
      },
    );
  }

  _copyTest(
    'Choose days reports a real closed destination without changing any day',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await _seed(database, _chosenDay);
      final daily = DailyLogRepository(database);
      await daily.startDay(_day(_chosenDay, 1));
      await daily.closeDay(_day(_chosenDay, 1));
      final before = await _rows(database);
      await _mount(tester, database);
      await _openConfirm(tester, multiple: true);
      await _confirm(tester);
      expect(find.text(_closedCopy['en']!), findsOneWidget);
      expect(await _rows(database), before);
      expect(tester.takeException(), isNull);
    },
  );
  _copyTest(
    'Copy from classifies actual invalid food separately from occupied',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await _seed(database, _day(_chosenDay, -1));
      final item = (await database.select(database.mealItems).get()).single;
      await (database.update(database.foods)
            ..where((food) => food.id.equals(item.foodId)))
          .write(FoodsCompanion(deletedAt: Value(DateTime(2026, 1, 2))));
      final before = await _rows(database);
      await _mount(tester, database);
      await _openConfirm(tester, multiple: false);
      await _confirm(tester);
      expect(find.text(_failedCopy['en']!), findsOneWidget);
      expect(find.textContaining('already has meals'), findsNothing);
      expect(await _rows(database), before);
      expect(tester.takeException(), isNull);
    },
  );

  for (final multiple in [false, true]) {
    for (final change in ['repository', 'date']) {
      _copyTest(
        'copy multiple=$multiple retires changed $change before confirmation',
        (tester) async {
          final first = AppDatabase.forTesting(NativeDatabase.memory());
          final second = AppDatabase.forTesting(NativeDatabase.memory());
          addTearDown(first.close);
          addTearDown(second.close);
          for (final database in [first, second]) {
            await _seed(database, multiple ? _chosenDay : _day(_chosenDay, -1));
            await _seed(database, _day(_chosenDay, 10));
          }
          final beforeFirst = await _rows(first);
          final beforeSecond = await _rows(second);
          final container = await _mount(tester, first);
          await _openConfirm(tester, multiple: multiple);
          if (change == 'repository') {
            container.read(_repository.notifier).state = MealRepository(second);
          } else {
            container.read(selectedLogDateProvider.notifier).state = _day(
              _chosenDay,
              10,
            );
          }
          await tester.pump();
          await _confirm(tester);
          expect(await _rows(first), beforeFirst);
          expect(await _rows(second), beforeSecond);
          expect(find.byType(SnackBar), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
    _copyTest(
      'copy multiple=$multiple suppresses stale feedback after a pending commit',
      (tester) async {
        final held = _HeldCommit();
        final first = AppDatabase.forTesting(
          NativeDatabase.memory().interceptWith(held),
        );
        final second = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(first.close);
        addTearDown(second.close);
        await _seed(first, multiple ? _chosenDay : _day(_chosenDay, -1));
        final container = await _mount(tester, first);
        await _openConfirm(tester, multiple: multiple);
        held.holdNext = true;
        try {
          await tester.tap(
            find
                .descendant(
                  of: find.bySubtype<AlertDialog>(),
                  matching: find.byType(FilledButton),
                )
                .first,
          );
          for (var turn = 0; turn < 30 && !held.entered.isCompleted; turn++) {
            await _drain(tester);
          }
          expect(
            held.entered.isCompleted,
            isTrue,
            reason:
                'The real transaction has reached its held commit boundary.',
          );
          if (multiple) {
            container.read(selectedLogDateProvider.notifier).state = _day(
              _chosenDay,
              10,
            );
          } else {
            container.read(_repository.notifier).state = MealRepository(second);
          }
          held.release.complete();
          await _drain(tester);
          final oldMeals = await first.select(first.meals).get();
          expect(
            oldMeals,
            hasLength(multiple ? 3 : 2),
            reason:
                'The admitted commit stays bound to its original repository and dates.',
          );
          expect(await second.select(second.meals).get(), isEmpty);
          expect(find.byType(SnackBar), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          if (!held.release.isCompleted) held.release.complete();
          await _drain(tester);
        }
      },
    );
    _copyTest(
      'copy multiple=$multiple reports only typed occupied-day conflict',
      (tester) async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);
        await _seed(database, multiple ? _chosenDay : _day(_chosenDay, -1));
        await _seed(database, _day(_chosenDay, multiple ? 1 : 0));
        final before = await _rows(database);
        await _mount(tester, database);
        await _openConfirm(tester, multiple: multiple);
        await _confirm(tester);
        expect(find.textContaining('already has meals'), findsOneWidget);
        expect(await _rows(database), before);
        expect(tester.takeException(), isNull);
      },
    );
    _copyTest(
      'copy multiple=$multiple succeeds across calendar year boundary',
      (tester) async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);
        await _seed(database, multiple ? _chosenDay : _day(_chosenDay, -1));
        await _mount(tester, database);
        await _openConfirm(tester, multiple: multiple);
        await _confirm(tester);
        expect(
          find.text(
            multiple
                ? 'Diary copied to 2 days.'
                : '1 meals copied after your confirmation.',
          ),
          findsOneWidget,
        );
        final meals = await database.select(database.meals).get();
        final destinations = multiple
            ? [_day(_chosenDay, 1), _day(_chosenDay, 2)]
            : [_day(_chosenDay, 0)];
        for (final day in destinations) {
          final meal = meals.singleWhere(
            (meal) => DateUtils.isSameDay(meal.date, day),
          );
          expect(meal.date, day);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
